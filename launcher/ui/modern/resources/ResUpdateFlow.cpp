#include "ResUpdateFlow.h"

#include <QTimer>
#include <algorithm>

#include "Application.h"
#include "Json.h"
#include "Markdown.h"
#include "ResFolderModel.h"
#include "ResTask.h"
#include "ResourceDownloadTask.h"
#include "StringUtils.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/mod/ModFolderModel.h"
#include "minecraft/mod/ResourceFolderModel.h"
#include "minecraft/mod/tasks/GetModDependenciesTask.h"
#include "modplatform/EnsureMetadataTask.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/flame/FlameCheckUpdate.h"
#include "modplatform/modrinth/ModrinthCheckUpdate.h"
#include "settings/SettingsObject.h"
#include "tasks/ConcurrentTask.h"
#include "tasks/SequentialTask.h"

namespace {
ModPlatform::ResourceProvider other(ModPlatform::ResourceProvider p)
{
    return p == ModPlatform::ResourceProvider::MODRINTH ? ModPlatform::ResourceProvider::FLAME : ModPlatform::ResourceProvider::MODRINTH;
}
}  // namespace

ResUpdateFlow::ResUpdateFlow(QObject* parent) : QObject(parent) {}

ResUpdateFlow::~ResUpdateFlow() = default;

void ResUpdateFlow::setStage(const QString& s)
{
    m_stage = s;
    emit stageChanged();
}

void ResUpdateFlow::runTask(Task::Ptr task, const QString& title, std::function<void(bool ok)> next)
{
    m_task = ResTaskHandle::run(std::move(task), title, this);
    setStage("running");
    connect(m_task, &ResTaskHandle::done, this, [this, next](bool ok, const QString& error, const QStringList& warnings) {
        if (!warnings.isEmpty()) {
            emit notice(warnings.join("\n"), "warning");
        }
        if (!ok) {
            if (error.isEmpty()) {
                setStage("idle");  // aborted / skipped
            } else {
                m_message = error;
                setStage("error");
            }
            return;
        }
        next(true);
    });
}

void ResUpdateFlow::start(ResFolderModel* folder, bool includeDeps, const QStringList& releaseTypes)
{
    cancel();
    if (!folder || !folder->source() || !folder->instance()) {
        return;
    }
    m_model = folder->source();
    m_instance = folder->instance();
    m_label = folder->isMods() ? tr("mods") : tr("resources");
    m_includeDeps = includeDeps;
    m_releaseTypes = ModPlatform::IndexedVersionType::fromStringList(releaseTypes);
    if (m_releaseTypes.empty()) {
        m_releaseTypes = ModPlatform::IndexedVersionType::fromStringList(
            Json::toStringList(APPLICATION->settings()->get("ModUpdateReleaseTypes").toString()));
    }
    m_loadersList = folder->isMods() ? m_instance->getPackProfile()->getModLoadersList() : QList<ModPlatform::ModLoaderType>{};
    m_mcVersions = { m_instance->getPackProfile()->getComponent("net.minecraft")->getVersion() };

    m_candidates = folder->selectedResources();
    const bool all = m_candidates.isEmpty();
    if (all) {
        m_candidates = m_model->allResources();
    }
    if (m_candidates.isEmpty()) {
        m_message = tr("There is nothing to update.");
        setStage("done");
        return;
    }

    for (auto* c : m_candidates) {
        if (c->status() != ResourceStatus::NoMetadata) {
            onMetadataEnsured(c);
        } else if (c->type() != ResourceType::FOLDER) {
            m_noMetadata << c;
            m_missingNames << c->name();
        }
    }
    if (!m_noMetadata.isEmpty()) {
        setStage("askProvider");
        return;
    }
    checkUpdates();
}

void ResUpdateFlow::chooseProvider(const QString& provider, bool tryOthers)
{
    if (m_stage != "askProvider") {
        return;
    }
    if (provider == "skip") {
        m_noMetadata.clear();
        checkUpdates();
        return;
    }
    generateMetadata(provider == "curseforge" ? ModPlatform::ResourceProvider::FLAME : ModPlatform::ResourceProvider::MODRINTH, tryOthers);
}

