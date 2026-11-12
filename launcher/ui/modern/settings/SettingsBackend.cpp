#include "SettingsBackend.h"

#include <QDate>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QFontDatabase>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>

#include "Application.h"
#include "BuildConfig.h"
#include "Commandline.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "HardwareInfo.h"
#include "JavaCommon.h"
#include "java/JavaInstall.h"
#include "java/JavaInstallList.h"
#include "java/JavaUtils.h"
#include "net/PasteUpload.h"
#include "settings/SettingsObject.h"
#include "tools/BaseProfiler.h"
#include "translations/TranslationsModel.h"
#include "ui/themes/CatPack.h"
#include "ui/themes/ITheme.h"
#include "ui/themes/IconTheme.h"
#include "ui/themes/ThemeManager.h"
#include "updater/ExternalUpdater.h"

static SettingsBackend* s_settingsBackend = nullptr;

SettingsBackend::SettingsBackend(QObject* parent) : QObject(parent)
{
    // Java messages raised by core code (e.g. JVM argument checks while launching) are shown as QML dialogs.
    JavaCommon::setMessageHook(
        [this](const QString& kind, const QString& title, const QString& text) { emit javaMessage(kind, title, text); });
}

SettingsBackend* SettingsBackend::create(QQmlEngine*, QJSEngine*)
{
    if (!s_settingsBackend) {
        s_settingsBackend = new SettingsBackend(APPLICATION);
    }
    QJSEngine::setObjectOwnership(s_settingsBackend, QJSEngine::CppOwnership);
    return s_settingsBackend;
}

SettingsBackend* SettingsBackend::instance()
{
    return s_settingsBackend;
}

int SettingsBackend::systemRamMiB() const
{
    return static_cast<int>(HardwareInfo::totalRamMiB());
}

bool SettingsBackend::javaDownloaderEnabled() const
{
    return BuildConfig.JAVA_DOWNLOADER_ENABLED;
}

bool SettingsBackend::supportsGameMode() const
{
    return APPLICATION->capabilities() & Application::SupportsGameMode;
}

bool SettingsBackend::supportsMangoHud() const
{
    return APPLICATION->capabilities() & Application::SupportsMangoHud;
}

bool SettingsBackend::supportsMSA() const
{
    return APPLICATION->capabilities() & Application::SupportsMSA;
}

bool SettingsBackend::isLinux() const
{
#ifdef Q_OS_LINUX
    return true;
#else
    return false;
#endif
}

QVariantList SettingsBackend::pinnableMajors() const
{
    QVariantList out;
    for (int major : JavaUtils::pinnableMajors) {
        out << major;
    }
    return out;
}

QVariantMap SettingsBackend::defaults() const
{
    QVariantMap m;
    m["metaUrl"] = BuildConfig.META_URL;
    m["resourceUrl"] = BuildConfig.DEFAULT_RESOURCE_BASE;
    m["fmlLibsUrl"] = BuildConfig.LEGACY_FMLLIBS_BASE_URL;
    m["userAgent"] = BuildConfig.USER_AGENT;
    m["helpUrl"] = BuildConfig.HELP_URL;
#ifdef Q_OS_LINUX
    m["glfw"] = APPLICATION->m_detectedGLFWPath;
    m["openal"] = APPLICATION->m_detectedOpenALPath;
    m["sdl"] = APPLICATION->m_detectedSDLPath;
#else
    m["glfw"] = tr("Path to %1 library file").arg(BuildConfig.GLFW_LIBRARY_NAME);
    m["openal"] = tr("Path to %1 library file").arg(BuildConfig.OPENAL_LIBRARY_NAME);
    m["sdl"] = tr("Path to %1 library file").arg(BuildConfig.SDL_LIBRARY_NAME);
#endif
    return m;
}

