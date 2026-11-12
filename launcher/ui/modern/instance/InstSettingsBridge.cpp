#include "InstSettingsBridge.h"

#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QUrl>

#include "Application.h"
#include "BuildConfig.h"
#include "FileSystem.h"
#include "HardwareInfo.h"
#include "InstanceList.h"
#include "Json.h"
#include "ModernLaunchHandler.h"
#include "java/JavaUtils.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "modplatform/ModIndex.h"
#include "settings/Setting.h"
#include "settings/SettingsObject.h"
#include "ui/java/InstallJavaDialog.h"

InstSettingsBridge::InstSettingsBridge(QObject* parent) : QObject(parent) {}

void InstSettingsBridge::setInstanceId(const QString& id)
{
    if (id == m_id && m_inst) {
        return;
    }
    disconnect(m_settingConn);
    m_id = id;
    m_inst = APPLICATION->instances()->getInstanceById(id);
    if (m_inst) {
        m_settingConn = connect(m_inst->settings(), &SettingsObject::SettingChanged, this, [this] {
            m_revision++;
            emit revisionChanged();
        });
    }
    m_revision++;
    emit instanceIdChanged();
    emit revisionChanged();
}

int InstSettingsBridge::totalRamMiB() const
{
    return int(HardwareInfo::totalRamMiB());
}

bool InstSettingsBridge::gameModeAvailable() const
{
    return (APPLICATION->capabilities() & Application::SupportsGameMode) != 0U;
}

bool InstSettingsBridge::mangoHudAvailable() const
{
    return (APPLICATION->capabilities() & Application::SupportsMangoHud) != 0U;
}

bool InstSettingsBridge::isLinux() const
{
#ifdef Q_OS_LINUX
    return true;
#else
    return false;
#endif
}

bool InstSettingsBridge::javaDownloaderEnabled() const
{
    return BuildConfig.JAVA_DOWNLOADER_ENABLED;
}

bool InstSettingsBridge::legacy() const
{
    return m_inst && m_inst->isLegacy();
}

QVariant InstSettingsBridge::get(const QString& key) const
{
    if (!m_inst || !m_inst->settings()->contains(key)) {
        return {};
    }
    return m_inst->settings()->get(key);
}

void InstSettingsBridge::set(const QString& key, const QVariant& value)
{
    if (!m_inst || !m_inst->settings()->contains(key)) {
        return;
    }
    if (m_inst->settings()->get(key) == value) {
        return;
    }
    if (key == "JavaPath") {
        // a manually chosen Java disables automatic switching for this instance (same as the classic page)
        m_inst->settings()->set("AutomaticJava", false);
    }
    m_inst->settings()->set(key, value);
}

void InstSettingsBridge::reset(const QString& key)
{
    if (m_inst && m_inst->settings()->contains(key)) {
        m_inst->settings()->reset(key);
    }
}

QVariant InstSettingsBridge::globalValue(const QString& key) const
{
    return APPLICATION->settings()->get(key);
}

void InstSettingsBridge::setOverride(const QString& gateKey, const QStringList& keys, bool on)
{
    if (!m_inst) {
        return;
    }
    auto* s = m_inst->settings();
    if (on) {
        // start from the values currently in effect
        QVariantMap current;
        for (const auto& k : keys) {
            current.insert(k, s->get(k));
        }
        s->set(gateKey, true);
        for (const auto& k : keys) {
            s->set(k, current.value(k));
        }
    } else {
        s->set(gateKey, false);
        for (const auto& k : keys) {
            s->reset(k);
        }
    }
    if (gateKey == "OverrideWindow") {
        s->set("OverrideMiscellaneous", on);
    }
}

QVariantList InstSettingsBridge::envVars() const
{
    QVariantList out;
    if (!m_inst) {
        return out;
    }
    const auto map = Json::toMap(m_inst->settings()->get("Env").toString());
    for (auto it = map.begin(); it != map.end(); ++it) {
        out.append(QVariantMap{ { "name", it.key() }, { "value", it.value().toString() } });
    }
    return out;
}

