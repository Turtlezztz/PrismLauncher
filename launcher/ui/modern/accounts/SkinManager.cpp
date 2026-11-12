#include "SkinManager.h"

#include <QFileDialog>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkReply>
#include <QDateTime>
#include <QPainter>

#include "AccountsModel.h"
#include "Application.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "ImageProviders.h"
#include "minecraft/auth/AuthFlow.h"
#include "minecraft/auth/Parsers.h"
#include "minecraft/skins/SkinList.h"
#include "minecraft/skins/SkinModel.h"
#include "minecraft/skins/SkinRequests.h"
#include "net/NetJob.h"
#include "net/Request.h"
#include "settings/SettingsObject.h"

namespace {

/// Draws a 16x32 front or back view of a 64x64 skin texture (2D, pixel art).
QImage renderBody(const QImage& tex, bool slim, bool back, const QImage& cape)
{
    QImage out(16, 32, QImage::Format_ARGB32);
    out.fill(Qt::transparent);
    if (tex.isNull() || tex.width() != 64 || tex.height() != 64) {
        return out;
    }
    QPainter p(&out);
    const int aw = slim ? 3 : 4;
    auto part = [&](int sx, int sy, int w, int h, int dx, int dy) { p.drawImage(dx, dy, tex.copy(sx, sy, w, h)); };
    if (!back) {
        part(8, 8, 8, 8, 4, 0);      // head
        part(40, 8, 8, 8, 4, 0);     // hat
        part(20, 20, 8, 12, 4, 8);   // body
        part(20, 36, 8, 12, 4, 8);   // jacket
        part(44, 20, aw, 12, 4 - aw, 8);  // right arm (viewer's left)
        part(44, 36, aw, 12, 4 - aw, 8);
        part(36, 52, aw, 12, 12, 8);      // left arm
        part(52, 52, aw, 12, 12, 8);
        part(4, 20, 4, 12, 4, 20);   // right leg
        part(4, 36, 4, 12, 4, 20);
        part(20, 52, 4, 12, 8, 20);  // left leg
        part(4, 52, 4, 12, 8, 20);
    } else {
        part(24, 8, 8, 8, 4, 0);     // head
        part(56, 8, 8, 8, 4, 0);
        part(32, 20, 8, 12, 4, 8);   // body
        part(32, 36, 8, 12, 4, 8);
        part(slim ? 51 : 52, 20, aw, 12, 12, 8);  // right arm (viewer's right)
        part(slim ? 51 : 52, 36, aw, 12, 12, 8);
        part(slim ? 43 : 44, 52, aw, 12, 4 - aw, 8);  // left arm
        part(slim ? 59 : 60, 52, aw, 12, 4 - aw, 8);
        part(12, 20, 4, 12, 8, 20);  // right leg
        part(12, 36, 4, 12, 8, 20);
        part(28, 52, 4, 12, 4, 20);  // left leg
        part(12, 52, 4, 12, 4, 20);
        if (!cape.isNull() && cape.width() >= 22 && cape.height() >= 17) {
            p.drawImage(3, 8, cape.copy(1, 1, 10, 16));
        }
    }
    return out;
}

QImage previewCape(const QImage& capeImage, bool elytra)
{
    if (capeImage.isNull()) {
        return {};
    }
    if (elytra) {
        auto wing = capeImage.copy(34, 2, 12, 20);
        QImage mirrored = wing.mirrored(true, false);
        QImage combined((wing.width() * 2) + 1, wing.height() + 14, QImage::Format_ARGB32);
        combined.fill(Qt::transparent);
        QPainter painter(&combined);
        painter.drawImage(0, 7, wing);
        painter.drawImage(wing.width() + 1, 7, mirrored);
        painter.end();
        return combined;
    }
    return capeImage.copy(1, 1, 10, 16);
}

}  // namespace

SkinManager::SkinManager(QObject* parent) : QObject(parent) {}

