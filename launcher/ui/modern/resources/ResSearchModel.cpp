#include "ResSearchModel.h"

#include <QRegularExpression>
#include <QTimer>
#include <QUrl>
#include <algorithm>

#include "Application.h"
#include "InstanceList.h"
#include "Json.h"
#include "Markdown.h"
#include "ResFolderModel.h"
#include "ResImages.h"
#include "ResTask.h"
#include "ResourceDownloadTask.h"
#include "StringUtils.h"
#include "meta/Index.h"
#include "meta/Version.h"
#include "meta/VersionList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/mod/DataPackFolderModel.h"
#include "minecraft/mod/ModFolderModel.h"
#include "minecraft/mod/ResourceFolderModel.h"
#include "minecraft/mod/ResourcePackFolderModel.h"
#include "minecraft/mod/ShaderPackFolderModel.h"
#include "minecraft/mod/TexturePackFolderModel.h"
#include "minecraft/mod/tasks/GetModDependenciesTask.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/modrinth/ModrinthAPI.h"
#include "settings/SettingsObject.h"
#include "tasks/ConcurrentTask.h"

namespace {
const QList<std::pair<ModPlatform::ModLoaderType, QString>>& loaderTable()
{
    static const QList<std::pair<ModPlatform::ModLoaderType, QString>> t = {
        { ModPlatform::NeoForge, "NeoForge" },         { ModPlatform::Forge, "Forge" },   { ModPlatform::Fabric, "Fabric" },
        { ModPlatform::Quilt, "Quilt" },               { ModPlatform::LiteLoader, "LiteLoader" },
        { ModPlatform::Cauldron, "Cauldron" },         { ModPlatform::Babric, "Babric" }, { ModPlatform::BTA, "BTA" },
        { ModPlatform::LegacyFabric, "Legacy Fabric" }, { ModPlatform::Ornithe, "Ornithe" }, { ModPlatform::Rift, "Rift" },
    };
    return t;
}

QString loadersText(ModPlatform::ModLoaderTypes l)
{
    QStringList out;
    for (const auto& [type, name] : loaderTable()) {
        if (l & type) {
            out << name;
        }
    }
    return out.join(", ");
}

// Constrain images in rich text to the panel width (QML rich text does not wrap images).
QString constrainImages(QString html)
{
    static const QRegularExpression img(R"(<img\b[^>]*>)", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression src(R"(src\s*=\s*["']([^"']+)["'])", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression widthAttr(R"(\s(width|height)\s*=\s*["']?[^"'\s>]*["']?)", QRegularExpression::CaseInsensitiveOption);
    QString out;
    qsizetype last = 0;
    auto it = img.globalMatch(html);
    while (it.hasNext()) {
        auto m = it.next();
        out += html.mid(last, m.capturedStart() - last);
        last = m.capturedEnd();
        QString tag = m.captured(0);
        auto s = src.match(tag);
        const QString url = s.hasMatch() ? s.captured(1) : QString();
        const bool badge = url.endsWith(".svg", Qt::CaseInsensitive) || url.contains("shields.io") || url.contains("badge");
        if (url.isEmpty() || badge || !(url.startsWith("http://") || url.startsWith("https://"))) {
            continue;  // drop badges / svgs / relative images: they can't be laid out sensibly
        }
        tag.remove(widthAttr);
        tag.insert(4, " width=\"%IMGW%\"");
        out += "<br>" + tag + "<br>";
    }
    out += html.mid(last);
    return out;
}
}  // namespace

ResSearchModel::ResSearchModel(QObject* parent) : QAbstractListModel(parent) {}

ResSearchModel::~ResSearchModel()
{
    if (m_searchJob && m_searchJob->isRunning()) {
        m_searchJob->disconnect(this);
        m_searchJob->abort();
    }
    for (auto& j : m_jobs) {
        j->disconnect(this);
    }
}

void ResSearchModel::componentComplete()
{
    m_complete = true;
    ResImages::ensure(qmlEngine(this));
    reconfigure();
}

void ResSearchModel::setInstanceId(const QString& v)
{
    if (v == m_instanceId) {
        return;
    }
    m_instanceId = v;
    reconfigure();
}

void ResSearchModel::setResourceType(const QString& v)
{
    if (v == m_resourceType) {
        return;
    }
    m_resourceType = v;
    reconfigure();
}

void ResSearchModel::setTargetFolder(const QString& v)
{
    if (v == m_targetFolder) {
        return;
    }
    m_targetFolder = v;
    reconfigure();
}

void ResSearchModel::reconfigure()
{
    if (!m_complete || m_reconfigurePending) {
        return;
    }
    // several properties usually change together (instanceId, resourceType...): apply once
    m_reconfigurePending = true;
    QTimer::singleShot(0, this, [this] {
        m_reconfigurePending = false;
        applyConfig();
    });
}

void ResSearchModel::applyConfig()
{
    m_instance = APPLICATION->instances()->getInstanceById(m_instanceId);
    ResFolderModel::ensureProfileLoaded(m_instance);
    m_ownedTarget.reset();
    if (m_instance && !m_targetFolder.isEmpty()) {
        bool isIndexed = !APPLICATION->settings()->get("ModMetadataDisabled").toBool();
        m_ownedTarget = std::make_unique<DataPackFolderModel>(m_targetFolder, m_instance.data(), isIndexed, true);
        m_ownedTarget->update();
    }
    // The target list is loaded by the tab that opened the browser (ResFolderModel watches it). Kicking updates of
    // the other lists here races with their own update tasks, so we don't.
    const auto provs = providers();
    if (!provs.contains(m_provider) && !provs.isEmpty()) {
        m_provider = provs.first();
        emit providerChanged();
    }
    resetDefaultsFromInstance();
    loadMcVersions();
    loadCategories();
    m_sortIndex = -1;
    emit configChanged();
    emit sortIndexChanged();
}

void ResSearchModel::resetDefaultsFromInstance()
{
    m_mcVersions.clear();
    m_loaders.clear();
    m_side.clear();
    m_releaseTypes.clear();
    m_categories.clear();
    m_openSource = false;
    m_hideInstalled = false;
    if (m_instance) {
        const auto mc = instanceMcVersion();
        if (!mc.isEmpty()) {
            m_mcVersions << mc;
        }
        if (auto l = m_instance->getPackProfile()->getSupportedModLoaders(); l.has_value()) {
            for (const auto& [type, name] : loaderTable()) {
                if (l.value() & type) {
                    m_loaders << ModPlatform::getModLoaderAsString(type);
                }
            }
        }
    }
    emit filterChanged();
}

QStringList ResSearchModel::providers() const
{
    QStringList out;
    if (!m_instance) {
        return out;
    }
    auto loaders = m_instance->getPackProfile()->getSupportedModLoaders().value_or(ModPlatform::ModLoaderTypes(0));
    const bool mods = m_resourceType == "mod";
    if (!mods || ModrinthAPI::validateModLoaders(loaders)) {
        out << "modrinth";
    }
    if ((APPLICATION->capabilities() & Application::SupportsFlame) && (!mods || FlameAPI::validateModLoaders(loaders))) {
        out << "curseforge";
    }
    return out;
}

const ResourceAPI* ResSearchModel::api() const
{
    if (m_provider == "curseforge") {
        return &FlameAPI::get();
    }
    return &ModrinthAPI::get();
}

ModPlatform::ResourceType ResSearchModel::platformType() const
{
    if (m_resourceType == "resourcepack") {
        return ModPlatform::ResourceType::ResourcePack;
    }
    if (m_resourceType == "texturepack") {
        return ModPlatform::ResourceType::TexturePack;
    }
    if (m_resourceType == "shaderpack") {
        return ModPlatform::ResourceType::ShaderPack;
    }
    if (m_resourceType == "datapack") {
        return ModPlatform::ResourceType::DataPack;
    }
    return ModPlatform::ResourceType::Mod;
}

ResourceFolderModel* ResSearchModel::baseModel() const
{
    if (m_ownedTarget) {
        return m_ownedTarget.get();
    }
    return targetModelFor(platformType());
}

ResourceFolderModel* ResSearchModel::targetModelFor(ModPlatform::ResourceType type) const
{
    if (!m_instance) {
        return nullptr;
    }
    switch (type) {
        case ModPlatform::ResourceType::Mod:
            return m_instance->loaderModList();
        case ModPlatform::ResourceType::ResourcePack:
            return m_instance->resourcePackList();
        case ModPlatform::ResourceType::TexturePack:
            return m_instance->texturePackList();
        case ModPlatform::ResourceType::ShaderPack:
            return m_instance->shaderPackList();
        case ModPlatform::ResourceType::DataPack:
            return m_ownedTarget ? m_ownedTarget.get() : m_instance->dataPackList();
        default:
            return nullptr;
    }
}

void ResSearchModel::setProvider(const QString& v)
{
    if (v == m_provider || !providers().contains(v)) {
        return;
    }
    m_provider = v;
    m_sortIndex = -1;
    m_categories.clear();
    emit providerChanged();
    emit sortIndexChanged();
    emit filterChanged();
    loadCategories();
    search();
}

void ResSearchModel::setSearchText(const QString& v)
{
    if (v == m_searchText) {
        return;
    }
    m_searchText = v;
    emit searchTextChanged();
}

void ResSearchModel::setSortIndex(int v)
{
    if (v == m_sortIndex) {
        return;
    }
    m_sortIndex = v;
    emit sortIndexChanged();
}

QVariantList ResSearchModel::sortOptions() const
{
    auto sorts = api()->getSortingMethods();
    std::ranges::sort(sorts, [](const auto& l, const auto& r) { return l.index < r.index; });
    QVariantList out;
    for (const auto& s : sorts) {
        out << QVariantMap{ { "value", static_cast<int>(s.index) }, { "text", s.readableName } };
    }
    return out;
}

QString ResSearchModel::instanceMcVersion() const
{
    return m_instance ? m_instance->getPackProfile()->getComponentVersion("net.minecraft") : QString();
}

void ResSearchModel::loadMcVersions()
{
    auto list = APPLICATION->metadataIndex()->get("net.minecraft");
    auto fill = [this, list] {
        QStringList out;
        for (const auto& v : list->versions()) {
            if (m_showSnapshots || v->type() == "release") {
                out << v->descriptor();
            }
        }
        const auto mc = instanceMcVersion();
        if (!mc.isEmpty() && !out.contains(mc)) {
            out.prepend(mc);
        }
        m_mcVersionOptions = out;
        emit mcVersionOptionsChanged();
    };
    if (list->isLoaded()) {
        fill();
        return;
    }
    m_mcVersionOptions = instanceMcVersion().isEmpty() ? QStringList() : QStringList{ instanceMcVersion() };
    emit mcVersionOptionsChanged();
    if (m_mcVersionsJob && m_mcVersionsJob->isRunning()) {
        return;  // the running load will call fill()
    }
    m_mcVersionsJob = list->getLoadTask();
    if (m_mcVersionsJob) {
        connect(m_mcVersionsJob.get(), &Task::succeeded, this, fill);
        if (!m_mcVersionsJob->isRunning()) {
            m_mcVersionsJob->start();
        }
    }
}

void ResSearchModel::setShowSnapshots(bool v)
{
    if (v == m_showSnapshots) {
        return;
    }
    m_showSnapshots = v;
    loadMcVersions();
}

void ResSearchModel::loadCategories()
{
    m_categoryOptions.clear();
    emit categoryOptionsChanged();
    if (!supportsFilters()) {
        return;
    }
    auto [task, response] = api()->getModCategories();
    if (m_categoriesJob && m_categoriesJob->isRunning()) {
        // never drop a running job (its request would be destroyed mid-flight); let it finish in the background
        m_categoriesJob->disconnect(this);
        m_jobs << m_categoriesJob;
    }
    m_categoriesJob = task;
    const auto* apiPtr = api();
    const QString prov = m_provider;
    connect(task.get(), &Task::succeeded, this, [this, response, apiPtr, prov] {
        if (prov != m_provider) {
            return;
        }
        QVariantList out;
        for (const auto& c : apiPtr->loadModCategories(*response)) {
            out << QVariantMap{ { "id", c.id }, { "name", c.name } };
        }
        m_categoryOptions = out;
        emit categoryOptionsChanged();
    });
    task->start();
}

void ResSearchModel::setMcVersions(const QStringList& v)
{
    if (v == m_mcVersions) {
        return;
    }
    m_mcVersions = v;
    emit filterChanged();
}

QVariantList ResSearchModel::loaderOptions() const
{
    QVariantList out;
    for (const auto& [type, name] : loaderTable()) {
        out << QVariantMap{ { "value", ModPlatform::getModLoaderAsString(type) }, { "text", name } };
    }
    return out;
}

void ResSearchModel::setLoaders(const QStringList& v)
{
    if (v == m_loaders) {
        return;
    }
    m_loaders = v;
    emit filterChanged();
}

void ResSearchModel::setSide(const QString& v)
{
    if (v == m_side) {
        return;
    }
    m_side = v;
    emit filterChanged();
}

void ResSearchModel::setReleaseTypes(const QStringList& v)
{
    if (v == m_releaseTypes) {
        return;
    }
    m_releaseTypes = v;
    emit filterChanged();
}

void ResSearchModel::setCategories(const QStringList& v)
{
    if (v == m_categories) {
        return;
    }
    m_categories = v;
    emit filterChanged();
}

void ResSearchModel::setOpenSourceOnly(bool v)
{
    if (v == m_openSource) {
        return;
    }
    m_openSource = v;
    emit filterChanged();
}

void ResSearchModel::setHideInstalled(bool v)
{
    if (v == m_hideInstalled) {
        return;
    }
    m_hideInstalled = v;
    emit filterChanged();
}

int ResSearchModel::activeFilterCount() const
{
    if (!supportsFilters()) {
        return 0;
    }
    int n = 0;
    const auto mc = instanceMcVersion();
    n += (m_mcVersions != QStringList{ mc }) ? 1 : 0;
    n += m_side.isEmpty() ? 0 : 1;
    n += m_releaseTypes.isEmpty() ? 0 : 1;
    n += m_categories.size();
    n += m_openSource ? 1 : 0;
    n += m_hideInstalled ? 1 : 0;
    return n;
}

void ResSearchModel::resetFilters()
{
    resetDefaultsFromInstance();
}

std::optional<ModPlatform::ModLoaderTypes> ResSearchModel::loaderFlags() const
{
    if (m_resourceType == "datapack") {
        return ModPlatform::ModLoaderTypes(ModPlatform::DataPack);
    }
    if (m_resourceType != "mod") {
        return {};
    }
    if (m_loaders.isEmpty()) {
        if (m_instance) {
            return m_instance->getPackProfile()->getSupportedModLoaders();
        }
        return {};
    }
    ModPlatform::ModLoaderTypes flags;
    for (const auto& l : m_loaders) {
        flags |= ModPlatform::getModLoaderFromString(l);
    }
    return flags;
}

std::optional<std::vector<Version>> ResSearchModel::versionFilter() const
{
    if (m_resourceType == "mod") {
        if (m_mcVersions.isEmpty()) {
            return {};
        }
        std::vector<Version> out;
        for (const auto& v : m_mcVersions) {
            out.emplace_back(v);
        }
        return out;
    }
    if (m_resourceType == "texturepack") {
        if (m_provider == "curseforge") {
            return std::vector<Version>{ Version(instanceMcVersion()) };
        }
        // texture packs only exist for <= 1.6
        std::vector<Version> out;
        auto list = APPLICATION->metadataIndex()->get("net.minecraft");
        if (list->isLoaded()) {
            for (const auto& v : list->versions()) {
                if (auto cv = v->toComparableVersion(); cv <= Version("1.6")) {
                    out.push_back(cv);
                }
            }
        }
        if (out.empty()) {
            return {};
        }
        return out;
    }
    return {};
}

ResourceAPI::SearchArgs ResSearchModel::searchArgs() const
{
    ResourceAPI::SearchArgs args;
    args.type = platformType();
    args.offset = m_offset;
    args.search = m_searchText;
    auto sorts = api()->getSortingMethods();
    std::ranges::sort(sorts, [](const auto& l, const auto& r) { return l.index < r.index; });
    for (const auto& s : sorts) {
        if (m_sortIndex < 0 || static_cast<int>(s.index) == m_sortIndex) {
            args.sorting = s;
            break;
        }
    }
    args.loaders = loaderFlags();
    args.versions = versionFilter();
    if (m_resourceType == "mod") {
        if (m_side == "client") {
            args.side = ModPlatform::SideType(ModPlatform::SideType::ClientSide);
        } else if (m_side == "server") {
            args.side = ModPlatform::SideType(ModPlatform::SideType::ServerSide);
        }
        if (!m_categories.isEmpty()) {
            args.categoryIds = m_categories;
        }
        args.openSource = m_openSource;
    }
    return args;
}

ResourceAPI::VersionSearchArgs ResSearchModel::versionArgs(const ModPlatform::IndexedPack::Ptr& pack) const
{
    ResourceAPI::VersionSearchArgs args;
    args.pack = pack;
    args.resourceType = platformType();
    if (m_resourceType == "mod") {
        args.mcVersions = versionFilter();
        args.loaders = loaderFlags();
    } else if (m_resourceType == "datapack") {
        args.loaders = ModPlatform::ModLoaderTypes(ModPlatform::DataPack);
    } else if (m_resourceType == "texturepack" && m_provider != "curseforge") {
        args.mcVersions = versionFilter();
    }
    return args;
}

bool ResSearchModel::checkPack(const ModPlatform::IndexedPack::Ptr& pack) const
{
    if (m_resourceType != "mod") {
        return true;
    }
    if (m_hideInstalled && isInstalled(pack)) {
        return false;
    }
    if ((m_side == "client" && pack->side == ModPlatform::SideType::ServerSide) ||
        (m_side == "server" && pack->side == ModPlatform::SideType::ClientSide)) {
        return false;
    }
    return true;
}

bool ResSearchModel::checkVersion(const ModPlatform::IndexedVersion& v) const
{
    if (v.downloadUrl.isEmpty()) {
        return false;  // opted out of third-party downloads (CurseForge)
    }
    if (m_resourceType != "mod") {
        return true;
    }
    auto loaders = loaderFlags();
    if (loaders.has_value() && v.loaders && !(loaders.value() & v.loaders)) {
        return false;
    }
    if ((m_side == "client" && v.side == ModPlatform::SideType::ServerSide) ||
        (m_side == "server" && v.side == ModPlatform::SideType::ClientSide)) {
        return false;
    }
    if (!m_releaseTypes.isEmpty() && !m_releaseTypes.contains(v.versionType.toString(), Qt::CaseInsensitive)) {
        return false;
    }
    if (!m_mcVersions.isEmpty()) {
        bool any = false;
        for (const auto& mc : m_mcVersions) {
            any |= v.mcVersion.contains(mc);
        }
        if (!any) {
            return false;
        }
    }
    return true;
}

bool ResSearchModel::isInstalled(const ModPlatform::IndexedPack::Ptr& pack) const
{
    return installedVersion(pack).isValid();
}

QVariant ResSearchModel::installedVersion(const ModPlatform::IndexedPack::Ptr& pack) const
{
    auto* list = baseModel();
    if (!list) {
        return {};
    }
    for (qsizetype i = 0; i < list->size(); ++i) {
        auto& res = list->at(static_cast<int>(i));
        if (auto meta = res.metadata(); meta && meta->provider == pack->provider && meta->projectId == pack->addonId) {
            return meta->fileId.isValid() ? meta->fileId : QVariant(meta->versionNumber);
        }
    }
    return {};
}

// ---------------- list model ----------------

QHash<int, QByteArray> ResSearchModel::roleNames() const
{
    return { { NameRole, "name" },           { SummaryRole, "summary" },     { AuthorsRole, "authors" },
             { LogoRole, "logo" },           { InstalledRole, "installed" }, { SelectedRole, "selected" },
             { ProjectIdRole, "projectId" }, { LoadingRole, "loading" } };
}

QVariant ResSearchModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_packs.size()) {
        return {};
    }
    const auto& p = m_packs.at(index.row());
    switch (role) {
        case NameRole:
            return p->name;
        case SummaryRole:
            return p->description;
        case AuthorsRole: {
            QStringList a;
            for (const auto& au : p->authors) {
                a << au.name;
            }
            return a.join(", ");
        }
        case LogoRole:
            return ResImages::remoteUrl(p->logoUrl);
        case InstalledRole:
            return isInstalled(p);
        case SelectedRole:
            return selectionIndex(*p) >= 0;
        case ProjectIdRole:
            return p->addonId.toString();
        case LoadingRole:
            return m_toggleQueue.contains(keyOf(*p));
        default:
            return {};
    }
}

