#include "NIShortcut.h"

#include <QDir>

#include "Application.h"
#include "BuildConfig.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/ShortcutUtils.h"
#include "minecraft/WorldList.h"
#include "minecraft/auth/AccountList.h"

NIShortcut::NIShortcut(QObject* parent) : QObject(parent) {}

void NIShortcut::setInstanceId(const QString& id)
{
    m_id = id;
    m_worlds.clear();
    m_quickJoin = false;
    if (auto* inst = APPLICATION->instances()->getInstanceById(id)) {
        m_quickJoin = inst->traits().contains("feature:is_quick_play_singleplayer");
        auto* worldList = inst->worldList();
        worldList->update();
        if (m_quickJoin) {
            for (const auto& world : worldList->allWorlds()) {
                m_worlds << QVariantMap{ { "value", world.name() },
                                         { "text", tr("%1 [%2] · last played %3")
                                                       .arg(world.name(), world.gameType().toTranslatedString(),
                                                            QLocale().toString(world.lastPlayed(), QLocale::ShortFormat)) } };
            }
        }
    }
    emit instanceChanged();
}

QString NIShortcut::instanceName() const
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    return inst ? inst->name() : QString();
}

QString NIShortcut::iconKey() const
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    return inst ? inst->iconKey() : QString();
}

QVariantList NIShortcut::targets() const
{
    QVariantList out;
    if (!DesktopServices::isFlatpak()) {
        if (!FS::getDesktopDir().isEmpty()) {
            out << QVariantMap{ { "value", "desktop" }, { "text", tr("Desktop") } };
        }
        if (!FS::getApplicationsDir().isEmpty()) {
            out << QVariantMap{ { "value", "applications" }, { "text", tr("Applications") } };
        }
    }
    out << QVariantMap{ { "value", "other" }, { "text", tr("Other location…") } };
    return out;
}

QVariantList NIShortcut::accounts() const
{
    QVariantList out;
    auto* accounts = APPLICATION->accounts();
    for (int i = 0; i < accounts->count(); i++) {
        auto account = accounts->at(i);
        out << QVariantMap{ { "value", account->profileName() }, { "text", account->profileName() } };
    }
    return out;
}

int NIShortcut::defaultAccount() const
{
    auto* accounts = APPLICATION->accounts();
    auto def = accounts->defaultAccount();
    for (int i = 0; i < accounts->count(); i++) {
        if (accounts->at(i) == def) {
            return i;
        }
    }
    return 0;
}

QString NIShortcut::otherExtension() const
{
#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD) || defined(Q_OS_OPENBSD)
    return ".desktop";
#elif defined(Q_OS_WINDOWS)
    return ".lnk";
#else
    return "";
#endif
}

QUrl NIShortcut::suggestedOtherFile(const QString& name) const
{
    return QUrl::fromLocalFile(FS::PathCombine(FS::getDesktopDir(), FS::RemoveInvalidFilenameChars(name) + otherExtension()));
}

QString NIShortcut::create(const QString& nameIn, const QString& target, const QString& launchTarget, const QString& world,
                           const QString& server, const QString& account, const QString& iconKey, const QUrl& otherFile)
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    if (!inst) {
        return tr("Instance not found.");
    }
    QString targetString = tr("instance");
    QStringList extraArgs;
    QString name = nameIn.trimmed();
    if (launchTarget == "world") {
        targetString = tr("world");
        extraArgs = { "--world", world };
        if (name.isEmpty()) {
            name = tr("%1 - %2").arg(inst->name(), world);
        }
    } else if (launchTarget == "server") {
        targetString = tr("server");
        extraArgs = { "--server", server };
        if (name.isEmpty()) {
            name = tr("%1 - Server %2").arg(inst->name(), server);
        }
    }
    if (name.isEmpty()) {
        name = inst->name();
    }
    if (!account.isEmpty()) {
        extraArgs.append({ "--profile", account });
    }

    ShortcutTarget kind = target == "desktop" ? ShortcutTarget::Desktop : target == "applications" ? ShortcutTarget::Applications
                                                                                                  : ShortcutTarget::Other;
    ShortcutUtils::Shortcut args{ inst, name, targetString, nullptr, extraArgs, iconKey, kind };

    QString path;
    if (kind == ShortcutTarget::Desktop) {
        const auto dir = FS::getDesktopDir();
        if (dir.isEmpty()) {
            return tr("Couldn't find the desktop folder.");
        }
        path = FS::PathCombine(dir, FS::RemoveInvalidFilenameChars(name));
    } else if (kind == ShortcutTarget::Applications) {
        auto dir = FS::getApplicationsDir();
        if (dir.isEmpty()) {
            return tr("Couldn't find the applications folder.");
        }
#if defined(Q_OS_MACOS) || defined(Q_OS_WIN)
        dir = FS::PathCombine(dir, BuildConfig.LAUNCHER_DISPLAYNAME + " Instances");
        if (!QDir(dir).mkpath(".")) {
            return tr("Failed to create instances folder in applications folder!");
        }
#endif
        path = FS::PathCombine(dir, FS::RemoveInvalidFilenameChars(name));
    } else {
        path = otherFile.isLocalFile() ? otherFile.toLocalFile() : otherFile.toString();
        if (path.isEmpty()) {
            return tr("No location chosen.");
        }
        const auto ext = otherExtension();
        if (!ext.isEmpty() && path.endsWith(ext)) {
            path.chop(ext.length());
        }
    }
    if (!ShortcutUtils::createInstanceShortcut(args, path)) {
        return tr("Failed to create %1 shortcut!").arg(targetString);
    }
    return {};
}