QVariantList SettingsBackend::pasteTypes() const
{
    // same order as the classic APIPage combo box
    const int order[] = { static_cast<int>(PasteUpload::Type::Mclogs), static_cast<int>(PasteUpload::Type::NullPointer),
                          static_cast<int>(PasteUpload::Type::PasteGG), static_cast<int>(PasteUpload::Type::Hastebin) };
    QVariantList out;
    for (int t : order) {
        PasteUpload::Type type(t);
        out << QVariantMap{ { "value", t }, { "text", type.toString() }, { "defaultBase", type.defaultBase() } };
    }
    return out;
}

bool SettingsBackend::updaterAvailable() const
{
    return APPLICATION->updaterEnabled() && APPLICATION->updater() != nullptr;
}

QString SettingsBackend::debugPage() const
{
    return qEnvironmentVariable("PRISM_MODERN_SETTINGS_PAGE");
}

bool SettingsBackend::updaterSupported() const
{
    return BuildConfig.UPDATER_ENABLED;
}

bool SettingsBackend::javaCheckerAvailable() const
{
    return !JavaUtils::getJavaCheckPath().isEmpty();
}

// ---------------------------------------------------------------- pickers & paths

QString SettingsBackend::browseDirectory(const QString& title, const QString& start) const
{
    return QFileDialog::getExistingDirectory(nullptr, title, start);
}

QString SettingsBackend::browseFile(const QString& title, const QString& start, const QString& filter) const
{
    return QFileDialog::getOpenFileName(nullptr, title, start, filter);
}

QString SettingsBackend::normalizePath(const QString& path) const
{
    return FS::NormalizePath(path);
}

bool SettingsBackend::directoryExists(const QString& path) const
{
    return !path.isEmpty() && QDir(path).exists();
}

QString SettingsBackend::instanceDirWarning(const QString& rawDir) const
{
    const auto cooked = FS::NormalizePath(rawDir);
    if (FS::checkProblemticPathJava(QDir(cooked))) {
        return tr("The folder path contains at least one '!'. Java is known to cause problems if that is the case — your instances "
                  "(probably) won't start!");
    }
    if (DesktopServices::isFlatpak() && rawDir.startsWith("/run/user")) {
        return tr("This folder was granted temporarily via Flatpak. After a restart the launcher might no longer have access to it. "
                  "Granting %1 access to it via Flatseal is recommended.")
            .arg(BuildConfig.LAUNCHER_DISPLAYNAME);
    }
    return {};
}

QString SettingsBackend::jvmArgsWarning(const QString& jvmargs) const
{
    // mirrors JavaCommon::checkJVMArgs
    static const QRegularExpression s_memRegex("-Xm[sx]");
    static const QRegularExpression s_versionRegex("-version:.*");
    if (jvmargs.contains("-XX:PermSize=") || jvmargs.contains(s_memRegex) || jvmargs.contains("-XX-MaxHeapSize") ||
        jvmargs.contains("-XX:InitialHeapSize")) {
        return tr("You tried to manually set a JVM memory option (using \"-XX:PermSize\", \"-XX-MaxHeapSize\", \"-XX:InitialHeapSize\", "
                  "\"-Xmx\" or \"-Xms\"). Use the dedicated memory settings instead.");
    }
    if (jvmargs.contains(s_versionRegex)) {
        return tr("You tried to pass a required Java version argument to the JVM (using \"-version:xxx\"). This is not safe and will "
                  "not be allowed.");
    }
    return {};
}

bool SettingsBackend::executableResolves(const QString& path) const
{
    return !FS::ResolveExecutable(path).isNull();
}

bool SettingsBackend::isExecutableFile(const QString& path) const
{
    QFileInfo info(path);
    return info.exists() && info.isExecutable();
}

QString SettingsBackend::resolveJsonEditor(const QString& path) const
{
    QString jsonEditor = path.trimmed();
    if (!jsonEditor.isEmpty() && (!QFileInfo(jsonEditor).exists() || !QFileInfo(jsonEditor).isExecutable())) {
        QString found = QStandardPaths::findExecutable(jsonEditor);
        if (!found.isEmpty()) {
            jsonEditor = found;
        }
    }
    return jsonEditor;
}