QString ResSearchModel::keyOf(const ModPlatform::IndexedPack& pack)
{
    return QString("%1:%2").arg(ModPlatform::ProviderCapabilities::name(pack.provider), pack.addonId.toString());
}

int ResSearchModel::rowOfPack(const ModPlatform::IndexedPack* pack) const
{
    for (int i = 0; i < m_packs.size(); ++i) {
        if (m_packs.at(i).get() == pack) {
            return i;
        }
    }
    return -1;
}

void ResSearchModel::emitRowChanged(const ModPlatform::IndexedPack* pack)
{
    const int row = rowOfPack(pack);
    if (row >= 0) {
        emit dataChanged(index(row), index(row));
    }
}

void ResSearchModel::runJob(const Task::Ptr& job)
{
    if (!job) {
        return;
    }
    m_jobs << job;
    auto* raw = job.get();
    connect(raw, &Task::finished, this, [this, raw] {
        QTimer::singleShot(0, this, [this, raw] {
            m_jobs.removeIf([raw](const Task::Ptr& j) { return j.get() == raw; });
        });
    });
    job->start();
}

// ---------------- searching ----------------

void ResSearchModel::search()
{
    if (m_reconfigurePending) {
        QTimer::singleShot(0, this, &ResSearchModel::search);
        return;
    }
    if (!m_instance) {
        return;
    }
    if (m_searchJob && m_searchJob->isRunning()) {
        m_searchJob->disconnect(this);
        m_searchJob->abort();
    }
    beginResetModel();
    m_packs.clear();
    m_toggleQueue.clear();
    endResetModel();
    m_offset = 0;
    m_canFetchMore = false;
    m_error.clear();
    m_currentRow = -1;
    m_currentVersionIndex = -1;
    emit currentChanged();
    fetchMoreResults();
}

