#include "AppController.h"

#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>

#include "Application.h"
#include "BuildConfig.h"
#include "DesktopServices.h"
#include "InstanceDirUpdate.h"
#include "InstanceList.h"
#include "InstanceModel.h"
#include "icons/IconList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/auth/AccountList.h"
#include "settings/Setting.h"
#include "settings/SettingsObject.h"
#include "ui/themes/ThemeManager.h"

static AppController* s_app = nullptr;

AppController::AppController(QObject* parent) : QObject(parent)
{
    m_instances = new InstanceModel(this);
    auto* list = APPLICATION->instances();
    connect(list, &InstanceList::instancesChanged, this, &AppController::groupsChanged);
    connect(list, &QAbstractItemModel::dataChanged, this, &AppController::groupsChanged);
    connect(list, &InstanceList::instancesChanged, this, &AppController::canUndoDeleteChanged);

    connect(APPLICATION->settings(), &SettingsObject::SettingChanged, this, [this](const Setting& setting, QVariant value) {
        const auto id = setting.id();
        emit settingChanged(id, value);
        if (id == "ModernTheme") {
            emit themeChanged();
        } else if (id == "ModernAccent") {
            emit accentChanged();
        } else if (id == "ModernReduceMotion") {
            emit reduceMotionChanged();
        }
    });
    connect(APPLICATION, &Application::updateAllowedChanged, this, &AppController::runningCountChanged);
}

AppController* AppController::create(QQmlEngine*, QJSEngine*)
{
    if (!s_app) {
        s_app = new AppController(APPLICATION);
    }
    QJSEngine::setObjectOwnership(s_app, QJSEngine::CppOwnership);
    return s_app;
}

AppController* AppController::instance()
{
    return s_app;
}

QString AppController::appName() const
{
    return BuildConfig.LAUNCHER_DISPLAYNAME;
}

QString AppController::version() const
{
    return BuildConfig.printableVersionString();
}

QString AppController::platform() const
{
#if defined(Q_OS_MACOS)
    return "macos";
#elif defined(Q_OS_WIN)
    return "windows";
#else
    return "linux";
#endif
}

QStringList AppController::groups() const
{
    auto groups = APPLICATION->instances()->getGroups();
    groups.removeAll(QString());
    groups.sort(Qt::CaseInsensitive);
    return groups;
}

bool AppController::canUndoDelete() const
{
    return APPLICATION->instances()->trashedSomething();
}

int AppController::runningCount() const
{
    int n = 0;
    auto* list = APPLICATION->instances();
    for (int i = 0; i < list->count(); i++) {
        if (list->at(i)->isRunning()) {
            n++;
        }
    }
    return n;
}

QString AppController::theme() const
{
    return APPLICATION->settings()->get("ModernTheme").toString();
}
void AppController::setTheme(const QString& theme)
{
    APPLICATION->settings()->set("ModernTheme", theme);
}
QString AppController::accent() const
{
    return APPLICATION->settings()->get("ModernAccent").toString();
}
void AppController::setAccent(const QString& accent)
{
    APPLICATION->settings()->set("ModernAccent", accent);
}
bool AppController::reduceMotion() const
{
    return APPLICATION->settings()->get("ModernReduceMotion").toBool();
}
void AppController::setReduceMotion(bool on)
{
    APPLICATION->settings()->set("ModernReduceMotion", on);
}

MinecraftInstance* AppController::find(const QString& id) const
{
    return APPLICATION->instances()->getInstanceById(id);
}

bool AppController::launch(const QString& instanceId, bool offline, const QString& profileName)
{
    auto* inst = find(instanceId);
    if (!inst) {
        return false;
    }
    MinecraftAccountPtr account;
    if (!profileName.isEmpty()) {
        account = APPLICATION->accounts()->getAccountByProfileName(profileName);
    }
    bool ok = APPLICATION->launch(inst, offline ? LaunchMode::Offline : LaunchMode::Normal, nullptr, account);
    emit runningCountChanged();
    return ok;
}

bool AppController::kill(const QString& instanceId)
{
    auto* inst = find(instanceId);
    if (!inst) {
        return false;
    }
    bool ok = APPLICATION->kill(inst);
    emit runningCountChanged();
    return ok;
}

QString AppController::deleteInstance(const QString& instanceId)
{
    auto* inst = find(instanceId);
    if (!inst) {
        return tr("Instance not found.");
    }
    if (inst->isRunning()) {
        return tr("The instance is currently running and cannot be deleted. Stop it first.");
    }
    if (!APPLICATION->instances()->trashInstance(instanceId)) {
        APPLICATION->instances()->deleteInstance(instanceId);
    }
    if (APPLICATION->settings()->get("SelectedInstance").toString() == instanceId) {
        APPLICATION->settings()->set("SelectedInstance", QString());
    }
    emit canUndoDeleteChanged();
    emit groupsChanged();
    return {};
}

bool AppController::undoDelete()
{
    bool ok = APPLICATION->instances()->undoTrashInstance();
    emit canUndoDeleteChanged();
    return ok;
}

