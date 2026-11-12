#include "InstanceBridge.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include "Application.h"
#include "DesktopServices.h"
#include "ImageProviders.h"
#include "InstanceList.h"
#include "InstanceModel.h"
#include "MMCTime.h"
#include "ModernLaunchHandler.h"
#include "icons/IconList.h"
#include "launch/LaunchTask.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/WorldList.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/launch/MinecraftTarget.h"
#include "settings/SettingsObject.h"
#include "tools/BaseProfiler.h"

InstanceBridge::InstanceBridge(QObject* parent) : QObject(parent)
{
    connect(APPLICATION->accounts(), &AccountList::listChanged, this, &InstanceBridge::accountsChanged);
    connect(static_cast<QAbstractItemModel*>(APPLICATION->icons()), &QAbstractItemModel::dataChanged, this, [this] {
        m_iconRev++;
        emit propertiesChanged();
    });
    connect(ModernLaunchHandler::instance(), &ModernLaunchHandler::instanceTaskChanged, this, [this](const QString& id) {
        if (id == m_id) {
            hookAuxTask();
        }
    });
    // keep "last played"/"play time" fresh while the page is open
    auto* timer = new QTimer(this);
    timer->setInterval(30000);
    connect(timer, &QTimer::timeout, this, &InstanceBridge::propertiesChanged);
    timer->start();
}

void InstanceBridge::setInstanceId(const QString& id)
{
    if (id == m_id && m_inst) {
        return;
    }
    for (auto& c : m_conns) {
        disconnect(c);
    }
    m_conns.clear();
    m_id = id;
    m_inst = APPLICATION->instances()->getInstanceById(id);
    m_restartQueued = false;
    if (m_inst) {
        auto* inst = m_inst.data();
        m_conns << connect(inst, &BaseInstance::propertiesChanged, this, &InstanceBridge::propertiesChanged);
        m_conns << connect(inst, &BaseInstance::profilerChanged, this, &InstanceBridge::profilerChanged);
        m_conns << connect(inst, &BaseInstance::launchTaskChanged, this, &InstanceBridge::hookLaunchTask);
        m_conns << connect(inst, &BaseInstance::statusChanged, this, [this](BaseInstance::Status, BaseInstance::Status to) {
            if (to == BaseInstance::Status::Gone) {
                emit gone();
            }
        });
        m_conns << connect(inst, &BaseInstance::runningStatusChanged, this, [this](bool running) {
            emit stateChanged();
            emit propertiesChanged();
            if (!running && m_restartQueued) {
                m_restartQueued = false;
                // let the current launch controller finish before launching again
                QTimer::singleShot(0, this, [this] {
                    launch();
                    emit stateChanged();
                });
            }
        });
        if (auto* profile = inst->getPackProfile()) {
            m_conns << connect(profile, &PackProfile::minecraftChanged, this, &InstanceBridge::propertiesChanged);
            m_conns << connect(profile, &QAbstractItemModel::dataChanged, this, &InstanceBridge::propertiesChanged);
            m_conns << connect(profile, &QAbstractItemModel::modelReset, this, &InstanceBridge::propertiesChanged);
        }
        hookLaunchTask(inst->getLaunchTask());
    } else {
        hookLaunchTask(nullptr);
    }
    hookAuxTask();
    emit instanceIdChanged();
    emit propertiesChanged();
    emit notesChanged();
    emit stateChanged();
    emit profilerChanged();
}

void InstanceBridge::hookLaunchTask(LaunchTask* task)
{
    for (auto& c : m_taskConns) {
        disconnect(c);
    }
    m_taskConns.clear();
    m_launchTask = task;
    if (task) {
        m_taskConns << connect(task, &Task::status, this, &InstanceBridge::progressChanged);
        m_taskConns << connect(task, &Task::progress, this, &InstanceBridge::progressChanged);
        m_taskConns << connect(task, &Task::finished, this, [this] {
            emit stateChanged();
            emit progressChanged();
        });
        m_taskConns << connect(task, &Task::started, this, &InstanceBridge::stateChanged);
    }
    emit stateChanged();
    emit progressChanged();
}