void ResSearchModel::fetchMoreResults()
{
    if (!m_instance || (m_searchJob && m_searchJob->isRunning())) {
        return;
    }
    const int gen = ++m_searchGen;
    const bool first = m_offset == 0;
    if (!first && !m_canFetchMore) {
        return;
    }

    if (first && m_searchText.startsWith("#") && m_searchText.size() > 1) {
        auto [job, response] = api()->getProjectTask(m_searchText.mid(1), true, false);
        m_searchJob = job;
        connect(job.get(), &NetJob::succeeded, this, [this, gen, response] {
            if (gen != m_searchGen) {
                return;
            }
            auto pack = std::make_shared<ModPlatform::IndexedPack>(*response);
            pack->resourceType = platformType();
            beginInsertRows({}, 0, 0);
            m_packs << pack;
            endInsertRows();
            m_canFetchMore = false;
            emit stateChanged();
            setCurrentRow(0);
        });
        connect(job.get(), &NetJob::failed, this, [this, gen](const QString& reason) {
            if (gen != m_searchGen) {
                return;
            }
            m_error = reason;
            emit stateChanged();
        });
        connect(job.get(), &Task::finished, this, &ResSearchModel::stateChanged);
        job->start();
        emit stateChanged();
        return;
    }

    auto [job, response] = api()->searchProjectsTask(searchArgs());
    m_searchJob = job;
    auto weak = job.toWeakRef();
    connect(job.get(), &NetJob::succeeded, this, [this, gen, response] {
        if (gen != m_searchGen) {
            return;
        }
        QList<ModPlatform::IndexedPack::Ptr> add;
        for (const auto& pack : *response) {
            ModPlatform::IndexedPack::Ptr p;
            // keep the selected instance, it carries the selected version
            for (const auto& sel : m_selected) {
                if (sel.pack->provider == pack.provider && sel.pack->addonId == pack.addonId) {
                    p = sel.pack;
                    break;
                }
            }
            if (!p) {
                p = std::make_shared<ModPlatform::IndexedPack>(pack);
            }
            if (p->resourceType == ModPlatform::ResourceType::Unknown) {
                p->resourceType = platformType();
            }
            if (checkPack(p)) {
                add << p;
            }
        }
        m_canFetchMore = response->size() >= 25;
        m_offset += 25;
        if (!add.isEmpty()) {
            beginInsertRows({}, static_cast<int>(m_packs.size()), static_cast<int>(m_packs.size() + add.size() - 1));
            m_packs << add;
            endInsertRows();
        }
        emit stateChanged();
    });
    connect(job.get(), &NetJob::failed, this, [this, gen, weak](const QString& reason) {
        if (gen != m_searchGen) {
            return;
        }
        int code = -1;
        if (auto j = weak.lock(); j && !j->getFailedActions().isEmpty() && j->getFailedActions().at(0)) {
            code = j->getFailedActions().at(0)->replyStatusCode();
        }
        m_canFetchMore = false;
        if (code == 409) {
            m_error = tr("API version too old! Please update %1.").arg(APPLICATION->applicationName());
        } else if (code != 404) {
            m_error = tr("A network error occurred. Could not load results: %1").arg(reason);
        }
        emit stateChanged();
    });
    connect(job.get(), &Task::finished, this, &ResSearchModel::stateChanged);
    job->start();
    emit stateChanged();
}