QString SettingsBackend::checkProfiler(const QString& id, const QString& path) const
{
    auto profiler = APPLICATION->profilers().value(id);
    if (!profiler) {
        return tr("Unknown profiler.");
    }
    QString error;
    if (!profiler->check(path, &error)) {
        return error.isEmpty() ? tr("Unknown error") : error;
    }
    return {};
}

QString SettingsBackend::worldToolCommandFor(const QString& executable) const
{
    return Commandline::quoteForSplitCommand(executable) + " ${WORLD_PATH}";
}

QString SettingsBackend::defaultApplicationsDir() const
{
#if defined(Q_OS_LINUX)
    return QStringLiteral("/usr/bin");
#else
    const auto locs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    return locs.isEmpty() ? QString() : locs.first();
#endif
}

// ---------------------------------------------------------------- network

void SettingsBackend::setUseSystemLocale(bool on)
{
    APPLICATION->translations()->setUseSystemLocale(on);
}

void SettingsBackend::applyProxy(const QString& type, const QString& addr, int port, const QString& user, const QString& pass)
{
    APPLICATION->updateProxySettings(type, addr, port, user, pass);
}

// ---------------------------------------------------------------- themes

QVariantList SettingsBackend::iconThemes() const
{
    QVariantList out;
    for (auto* theme : APPLICATION->themeManager()->getValidIconThemes()) {
        out << QVariantMap{ { "value", theme->id() }, { "text", theme->name() } };
    }
    return out;
}

QVariantList SettingsBackend::widgetThemes() const
{
    QVariantList out;
    for (auto* theme : APPLICATION->themeManager()->getValidApplicationThemes()) {
        out << QVariantMap{ { "value", theme->id() }, { "text", theme->name() }, { "tooltip", theme->tooltip() } };
    }
    return out;
}

QVariantList SettingsBackend::catPacks() const
{
    QVariantList out;
    for (auto* cat : APPLICATION->themeManager()->getValidCatPacks()) {
        out << QVariantMap{ { "value", cat->id() }, { "text", cat->name() } };
    }
    return out;
}

void SettingsBackend::reloadThemes()
{
    APPLICATION->themeManager()->refresh();
}

void SettingsBackend::applyClassicTheme()
{
    APPLICATION->themeManager()->applyCurrentlySelectedTheme();
}

void SettingsBackend::setCatPack(const QString& id)
{
    APPLICATION->settings()->set("BackgroundCat", id);
    const auto cats = APPLICATION->themeManager()->getValidCatPacks();
    for (int i = 0; i < cats.size(); i++) {
        if (cats[i]->id() == id) {
            APPLICATION->currentCatChanged(i);
            break;
        }
    }
}

QString SettingsBackend::catImageUrl() const
{
    const auto path = APPLICATION->themeManager()->getCatPack();
    if (path.isEmpty()) {
        return {};
    }
    if (path.startsWith(":")) {
        return "qrc" + path;
    }
    return QUrl::fromLocalFile(path).toString();
}

QVariantList SettingsBackend::consolePreview() const
{
    const LogColors& colors = APPLICATION->themeManager()->getLogColors();
    QVariantList out;
    auto line = [&](const QString& text, MessageLevel level) {
        QColor bg = colors.background.value(level);
        QColor fg = colors.foreground.value(level);
        out << QVariantMap{ { "text", text },
                            { "fg", fg.isValid() ? fg.name(QColor::HexArgb) : QString() },
                            { "bg", bg.isValid() ? bg.name(QColor::HexArgb) : QString() } };
    };
    line(QString("%1 version: %2").arg(BuildConfig.LAUNCHER_DISPLAYNAME, BuildConfig.printableVersionString()), MessageLevel::Launcher);
    const QDate today = QDate::currentDate();
    line(today.month() == 10 && today.day() == 31 ? tr("[ERROR] OOoooOOOoooo! A spooky error!") : tr("[ERROR] A spooky error!"),
         MessageLevel::Error);
    line(tr("[INFO] A harmless message..."), MessageLevel::Info);
    line(tr("[WARN] A not so spooky warning."), MessageLevel::Warning);
    line(tr("[DEBUG] A secret debugging message..."), MessageLevel::Debug);
    line(tr("[FATAL] A terrifying fatal error!"), MessageLevel::Fatal);
    return out;
}