void InstanceBridge::hookAuxTask()
{
    for (auto& c : m_auxConns) {
        disconnect(c);
    }
    m_auxConns.clear();
    m_auxTask = ModernLaunchHandler::instance()->taskFor(m_id);
    if (m_auxTask) {
        m_auxConns << connect(m_auxTask.data(), &Task::status, this, &InstanceBridge::progressChanged);
        m_auxConns << connect(m_auxTask.data(), &Task::progress, this, &InstanceBridge::progressChanged);
    }
    emit progressChanged();
    emit stateChanged();
}

QString InstanceBridge::name() const
{
    return m_inst ? m_inst->name() : QString();
}

QString InstanceBridge::iconKey() const
{
    return m_inst ? m_inst->iconKey() : QString();
}

QString InstanceBridge::iconSource() const
{
    return m_inst ? QString("image://instanceicon/%1?v=b%2").arg(m_inst->iconKey()).arg(m_iconRev) : QString();
}

QString InstanceBridge::versionText() const
{
    if (!m_inst) {
        return {};
    }
    auto* profile = m_inst->getPackProfile();
    if (!profile) {
        return {};
    }
    static const QList<QPair<QString, QString>> loaders = {
        { "net.neoforged", "NeoForge" },          { "net.minecraftforge", "Forge" },      { "net.fabricmc.fabric-loader", "Fabric" },
        { "org.quiltmc.quilt-loader", "Quilt" }, { "com.mumfrey.liteloader", "LiteLoader" },
    };
    QHash<QString, QString> fromFile;
    auto mc = profile->getComponentVersion("net.minecraft");
    if (mc.isEmpty()) {
        // profile not loaded yet: read mmc-pack.json directly (cheap, no network)
        QFile f(QDir(m_inst->instanceRoot()).filePath("mmc-pack.json"));
        if (f.open(QIODevice::ReadOnly)) {
            const auto comps = QJsonDocument::fromJson(f.readAll()).object().value("components").toArray();
            for (const auto& c : comps) {
                const auto o = c.toObject();
                fromFile.insert(o.value("uid").toString(), o.value("version").toString(o.value("cachedVersion").toString()));
            }
        }
        mc = fromFile.value("net.minecraft");
    }
    QStringList parts;
    parts << (mc.isEmpty() ? tr("Minecraft") : tr("Minecraft %1").arg(mc));
    for (const auto& [uid, label] : loaders) {
        const auto v = fromFile.isEmpty() ? profile->getComponentVersion(uid) : fromFile.value(uid);
        if (!v.isEmpty()) {
            parts << QString("%1 %2").arg(label, v);
        }
    }
    return parts.join(QStringLiteral("  ·  "));
}

QString InstanceBridge::minecraftVersion() const
{
    if (!m_inst || !m_inst->getPackProfile()) {
        return {};
    }
    auto mc = m_inst->getPackProfile()->getComponentVersion("net.minecraft");
    if (mc.isEmpty()) {
        QFile f(QDir(m_inst->instanceRoot()).filePath("mmc-pack.json"));
        if (f.open(QIODevice::ReadOnly)) {
            for (const auto& c : QJsonDocument::fromJson(f.readAll()).object().value("components").toArray()) {
                if (c.toObject().value("uid").toString() == "net.minecraft") {
                    return c.toObject().value("version").toString();
                }
            }
        }
    }
    return mc;
}

QString InstanceBridge::playTimeText() const
{
    if (!m_inst) {
        return {};
    }
    if (m_inst->totalTimePlayed() <= 0) {
        return tr("Not played yet");
    }
    return Time::prettifyDuration(m_inst->totalTimePlayed(), APPLICATION->settings()->get("ShowGameTimeWithoutDays").toBool());
}

QString InstanceBridge::lastPlayedText() const
{
    return m_inst ? InstanceModel::relativeTime(m_inst->lastLaunch()) : QString();
}

QString InstanceBridge::group() const
{
    return m_inst ? APPLICATION->instances()->getInstanceGroup(m_id) : QString();
}

