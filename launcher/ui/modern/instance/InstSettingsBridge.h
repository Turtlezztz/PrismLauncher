#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QVariant>

#include "java/JavaChecker.h"

class MinecraftInstance;

/**
 * Per-instance settings access for the instance Settings tab.
 * Values are applied immediately. Override groups: setOverride(gateKey, keys, on) mirrors the classic checkable group boxes
 * (turning a group off resets its keys so the global values apply again).
 */
class InstSettingsBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceIdChanged)
    /// bumped whenever any instance setting changes; bind with `bridge.revision, bridge.get("Key")`
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(int totalRamMiB READ totalRamMiB CONSTANT)
    Q_PROPERTY(bool gameModeAvailable READ gameModeAvailable CONSTANT)
    Q_PROPERTY(bool mangoHudAvailable READ mangoHudAvailable CONSTANT)
    Q_PROPERTY(bool isLinux READ isLinux CONSTANT)
    Q_PROPERTY(bool javaDownloaderEnabled READ javaDownloaderEnabled CONSTANT)
    Q_PROPERTY(bool legacy READ legacy NOTIFY instanceIdChanged)
    Q_PROPERTY(bool javaTesting READ javaTesting NOTIFY javaTestingChanged)

   public:
    explicit InstSettingsBridge(QObject* parent = nullptr);

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    int revision() const { return m_revision; }
    int totalRamMiB() const;
    bool gameModeAvailable() const;
    bool mangoHudAvailable() const;
    bool isLinux() const;
    bool javaDownloaderEnabled() const;
    bool legacy() const;
    bool javaTesting() const { return m_checker != nullptr; }

    Q_INVOKABLE QVariant get(const QString& key) const;
    Q_INVOKABLE void set(const QString& key, const QVariant& value);
    Q_INVOKABLE void reset(const QString& key);
    /// value from the global settings
    Q_INVOKABLE QVariant globalValue(const QString& key) const;
    Q_INVOKABLE void setOverride(const QString& gateKey, const QStringList& keys, bool on);

    /// environment variables as [{ name, value }]
    Q_INVOKABLE QVariantList envVars() const;
    Q_INVOKABLE void setEnvVars(const QVariantList& vars);

    /// mod download loaders: [{ key, name, checked }]
    Q_INVOKABLE QVariantList modLoaders() const;
    Q_INVOKABLE void setModLoaders(const QStringList& keys);
    Q_INVOKABLE void setModLoaderOverride(bool on);

    /// placeholder text for the native library path fields ("glfw" | "openal" | "sdl")
    Q_INVOKABLE QString nativeLibraryPlaceholder(const QString& which) const;

    /// pick files / folders with the native dialog. Returns "" when cancelled.
    Q_INVOKABLE QString browseJava(const QString& current) const;
    Q_INVOKABLE QString browseFile(const QString& title, const QString& current) const;
    Q_INVOKABLE QString browseDataPacksFolder() const;

    /// Test the given Java with the given arguments; answers with javaTestFinished.
    Q_INVOKABLE void testJava(const QString& path, const QString& jvmArgs, int minMem, int maxMem, int permGen);
    /// Open the Java download dialog.
    Q_INVOKABLE void openJavaInstaller();
    /// "" if acceptable, else a warning text (same rules as at launch)
    Q_INVOKABLE QString jvmArgsProblem(const QString& args) const;

   signals:
    void instanceIdChanged();
    void revisionChanged();
    void javaTestingChanged();
    /// kind: success | warning | error
    void javaTestFinished(const QString& kind, const QString& title, const QString& text);

   private:
    QPointer<MinecraftInstance> m_inst;
    QString m_id;
    int m_revision = 0;
    QMetaObject::Connection m_settingConn;
    JavaChecker::Ptr m_checker;
    QString m_testArgs;
    int m_testMin = 0, m_testMax = 0, m_testPermGen = 0;
};
