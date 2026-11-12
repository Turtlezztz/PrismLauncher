#include "ResUtil.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QSaveFile>

#include "Application.h"
#include "DesktopServices.h"
#include "InstanceList.h"
#include "ResFolderModel.h"
#include "ResImages.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/VersionFilterData.h"
#include "minecraft/mod/ModFolderModel.h"
#include "settings/SettingsObject.h"

ResUtil* ResUtil::create(QQmlEngine* engine, QJSEngine*)
{
    ResImages::ensure(engine);
    return new ResUtil();
}

QString ResUtil::saveText(const QUrl& file, const QString& text) const
{
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        return f.errorString();
    }
    f.write(text.toUtf8());
    if (!f.commit()) {
        return f.errorString();
    }
    return {};
}

void ResUtil::copyText(const QString& text) const
{
    QGuiApplication::clipboard()->setText(text);
}

QStringList ResUtil::modFolders(const QString& instanceId) const
{
    QStringList out{ "mods" };
    auto* inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) {
        return out;
    }
    ResFolderModel::ensureProfileLoaded(inst);
    // classic CoreModFolderPage::shouldDisplay
    auto* profile = inst->getPackProfile();
    if (profile && profile->getComponent("net.minecraftforge") && profile->getComponent("net.minecraft")) {
        auto mc = profile->getComponent("net.minecraft");
        if (mc->m_loaded && mc->getReleaseDateTime() < g_VersionFilterData.legacyCutoffDate) {
            out << "coremods";
        }
    }
    // classic NilModFolderPage::shouldDisplay
    if (inst->nilModList() && inst->nilModList()->dir().exists()) {
        out << "nilmods";
    }
    return out;
}

QString ResUtil::instanceName(const QString& instanceId) const
{
    auto* inst = APPLICATION->instances()->getInstanceById(instanceId);
    return inst ? inst->name() : QString();
}

bool ResUtil::instanceRunning(const QString& instanceId) const
{
    auto* inst = APPLICATION->instances()->getInstanceById(instanceId);
    return inst && inst->isRunning();
}

QString ResUtil::centralModsDir() const
{
    return APPLICATION->settings()->get("CentralModsDir").toString();
}

void ResUtil::openPath(const QString& path) const
{
    DesktopServices::openPath(path, true);
}