QString InstanceBridge::notes() const
{
    return m_inst ? m_inst->notes() : QString();
}

void InstanceBridge::setNotes(const QString& notes)
{
    if (!m_inst || m_inst->notes() == notes) {
        return;
    }
    m_inst->setNotes(notes);
    emit notesChanged();
}

QString InstanceBridge::instanceRoot() const
{
    return m_inst ? m_inst->instanceRoot() : QString();
}

QString InstanceBridge::gameRoot() const
{
    return m_inst ? m_inst->gameRoot() : QString();
}

bool InstanceBridge::crashed() const
{
    return m_inst && m_inst->hasCrashed();
}

bool InstanceBridge::broken() const
{
    return m_inst && m_inst->hasVersionBroken();
}

bool InstanceBridge::managedPack() const
{
    return m_inst && m_inst->isManagedPack();
}

QString InstanceBridge::managedPackType() const
{
    return m_inst ? m_inst->getManagedPackType() : QString();
}

bool InstanceBridge::running() const
{
    return m_inst && m_inst->isRunning();
}

bool InstanceBridge::launching() const
{
    return m_inst && m_inst->launchController() != nullptr && !m_inst->isRunning();
}

bool InstanceBridge::canLaunch() const
{
    return m_inst && m_inst->canLaunch();
}

QString InstanceBridge::launchStatus() const
{
    if (m_auxTask && m_auxTask->isRunning()) {
        return m_auxTask->getStatus();
    }
    if (m_launchTask && m_launchTask->isRunning()) {
        return m_launchTask->getStatus();
    }
    return {};
}

double InstanceBridge::launchProgress() const
{
    Task* t = (m_auxTask && m_auxTask->isRunning()) ? m_auxTask.data() : m_launchTask.data();
    if (!t || !t->isRunning() || t->getTotalProgress() <= 0) {
        return -1;
    }
    return double(t->getProgress()) / double(t->getTotalProgress());
}

bool InstanceBridge::hasLog() const
{
    return m_inst && m_inst->getLaunchTask() != nullptr;
}

bool InstanceBridge::supportsDemo() const
{
    return m_inst && m_inst->supportsDemo();
}

bool InstanceBridge::supportsQuickPlayWorld() const
{
    return m_inst && m_inst->traits().contains("feature:is_quick_play_singleplayer");
}

QVariantList InstanceBridge::accounts() const
{
    QVariantList list;
    auto* accounts = APPLICATION->accounts();
    for (int i = 0; i < accounts->count(); i++) {
        auto account = accounts->at(i);
        QString face;
        auto pix = account->getFace();
        if (!pix.isNull()) {
            face = "face-" + account->profileId();
            PixmapCacheProvider::insert(face, pix);
            face = "image://pixmap/" + face;
        }
        list.append(QVariantMap{ { "id", account->profileId() },
                                 { "name", account->displayName() },
                                 { "type", account->typeString() },
                                 { "face", face },
                                 { "isDefault", accounts->defaultAccount() == account } });
    }
    return list;
}

QVariantList InstanceBridge::profilers() const
{
    QVariantList list;
    const auto& all = APPLICATION->profilers();
    for (auto it = all.begin(); it != all.end(); ++it) {
        QString error;
        const bool ok = it.value()->check(&error);
        list.append(QVariantMap{ { "key", it.key() }, { "name", it.value()->name() }, { "available", ok }, { "error", error } });
    }
    return list;
}

QString InstanceBridge::profiler() const
{
    return m_inst ? m_inst->settings()->get("Profiler").toString() : QString();
}

void InstanceBridge::setProfiler(const QString& key)
{
    if (!m_inst) {
        return;
    }
    m_inst->settings()->set("Profiler", key);
    emit m_inst->profilerChanged();
}

bool InstanceBridge::launch(const QString& mode, const QString& accountId)
{
    if (!m_inst) {
        return false;
    }
    MinecraftAccountPtr account;
    if (!accountId.isEmpty()) {
        auto* accounts = APPLICATION->accounts();
        const int index = accounts->findAccountByProfileId(accountId);
        if (index >= 0) {
            account = accounts->at(index);
        }
    }
    const auto launchMode = mode == "offline" ? LaunchMode::Offline : mode == "demo" ? LaunchMode::Demo : LaunchMode::Normal;
    const bool ok = APPLICATION->launch(m_inst, launchMode, nullptr, account);
    emit stateChanged();
    return ok;
}