void ResSearchModel::openProject(const QString& provider, const QString& projectId)
{
    if (m_reconfigurePending) {
        QTimer::singleShot(0, this, [this, provider, projectId] { openProject(provider, projectId); });
        return;
    }
    if (providers().contains(provider)) {
        m_provider = provider;
        emit providerChanged();
    }
    m_searchText = "#" + projectId;
    emit searchTextChanged();
    search();
}

bool ResSearchModel::isSafeUrl(const QString& url) const
{
    const QUrl u(url);
    return u.scheme() == "http" || u.scheme() == "https";
}

// ---------------- current project / versions ----------------

void ResSearchModel::setCurrentRow(int row)
{
    if (row < -1 || row >= m_packs.size()) {
        row = -1;
    }
    m_currentRow = row;
    m_currentVersionIndex = -1;
    if (row >= 0) {
        auto pack = m_packs.at(row);
        if (!pack->versionsLoaded || !pack->extraDataLoaded) {
            loadEntry(pack);
        } else {
            m_currentVersionIndex = preferredVersionIndex(pack);
        }
    }
    emit currentChanged();
}

bool ResSearchModel::currentLoading() const
{
    if (m_currentRow < 0) {
        return false;
    }
    return !m_packs.at(m_currentRow)->versionsLoaded;
}