SkinManager::~SkinManager()
{
    if (m_task && m_task->isRunning()) {
        m_task->disconnect(this);
        m_task->abort();
    }
}

void SkinManager::setAccountId(const QString& id)
{
    if (id == m_accountId) {
        return;
    }
    m_accountId = id;
    m_account = AccountsModel::findAccount(id);
    delete m_list;
    m_list = nullptr;
    if (m_account) {
        m_list = new SkinList(this, APPLICATION->settings()->get("SkinsDir").toString(), m_account);
        m_list->startWatching();
        connect(m_list, &QAbstractItemModel::modelReset, this, &SkinManager::rebuild);
        connect(m_list, &QAbstractItemModel::layoutChanged, this, &SkinManager::rebuild);
        connect(m_list, &QAbstractItemModel::rowsInserted, this, &SkinManager::rebuild);
        connect(m_list, &QAbstractItemModel::rowsRemoved, this, &SkinManager::rebuild);
        connect(m_list, &QAbstractItemModel::dataChanged, this, &SkinManager::rebuild);
        setupCapes();
        const int current = m_list->getSelectedAccountSkin();
        if (current >= 0) {
            m_selected = m_list->index(current).data(Qt::UserRole).toString();
        }
    }
    emit accountIdChanged();
    rebuild();
}

QString SkinManager::folder() const
{
    return m_list ? m_list->getDir() : QString();
}

QString SkinManager::renderKey(SkinModel* skin, bool back)
{
    // deterministic key: file + modification time + model + cape + side, so the cache doesn't grow on every refresh
    const QFileInfo info(skin->getPath());
    const auto key = QString("skin/%1/%2/%3/%4/%5")
                         .arg(qHash(info.absoluteFilePath()))
                         .arg(info.lastModified().toMSecsSinceEpoch())
                         .arg(skin->getModel() == SkinModel::SLIM ? "slim" : "classic", back ? skin->getCapeId() : QString(),
                              back ? "back" : "front");
    if (PixmapCacheProvider::contains(key)) {
        return "image://pixmap/" + key;
    }
    const QImage cape = m_capes.value(skin->getCapeId());
    PixmapCacheProvider::insert(key, QPixmap::fromImage(renderBody(skin->getTexture(), skin->getModel() == SkinModel::SLIM, back, cape)));
    return "image://pixmap/" + key;
}

void SkinManager::rebuild()
{
    m_skins.clear();
    if (m_list) {
        const int inUse = m_list->getSelectedAccountSkin();
        for (int i = 0; i < m_list->rowCount(); i++) {
            const auto name = m_list->index(i).data(Qt::UserRole).toString();
            auto* skin = m_list->skin(name);
            if (!skin || !skin->isValid()) {
                continue;
            }
            m_skins << QVariantMap{ { "name", name },
                                    { "front", renderKey(skin, false) },
                                    { "slim", skin->getModel() == SkinModel::SLIM },
                                    { "capeId", skin->getCapeId() },
                                    { "inUse", i == inUse } };
        }
    }
    emit skinsChanged();
    emit selectionChanged();
}

SkinModel* SkinManager::selectedSkin() const
{
    if (!m_list || m_selected.isEmpty()) {
        return nullptr;
    }
    auto* skin = m_list->skin(m_selected);
    return skin && skin->isValid() ? skin : nullptr;
}

void SkinManager::setSelected(const QString& name)
{
    if (name == m_selected) {
        return;
    }
    m_selected = name;
    emit selectionChanged();
}

QString SkinManager::selectedFront() const
{
    auto* skin = selectedSkin();
    return skin ? const_cast<SkinManager*>(this)->renderKey(skin, false) : QString();
}

QString SkinManager::selectedBack() const
{
    auto* skin = selectedSkin();
    return skin ? const_cast<SkinManager*>(this)->renderKey(skin, true) : QString();
}

bool SkinManager::selectedSlim() const
{
    auto* skin = selectedSkin();
    return skin && skin->getModel() == SkinModel::SLIM;
}