QStringList SettingsBackend::fontFamilies() const
{
    return QFontDatabase::families();
}

// ---------------------------------------------------------------- updater

bool SettingsBackend::updaterAutoCheck() const
{
    auto* updater = APPLICATION->updater();
    return updater && updater->getAutomaticallyChecksForUpdates();
}

void SettingsBackend::setUpdaterAutoCheck(bool on)
{
    if (auto* updater = APPLICATION->updater()) {
        updater->setAutomaticallyChecksForUpdates(on);
    }
}

int SettingsBackend::updaterIntervalHours() const
{
    auto* updater = APPLICATION->updater();
    return updater ? static_cast<int>(updater->getUpdateCheckInterval() / 3600) : 24;
}

void SettingsBackend::setUpdaterIntervalHours(int hours)
{
    if (auto* updater = APPLICATION->updater()) {
        updater->setUpdateCheckInterval(hours * 3600);
    }
}

void SettingsBackend::checkForUpdates()
{
    APPLICATION->triggerUpdateCheck();
}

// ---------------------------------------------------------------- java

static QVariantList javaListToVariant(BaseVersionList* list)
{
    QVariantList out;
    for (int i = 0; i < list->count(); i++) {
        auto java = std::dynamic_pointer_cast<JavaInstall>(list->at(i));
        if (!java) {
            continue;
        }
        out << QVariantMap{ { "path", java->path },
                            { "version", java->id.toString() },
                            { "major", java->id.major() },
                            { "arch", java->arch },
                            { "is64", java->is_64bit } };
    }
    return out;
}

void SettingsBackend::refreshJavaInstalls(bool force)
{
    if (m_javaLoading) {
        return;
    }
    auto* list = APPLICATION->javalist();
    if (list->isLoaded() && !force) {
        m_javaInstalls = javaListToVariant(list);
        emit javaInstallsChanged();
        return;
    }
    auto task = list->getLoadTask(force);
    if (!task) {
        m_javaInstalls = javaListToVariant(list);
        emit javaInstallsChanged();
        return;
    }
    m_javaLoading = true;
    emit javaInstallsChanged();
    connect(task.get(), &Task::finished, this, [this, list] {
        m_javaLoading = false;
        m_javaInstalls = javaListToVariant(list);
        emit javaInstallsChanged();
    });
    if (!task->isRunning()) {
        task->start();
    }
}

void SettingsBackend::refreshManagedJavas()
{
    if (!BuildConfig.JAVA_DOWNLOADER_ENABLED || m_managedLoading) {
        return;
    }
    if (!m_managedList) {
        m_managedList = new JavaInstallList(this, true);
    }
    auto task = m_managedList->getLoadTask(true);
    if (!task) {
        m_managedJavas = javaListToVariant(m_managedList);
        emit managedJavasChanged();
        return;
    }
    m_managedLoading = true;
    emit managedJavasChanged();
    connect(task.get(), &Task::finished, this, [this] {
        m_managedLoading = false;
        m_managedJavas = javaListToVariant(m_managedList);
        emit managedJavasChanged();
    });
    if (!task->isRunning()) {
        task->start();
    }
}

QString SettingsBackend::managedJavaFolderName(const QString& path) const
{
    QDir dir(APPLICATION->javaPath());
    for (auto& entry : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (path.startsWith(entry.canonicalFilePath())) {
            return entry.fileName();
        }
    }
    return {};
}

