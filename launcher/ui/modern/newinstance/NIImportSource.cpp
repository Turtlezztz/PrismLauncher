#include "NIImportSource.h"

#include <QDir>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QUrlQuery>

#include "Application.h"
#include "BuildConfig.h"
#include "InstanceImportTask.h"
#include "InstanceList.h"
#include "Json.h"
#include "TaskBridge.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/WorldList.h"
#include "minecraft/mod/ModFolderModel.h"
#include "minecraft/mod/ResourcePackFolderModel.h"
#include "minecraft/mod/ShaderPackFolderModel.h"
#include "minecraft/mod/TexturePackFolderModel.h"
#include "minecraft/mod/tasks/LocalResourceParse.h"
#include "modplatform/ResourceType.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/flame/FlameModIndex.h"
#include "modplatform/modrinth/ModrinthAPI.h"
#include "net/ApiRequest.h"
#include "net/NetJob.h"

NIImportSource::NIImportSource(QObject* parent) : QObject(parent) {}

void NIImportSource::setController(NIController* c)
{
    m_controller = c;
    emit controllerChanged();
}

void NIImportSource::setActive(bool a)
{
    if (a == m_active) {
        return;
    }
    m_active = a;
    emit activeChanged();
    if (a) {
        updateState();
    }
}

void NIImportSource::setText(const QString& t)
{
    if (t == m_text) {
        return;
    }
    m_text = t;
    emit textChanged();
    updateState();
}

void NIImportSource::setExtraInfo(const QVariantMap& info)
{
    m_extraInfo.clear();
    for (auto it = info.begin(); it != info.end(); ++it) {
        m_extraInfo.insert(it.key(), it.value().toString());
    }
    updateState();
}

void NIImportSource::suggest(const QString& name, const QUrl& url)
{
    if (m_controller) {
        m_controller->setSuggestedPack(name, {}, new InstanceImportTask(url, false, nullptr, m_extraInfo));
        m_controller->clearSuggestedIcon();
    }
}