QString SkinManager::selectedCape() const
{
    auto* skin = selectedSkin();
    return skin ? skin->getCapeId() : QString();
}

void SkinManager::setShowElytra(bool on)
{
    if (on == m_showElytra) {
        return;
    }
    m_showElytra = on;
    emit capesChanged();
}

QVariantList SkinManager::capes() const
{
    QVariantList out;
    out << QVariantMap{ { "id", QString() }, { "alias", tr("No cape") }, { "preview", QString() } };
    if (!m_account) {
        return out;
    }
    for (auto& cape : m_account->accountData()->minecraftProfile.capes) {
        QString preview;
        if (m_capes.contains(cape.id)) {
            const auto key = QString("cape/%1/%2").arg(cape.id, m_showElytra ? "elytra" : "cape");
            if (!PixmapCacheProvider::contains(key)) {
                PixmapCacheProvider::insert(key, QPixmap::fromImage(previewCape(m_capes.value(cape.id), m_showElytra)));
            }
            preview = "image://pixmap/" + key;
        }
        out << QVariantMap{ { "id", cape.id }, { "alias", cape.alias }, { "preview", preview } };
    }
    return out;
}

void SkinManager::setupCapes()
{
    m_capes.clear();
    if (!m_account || !m_list) {
        return;
    }
    auto& data = *m_account->accountData();
    const auto capesDir = FS::PathCombine(m_list->getDir(), "capes");
    FS::ensureFolderPathExists(capesDir);
    NetJob::Ptr job{ new NetJob(tr("Download capes"), APPLICATION->network()) };
    bool needsToDownload = false;
    for (auto& cape : data.minecraftProfile.capes) {
        const auto path = FS::PathCombine(capesDir, cape.id + ".png");
        QImage capeImage;
        if (!cape.data.isEmpty() && capeImage.loadFromData(cape.data, "PNG")) {
            capeImage.save(path);
            m_capes[cape.id] = capeImage;
            continue;
        }
        if (QFileInfo::exists(path) && capeImage.load(path)) {
            m_capes[cape.id] = capeImage;
            continue;
        }
        if (!cape.url.isEmpty()) {
            needsToDownload = true;
            job->addNetAction(Net::Request::makeFile(cape.url, path));
        }
    }
    emit capesChanged();
    if (!needsToDownload) {
        return;
    }
    connect(job.get(), &Task::finished, this, [this, capesDir, job] {
        if (!m_account) {
            return;
        }
        for (auto& cape : m_account->accountData()->minecraftProfile.capes) {
            QImage capeImage;
            const auto path = FS::PathCombine(capesDir, cape.id + ".png");
            if (!m_capes.contains(cape.id) && QFileInfo::exists(path) && capeImage.load(path)) {
                m_capes[cape.id] = capeImage;
            }
        }
        emit capesChanged();
        rebuild();
    });
    job->start();
}

void SkinManager::setSlim(bool slim)
{
    if (auto* skin = selectedSkin()) {
        skin->setModel(slim ? SkinModel::SLIM : SkinModel::CLASSIC);
        m_list->save();
        rebuild();
    }
}

void SkinManager::setCape(const QString& capeId)
{
    if (auto* skin = selectedSkin()) {
        skin->setCapeId(capeId);
        m_list->save();
        rebuild();
    }
}

QString SkinManager::installFromFile(const QString& path)
{
    if (!m_list) {
        return tr("No account selected.");
    }
    auto message = m_list->installSkin(path, {});
    if (message.isEmpty()) {
        m_selected = QFileInfo(path).completeBaseName();
        rebuild();
    }
    return message;
}

QString SkinManager::browseAndInstall()
{
    const auto filter = QMimeDatabase().mimeTypeForName("image/png").filterString();
    const QString rawPath = QFileDialog::getOpenFileName(nullptr, tr("Select Skin Texture"), QString(), filter);
    if (rawPath.isEmpty()) {
        return QStringLiteral("cancelled");
    }
    return installFromFile(rawPath);
}