void ResSearchModel::loadEntry(const ModPlatform::IndexedPack::Ptr& pack)
{
    const QString key = keyOf(*pack);
    if (m_loadingKeys.contains(key)) {
        return;
    }
    m_loadingKeys.insert(key);
    QPointer<ResSearchModel> self(this);
    int pending = 0;
    auto remaining = std::make_shared<int>(0);
    auto finishOne = [self, key, remaining] {
        if (--(*remaining) <= 0 && self) {
            self->m_loadingKeys.remove(key);
        }
    };

    if (!pack->versionsLoaded) {
        ResourceAPI::Callback<QVector<ModPlatform::IndexedVersion>> cb;
        cb.onSucceed = [self, pack, finishOne](QVector<ModPlatform::IndexedVersion>& versions) {
            pack->versions = versions;
            pack->versionsLoaded = true;
            finishOne();
            if (self) {
                self->packUpdated(pack);
            }
        };
        cb.onFail = [self, pack, finishOne](const QString& reason, int) {
            pack->versionsLoaded = true;  // stop spinning; show "no versions"
            finishOne();
            if (self) {
                emit self->notice(tr("Could not load versions of %1: %2").arg(pack->name, reason), "error");
                self->packUpdated(pack);
            }
        };
        cb.onAbort = finishOne;
        if (auto job = api()->getProjectVersions(versionArgs(pack), cb)) {
            ++pending;
            runJob(job);
        } else {
            pack->versionsLoaded = true;
        }
    }
    if (!pack->extraDataLoaded) {
        auto [job, response] = api()->getProjectTask(pack->addonId.toString(), true);
        connect(job.get(), &NetJob::succeeded, this, [this, pack, response] {
            auto versions = std::move(pack->versions);
            auto loaded = pack->versionsLoaded;
            auto type = pack->resourceType;
            auto authors = pack->authors;
            auto logo = pack->logoUrl;
            *pack = *response;
            if (pack->authors.isEmpty()) {
                pack->authors = authors;  // project endpoints don't always carry the author list
            }
            if (pack->logoUrl.isEmpty()) {
                pack->logoUrl = logo;
            }
            pack->versions = std::move(versions);
            pack->versionsLoaded = loaded;
            if (pack->resourceType == ModPlatform::ResourceType::Unknown) {
                pack->resourceType = type;
            }
            pack->extraDataLoaded = true;
            packUpdated(pack);
        });
        connect(job.get(), &Task::finished, this, finishOne);
        ++pending;
        runJob(job);
    }
    *remaining = pending;
    if (pending == 0) {
        m_loadingKeys.remove(key);
    }
}

