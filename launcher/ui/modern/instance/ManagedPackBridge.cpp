#include "ManagedPackBridge.h"

#include <QDir>
#include <QFileDialog>

#include "Application.h"
#include "InstanceImportTask.h"
#include "InstanceList.h"
#include "Markdown.h"
#include "StringUtils.h"
#include "minecraft/MinecraftInstance.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/modrinth/ModrinthAPI.h"
#include "settings/SettingsObject.h"

ManagedPackBridge::ManagedPackBridge(QObject* parent) : QObject(parent) {}

void ManagedPackBridge::setInstanceId(const QString& id)
{
    if (id == m_id && m_inst) {
        return;
    }
    m_id = id;
    m_inst = APPLICATION->instances()->getInstanceById(id);
    m_pack = {};
    m_selected = -1;
    m_changelog.clear();
    m_failed = false;
    emit changed();
    emit versionsChanged();
    emit selectionChanged();
}

bool ManagedPackBridge::supported() const
{
    if (!m_inst || !m_inst->isManagedPack()) {
        return false;
    }
    const auto t = m_inst->getManagedPackType();
    return t == "modrinth" || (t == "flame" && (APPLICATION->capabilities() & Application::SupportsFlame) != 0U);
}

QString ManagedPackBridge::type() const
{
    return m_inst ? m_inst->getManagedPackType() : QString();
}

QString ManagedPackBridge::platformName() const
{
    const auto t = type();
    if (t == "flame") {
        return "CurseForge";
    }
    if (t == "modrinth") {
        return "Modrinth";
    }
    return t.isEmpty() ? QString() : t.left(1).toUpper() + t.mid(1);
}

QString ManagedPackBridge::packName() const
{
    if (!m_inst) {
        return {};
    }
    return local() ? m_inst->name() : m_inst->getManagedPackName();
}

QString ManagedPackBridge::packVersion() const
{
    return m_inst ? m_inst->getManagedPackVersionName() : QString();
}

QString ManagedPackBridge::packId() const
{
    return m_inst ? m_inst->getManagedPackID() : QString();
}

QString ManagedPackBridge::versionId() const
{
    return m_inst ? m_inst->getManagedPackVersionID() : QString();
}

QString ManagedPackBridge::websiteUrl() const
{
    if (!m_inst || local()) {
        return {};
    }
    if (type() == "flame") {
        return "https://www.curseforge.com/projects/" + packId();
    }
    return "https://modrinth.com/mod/" + packId();
}

bool ManagedPackBridge::local() const
{
    return m_inst && m_inst->getManagedPackID().isEmpty();
}

QString ManagedPackBridge::customUrl() const
{
    return m_inst ? m_inst->settings()->get("ManagedPackURL").toString().trimmed() : QString();
}

void ManagedPackBridge::setCustomUrl(const QString& url)
{
    if (m_inst && url.trimmed() != customUrl()) {
        m_inst->settings()->set("ManagedPackURL", url.trimmed());
        emit changed();
    }
}

QVariantList ManagedPackBridge::versions() const
{
    QVariantList out;
    for (const auto& v : m_pack.versions) {
        bool current = type() == "flame" ? v.fileId.toString() == versionId() : v.version == packVersion();
        out.append(QVariantMap{ { "name", v.getVersionDisplayString() },
                                { "version", v.version },
                                { "current", current },
                                { "date", v.date },
                                { "type", v.versionType.isValid() ? v.versionType.toString() : QString() } });
    }
    return out;
}

void ManagedPackBridge::setFailState(const QString& message)
{
    m_failed = true;
    m_failMessage = message;
    m_changelog = message;
    emit versionsChanged();
    emit selectionChanged();
}

void ManagedPackBridge::reload()
{
    if (!supported() || local()) {
        return;
    }
    if (m_fetchJob && m_fetchJob->isRunning()) {
        m_fetchJob->abort();
    }
    m_failed = false;
    m_pack = { .addonId = packId() };
    ResourceAPI::Callback<QVector<ModPlatform::IndexedVersion>> callbacks{};
    callbacks.onSucceed = [this](auto& doc) {
        m_pack.versions = doc;
        m_pack.versionsLoaded = true;
        int index = 0;
        auto list = versions();
        for (int i = 0; i < list.size(); i++) {
            if (list[i].toMap().value("current").toBool()) {
                // suggest the newest version: list is newest first, keep 0 unless the current one is the newest
                index = 0;
                break;
            }
        }
        emit versionsChanged();
        m_selected = -1;
        setSelectedIndex(m_pack.versions.isEmpty() ? -1 : index);
        if (m_pack.versions.isEmpty()) {
            setFailState(tr("No versions of this modpack were found."));
        }
    };
    callbacks.onFail = [this](const QString& reason, int) { setFailState(tr("Failed to search for available versions: %1").arg(reason)); };
    callbacks.onAbort = [this] { setFailState(tr("Fetching versions was aborted.")); };

    ResourceAPI::VersionSearchArgs args{ .pack = std::make_shared<ModPlatform::IndexedPack>(m_pack),
                                         .mcVersions = {},
                                         .loaders = {},
                                         .resourceType = ModPlatform::ResourceType::Modpack,
                                         .includeChangelog = true };
    if (type() == "flame") {
        m_fetchJob = FlameAPI::get().getProjectVersions(args, callbacks);
    } else {
        m_fetchJob = ModrinthAPI::get().getProjectVersions(args, callbacks);
    }
    connect(m_fetchJob.get(), &Task::finished, this, &ManagedPackBridge::versionsChanged);
    m_fetchJob->start();
    emit versionsChanged();
}