void SkinManager::setBusy(bool busy, const QString& text)
{
    m_busy = busy;
    m_busyText = text;
    emit busyChanged();
}

void SkinManager::installFromUrl(const QString& urlText)
{
    if (!m_list || m_busy) {
        return;
    }
    const QUrl url(urlText.trimmed());
    if (!url.isValid() || url.scheme().isEmpty()) {
        emit notify("error", tr("Invalid URL"));
        return;
    }
    const auto path = FS::PathCombine(m_list->getDir(), url.fileName().isEmpty() ? "skin.png" : url.fileName());
    auto request = Net::Request::makeFile(url, path);
    request->setNetwork(APPLICATION->network());
    m_task = request;
    setBusy(true, tr("Downloading skin…"));
    connect(request.get(), &Task::finished, this, [this, path, urlText] {
        setBusy(false);
        m_task.reset();
        SkinModel s(path);
        if (!s.isValid()) {
            emit notify("error", QFileInfo::exists(path) ? tr("Skin images must be 64x64 or 64x32 pixel PNG files.")
                                                         : tr("Unable to download the skin: '%1'.").arg(urlText));
            QFile::remove(path);
            return;
        }
        QString finalPath = path;
        if (QFileInfo(path).suffix().isEmpty()) {
            QFile::rename(path, path + ".png");
            finalPath = path + ".png";
        }
        m_selected = QFileInfo(finalPath).completeBaseName();
        rebuild();
        emit notify("success", tr("Skin added."));
    });
    request->start();
}

void SkinManager::importFromUsername(const QString& usernameRaw)
{
    const auto user = usernameRaw.trimmed();
    if (!m_list || m_busy || user.isEmpty()) {
        return;
    }
    setBusy(true, tr("Looking up %1…").arg(user));
    const auto path = FS::PathCombine(m_list->getDir(), user + ".png");

    auto fail = [this, user, path](const QString& why) {
        setBusy(false);
        m_task.reset();
        QFile::remove(path);
        emit notify("error", tr("Unable to find the skin for '%1' because: %2.").arg(user, why));
    };

    // 1. name -> uuid
    auto [lookup, lookupData] = Net::Request::makeByteArray(QUrl("https://api.minecraftservices.com/minecraft/profile/lookup/name/" + user));
    lookup->setNetwork(APPLICATION->network());
    m_task = lookup;
    connect(lookup.get(), &Task::finished, this, [this, lookup, lookupData, fail, path] {
        const auto id = QJsonDocument::fromJson(*lookupData).object().value("id").toString();
        if (lookup->error() != QNetworkReply::NoError || id.isEmpty()) {
            fail(tr("failed to get user UUID"));
            return;
        }
        // 2. uuid -> profile (skin url + model)
        auto [profileReq, profileData] =
            Net::Request::makeByteArray(QUrl("https://sessionserver.mojang.com/session/minecraft/profile/" + id));
        profileReq->setNetwork(APPLICATION->network());
        m_task = profileReq;
        connect(profileReq.get(), &Task::finished, this, [this, profileReq, profileData, fail, path] {
            auto profile = std::make_shared<MinecraftProfile>();
            if (profileReq->error() != QNetworkReply::NoError || !Parsers::parseMinecraftProfileMojang(*profileData, *profile) ||
                profile->skin.url.isEmpty()) {
                fail(tr("failed to get user profile"));
                return;
            }
            // 3. download the texture
            auto download = Net::Request::makeFile(QUrl(profile->skin.url), path);
            download->setNetwork(APPLICATION->network());
            m_task = download;
            connect(download.get(), &Task::finished, this, [this, profile, fail, path] {
                SkinModel s(path);
                if (!s.isValid()) {
                    fail(tr("the skin is invalid"));
                    return;
                }
                setBusy(false);
                m_task.reset();
                s.setModel(profile->skin.variant.toUpper() == "SLIM" ? SkinModel::SLIM : SkinModel::CLASSIC);
                s.setURL(profile->skin.url);
                if (m_capes.contains(profile->currentCape)) {
                    s.setCapeId(profile->currentCape);
                }
                m_list->updateSkin(&s);
                m_selected = QFileInfo(path).completeBaseName();
                rebuild();
                emit notify("success", tr("Skin imported."));
            });
            download->start();
        });
        profileReq->start();
    });
    lookup->start();
}