bool InstanceBridge::launchJoinServer(const QString& address)
{
    if (!m_inst || address.trimmed().isEmpty()) {
        return false;
    }
    auto target = std::make_shared<MinecraftTarget>(MinecraftTarget::parse(address.trimmed(), false));
    const bool ok = APPLICATION->launch(m_inst, LaunchMode::Normal, target);
    emit stateChanged();
    return ok;
}

bool InstanceBridge::launchJoinWorld(const QString& world)
{
    if (!m_inst || world.isEmpty()) {
        return false;
    }
    auto target = std::make_shared<MinecraftTarget>(MinecraftTarget::parse(world, true));
    const bool ok = APPLICATION->launch(m_inst, LaunchMode::Normal, target);
    emit stateChanged();
    return ok;
}

bool InstanceBridge::kill()
{
    if (!m_inst) {
        return false;
    }
    const bool ok = APPLICATION->kill(m_inst);
    emit stateChanged();
    return ok;
}

void InstanceBridge::restart()
{
    if (!m_inst || !m_inst->isRunning()) {
        return;
    }
    m_restartQueued = APPLICATION->kill(m_inst);
    emit stateChanged();
}

QStringList InstanceBridge::worlds() const
{
    QStringList out;
    if (!m_inst) {
        return out;
    }
    auto* list = m_inst->worldList();
    list->update();
    for (const auto& world : list->allWorlds()) {
        out << world.folderName();
    }
    return out;
}

void InstanceBridge::openFolder(const QString& which)
{
    if (!m_inst) {
        return;
    }
    QString path = m_inst->instanceRoot();
    if (which == "game") {
        path = m_inst->gameRoot();
    } else if (which == "libraries") {
        path = m_inst->getLocalLibraryPath();
    } else if (which == "logs") {
        path = QDir(m_inst->gameRoot()).filePath("logs");
    } else if (which == "jarmods") {
        path = m_inst->jarModsDir();
    } else if (!which.isEmpty()) {
        path = QDir(m_inst->gameRoot()).filePath(which);
    }
    QDir().mkpath(path);
    DesktopServices::openPath(path, true);
}

QString InstanceBridge::gameOptionsPath() const
{
    return m_inst ? QDir(m_inst->gameRoot()).filePath("options.txt") : QString();
}

QVariantList InstanceBridge::gameOptions() const
{
    QVariantList out;
    QFile f(gameOptionsPath());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return out;
    }
    while (!f.atEnd()) {
        const auto line = QString::fromUtf8(f.readLine()).trimmed();
        if (line.isEmpty()) {
            continue;
        }
        const int sep = line.indexOf(':');
        if (sep < 0) {
            continue;
        }
        const auto key = line.left(sep);
        const auto value = line.mid(sep + 1);
        QString category = "Other";
        if (key.startsWith("key_")) {
            category = "Controls";
        } else if (key.startsWith("soundCategory_")) {
            category = "Sound";
        } else if (key.startsWith("modelPart_")) {
            category = "Skin";
        }
        out.append(QVariantMap{ { "key", key }, { "value", value }, { "category", category } });
    }
    return out;
}

bool InstanceBridge::legacy() const
{
    return m_inst && m_inst->isLegacy();
}

bool InstanceBridge::usesTexturePacks() const
{
    return m_inst && m_inst->traits().contains("texturepacks");
}

QString InstanceBridge::environment(const QString& name) const
{
    if (!name.startsWith("PRISM_MODERN_")) {
        return {};
    }
    return qEnvironmentVariable(name.toUtf8().constData());
}

bool InstanceBridge::resourceExists(const QUrl& url) const
{
    if (url.scheme() == "qrc") {
        return QFile::exists(":" + url.path());
    }
    return QFile::exists(url.toLocalFile());
}