void InstSettingsBridge::setEnvVars(const QVariantList& vars)
{
    if (!m_inst) {
        return;
    }
    QVariantMap map;
    for (const auto& v : vars) {
        const auto m = v.toMap();
        const auto name = m.value("name").toString().trimmed();
        if (!name.isEmpty()) {
            map.insert(name, m.value("value").toString());
        }
    }
    m_inst->settings()->set("Env", Json::fromMap(map));
}

QVariantList InstSettingsBridge::modLoaders() const
{
    QVariantList out;
    if (!m_inst) {
        return out;
    }
    static const QList<QPair<ModPlatform::ModLoaderType, QString>> all = {
        { ModPlatform::NeoForge, "NeoForge" },        { ModPlatform::Forge, "Forge" },     { ModPlatform::Fabric, "Fabric" },
        { ModPlatform::Quilt, "Quilt" },              { ModPlatform::LiteLoader, "LiteLoader" }, { ModPlatform::Babric, "Babric" },
        { ModPlatform::BTA, "BTA (Babric)" },         { ModPlatform::LegacyFabric, "Legacy Fabric" },
        { ModPlatform::Ornithe, "Ornithe" },          { ModPlatform::Rift, "Rift" },
    };
    const bool overrideLoaders = m_inst->settings()->get("OverrideModDownloadLoaders").toBool();
    const QStringList chosen = Json::toStringList(m_inst->settings()->get("ModDownloadLoaders").toString());
    const auto instLoaders = m_inst->getPackProfile()->getSupportedModLoaders().value_or(ModPlatform::ModLoaderTypes(0));
    for (const auto& [type, name] : all) {
        const auto key = ModPlatform::getModLoaderAsString(type);
        const bool checked = overrideLoaders ? chosen.contains(key) : instLoaders.testAnyFlags(type);
        out.append(QVariantMap{ { "key", key }, { "name", name }, { "checked", checked } });
    }
    return out;
}

void InstSettingsBridge::setModLoaders(const QStringList& keys)
{
    if (m_inst) {
        m_inst->settings()->set("ModDownloadLoaders", Json::fromStringList(keys));
    }
}

void InstSettingsBridge::setModLoaderOverride(bool on)
{
    if (!m_inst) {
        return;
    }
    if (on) {
        QStringList keys;
        for (const auto& v : modLoaders()) {
            const auto m = v.toMap();
            if (m.value("checked").toBool()) {
                keys << m.value("key").toString();
            }
        }
        m_inst->settings()->set("OverrideModDownloadLoaders", true);
        setModLoaders(keys);
    } else {
        m_inst->settings()->set("OverrideModDownloadLoaders", false);
        m_inst->settings()->reset("ModDownloadLoaders");
    }
}

QString InstSettingsBridge::nativeLibraryPlaceholder(const QString& which) const
{
#ifdef Q_OS_LINUX
    if (which == "glfw") {
        return APPLICATION->m_detectedGLFWPath;
    }
    if (which == "openal") {
        return APPLICATION->m_detectedOpenALPath;
    }
    return APPLICATION->m_detectedSDLPath;
#else
    const auto name = which == "glfw" ? BuildConfig.GLFW_LIBRARY_NAME : which == "openal" ? BuildConfig.OPENAL_LIBRARY_NAME : BuildConfig.SDL_LIBRARY_NAME;
    return tr("Path to %1 library file").arg(name);
#endif
}

QString InstSettingsBridge::browseJava(const QString& current) const
{
    const auto raw = QFileDialog::getOpenFileName(nullptr, tr("Find Java executable"), current);
    if (raw.isEmpty()) {
        return {};
    }
    const auto cooked = FS::NormalizePath(raw);
    QFileInfo info(cooked);
    if (!info.exists() || !info.isExecutable()) {
        return {};
    }
    return cooked;
}

QString InstSettingsBridge::browseFile(const QString& title, const QString& current) const
{
    return QFileDialog::getOpenFileName(nullptr, title, current);
}