void ResSearchModel::packUpdated(const ModPlatform::IndexedPack::Ptr& pack)
{
    const QString key = keyOf(*pack);
    if (m_toggleQueue.contains(key) && pack->versionsLoaded) {
        m_toggleQueue.remove(key);
        const int idx = preferredVersionIndex(pack);
        if (idx >= 0) {
            selectVersion(pack, pack->versions[idx]);
        } else {
            emit notice(tr("No versions of “%1” are available. The author may have blocked third-party launchers.").arg(pack->name),
                        "warning");
        }
    }
    if (m_currentRow >= 0 && m_currentRow < m_packs.size() && m_packs.at(m_currentRow) == pack) {
        if (m_currentVersionIndex < 0 && pack->versionsLoaded) {
            m_currentVersionIndex = preferredVersionIndex(pack);
        }
        emit currentChanged();
    }
    emitRowChanged(pack.get());
}

int ResSearchModel::preferredVersionIndex(const ModPlatform::IndexedPack::Ptr& pack) const
{
    if (!pack->versionsLoaded) {
        return -1;
    }
    // a version already selected wins
    if (int s = selectionIndex(*pack); s >= 0) {
        const auto& selV = m_selected.at(s).version;
        for (int i = 0; i < pack->versions.size(); ++i) {
            if (pack->versions[i].fileId == selV.fileId) {
                return i;
            }
        }
    }
    const auto releaseTypes = ModPlatform::IndexedVersionType::fromStringList(
        Json::toStringList(APPLICATION->settings()->get("ModUpdateReleaseTypes").toString()));
    int firstValid = -1;
    for (int i = 0; i < pack->versions.size(); ++i) {
        const auto& v = pack->versions[i];
        if (!checkVersion(v)) {
            continue;
        }
        if (firstValid < 0) {
            firstValid = i;
        }
        if (releaseTypes.empty() || std::ranges::any_of(releaseTypes, [&v](auto t) { return v.versionType == t; })) {
            return i;
        }
    }
    return firstValid;
}

QVariantMap ResSearchModel::current() const
{
    if (m_currentRow < 0 || m_currentRow >= m_packs.size()) {
        return {};
    }
    const auto& p = m_packs.at(m_currentRow);
    QVariantMap m;
    m["name"] = p->name;
    m["summary"] = p->description;
    m["logo"] = ResImages::remoteUrl(p->logoUrl);
    m["website"] = p->websiteUrl;
    m["projectId"] = p->addonId.toString();
    m["installed"] = isInstalled(p);
    m["selected"] = selectionIndex(*p) >= 0;
    m["providerName"] = ModPlatform::ProviderCapabilities::readableName(p->provider);
    QVariantList authors;
    for (const auto& a : p->authors) {
        authors << QVariantMap{ { "name", a.name }, { "url", a.url } };
    }
    m["authors"] = authors;
    m["archived"] = p->extraDataLoaded && p->extraData.status == "archived";
    QVariantList links;
    auto addLink = [&links](const QString& name, const QString& icon, const QString& url) {
        if (!url.isEmpty()) {
            links << QVariantMap{ { "name", name }, { "icon", icon }, { "url", url } };
        }
    };
    addLink(tr("Website"), "globe", p->websiteUrl);
    if (p->extraDataLoaded) {
        addLink(tr("Issues"), "bug", p->extraData.issuesUrl);
        addLink(tr("Source"), "github", p->extraData.sourceUrl);
        addLink(tr("Wiki"), "book", p->extraData.wikiUrl);
        addLink(tr("Discord"), "discord", p->extraData.discordUrl);
        for (const auto& d : p->extraData.donate) {
            addLink(tr("Donate (%1)").arg(d.platform), "heart", d.url);
        }
    }
    m["links"] = links;
    const QString body = p->extraData.body.isEmpty() ? p->description : markdownToHTML(p->extraData.body);
    m["descriptionHtml"] = constrainImages(StringUtils::htmlListPatch(body));
    m["extraLoaded"] = p->extraDataLoaded;
    m["versionsLoaded"] = p->versionsLoaded;
    return m;
}