void ResUpdateFlow::generateMetadata(ModPlatform::ResourceProvider provider, bool tryOthers)
{
    auto seq = makeShared<SequentialTask>(tr("Looking for metadata"));
    m_secondTry = makeShared<ConcurrentTask>("Second Metadata Search", APPLICATION->settings()->get("NumberOfConcurrentTasks").toInt());
    m_metadataTmp = m_noMetadata;
    auto task = makeShared<EnsureMetadataTask>(m_metadataTmp, m_model->indexDir(), provider);
    connect(task.get(), &EnsureMetadataTask::metadataReady, this, [this](Resource* r) { onMetadataEnsured(r); });
    connect(task.get(), &EnsureMetadataTask::metadataFailed, this,
            [this, tryOthers, provider](Resource* r) { onMetadataFailed(r, tryOthers, provider); });
    if (task->getHashingTask()) {
        seq->addTask(task->getHashingTask());
    }
    seq->addTask(task);
    seq->addTask(m_secondTry);
    runTask(seq, tr("Generating metadata…"), [this](bool) {
        if (!m_failedMetadata.isEmpty()) {
            m_failureList.clear();
            for (const auto& [res, reason] : m_failedMetadata) {
                m_failureList << QVariantMap{ { "name", res->name() }, { "fileName", res->fileinfo().fileName() }, { "reason", reason } };
            }
            setStage("metadataFailed");
            return;
        }
        checkUpdates();
    });
}

void ResUpdateFlow::onMetadataEnsured(Resource* r)
{
    if (!r->metadata() || r->lockUpdate()) {
        return;
    }
    if (r->metadata()->provider == ModPlatform::ResourceProvider::FLAME) {
        m_flameToUpdate << r;
    } else {
        m_modrinthToUpdate << r;
    }
}

void ResUpdateFlow::onMetadataFailed(Resource* r, bool tryOthers, ModPlatform::ResourceProvider first)
{
    if (tryOthers && m_model) {
        auto task = makeShared<EnsureMetadataTask>(r, m_model->indexDir(), other(first));
        connect(task.get(), &EnsureMetadataTask::metadataReady, this, [this](Resource* c) { onMetadataEnsured(c); });
        connect(task.get(), &EnsureMetadataTask::metadataFailed, this,
                [this](Resource* c) { onMetadataFailed(c, false, ModPlatform::ResourceProvider::MODRINTH); });
        if (task->getHashingTask()) {
            auto seq = makeShared<SequentialTask>();
            seq->addTask(task->getHashingTask());
            seq->addTask(task);
            m_secondTry->addTask(seq);
        } else {
            m_secondTry->addTask(task);
        }
        return;
    }
    m_failedMetadata.append({ r, tr("Couldn't find a valid version on the selected mod provider(s)") });
}

void ResUpdateFlow::proceed(bool disableUnavailable)
{
    if (m_stage == "metadataFailed") {
        checkUpdates();
    } else if (m_stage == "checkFailed") {
        if (disableUnavailable) {
            for (const auto& f : m_failedCheck) {
                std::get<0>(f)->enable(EnableAction::DISABLE);
            }
            if (m_model) {
                m_model->update();
            }
        }
        resolveDependencies();
    }
}

void ResUpdateFlow::checkUpdates()
{
    if (!m_model) {
        return;
    }
    if (m_modrinthToUpdate.isEmpty() && m_flameToUpdate.isEmpty()) {
        afterCheck();
        return;
    }
    auto seq = makeShared<SequentialTask>(tr("Checking for updates"));
    auto onFail = [this](Resource* r, const QString& reason, const QUrl& url) { m_failedCheck.append({ r, reason, url }); };
    if (!m_modrinthToUpdate.isEmpty()) {
        m_modrinthCheck.reset(new ModrinthCheckUpdate(m_modrinthToUpdate, m_mcVersions, m_loadersList, m_model, m_releaseTypes));
        connect(m_modrinthCheck.get(), &CheckUpdateTask::checkFailed, this, onFail);
        seq->addTask(m_modrinthCheck);
    }
    if (!m_flameToUpdate.isEmpty()) {
        m_flameCheck.reset(new FlameCheckUpdate(m_flameToUpdate, m_mcVersions, m_loadersList, m_model, m_releaseTypes));
        connect(m_flameCheck.get(), &CheckUpdateTask::checkFailed, this, onFail);
        seq->addTask(m_flameCheck);
    }
    runTask(seq, tr("Checking for updates…"), [this](bool) { afterCheck(); });
}

void ResUpdateFlow::afterCheck()
{
    auto take = [this](CheckUpdateTask* t) {
        if (!t) {
            return;
        }
        for (auto& u : t->getUpdates()) {
            m_items.append(Item{ u, {}, false });
        }
        m_depsSeed.append(t->getDependencies());
    };
    take(m_modrinthCheck.get());
    take(m_flameCheck.get());

    if (!m_failedCheck.isEmpty()) {
        m_failureList.clear();
        for (const auto& [res, reason, url] : m_failedCheck) {
            m_failureList << QVariantMap{ { "name", res->name() }, { "reason", reason }, { "url", url.toString() } };
        }
        setStage("checkFailed");
        return;
    }
    resolveDependencies();
}