QString InstSettingsBridge::browseDataPacksFolder() const
{
    if (!m_inst) {
        return {};
    }
    QString path = QFileDialog::getExistingDirectory(nullptr, tr("Select Global Data Packs Folder"), m_inst->gameRoot());
    if (path.isEmpty()) {
        return {};
    }
    // inside the instance: store relative to .minecraft
    const QUrl rootUrl = QUrl::fromLocalFile(m_inst->instanceRoot());
    if (rootUrl.isParentOf(QUrl::fromLocalFile(path))) {
        path = QDir(m_inst->gameRoot()).relativeFilePath(path);
    }
    return path;
}

QString InstSettingsBridge::jvmArgsProblem(const QString& args) const
{
    static const QRegularExpression s_memRegex("-Xm[sx]");
    static const QRegularExpression s_versionRegex("-version:.*");
    if (args.contains("-XX:PermSize=") || args.contains(s_memRegex) || args.contains("-XX-MaxHeapSize") ||
        args.contains("-XX:InitialHeapSize")) {
        return tr("Memory options (-Xmx, -Xms, -XX:PermSize, ...) are not allowed here. Use the memory settings above instead.");
    }
    if (args.contains(s_versionRegex)) {
        return tr("Passing a required Java version (-version:...) is not allowed.");
    }
    return {};
}

void InstSettingsBridge::testJava(const QString& path, const QString& jvmArgs, int minMem, int maxMem, int permGen)
{
    if (m_checker) {
        return;
    }
    if (auto problem = jvmArgsProblem(jvmArgs); !problem.isEmpty()) {
        emit javaTestFinished("warning", tr("JVM arguments warning"), problem);
        return;
    }
    if (JavaUtils::getJavaCheckPath().isEmpty()) {
        emit javaTestFinished("error", tr("Java test failure"), tr("Java checker library could not be found. Please check your installation."));
        return;
    }
    m_testArgs = jvmArgs;
    m_testMin = minMem;
    m_testMax = maxMem;
    m_testPermGen = permGen;
    m_checker.reset(new JavaChecker(path, "", 0, 0, 0, 0));
    connect(m_checker.get(), &JavaChecker::checkFinished, this, [this, path](const JavaChecker::Result& result) {
        if (result.validity != JavaChecker::Result::Validity::Valid) {
            QString text = tr("The specified Java binary didn't work.\nYou should use the auto-detect feature, or set the path to the Java "
                              "executable.");
            if (!result.errorLog.isEmpty()) {
                text += "\n\n" + result.errorLog;
            }
            m_checker.reset();
            emit javaTestingChanged();
            emit javaTestFinished("error", tr("Java test failure"), text);
            return;
        }
        // second pass with the arguments
        auto checker = JavaChecker::Ptr(new JavaChecker(path, m_testArgs, m_testMin, m_testMax,
                                                        result.javaVersion.requiresPermGen() ? m_testPermGen : 0, 0));
        m_checker = checker;
        connect(checker.get(), &JavaChecker::checkFinished, this, [this](const JavaChecker::Result& r) {
            m_checker.reset();
            emit javaTestingChanged();
            if (r.validity == JavaChecker::Result::Validity::Valid) {
                QString text = tr("Platform reported: %1\nJava version reported: %2\nJava vendor reported: %3")
                                   .arg(r.realPlatform, r.javaVersion.toString(), r.javaVendor);
                if (!r.errorLog.isEmpty()) {
                    text += "\n\n" + tr("Warnings:") + "\n" + r.errorLog;
                }
                emit javaTestFinished("success", tr("Java test succeeded"), text);
            } else {
                emit javaTestFinished("error", tr("Java test failure"),
                                      tr("The specified Java binary didn't work with the arguments you provided:") + "\n\n" + r.errorLog);
            }
        });
        checker->start();
    });
    emit javaTestingChanged();
    m_checker->start();
}

void InstSettingsBridge::openJavaInstaller()
{
    if (!m_inst) {
        return;
    }
    // The Java downloader is still the classic dialog.
    auto* dialog = new Java::InstallDialog({}, m_inst, nullptr);
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->open();
}
