#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariant>

#include "QObjectPtr.h"
#include "java/JavaChecker.h"

/**
 * `SettingsBackend` QML singleton: everything the global settings pages need beyond plain
 * App.setting()/App.setSetting() — platform capabilities, folder/file pickers, validation helpers,
 * theme lists, Java detection/testing, the managed Java list, proxy & updater glue.
 *
 * Settings keys are always the ones used by the classic pages in ui/pages/global/.
 */
class SettingsBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int systemRamMiB READ systemRamMiB CONSTANT)
    Q_PROPERTY(bool javaDownloaderEnabled READ javaDownloaderEnabled CONSTANT)
    Q_PROPERTY(bool supportsGameMode READ supportsGameMode CONSTANT)
    Q_PROPERTY(bool supportsMangoHud READ supportsMangoHud CONSTANT)
    Q_PROPERTY(bool supportsMSA READ supportsMSA CONSTANT)
    Q_PROPERTY(bool isLinux READ isLinux CONSTANT)
    Q_PROPERTY(QVariantList pinnableMajors READ pinnableMajors CONSTANT)
    /// metaUrl, resourceUrl, fmlLibsUrl, userAgent, glfw, openal, sdl (placeholders), helpUrl
    Q_PROPERTY(QVariantMap defaults READ defaults CONSTANT)
    /// [{ value, text, defaultBase }]
    Q_PROPERTY(QVariantList pasteTypes READ pasteTypes CONSTANT)
    Q_PROPERTY(bool updaterAvailable READ updaterAvailable CONSTANT)
    Q_PROPERTY(bool updaterSupported READ updaterSupported CONSTANT)
    /// Debug: env PRISM_MODERN_SETTINGS_PAGE=<page id> opens that settings page (for screenshots)
    Q_PROPERTY(QString debugPage READ debugPage CONSTANT)

    Q_PROPERTY(bool javaListLoading READ javaListLoading NOTIFY javaInstallsChanged)
    /// [{ path, version, major, arch, is64, recommended }]
    Q_PROPERTY(QVariantList javaInstalls READ javaInstalls NOTIFY javaInstallsChanged)
    Q_PROPERTY(bool managedJavaLoading READ managedJavaLoading NOTIFY managedJavasChanged)
    Q_PROPERTY(QVariantList managedJavas READ managedJavas NOTIFY managedJavasChanged)
    Q_PROPERTY(bool javaTesting READ javaTesting NOTIFY javaTestingChanged)
    Q_PROPERTY(bool javaCheckerAvailable READ javaCheckerAvailable CONSTANT)

   public:
    explicit SettingsBackend(QObject* parent = nullptr);
    static SettingsBackend* create(QQmlEngine*, QJSEngine*);
    static SettingsBackend* instance();

    int systemRamMiB() const;
    bool javaDownloaderEnabled() const;
    bool supportsGameMode() const;
    bool supportsMangoHud() const;
    bool supportsMSA() const;
    bool isLinux() const;
    QVariantList pinnableMajors() const;
    QVariantMap defaults() const;
    QVariantList pasteTypes() const;
    bool updaterAvailable() const;
    bool updaterSupported() const;
    QString debugPage() const;
    bool javaCheckerAvailable() const;

    bool javaListLoading() const { return m_javaLoading; }
    QVariantList javaInstalls() const { return m_javaInstalls; }
    bool managedJavaLoading() const { return m_managedLoading; }
    QVariantList managedJavas() const { return m_managedJavas; }
    bool javaTesting() const { return m_tester != nullptr; }

    // ---- pickers & paths ----
    Q_INVOKABLE QString browseDirectory(const QString& title, const QString& start = QString()) const;
    Q_INVOKABLE QString browseFile(const QString& title, const QString& start = QString(), const QString& filter = QString()) const;
    Q_INVOKABLE QString normalizePath(const QString& path) const;
    Q_INVOKABLE bool directoryExists(const QString& path) const;
    /// Returns a warning when the instance folder is known to be problematic ("" otherwise).
    Q_INVOKABLE QString instanceDirWarning(const QString& rawDir) const;
    /// Returns a warning if the JVM arguments contain options that are not allowed ("" otherwise).
    Q_INVOKABLE QString jvmArgsWarning(const QString& args) const;
    Q_INVOKABLE bool executableResolves(const QString& path) const;
    Q_INVOKABLE bool isExecutableFile(const QString& path) const;
    Q_INVOKABLE QString resolveJsonEditor(const QString& path) const;
    /// "" when the profiler install at path is OK, else the error. id: jprofiler | jvisualvm
    Q_INVOKABLE QString checkProfiler(const QString& id, const QString& path) const;
    Q_INVOKABLE QString worldToolCommandFor(const QString& executable) const;
    Q_INVOKABLE QString defaultApplicationsDir() const;

    // ---- network ----
    Q_INVOKABLE void setUseSystemLocale(bool on);
    Q_INVOKABLE void applyProxy(const QString& type, const QString& addr, int port, const QString& user, const QString& pass);

    // ---- classic themes (still used by classic dialogs) ----
    Q_INVOKABLE QVariantList iconThemes() const;
    Q_INVOKABLE QVariantList widgetThemes() const;
    Q_INVOKABLE QVariantList catPacks() const;
    Q_INVOKABLE void reloadThemes();
    Q_INVOKABLE void applyClassicTheme();
    Q_INVOKABLE void setCatPack(const QString& id);
    Q_INVOKABLE QString catImageUrl() const;
    /// [{ text, fg, bg }] lines of the console colour preview
    Q_INVOKABLE QVariantList consolePreview() const;
    Q_INVOKABLE QStringList fontFamilies() const;

    // ---- updater ----
    Q_INVOKABLE bool updaterAutoCheck() const;
    Q_INVOKABLE void setUpdaterAutoCheck(bool on);
    Q_INVOKABLE int updaterIntervalHours() const;
    Q_INVOKABLE void setUpdaterIntervalHours(int hours);
    Q_INVOKABLE void checkForUpdates();

    // ---- java ----
    Q_INVOKABLE void refreshJavaInstalls(bool force = false);
    Q_INVOKABLE void refreshManagedJavas();
    /// "" on success, else an error message
    Q_INVOKABLE QString removeManagedJava(const QString& path);
    Q_INVOKABLE QString managedJavaFolderName(const QString& path) const;
    Q_INVOKABLE void testJava(const QString& path, const QString& args, int minMem, int maxMem, int permGen);

    // ---- APPLICATION signals the classic code relies on ----
    Q_INVOKABLE void notifyAboutToOpen();
    Q_INVOKABLE void notifyApplied();

   signals:
    void javaInstallsChanged();
    void managedJavasChanged();
    void javaTestingChanged();
    /// kind: success | warning | error;  message is rich text
    void javaTestFinished(const QString& kind, const QString& title, const QString& message);
    /// a message raised by core Java code (JavaCommon) while the modern UI is active
    void javaMessage(const QString& kind, const QString& title, const QString& message);

   private:
    void finishTest(const QString& kind, const QString& title, const QString& message);

    bool m_javaLoading = false;
    QVariantList m_javaInstalls;
    bool m_managedLoading = false;
    QVariantList m_managedJavas;
    class JavaInstallList* m_managedList = nullptr;

    JavaChecker::Ptr m_tester;
    QString m_testArgs;
    int m_testMin = 0, m_testMax = 0, m_testPermGen = 0;
    QString m_testPath;
};