void NIImportSource::updateState()
{
    auto setState = [this](const QString& kind, const QString& hint) {
        m_kind = kind;
        m_hint = hint;
        emit stateChanged();
    };
    if (!m_active) {
        return;
    }
    QString input = m_text.trimmed();
    if (input.isEmpty()) {
        if (m_controller) {
            m_controller->setSuggestedPack();
        }
        setState("", {});
        return;
    }
    QUrl url = QUrl::fromUserInput(input);
    const bool fileExists = QFile::exists(input);
    const QUrl asUrl(input);
    const bool validUrl = asUrl.isValid() && !asUrl.isRelative() && !asUrl.isEmpty();
    if (!fileExists && !validUrl) {
        if (m_controller) {
            m_controller->setSuggestedPack();
        }
        setState("invalid", tr("Enter a path to a .zip / .mrpack file or a link to one."));
        return;
    }

    if (url.isLocalFile()) {
        QFileInfo fi(url.toLocalFile());
        const bool isZip = QMimeDatabase().mimeTypeForUrl(url).suffixes().contains("zip");
        const bool isMRPack = fi.suffix() == "mrpack";
        if (fi.exists() && fi.isFile() && (isZip || isMRPack)) {
            suggest(fi.completeBaseName(), url);
            setState("file", isMRPack ? tr("Modrinth modpack") : tr("Zip archive (Prism / MultiMC / CurseForge / Modrinth / Technic)"));
        } else {
            if (m_controller) {
                m_controller->setSuggestedPack();
            }
            setState("invalid", fi.exists() ? tr("This file type is not supported. Choose a .zip or .mrpack file.") : tr("File not found."));
        }
        return;
    }

    if (url.scheme() == "curseforge") {
        QUrlQuery query(url);
        if (query.allQueryItemValues("addonId").isEmpty() || query.allQueryItemValues("fileId").isEmpty()) {
            setState("invalid", tr("Invalid CurseForge link."));
            return;
        }
        auto addonId = query.allQueryItemValues("addonId")[0];
        auto fileId = query.allQueryItemValues("fileId")[0];
        auto [job, array] = FlameAPI::getFile(addonId, fileId);
        m_resolving = true;
        setState("curseforge", tr("Looking up the CurseForge file…"));
        connect(job.get(), &Task::failed, this, [this](const QString& reason) {
            m_resolving = false;
            m_kind = "invalid";
            m_hint = reason;
            emit stateChanged();
        });
        connect(job.get(), &Task::succeeded, this, [this, array, addonId, fileId, input] {
            m_resolving = false;
            if (m_text.trimmed() != input) {
                return;
            }
            auto doc = Json::requireDocument(*array);
            if (!doc) {
                m_kind = "invalid";
                m_hint = doc.error();
                emit stateChanged();
                return;
            }
            auto data = doc->object()["data"].toObject();
            auto fileName = data["fileName"].toString();
            if (!fileName.endsWith(".zip")) {
                m_kind = "invalid";
                m_hint = tr("This URL isn't a valid modpack!");
                emit stateChanged();
                return;
            }
            auto dlUrl = QUrl(data["downloadUrl"].toString(""));
            if (!dlUrl.isValid()) {
                m_kind = "invalid";
                m_hint = tr("The modpack %1 is blocked for third-parties! Please download it manually.").arg(fileName);
                emit stateChanged();
                return;
            }
            QFileInfo dlFile(dlUrl.fileName());
            m_extraInfo.insert("pack_id", addonId);
            m_extraInfo.insert("pack_version_id", fileId);
            suggest(data["displayName"].toString(dlFile.completeBaseName()), dlUrl);
            m_kind = "curseforge";
            m_hint = tr("CurseForge modpack: %1").arg(fileName);
            emit stateChanged();
        });
        m_job = job;
        job->start();
        return;
    }

    if (input.endsWith("?client=y")) {
        input.chop(9);
        input.append("/file");
        url = QUrl::fromUserInput(input);
    }
    QFileInfo fi(url.fileName());
    suggest(fi.completeBaseName(), url);
    setState("url", tr("The file will be downloaded from %1").arg(url.host()));
}

// ------------------------------------------------------------------------ URL processing

void NIImportSource::processUrls(const QList<QUrl>& urls)
{
    m_queue.append(urls);
    if (!m_busy) {
        processNext();
    }
}