void ResUpdateFlow::resolveDependencies()
{
    auto* mods = qobject_cast<ModFolderModel*>(m_model.data());
    if (!m_includeDeps || !mods || !m_instance || APPLICATION->settings()->get("ModDependenciesDisabled").toBool()) {
        finishReview();
        return;
    }
    auto depTask = makeShared<GetModDependenciesTask>(m_instance.data(), mods, m_depsSeed);
    auto* raw = depTask.get();
    runTask(depTask, tr("Checking for dependencies…"), [this, raw](bool) {
        auto extra = raw->getExtraInfo();
        for (const auto& dep : raw->getDependecies()) {
            auto changelog = dep->version.changelog;
            if (dep->pack->provider == ModPlatform::ResourceProvider::FLAME) {
                changelog = FlameAPI::getModFileChangelog(dep->version.addonId.toInt(), dep->version.fileId.toInt());
            }
            auto info = extra.value(dep->version.addonId.toString());
            auto download = makeShared<ResourceDownloadTask>(dep->pack, dep->version, m_model, true, "dependency",
                                                             info.requiredByIds.isEmpty() ? QString() : info.requiredByIds.first());
            CheckUpdateTask::Update u{ dep->pack->name, dep->version.hash, tr("Not installed"), dep->version.version,
                                       dep->version.versionType, changelog, dep->pack->provider, download, !info.maybeInstalled };
            m_items.append(Item{ u, info.requiredByNames, true });
        }
        finishReview();
    });
}

void ResUpdateFlow::finishReview()
{
    if (m_items.isEmpty()) {
        if (m_candidates.size() == 1) {
            m_message = tr("“%1” is up to date.").arg(m_candidates.first()->name());
        } else {
            m_message = tr("All %1 are up to date.").arg(m_label);
        }
        setStage("done");
        return;
    }
    std::ranges::sort(m_items, [](const Item& a, const Item& b) {
        if (a.dependency != b.dependency) {
            return !a.dependency;
        }
        return QString::compare(a.update.name, b.update.name, Qt::CaseInsensitive) < 0;
    });
    setStage("review");
}

QVariantList ResUpdateFlow::updates() const
{
    QVariantList out;
    for (const auto& it : m_items) {
        const auto& u = it.update;
        QString log = u.changelog;
        if (u.provider == ModPlatform::ResourceProvider::MODRINTH) {
            log = markdownToHTML(u.changelog.toUtf8());
        }
        out << QVariantMap{
            { "key", u.name },
            { "name", u.name },
            { "provider", ModPlatform::ProviderCapabilities::readableName(u.provider) },
            { "oldVersion", u.oldVersion },
            { "newVersion", u.newVersion },
            { "versionType", u.newVersionType.has_value() ? u.newVersionType->toString() : QString() },
            { "changelogHtml", StringUtils::htmlListPatch(log) },
            { "requiredBy", it.requiredBy },
            { "dependency", it.dependency },
            { "enabled", u.enabled },
        };
    }
    return out;
}

ResTaskHandle* ResUpdateFlow::install(const QStringList& excludedKeys)
{
    if (m_stage != "review") {
        return nullptr;
    }
    auto tasks = makeShared<ConcurrentTask>(tr("Download %1").arg(m_label),
                                            APPLICATION->settings()->get("NumberOfConcurrentDownloads").toInt());
    for (const auto& it : m_items) {
        if (!excludedKeys.contains(it.update.name) && it.update.download) {
            tasks->addTask(it.update.download);
        }
    }
    QPointer<ResourceFolderModel> model = m_model;
    m_task = ResTaskHandle::run(tasks, tr("Updating %1…").arg(m_label), this);
    setStage("running");
    connect(m_task, &ResTaskHandle::done, this, [this, model](bool ok, const QString& error, const QStringList& warnings) {
        if (model) {
            model->update();
        }
        if (!warnings.isEmpty()) {
            emit notice(warnings.join("\n"), "warning");
        }
        if (ok) {
            m_message = tr("Updates installed.");
            setStage("done");
            emit installed();
        } else if (!error.isEmpty()) {
            m_message = error;
            setStage("error");
        } else {
            setStage("idle");
        }
    });
    return m_task;
}

void ResUpdateFlow::cancel()
{
    if (m_task && m_task->running()) {
        m_task->disconnect(this);
        m_task->abort();
    }
    m_task = nullptr;
    m_candidates.clear();
    m_noMetadata.clear();
    m_missingNames.clear();
    m_modrinthToUpdate.clear();
    m_flameToUpdate.clear();
    m_failedMetadata.clear();
    m_failedCheck.clear();
    m_failureList.clear();
    m_depsSeed.clear();
    m_items.clear();
    m_modrinthCheck.reset();
    m_flameCheck.reset();
    m_message.clear();
    if (m_stage != "idle") {
        setStage("idle");
    }
}