void ManagedPackBridge::setSelectedIndex(int index)
{
    if (index == m_selected) {
        return;
    }
    m_selected = index;
    m_changelog.clear();
    if (index >= 0 && index < m_pack.versions.size()) {
        const auto& v = m_pack.versions.at(index);
        if (type() == "flame") {
            m_changelog = StringUtils::htmlListPatch(FlameAPI::getModFileChangelog(packId().toInt(), v.fileId.toInt()));
        } else {
            m_changelog = StringUtils::htmlListPatch(markdownToHTML(v.changelog.toUtf8()));
        }
        if (m_changelog.trimmed().isEmpty()) {
            m_changelog = tr("No changelog available for this version.");
        }
    }
    emit selectionChanged();
}

QString ManagedPackBridge::selectedVersionName() const
{
    if (m_selected >= 0 && m_selected < m_pack.versions.size()) {
        return m_pack.versions.at(m_selected).version;
    }
    return {};
}

QString ManagedPackBridge::updateStatus() const
{
    return m_task ? m_task->getStatus() : QString();
}

double ManagedPackBridge::updateProgress() const
{
    if (!m_task || m_task->getTotalProgress() <= 0) {
        return -1;
    }
    return double(m_task->getProgress()) / double(m_task->getTotalProgress());
}

void ManagedPackBridge::updateToSelected()
{
    if (!m_inst) {
        return;
    }
    const auto url = customUrl();
    if (local()) {
        if (!url.isEmpty()) {
            updatePack(QUrl::fromUserInput(url), false);
        }
        return;
    }
    if (m_selected < 0 || m_selected >= m_pack.versions.size()) {
        return;
    }
    const auto& v = m_pack.versions.at(m_selected);
    updatePack(v.downloadUrl, true, v.fileId.toString(), v.version);
}

void ManagedPackBridge::updateFromFile()
{
    const auto filter = type() == "flame" ? tr("CurseForge pack") + " (*.zip)" : tr("Modrinth pack") + " (*.mrpack *.zip)";
    auto output = QFileDialog::getOpenFileUrl(nullptr, tr("Choose update file"), QUrl::fromLocalFile(QDir::homePath()), filter);
    if (output.isEmpty()) {
        return;
    }
    updatePack(output, false);
}

QString ManagedPackBridge::validateUrl(const QString& input) const
{
    auto url = QUrl::fromUserInput(input.trimmed());
    if (!url.isValid() || (url.scheme() != "http" && url.scheme() != "https")) {
        return tr("Please enter a valid HTTP(S) URL.");
    }
    return {};
}

void ManagedPackBridge::updateFromUrl(const QString& input)
{
    if (!validateUrl(input).isEmpty()) {
        return;
    }
    updatePack(QUrl::fromUserInput(input.trimmed()), false);
}

void ManagedPackBridge::updatePack(const QUrl& url, bool trusted, const QString& versionId, const QString& versionName)
{
    if (!m_inst || m_task) {
        return;
    }
    QMap<QString, QString> extraInfo;
    extraInfo.insert("pack_id", m_inst->getManagedPackID());
    extraInfo.insert("pack_version_id", versionId);
    extraInfo.insert("original_instance_id", m_inst->id());

    // NOTE: InstanceImportTask may still show classic dialogs (e.g. optional mods) during the import.
    auto* extracted = new InstanceImportTask(url, trusted, nullptr, std::move(extraInfo));
    if (versionName.isEmpty()) {
        extracted->setName(m_inst->name());
    } else {
        extracted->setOriginalName(m_inst->getManagedPackName(), versionName);
        extracted->setName(m_inst->name().replace(m_inst->getManagedPackVersionName(), versionName));
    }
    extracted->setGroup(APPLICATION->instances()->getInstanceGroup(m_inst->id()));
    extracted->setIcon(m_inst->iconKey());
    extracted->setConfirmUpdate(false);

    auto* wrapped = APPLICATION->instances()->wrapInstanceTask(extracted);
    m_task = wrapped;
    connect(wrapped, &Task::status, this, &ManagedPackBridge::updatingChanged);
    connect(wrapped, &Task::progress, this, &ManagedPackBridge::updatingChanged);
    connect(wrapped, &Task::finished, this, [this, wrapped, extracted] {
        const bool ok = wrapped->wasSuccessful();
        const QString warnings = ok ? extracted->warnings().join('\n') : QString();
        const QString message = ok ? tr("The instance updated to pack version %1 successfully.").arg(packVersion())
                                   : (wrapped->failReason().isEmpty()
                                          ? tr("The instance failed to update. Please check launcher logs for more information.")
                                          : wrapped->failReason());
        m_task = nullptr;
        wrapped->deleteLater();
        emit updatingChanged();
        emit changed();
        emit updateFinished(ok, message, warnings);
    });
    emit updatingChanged();
    wrapped->start();
}