void NIImportSource::processNext()
{
    while (!m_queue.isEmpty()) {
        QUrl url = m_queue.takeFirst();
        if (url.isEmpty() || url.toString().trimmed().isEmpty()) {
            continue;
        }
        if (url.scheme().isEmpty()) {
            url.setScheme("file");
        }
        m_pendingExtra.clear();
        m_pendingVersion = {};

        if (url.isLocalFile()) {
            identifyLocal(url.toLocalFile());
            return;
        }

        if (url.scheme().compare("modrinth", Qt::CaseInsensitive) == 0) {
            const auto packId = ModrinthAPI::getModpackIdFromUrl(url);
            if (!packId.isEmpty()) {
                emit modrinthPackRequested(packId);
            } else {
                emit error(tr("Unsupported Modrinth link.<br><br>%1 currently only supports modpack links such as "
                              "modrinth://modpack/fabulously-optimized.")
                               .arg(BuildConfig.LAUNCHER_DISPLAYNAME));
            }
            continue;
        }

        const bool isExternalImport = url.host().toLower() == "import" || url.path().startsWith("/import", Qt::CaseInsensitive);
        const auto binary = BuildConfig.LAUNCHER_APP_BINARY_NAME;

        if (url.scheme() == "curseforge" || (url.scheme() == binary && url.host() == "install")) {
            QUrlQuery query(url);
            if (url.scheme() == binary && query.queryItemValue("platform").toLower() != "curseforge") {
                qDebug() << "Invalid mod distribution platform:" << query.queryItemValue("platform");
                continue;
            }
            if (query.allQueryItemValues("addonId").isEmpty() || query.allQueryItemValues("fileId").isEmpty()) {
                emit error(tr("Invalid CurseForge link."));
                continue;
            }
            auto addonId = query.allQueryItemValues("addonId")[0];
            auto fileId = query.allQueryItemValues("fileId")[0];
            m_pendingExtra.insert("pack_id", addonId);
            m_pendingExtra.insert("pack_version_id", fileId);
            auto [job, array] = FlameAPI::getFile(addonId, fileId);
            m_busy = true;
            auto* bridge = new TaskBridge(this);
            bridge->setTask(job, tr("Resolving CurseForge link"));
            connect(job.get(), &Task::failed, this, [this](const QString& reason) {
                emit error(reason);
                m_busy = false;
                processNext();
            });
            connect(job.get(), &Task::aborted, this, [this] {
                m_busy = false;
                processNext();
            });
            connect(job.get(), &Task::succeeded, this, [this, array] {
                auto doc = Json::requireDocument(*array);
                if (!doc) {
                    emit error(doc.error());
                    m_busy = false;
                    processNext();
                    return;
                }
                auto data = doc->object()["data"].toObject();
                auto versionRes = FlameMod::loadIndexedPackVersion(data);
                if (!versionRes) {
                    emit error(versionRes.error());
                    m_busy = false;
                    processNext();
                    return;
                }
                m_pendingVersion = versionRes.value();
                QUrl dlUrl(m_pendingVersion.downloadUrl);
                if (!dlUrl.isValid()) {
                    emit error(tr("The modpack, mod, or resource %1 is blocked for third-parties! Please download it manually.")
                                   .arg(m_pendingVersion.fileName));
                    m_busy = false;
                    processNext();
                    return;
                }
                downloadThenIdentify(dlUrl);
            });
            emit taskStarted(bridge);
            bridge->start();
            return;
        }

        if (url.scheme() == binary && !isExternalImport) {
            // OAuth reply (e.g. Microsoft login redirect)
            QVariantMap received;
            const QUrlQuery query(url.query());
            for (const auto& item : query.queryItems()) {
                received.insert(item.first, item.second);
            }
            emit APPLICATION->oauthReplyRecieved(received);
            continue;
        }

        if ((url.scheme() == "prismlauncher" || url.scheme() == binary) && isExternalImport) {
            const auto host = url.host().toLower();
            QString encoded;
            {
                QUrlQuery query(url);
                const auto values = query.allQueryItemValues("url");
                if (!values.isEmpty()) {
                    encoded = values.first();
                }
            }
            if (encoded.isEmpty()) {
                QString p = url.path();
                if (p.startsWith("/import/", Qt::CaseInsensitive)) {
                    p = p.mid(QString("/import/").size());
                } else if (host == "import" && p.startsWith("/")) {
                    p = p.mid(1);
                }
                if (!p.isEmpty() && p != "/import") {
                    encoded = p;
                }
            }
            if (encoded.isEmpty()) {
                emit error(tr("Invalid import link: missing 'url' parameter."));
                continue;
            }
            const QUrl target = QUrl::fromUserInput(QUrl::fromPercentEncoding(encoded.toUtf8()).trimmed());
            if (!target.isValid() || (target.scheme() != "https" && target.scheme() != "http")) {
                emit error(tr("Invalid import link: URL must be http(s)."));
                continue;
            }
            m_busy = true;
            emit downloadConfirmationRequested(target, target.host());
            return;
        }

        m_busy = true;
        downloadThenIdentify(url);
        return;
    }
    m_busy = false;
}

void NIImportSource::confirmDownload(const QUrl& url, bool accepted)
{
    if (accepted) {
        downloadThenIdentify(url);
    } else {
        m_busy = false;
        processNext();
    }
}