bool AppController::renameInstance(const QString& instanceId, const QString& newName)
{
    auto* inst = find(instanceId);
    const auto name = newName.trimmed();
    if (!inst || name.isEmpty()) {
        return false;
    }
    const auto before = inst->name();
    if (before == name) {
        return true;
    }
    inst->setName(name);

    // Optionally rename the instance folder too (respects the "InstRenamingMode" setting)
    const auto newRoot = askToUpdateInstanceDirName(inst, before, name, nullptr);
    if (!newRoot.isEmpty()) {
        const auto newId = QFileInfo(newRoot).fileName();
        const auto group = APPLICATION->instances()->getInstanceGroup(instanceId);
        if (!group.isEmpty() && newId != instanceId) {
            APPLICATION->instances()->setInstanceGroup(instanceId, QString());
            APPLICATION->instances()->loadList();
            APPLICATION->instances()->setInstanceGroup(newId, group);
        } else {
            APPLICATION->instances()->loadList();
        }
    }
    return true;
}

void AppController::setInstanceGroup(const QString& instanceId, const QString& group)
{
    APPLICATION->instances()->setInstanceGroup(instanceId, group.trimmed());
    emit groupsChanged();
}

void AppController::renameGroup(const QString& from, const QString& to)
{
    APPLICATION->instances()->renameGroup(from, to.trimmed());
    emit groupsChanged();
}

void AppController::deleteGroup(const QString& group)
{
    APPLICATION->instances()->deleteGroup(group);
    emit groupsChanged();
}

void AppController::setInstanceIcon(const QString& instanceId, const QString& iconKey)
{
    if (auto* inst = find(instanceId)) {
        inst->setIconKey(iconKey);
    }
}

void AppController::openInstanceFolder(const QString& instanceId, const QString& subPath)
{
    auto* inst = find(instanceId);
    if (!inst) {
        return;
    }
    if (subPath.isEmpty()) {
        DesktopServices::openPath(QFileInfo(inst->instanceRoot()));
    } else {
        DesktopServices::openPath(QDir(inst->gameRoot()).filePath(subPath), true);
    }
}

bool AppController::instanceExists(const QString& instanceId) const
{
    return find(instanceId) != nullptr;
}

QStringList AppController::instanceShortcuts(const QString& instanceId) const
{
    QStringList out;
    if (auto* inst = find(instanceId)) {
        for (const auto& s : inst->shortcuts()) {
            out << s.filePath;
        }
    }
    return out;
}

void AppController::openFolder(const QString& which)
{
    auto* s = APPLICATION->settings();
    if (which == "root") {
        DesktopServices::openPath(".");
    } else if (which == "instances") {
        DesktopServices::openPath(s->get("InstanceDir").toString());
    } else if (which == "centralMods") {
        DesktopServices::openPath(s->get("CentralModsDir").toString(), true);
    } else if (which == "skins") {
        DesktopServices::openPath(s->get("SkinsDir").toString(), true);
    } else if (which == "iconThemes") {
        DesktopServices::openPath(APPLICATION->themeManager()->getIconThemesFolder().path(), true);
    } else if (which == "widgetThemes") {
        DesktopServices::openPath(APPLICATION->themeManager()->getApplicationThemesFolder().path(), true);
    } else if (which == "catPacks") {
        DesktopServices::openPath(APPLICATION->themeManager()->getCatPacksFolder().path(), true);
    } else if (which == "icons") {
        DesktopServices::openPath(APPLICATION->icons()->getDirectory(), true);
    } else if (which == "logs") {
        DesktopServices::openPath("logs", true);
    } else if (which == "java") {
        DesktopServices::openPath(APPLICATION->javaPath(), true);
    } else if (which == "templates") {
        DesktopServices::openPath(s->get("TemplateDir").toString(), true);
    } else {
        qWarning() << "Modern UI: unknown folder" << which;
    }
}

void AppController::openUrl(const QString& url)
{
    DesktopServices::openUrl(QUrl(url));
}

void AppController::openPath(const QString& path)
{
    DesktopServices::openPath(path, true);
}

void AppController::copyToClipboard(const QString& text)
{
    QGuiApplication::clipboard()->setText(text);
}

QString AppController::urlToLocalFile(const QUrl& url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QVariant AppController::setting(const QString& key) const
{
    return APPLICATION->settings()->get(key);
}

void AppController::setSetting(const QString& key, const QVariant& value)
{
    APPLICATION->settings()->set(key, value);
}

void AppController::resetSetting(const QString& key)
{
    APPLICATION->settings()->reset(key);
}

void AppController::useClassicUi(bool classic)
{
    APPLICATION->settings()->set("UseClassicUI", classic);
}

void AppController::restart()
{
    QProcess::startDetached(QCoreApplication::applicationFilePath(), QCoreApplication::arguments().mid(1));
    QCoreApplication::exit(0);
}

void AppController::notify(const QString& message, const QString& kind)
{
    emit toast(message, kind);
}