QVariantList ResSearchModel::currentVersions() const
{
    QVariantList out;
    if (m_currentRow < 0 || m_currentRow >= m_packs.size()) {
        return out;
    }
    const auto& p = m_packs.at(m_currentRow);
    if (!p->versionsLoaded) {
        return out;
    }
    const auto installed = installedVersion(p);
    const int sel = selectionIndex(*p);
    for (int i = 0; i < p->versions.size(); ++i) {
        const auto& v = p->versions[i];
        if (!checkVersion(v)) {
            continue;
        }
        QStringList mc = v.mcVersion;
        out << QVariantMap{
            { "index", i },
            { "name", v.version },
            { "number", v.versionNumber },
            { "type", v.versionType.isValid() ? v.versionType.toString() : QString() },
            { "date", v.date.left(10) },
            { "fileName", v.fileName },
            { "mcVersions", mc.mid(0, 6).join(", ") + (mc.size() > 6 ? "…" : "") },
            { "loaders", loadersText(v.loaders) },
            { "installed", installed.isValid() && (v.fileId == installed || v.versionNumber == installed.toString()) },
            { "selected", sel >= 0 && m_selected.at(sel).version.fileId == v.fileId },
        };
    }
    return out;
}

void ResSearchModel::setCurrentVersionIndex(int idx)
{
    if (idx == m_currentVersionIndex) {
        return;
    }
    m_currentVersionIndex = idx;
    // changing the version of an already selected project switches the selection over
    if (m_currentRow >= 0) {
        auto pack = m_packs.at(m_currentRow);
        if (selectionIndex(*pack) >= 0 && idx >= 0 && idx < pack->versions.size()) {
            selectVersion(pack, pack->versions[idx]);
        }
    }
    emit currentChanged();
}

// ---------------- selection ----------------

int ResSearchModel::selectionIndex(const ModPlatform::IndexedPack& pack) const
{
    for (int i = 0; i < m_selected.size(); ++i) {
        const auto& s = m_selected.at(i).pack;
        if (s->provider == pack.provider && s->addonId == pack.addonId) {
            return i;
        }
    }
    return -1;
}

void ResSearchModel::selectVersion(const ModPlatform::IndexedPack::Ptr& pack, const ModPlatform::IndexedVersion& v)
{
    Selection s;
    s.pack = pack;
    s.version = v;
    if (int i = selectionIndex(*pack); i >= 0) {
        m_selected[i] = s;
    } else {
        m_selected << s;
    }
    emitRowChanged(pack.get());
    emit selectionChanged();
    emit currentChanged();
}

void ResSearchModel::toggleRow(int row)
{
    if (row < 0 || row >= m_packs.size()) {
        return;
    }
    auto pack = m_packs.at(row);
    if (int i = selectionIndex(*pack); i >= 0) {
        m_selected.removeAt(i);
        emitRowChanged(pack.get());
        emit selectionChanged();
        emit currentChanged();
        return;
    }
    if (pack->versionsLoaded) {
        const int idx = (row == m_currentRow && m_currentVersionIndex >= 0) ? m_currentVersionIndex : preferredVersionIndex(pack);
        if (idx < 0) {
            emit notice(tr("No versions of “%1” are available. The author may have blocked third-party launchers.").arg(pack->name),
                        "warning");
            return;
        }
        selectVersion(pack, pack->versions[idx]);
        return;
    }
    m_toggleQueue.insert(keyOf(*pack));
    emitRowChanged(pack.get());
    loadEntry(pack);
}

void ResSearchModel::toggleCurrentVersion()
{
    if (m_currentRow < 0) {
        return;
    }
    auto pack = m_packs.at(m_currentRow);
    const int sel = selectionIndex(*pack);
    if (sel >= 0 && m_currentVersionIndex >= 0 && m_currentVersionIndex < pack->versions.size() &&
        m_selected.at(sel).version.fileId == pack->versions[m_currentVersionIndex].fileId) {
        m_selected.removeAt(sel);
        emitRowChanged(pack.get());
        emit selectionChanged();
        emit currentChanged();
        return;
    }
    if (m_currentVersionIndex >= 0 && m_currentVersionIndex < pack->versions.size()) {
        selectVersion(pack, pack->versions[m_currentVersionIndex]);
    }
}

bool ResSearchModel::isCurrentVersionSelected() const
{
    if (m_currentRow < 0) {
        return false;
    }
    const auto& pack = m_packs.at(m_currentRow);
    const int sel = selectionIndex(*pack);
    return sel >= 0 && m_currentVersionIndex >= 0 && m_currentVersionIndex < pack->versions.size() &&
           m_selected.at(sel).version.fileId == pack->versions[m_currentVersionIndex].fileId;
}

void ResSearchModel::deselect(const QString& key)
{
    for (int i = 0; i < m_selected.size(); ++i) {
        if (keyOf(*m_selected.at(i).pack) == key) {
            auto pack = m_selected.at(i).pack;
            m_selected.removeAt(i);
            emitRowChanged(pack.get());
            emit selectionChanged();
            emit currentChanged();
            return;
        }
    }
}

void ResSearchModel::clearSelection()
{
    m_selected.clear();
    if (!m_packs.isEmpty()) {
        emit dataChanged(index(0), index(static_cast<int>(m_packs.size()) - 1), { SelectedRole });
    }
    emit selectionChanged();
    emit currentChanged();
}

QVariantList ResSearchModel::selectedItems() const
{
    QVariantList out;
    for (const auto& s : m_selected) {
        out << QVariantMap{
            { "key", keyOf(*s.pack) },
            { "name", s.pack->name },
            { "version", s.version.version },
            { "fileName", s.version.fileName },
            { "logo", ResImages::remoteUrl(s.pack->logoUrl) },
            { "provider", ModPlatform::ProviderCapabilities::readableName(s.pack->provider) },
            { "dependency", s.dependency },
        };
    }
    return out;
}