bool SkinManager::rename(const QString& name, const QString& newName)
{
    if (!m_list || newName.trimmed().isEmpty()) {
        return false;
    }
    const int idx = m_list->getSkinIndex(name);
    if (idx < 0) {
        return false;
    }
    const bool ok = m_list->setData(m_list->index(idx), newName.trimmed(), Qt::EditRole);
    if (ok && m_selected == name) {
        m_selected = newName.trimmed();
    }
    rebuild();
    return ok;
}

QString SkinManager::remove(const QString& name)
{
    if (!m_list) {
        return tr("No account selected.");
    }
    if (m_list->getSkinIndex(name) == m_list->getSelectedAccountSkin()) {
        return tr("Can not delete skin that is in use.");
    }
    if (!m_list->deleteSkin(name, true)) {
        m_list->deleteSkin(name, false);
    }
    if (m_selected == name) {
        m_selected.clear();
    }
    rebuild();
    return {};
}

void SkinManager::openFolder()
{
    if (m_list) {
        DesktopServices::openPath(m_list->getDir(), true);
    }
}

void SkinManager::apply()
{
    auto* skin = selectedSkin();
    if (!skin || !m_account || m_busy) {
        return;
    }
    if (!QFile::exists(skin->getPath())) {
        emit notify("error", tr("Skin file does not exist!"));
        return;
    }
    NetJob::Ptr job{ new NetJob(tr("Change skin"), APPLICATION->network(), 1) };
    job->addNetAction(makeSkinUploadRequest(m_account->accessToken(), skin->getPath(), skin->getModelString()));
    const auto selectedCape = skin->getCapeId();
    if (selectedCape != m_account->accountData()->minecraftProfile.currentCape) {
        job->addNetAction(makeCapeChangeRequest(m_account->accessToken(), selectedCape));
    }
    job->addTask(m_account->refresh().staticCast<Task>());
    m_task = job;
    setBusy(true, tr("Uploading skin…"));
    const auto name = skin->name();
    connect(job.get(), &Task::succeeded, this, [this, name] {
        if (auto* s = m_list->skin(name)) {
            s->setURL(m_account->accountData()->minecraftProfile.skin.url);
            m_list->save();
        }
        setBusy(false);
        m_task.reset();
        rebuild();
        emit notify("success", tr("Skin updated."));
        emit applied();
    });
    connect(job.get(), &Task::failed, this, [this](const QString& reason) {
        setBusy(false);
        m_task.reset();
        emit notify("error", tr("Failed to upload skin!") + (reason.isEmpty() ? QString() : "\n" + reason));
    });
    connect(job.get(), &Task::aborted, this, [this] {
        setBusy(false);
        m_task.reset();
    });
    job->start();
}

void SkinManager::resetSkin()
{
    if (!m_account || m_busy) {
        return;
    }
    NetJob::Ptr job{ new NetJob(tr("Reset skin"), APPLICATION->network(), 1) };
    job->addNetAction(makeSkinDeleteRequest(m_account->accessToken()));
    job->addTask(m_account->refresh().staticCast<Task>());
    m_task = job;
    setBusy(true, tr("Resetting skin…"));
    connect(job.get(), &Task::succeeded, this, [this] {
        setBusy(false);
        m_task.reset();
        rebuild();
        emit notify("success", tr("Skin reset to default."));
        emit applied();
    });
    connect(job.get(), &Task::failed, this, [this](const QString& reason) {
        setBusy(false);
        m_task.reset();
        emit notify("error", tr("Failed to delete current skin!") + (reason.isEmpty() ? QString() : "\n" + reason));
    });
    job->start();
}