void NIImportSource::downloadThenIdentify(const QUrl& url)
{
    m_busy = true;
    const QString path = url.host() + '/' + url.path();
    auto entry = APPLICATION->metacache()->resolveEntry("general", path);
    entry->setStale(true);
    auto job = makeShared<NetJob>(tr("Modpack download"), APPLICATION->network());
    job->addNetAction(Net::ApiRequest::makeCached(url, entry));
    const auto archivePath = entry->getFullPath();
    auto* bridge = new TaskBridge(this);
    bridge->setTask(job, tr("Downloading %1").arg(url.fileName().isEmpty() ? url.host() : url.fileName()));
    connect(job.get(), &Task::failed, this, [this](const QString& reason) {
        emit error(reason);
        m_busy = false;
        processNext();
    });
    connect(job.get(), &Task::aborted, this, [this] {
        m_busy = false;
        processNext();
    });
    connect(job.get(), &Task::succeeded, this, [this, archivePath] { identifyLocal(archivePath); });
    emit taskStarted(bridge);
    bridge->start();
}

void NIImportSource::identifyLocal(const QString& rawPath)
{
    m_busy = true;
    const auto path = QDir::toNativeSeparators(rawPath);
    QFileInfo info(path);
    if (path.isEmpty() || !info.exists()) {
        qDebug() << "Ignoring invalid path" << path;
        m_busy = false;
        processNext();
        return;
    }
    auto type = ResourceUtils::identify(info);
    if (ModPlatform::ResourceTypeUtils::g_VALID_RESOURCES.count(type) == 0) {
        QVariantMap extra;
        for (auto it = m_pendingExtra.begin(); it != m_pendingExtra.end(); ++it) {
            extra.insert(it.key(), it.value());
        }
        emit packRequested(path, extra);
        m_busy = false;
        processNext();
        return;
    }
    if (APPLICATION->instances()->count() <= 0) {
        emit error(tr("No instance available to add the resource to.<br>Please create a new instance before attempting to install this "
                      "resource again."));
        m_busy = false;
        processNext();
        return;
    }
    // wait for installResource() / the user cancelling (installResource with an empty id)
    emit resourceRequested(path, static_cast<int>(type), ModPlatform::ResourceTypeUtils::getName(type));
}

QString NIImportSource::installResource(const QString& path, int typeInt, const QString& instanceId)
{
    QString err;
    if (!instanceId.isEmpty()) {
        auto* inst = APPLICATION->instances()->getInstanceById(instanceId);
        if (!inst) {
            err = tr("Instance not found.");
        } else {
            switch (static_cast<ModPlatform::ResourceType>(typeInt)) {
                case ModPlatform::ResourceType::ResourcePack:
                    inst->resourcePackList()->installResourceWithFlameMetadata(path, m_pendingVersion);
                    break;
                case ModPlatform::ResourceType::TexturePack:
                    inst->texturePackList()->installResourceWithFlameMetadata(path, m_pendingVersion);
                    break;
                case ModPlatform::ResourceType::DataPack:
                    err = tr("Importing data packs this way is not supported. Add it to a world from the instance's Worlds page.");
                    break;
                case ModPlatform::ResourceType::Mod:
                    inst->loaderModList()->installResourceWithFlameMetadata(path, m_pendingVersion);
                    break;
                case ModPlatform::ResourceType::ShaderPack:
                    inst->shaderPackList()->installResourceWithFlameMetadata(path, m_pendingVersion);
                    break;
                case ModPlatform::ResourceType::World:
                    inst->worldList()->installWorld(QFileInfo(path));
                    break;
                default:
                    err = tr("Can't identify this file.");
                    break;
            }
        }
    }
    m_busy = false;
    QMetaObject::invokeMethod(this, &NIImportSource::processNext, Qt::QueuedConnection);
    return err;
}