// ---------------- review & install ----------------

ResTaskHandle* ResSearchModel::prepareReview()
{
    cancelReview();
    auto* mods = qobject_cast<ModFolderModel*>(baseModel());
    if (m_resourceType != "mod" || !mods || !m_instance || APPLICATION->settings()->get("ModDependenciesDisabled").toBool()) {
        QTimer::singleShot(0, this, &ResSearchModel::reviewReady);
        return nullptr;
    }
    QList<std::shared_ptr<GetModDependenciesTask::PackDependency>> selectedVers;
    for (const auto& s : m_selected) {
        selectedVers << std::make_shared<GetModDependenciesTask::PackDependency>(s.pack, s.version);
    }
    auto task = makeShared<GetModDependenciesTask>(m_instance.data(), mods, selectedVers);
    auto* handle = ResTaskHandle::run(task, tr("Checking for dependencies…"), this);
    auto* raw = task.get();
    connect(handle, &ResTaskHandle::done, this, [this, raw](bool ok, const QString& error, const QStringList& warnings) {
        if (!ok) {
            if (!error.isEmpty()) {
                emit notice(tr("Dependency check failed: %1").arg(error), "error");
            }
            return;
        }
        if (!warnings.isEmpty()) {
            emit notice(warnings.join("\n"), "warning");
        }
        auto extra = raw->getExtraInfo();
        for (const auto& dep : raw->getDependecies()) {
            auto info = extra.value(dep->pack->addonId.toString());
            Selection s;
            s.pack = dep->pack;
            s.version = dep->version;
            s.reason = "dependency";
            s.dependentOn = info.requiredByIds.isEmpty() ? QString() : info.requiredByIds.first();
            s.dependency = true;
            s.maybeInstalled = info.maybeInstalled;
            s.requiredBy = info.requiredByNames;
            if (int i = selectionIndex(*dep->pack); i >= 0) {
                m_selected[i] = s;
            } else {
                m_selected << s;
            }
            m_reviewDeps.insert(keyOf(*dep->pack));
        }
        // annotate explicitly selected ones with "required by" too
        for (auto& s : m_selected) {
            if (!s.dependency) {
                auto info = extra.value(s.pack->addonId.toString());
                s.requiredBy = info.requiredByNames;
            }
        }
        emit selectionChanged();
        emit reviewReady();
    });
    return handle;
}

QVariantList ResSearchModel::reviewItems() const
{
    QList<Selection> sorted = m_selected;
    std::ranges::sort(sorted, [](const Selection& a, const Selection& b) {
        if (a.dependency != b.dependency) {
            return !a.dependency;
        }
        return QString::compare(a.pack->name, b.pack->name, Qt::CaseInsensitive) < 0;
    });
    QVariantList out;
    for (const auto& s : sorted) {
        out << QVariantMap{
            { "key", keyOf(*s.pack) },
            { "name", s.pack->name },
            { "fileName", s.version.fileName },
            { "logo", ResImages::remoteUrl(s.pack->logoUrl) },
            { "provider", ModPlatform::ProviderCapabilities::readableName(s.pack->provider) },
            { "version", s.version.version },
            { "versionType", s.version.versionType.isValid() ? s.version.versionType.toString() : QString() },
            { "requiredBy", s.requiredBy },
            { "dependency", s.dependency },
            { "enabled", !s.maybeInstalled },
            { "maybeInstalled", s.maybeInstalled },
        };
    }
    return out;
}

void ResSearchModel::cancelReview()
{
    if (m_reviewDeps.isEmpty()) {
        return;
    }
    m_selected.removeIf([this](const Selection& s) { return s.dependency && m_reviewDeps.contains(keyOf(*s.pack)); });
    m_reviewDeps.clear();
    emit selectionChanged();
}

ResTaskHandle* ResSearchModel::install(const QStringList& excludedKeys)
{
    if (!m_instance || m_selected.isEmpty()) {
        return nullptr;
    }
    auto tasks = makeShared<ConcurrentTask>(tr("Download %1").arg(m_resourceType),
                                            APPLICATION->settings()->get("NumberOfConcurrentDownloads").toInt());
    const bool isIndexed = !APPLICATION->settings()->get("ModMetadataDisabled").toBool();
    QList<ResourceFolderModel*> touched;
    for (auto& s : m_selected) {
        if (excludedKeys.contains(keyOf(*s.pack))) {
            continue;
        }
        auto* target = baseModel();
        if (auto* typed = targetModelFor(s.pack->resourceType); typed && !m_ownedTarget) {
            target = typed;
        }
        if (!target) {
            continue;
        }
        if (!touched.contains(target)) {
            touched << target;
        }
        s.version.isCurrentlySelected = true;
        tasks->addTask(makeShared<ResourceDownloadTask>(s.pack, s.version, target, isIndexed, s.reason, s.dependentOn));
    }
    auto* handle = ResTaskHandle::run(tasks, tr("Downloading"), this);
    QList<QPointer<ResourceFolderModel>> targets;
    for (auto* t : touched) {
        targets << QPointer<ResourceFolderModel>(t);
    }
    connect(handle, &ResTaskHandle::done, this, [this, targets](bool ok, const QString&, const QStringList&) {
        for (const auto& t : targets) {
            if (t) {
                t->update();
            }
        }
        if (ok) {
            m_selected.clear();
            m_reviewDeps.clear();
            if (!m_packs.isEmpty()) {
                emit dataChanged(index(0), index(static_cast<int>(m_packs.size()) - 1));
            }
            emit selectionChanged();
            emit currentChanged();
            emit installed();
        }
    });
    return handle;
}