QString SettingsBackend::removeManagedJava(const QString& path)
{
    QDir dir(APPLICATION->javaPath());
    for (auto& entry : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (path.startsWith(entry.canonicalFilePath())) {
            if (!FS::deletePath(entry.canonicalFilePath())) {
                return tr("Could not delete %1").arg(entry.canonicalFilePath());
            }
            refreshManagedJavas();
            // the detected list may contain it too
            refreshJavaInstalls(true);
            return {};
        }
    }
    return tr("This Java installation is not managed by the launcher.");
}

void SettingsBackend::testJava(const QString& path, const QString& args, int minMem, int maxMem, int permGen)
{
    if (m_tester) {
        return;
    }
    if (auto warning = jvmArgsWarning(args); !warning.isEmpty()) {
        emit javaTestFinished("warning", tr("JVM arguments warning"), warning);
        return;
    }
    if (JavaUtils::getJavaCheckPath().isEmpty()) {
        emit javaTestFinished("error", tr("Java test failure"), tr("Java checker library could not be found. Please check your installation."));
        return;
    }
    m_testPath = path;
    m_testArgs = args;
    m_testMin = minMem;
    m_testMax = maxMem;
    m_testPermGen = permGen;

    // first pass: is the binary usable at all?
    m_tester.reset(new JavaChecker(path, "", 0, 0, 0, 0));
    connect(m_tester.get(), &JavaChecker::checkFinished, this, [this](const JavaChecker::Result& result) {
        if (result.validity != JavaChecker::Result::Validity::Valid) {
            finishTest("error", tr("Java test failure"),
                       tr("The specified Java binary didn't work.<br />You should press 'Detect', or set the path to the Java executable."));
            return;
        }
        // second pass: with the configured arguments and memory
        auto second = JavaChecker::Ptr(new JavaChecker(m_testPath, m_testArgs, m_testMin, m_testMax,
                                                       result.javaVersion.requiresPermGen() ? m_testPermGen : 0, 0));
        m_tester = second;
        connect(second.get(), &JavaChecker::checkFinished, this, [this](const JavaChecker::Result& r) {
            if (r.validity == JavaChecker::Result::Validity::Valid) {
                QString text = tr("Java test succeeded!<br />Platform reported: %1<br />Java version reported: %2<br />Java vendor "
                                  "reported: %3<br />")
                                   .arg(r.realPlatform, r.javaVersion.toString(), r.javaVendor);
                if (!r.errorLog.isEmpty()) {
                    auto htmlError = r.errorLog.toHtmlEscaped();
                    htmlError.replace('\n', "<br />");
                    text += tr("<br />Warnings:<br /><font color=\"orange\">%1</font>").arg(htmlError);
                }
                finishTest("success", tr("Java test success"), text);
            } else {
                auto htmlError = r.errorLog.toHtmlEscaped();
                htmlError.replace('\n', "<br />");
                finishTest("error", tr("Java test failure"),
                           tr("The specified Java binary didn't work with the arguments you provided:<br />") +
                               QString("<font color=\"red\">%1</font>").arg(htmlError));
            }
        });
        second->start();
    });
    emit javaTestingChanged();
    m_tester->start();
}

void SettingsBackend::finishTest(const QString& kind, const QString& title, const QString& message)
{
    // shared_qobject_ptr uses deleteLater(), so dropping the checker inside its own signal is safe
    m_tester.reset();
    emit javaTestingChanged();
    emit javaTestFinished(kind, title, message);
}

// ---------------------------------------------------------------- APPLICATION signals

void SettingsBackend::notifyAboutToOpen()
{
    emit APPLICATION->globalSettingsAboutToOpen();
}

void SettingsBackend::notifyApplied()
{
    emit APPLICATION->globalSettingsApplied();
}
