// Per-platform selection / details logic of NIPackBrowser (ported from the classic *Page.cpp files).
#include "NIPackBrowser.h"

#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTemporaryFile>

#include "Application.h"
#include "BuildConfig.h"
#include "FileSystem.h"
#include "InstanceImportTask.h"
#include "Json.h"
#include "Markdown.h"
#include "StringUtils.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/modrinth/ModrinthAPI.h"
#include "modplatform/technic/SolderPackManifest.h"
#include "net/ApiRequest.h"
#include "net/NetJob.h"
#include "ui/pages/modplatform/flame/FlameModel.h"
#include "ui/pages/modplatform/ftb/FtbListModel.h"
#include "ui/pages/modplatform/import_ftb/ListModel.h"
#include "ui/pages/modplatform/legacy_ftb/ListModel.h"
#include "ui/pages/modplatform/modrinth/ModrinthModel.h"
#include "ui/pages/modplatform/technic/TechnicModel.h"
#include "modplatform/legacy_ftb/PackFetchTask.h"
#include "modplatform/legacy_ftb/PrivatePackManager.h"

namespace {
/// Rich text for QML's Text.RichText: drop media that the lightweight renderer can't lay out nicely.
QString cleanHtml(QString html)
{
    static const QRegularExpression media("<(img|iframe|video|source|picture)[^>]*>", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression closers("</(iframe|video|picture)>", QRegularExpression::CaseInsensitiveOption);
    html.remove(media);
    html.remove(closers);
    return StringUtils::htmlListPatch(html);
}

QVariantMap link(const QString& label, const QString& url)
{
    return { { "label", label }, { "url", url } };
}
}  // namespace

// ============================================================================ Modrinth / CurseForge

void NIPackBrowser::selectIndexed(int row)
{
    auto* src = m_modrinth ? static_cast<QAbstractItemModel*>(m_modrinth) : static_cast<QAbstractItemModel*>(m_flame);
    const auto srcIndex = m_model->mapToSource(m_model->index(row, 0));
    m_indexed = src->data(srcIndex, Qt::UserRole).value<ModPlatform::IndexedPack::Ptr>();
    m_versions.clear();
    m_versionIndex = -1;
    if (!m_indexed) {
        clearSelection();
        return;
    }
    updateIndexedInfo();
    const auto addonId = m_indexed->addonId;
    const bool isModrinth = m_modrinth != nullptr;

    // extra info (body, links)
    if (!m_indexed->extraDataLoaded || (!isModrinth && m_indexed->extraData.body.isEmpty())) {
        auto [job, response] = isModrinth ? ModrinthAPI::get().getProjectTask(addonId.toString(), true)
                                          : FlameAPI::get().getProjectTask(addonId.toString(), true);
        connect(job.get(), &Task::succeeded, this, [this, addonId, response, srcIndex, src] {
            if (!m_indexed || addonId != m_indexed->addonId) {
                return;
            }
            auto versions = std::move(m_indexed->versions);
            auto versionsLoaded = m_indexed->versionsLoaded;
            *m_indexed = *response;
            m_indexed->versions = std::move(versions);
            m_indexed->versionsLoaded = versionsLoaded;
            src->setData(srcIndex, QVariant::fromValue(m_indexed), Qt::UserRole);
            updateIndexedInfo();
        });
        m_detailsJob = job;
        job->start();
    }

    // versions
    if (!m_indexed->versionsLoaded || m_filterChanged) {
        m_versionsLoading = true;
        emit versionsChanged();
        ResourceAPI::Callback<QVector<ModPlatform::IndexedVersion>> callbacks{};
        callbacks.onSucceed = [this, addonId, srcIndex, src](auto& doc) {
            if (!m_indexed || addonId != m_indexed->addonId) {
                return;
            }
            m_indexed->versions = doc;
            m_indexed->versionsLoaded = true;
            src->setData(srcIndex, QVariant::fromValue(m_indexed), Qt::UserRole);
            m_versionsLoading = false;
            suggestIndexed();  // rebuilds the versions list
        };
        callbacks.onFail = [this](const QString& reason, int) {
            m_versionsLoading = false;
            emit versionsChanged();
            emit error(reason);
        };
        auto job = isModrinth ? ModrinthAPI::get().getProjectVersions(
                                    { .pack = m_indexed, .mcVersions = {}, .loaders = {}, .resourceType = ModPlatform::ResourceType::Modpack },
                                    callbacks)
                              : FlameAPI::get().getProjectVersions(
                                    { .pack = m_indexed, .mcVersions = {}, .loaders = {}, .resourceType = ModPlatform::ResourceType::Modpack },
                                    callbacks);
        m_versionsJob = job;
        job->start();
    } else {
        m_versionsLoading = false;
        suggestIndexed();
    }
}

void NIPackBrowser::updateIndexedInfo()
{
    if (!m_indexed) {
        return;
    }
    QVariantMap info;
    info["name"] = m_indexed->name;
    info["summary"] = m_indexed->description;
    info["websiteUrl"] = m_indexed->websiteUrl;
    info["logo"] = m_model->data(m_model->index(m_selectedRow, 0), NIPackListModel::LogoRole);
    QStringList authors;
    for (const auto& a : m_indexed->authors) {
        authors << (a.url.isEmpty() ? a.name.toHtmlEscaped() : QString("<a href=\"%1\">%2</a>").arg(a.url, a.name.toHtmlEscaped()));
    }
    info["authorsHtml"] = authors.join(", ");
    QVariantList links;
    if (!m_indexed->websiteUrl.isEmpty()) {
        links << link(m_modrinth ? tr("Modrinth page") : tr("CurseForge page"), m_indexed->websiteUrl);
    }
    QVariantList donate;
    if (m_indexed->extraDataLoaded) {
        const auto& x = m_indexed->extraData;
        info["archived"] = x.status == "archived";
        if (!x.issuesUrl.isEmpty()) {
            links << link(tr("Issues"), x.issuesUrl);
        }
        if (!x.wikiUrl.isEmpty()) {
            links << link(tr("Wiki"), x.wikiUrl);
        }
        if (!x.sourceUrl.isEmpty()) {
            links << link(tr("Source code"), x.sourceUrl);
        }
        if (!x.discordUrl.isEmpty()) {
            links << link(tr("Discord"), x.discordUrl);
        }
        for (const auto& d : x.donate) {
            donate << link(d.platform, d.url);
        }
        QString body = m_modrinth ? markdownToHTML(x.body.toUtf8()) : x.body;
        info["descriptionHtml"] = cleanHtml(body.isEmpty() ? m_indexed->description.toHtmlEscaped() : body);
        info["detailsLoading"] = false;
    } else {
        info["descriptionHtml"] = m_indexed->description.toHtmlEscaped();
        info["detailsLoading"] = true;
    }
    info["links"] = links;
    info["donate"] = donate;
    m_currentInfo = info;
    emit currentChanged();
}

void NIPackBrowser::suggestIndexed()
{
    if (!m_indexed) {
        return;
    }
    // (re)build the version list honouring the filters, keeping the selection when possible
    const auto previous = m_versionIndex >= 0 && m_versionIndex < m_versions.size() ? m_versions.at(m_versionIndex).toMap().value("id") : QVariant();
    QVariantList list;
    int keep = -1;
    int i = 0;
    for (const auto& v : m_indexed->versions) {
        if (m_filter && !m_filter->checkModpackFilters(v)) {
            i++;
            continue;
        }
        QVariantMap m;
        m["name"] = v.version;
        m["text"] = v.getVersionDisplayString();
        m["id"] = v.fileId;
        m["index"] = i;
        m["type"] = v.versionType.toString();
        m["mcVersions"] = v.mcVersion.join(", ");
        m["disabled"] = v.downloadUrl.isEmpty();
        if (v.fileId == previous) {
            keep = static_cast<int>(list.size());
        }
        list << m;
        i++;
    }
    if (keep < 0) {
        keep = 0;
        while (keep < list.size() && list.at(keep).toMap().value("disabled").toBool()) {
            keep++;
        }
    }
    m_versions = list;
    m_versionIndex = keep < list.size() ? keep : -1;
    emit versionsChanged();

    if (!m_active || !m_controller) {
        return;
    }
    if (m_versionIndex < 0) {
        m_controller->setSuggestedPack();
        return;
    }
    const auto& ver = m_indexed->versions.at(m_versions.at(m_versionIndex).toMap().value("index").toInt());
    QMap<QString, QString> extra;
    extra.insert("pack_id", m_indexed->addonId.toString());
    extra.insert("pack_version_id", ver.fileId.toString());
    if (m_modrinth) {
        m_controller->setSuggestedPack(m_indexed->name, ver.version, new InstanceImportTask(ver.downloadUrl, true, nullptr, extra));
    } else {
        m_controller->setSuggestedPack(m_indexed->name, {}, new InstanceImportTask(ver.downloadUrl, true, nullptr, extra));
    }
    QPointer<NIController> ctl = m_controller;
    const auto iconName = (m_modrinth ? "modrinth_" : "curseforge_") + m_indexed->logoName;
    auto cb = [ctl, iconName](const QString& path) {
        if (ctl) {
            ctl->setSuggestedIconFromFile(path, iconName);
        }
    };
    if (m_modrinth) {
        m_modrinth->getLogo(m_indexed->logoName, m_indexed->logoUrl, cb);
    } else {
        m_flame->getLogo(m_indexed->logoName, m_indexed->logoUrl, cb);
    }
}

// ============================================================================ Technic

void NIPackBrowser::selectTechnic(int row)
{
    const auto srcIndex = m_model->mapToSource(m_model->index(row, 0));
    m_technicPack = m_technic->data(srcIndex, Qt::UserRole).value<Technic::Modpack>();
    m_versions.clear();
    m_versionIndex = -1;
    QVariantMap info;
    info["name"] = m_technicPack.name;
    info["logo"] = m_model->data(m_model->index(row, 0), NIPackListModel::LogoRole);
    info["detailsLoading"] = !m_technicPack.metadataLoaded;
    m_currentInfo = info;
    emit currentChanged();
    emit versionsChanged();
    if (m_technicPack.broken) {
        m_currentInfo["descriptionHtml"] = tr("This modpack is broken and can't be installed.");
        emit currentChanged();
        if (m_active && m_controller) {
            m_controller->setSuggestedPack();
        }
        return;
    }
    if (m_technicPack.metadataLoaded) {
        technicMetadataLoaded();
        return;
    }
    m_versionsLoading = true;
    emit versionsChanged();
    auto netJob = makeShared<NetJob>(QString("Technic::PackMeta(%1)").arg(m_technicPack.name), APPLICATION->network());
    const QString slug = m_technicPack.slug;
    auto [action, responsePtr] = Net::ApiRequest::makeByteArray(
        QString("%1modpack/%2?build=%3").arg(BuildConfig.TECHNIC_API_BASE_URL, slug, BuildConfig.TECHNIC_API_BUILD));
    netJob->addNetAction(action);
    connect(netJob.get(), &NetJob::succeeded, this, [this, responsePtr, slug] {
        QByteArray response = std::move(*responsePtr);
        if (m_technicPack.slug != slug) {
            return;
        }
        auto doc = Json::requireDocument(response);
        if (!doc) {
            emit error(tr("Error while parsing the Technic response: %1").arg(doc.error()));
            return;
        }
        auto obj = doc->object();
        auto url = obj["url"];
        if (url.isString() && !url.toString().isEmpty()) {
            m_technicPack.url = url.toString();
        } else if (obj["solder"].isString()) {
            m_technicPack.url = obj["solder"].toString();
            m_technicPack.isSolder = true;
        } else {
            emit error(tr("This Technic pack has no download URL."));
            m_versionsLoading = false;
            emit versionsChanged();
            return;
        }
        m_technicPack.minecraftVersion = obj["minecraft"].toString();
        m_technicPack.websiteUrl = obj["platformUrl"].toString();
        m_technicPack.author = obj["user"].toString();
        m_technicPack.description = obj["description"].toString();
        m_technicPack.currentVersion = obj["version"].toString();
        m_technicPack.metadataLoaded = true;
        technicMetadataLoaded();
    });
    connect(netJob.get(), &NetJob::failed, this, [this](const QString& reason) {
        m_versionsLoading = false;
        emit versionsChanged();
        emit error(reason);
    });
    m_detailsJob = netJob;
    netJob->start();
}

void NIPackBrowser::technicMetadataLoaded()
{
    QVariantMap info = m_currentInfo;
    info["name"] = m_technicPack.name;
    info["websiteUrl"] = m_technicPack.websiteUrl;
    info["authorsHtml"] = m_technicPack.author.toHtmlEscaped();
    info["mcVersion"] = m_technicPack.minecraftVersion;
    info["descriptionHtml"] = cleanHtml(m_technicPack.description);
    info["detailsLoading"] = false;
    if (!m_technicPack.websiteUrl.isEmpty()) {
        info["links"] = QVariantList{ link(tr("Technic page"), m_technicPack.websiteUrl) };
    }
    m_currentInfo = info;
    emit currentChanged();

    if (m_technicPack.isSolder) {
        while (m_technicPack.url.endsWith('/')) {
            m_technicPack.url.chop(1);
        }
    }

    auto makeList = [this](const QStringList& names, const QString& preferred) {
        QVariantList list;
        int pick = 0;
        for (const auto& n : names) {
            if (n == preferred) {
                pick = static_cast<int>(list.size());
            }
            list << QVariantMap{ { "name", n }, { "text", n == m_technicPack.recommended ? tr("%1 (recommended)").arg(n) : n } };
        }
        m_versionsLoading = false;
        setVersions(list, pick);
    };

    if (!m_technicPack.isSolder) {
        makeList({ m_technicPack.currentVersion }, m_technicPack.currentVersion);
    } else if (m_technicPack.versionsLoaded) {
        QStringList reversed;
        for (auto i = m_technicPack.versions.size(); (i--) != 0;) {
            reversed << m_technicPack.versions.at(i);
        }
        makeList(reversed, m_technicPack.recommended);
    } else {
        makeList({ m_technicPack.currentVersion }, m_technicPack.currentVersion);
        m_versionsLoading = true;
        emit versionsChanged();
        auto netJob = makeShared<NetJob>(QString("Technic::SolderMeta(%1)").arg(m_technicPack.name), APPLICATION->network());
        auto [action, response] = Net::ApiRequest::makeByteArray(QUrl(QString("%1/modpack/%2").arg(m_technicPack.url, m_technicPack.slug)));
        netJob->addNetAction(action);
        const auto slug = m_technicPack.slug;
        connect(netJob.get(), &NetJob::succeeded, this, [this, response, slug] {
            if (m_technicPack.slug != slug) {
                return;
            }
            technicSolderLoaded(response);
        });
        connect(netJob.get(), &NetJob::failed, this, [this](const QString& reason) {
            m_versionsLoading = false;
            emit versionsChanged();
            emit error(reason);
        });
        m_versionsJob = netJob;
        netJob->start();
    }
}

void NIPackBrowser::technicSolderLoaded(QByteArray* responsePtr)
{
    QByteArray response = std::move(*responsePtr);
    m_technicPack.versions.clear();
    TechnicSolder::Pack pack;
    auto doc = Json::requireDocument(response).and_then([&pack](const auto& v) {
        auto obj = v.object();
        return TechnicSolder::loadPack(pack, obj);
    });
    m_technicPack.versionsLoaded = true;
    if (!doc) {
        m_technicPack.versions.append(m_technicPack.currentVersion);
    } else {
        m_technicPack.recommended = pack.recommended;
        m_technicPack.versions.append(pack.builds);
    }
    technicMetadataLoaded();
}

// ============================================================================ ATLauncher

void NIPackBrowser::selectAtl(int row)
{
    m_atlPack = m_model->index(row, 0).data(Qt::UserRole).value<ATLauncher::IndexedPack>();
    QVariantMap info;
    info["name"] = m_atlPack.name;
    info["logo"] = m_model->data(m_model->index(row, 0), NIPackListModel::LogoRole);
    info["descriptionHtml"] = cleanHtml(QString(m_atlPack.description).replace("\n", "<br>"));
    info["websiteUrl"] = QString("https://atlauncher.com/pack/%1").arg(m_atlPack.safeName);
    info["links"] = QVariantList{ link(tr("ATLauncher page"), info["websiteUrl"].toString()) };
    if (!m_atlPack.versions.isEmpty()) {
        info["mcVersion"] = m_atlPack.versions.first().minecraft;
    }
    m_currentInfo = info;
    emit currentChanged();
    QVariantList list;
    for (const auto& v : m_atlPack.versions) {
        list << QVariantMap{ { "name", v.version }, { "text", v.version }, { "mcVersions", v.minecraft } };
    }
    m_versionsLoading = false;
    setVersions(list, 0);
}

// ============================================================================ FTB

void NIPackBrowser::selectFtb(int row)
{
    m_ftbPack = m_model->index(row, 0).data(Qt::UserRole).value<FTB::Modpack>();
    QVariantMap info;
    info["name"] = m_ftbPack.name;
    info["summary"] = m_ftbPack.synopsis;
    info["logo"] = m_model->data(m_model->index(row, 0), NIPackListModel::LogoRole);
    info["descriptionHtml"] = cleanHtml(markdownToHTML(m_ftbPack.description.toUtf8()));
    QStringList authors;
    for (const auto& a : m_ftbPack.authors) {
        authors << (a.website.isEmpty() ? a.name.toHtmlEscaped() : QString("<a href=\"%1\">%2</a>").arg(a.website, a.name.toHtmlEscaped()));
    }
    info["authorsHtml"] = authors.join(", ");
    info["websiteUrl"] = QString("https://www.feed-the-beast.com/modpacks/%1").arg(m_ftbPack.id);
    info["links"] = QVariantList{ link(tr("FTB page"), info["websiteUrl"].toString()) };
    m_currentInfo = info;
    emit currentChanged();
    QVariantList list;
    for (auto i = m_ftbPack.versions.size(); i--;) {
        const auto& v = m_ftbPack.versions.at(i);
        list << QVariantMap{ { "name", v.name }, { "text", v.name }, { "type", v.type } };
    }
    m_versionsLoading = false;
    setVersions(list, 0);
}

// ============================================================================ legacy FTB

QAbstractItemModel* NIPackBrowser::currentLegacyModel() const
{
    const int i = m_legacyTab == "thirdParty" ? 1 : m_legacyTab == "private" ? 2 : 0;
    return m_legacyLists[i];
}

QSortFilterProxyModel* NIPackBrowser::currentLegacyFilter() const
{
    if (!m_legacyFilters[0]) {
        return nullptr;
    }
    const int i = m_legacyTab == "thirdParty" ? 1 : m_legacyTab == "private" ? 2 : 0;
    return m_legacyFilters[i];
}

void NIPackBrowser::setLegacyTab(const QString& tab)
{
    if (tab == m_legacyTab || !m_legacyFilters[0]) {
        return;
    }
    m_legacyTab = tab;
    m_model->setSource(currentLegacyFilter());
    applyLocalSearch();
    emit legacyTabChanged();
    clearSelection();
}

void NIPackBrowser::selectLegacy(int row)
{
    m_legacyPack = m_model->index(row, 0).data(Qt::UserRole).value<LegacyFTB::Modpack>();
    QVariantMap info;
    info["name"] = m_legacyPack.name;
    info["logo"] = m_model->data(m_model->index(row, 0), NIPackListModel::LogoRole);
    info["authorsHtml"] = m_legacyPack.author.toHtmlEscaped();
    info["mcVersion"] = m_legacyPack.mcVersion;
    QString mods = m_legacyPack.mods;
    info["descriptionHtml"] =
        cleanHtml(m_legacyPack.description + "<h4>" + tr("Mods") + "</h4><ul><li>" + mods.replace(";", "</li><li>") + "</li></ul>");
    if (m_legacyPack.broken) {
        info["warning"] = tr("This pack is marked as broken and can't be installed.");
    }
    m_currentInfo = info;
    emit currentChanged();
    QVariantList list;
    bool currentAdded = false;
    for (const auto& v : m_legacyPack.oldVersions) {
        if (v == m_legacyPack.currentVersion) {
            currentAdded = true;
        }
        list << QVariantMap{ { "name", v }, { "text", v } };
    }
    if (!currentAdded) {
        list << QVariantMap{ { "name", m_legacyPack.currentVersion }, { "text", m_legacyPack.currentVersion } };
    }
    m_versionsLoading = false;
    setVersions(list, 0);
}

void NIPackBrowser::addPrivatePack(const QString& code)
{
    if (!m_legacyFetch || code.trimmed().isEmpty()) {
        return;
    }
    m_legacyPrivate->add(code.trimmed());
    m_legacyFetch->fetchPrivate({ code.trimmed() });
}

void NIPackBrowser::removePrivatePack(int row)
{
    if (!m_legacyFetch || m_legacyTab != "private") {
        return;
    }
    const auto srcRow = m_legacyFilters[2]->mapToSource(m_legacyFilters[2]->index(row, 0)).row();
    if (srcRow < 0) {
        return;
    }
    auto pack = m_legacyLists[2]->at(srcRow);
    m_legacyPrivate->remove(pack.packCode);
    m_legacyLists[2]->remove(srcRow);
    clearSelection();
}

void NIPackBrowser::forgetPrivatePackCode(const QString& code)
{
    if (m_legacyPrivate) {
        m_legacyPrivate->remove(code);
    }
}

// ============================================================================ FTB app import

QString NIPackBrowser::ftbAppPath() const
{
    return m_ftbApp ? m_ftbApp->getUserPath() : QString();
}

void NIPackBrowser::setFtbAppPath(const QUrl& dir)
{
    if (!m_ftbApp) {
        return;
    }
    const auto path = dir.isLocalFile() ? dir.toLocalFile() : dir.toString();
    if (path.isEmpty()) {
        return;
    }
    m_ftbApp->setPath(path);
    clearSelection();
    emit ftbAppPathChanged();
}

void NIPackBrowser::selectFtbApp(int row)
{
    m_ftbAppPack = m_model->index(row, 0).data(Qt::UserRole).value<FTBImportAPP::Modpack>();
    QVariantMap info;
    info["name"] = m_ftbAppPack.name;
    info["logo"] = m_model->data(m_model->index(row, 0), NIPackListModel::LogoRole);
    info["mcVersion"] = m_ftbAppPack.mcVersion;
    QString loader;
    if (m_ftbAppPack.loaderType) {
        loader = ModPlatform::getModLoaderAsString(*m_ftbAppPack.loaderType) + " " + m_ftbAppPack.loaderVersion;
    }
    info["descriptionHtml"] = tr("Installed with the FTB app in<br><code>%1</code><br><br>Minecraft %2%3<br>Play time: %4 h")
                                  .arg(m_ftbAppPack.path.toHtmlEscaped(), m_ftbAppPack.mcVersion,
                                       loader.isEmpty() ? QString() : " · " + loader.toHtmlEscaped(),
                                       QString::number(m_ftbAppPack.totalPlayTime / 3600.0, 'f', 1));
    m_currentInfo = info;
    emit currentChanged();
    m_versionsLoading = false;
    setVersions({ QVariantMap{ { "name", m_ftbAppPack.version }, { "text", m_ftbAppPack.version } } }, 0);
}

void NIPackBrowser::suggestFtbAppIcon()
{
    const QString editedLogoName = QString("ftb_%1_%2.jpg").arg(m_ftbAppPack.name, QString::number(m_ftbAppPack.id));
    auto iconPath = FS::PathCombine(m_ftbAppPack.path, "folder.jpg");
    if (!QFileInfo::exists(iconPath) && !m_ftbAppPack.icon.isNull()) {
        auto sizes = m_ftbAppPack.icon.availableSizes();
        QPixmap pixmap = m_ftbAppPack.icon.pixmap(sizes.isEmpty() ? QSize(128, 128) : sizes.last());
        QTemporaryFile tempFile(QDir::tempPath() + "/iconXXXXXX.png");
        tempFile.setAutoRemove(false);
        iconPath.clear();
        if (tempFile.open()) {
            const auto tempPath = tempFile.fileName();
            tempFile.close();
            if (pixmap.save(tempPath, "PNG")) {
                iconPath = tempPath;
            }
        }
    }
    if (!iconPath.isEmpty() && QFileInfo::exists(iconPath)) {
        m_controller->setSuggestedIconFromFile(iconPath, editedLogoName);
    }
}
