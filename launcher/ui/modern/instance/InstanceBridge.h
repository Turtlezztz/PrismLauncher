#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QUrl>
#include <QVariantList>

class MinecraftInstance;
class LaunchTask;
class Task;

/**
 * Per-instance state + actions for the modern instance page.
 *   InstanceBridge { instanceId: page.instanceId }
 */
class InstanceBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceIdChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY instanceIdChanged)

    // identity
    Q_PROPERTY(QString name READ name NOTIFY propertiesChanged)
    Q_PROPERTY(QString iconKey READ iconKey NOTIFY propertiesChanged)
    Q_PROPERTY(QString iconSource READ iconSource NOTIFY propertiesChanged)
    Q_PROPERTY(QString versionText READ versionText NOTIFY propertiesChanged)
    Q_PROPERTY(QString minecraftVersion READ minecraftVersion NOTIFY propertiesChanged)
    Q_PROPERTY(QString playTimeText READ playTimeText NOTIFY propertiesChanged)
    Q_PROPERTY(QString lastPlayedText READ lastPlayedText NOTIFY propertiesChanged)
    Q_PROPERTY(QString group READ group NOTIFY propertiesChanged)
    Q_PROPERTY(QString notes READ notes WRITE setNotes NOTIFY notesChanged)
    Q_PROPERTY(QString instanceRoot READ instanceRoot NOTIFY instanceIdChanged)
    Q_PROPERTY(QString gameRoot READ gameRoot NOTIFY instanceIdChanged)
    Q_PROPERTY(bool crashed READ crashed NOTIFY propertiesChanged)
    Q_PROPERTY(bool broken READ broken NOTIFY propertiesChanged)

    // managed pack
    Q_PROPERTY(bool managedPack READ managedPack NOTIFY propertiesChanged)
    Q_PROPERTY(QString managedPackType READ managedPackType NOTIFY propertiesChanged)

    // launch state
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(bool launching READ launching NOTIFY stateChanged)
    Q_PROPERTY(bool canLaunch READ canLaunch NOTIFY stateChanged)
    Q_PROPERTY(bool restartQueued READ restartQueued NOTIFY stateChanged)
    Q_PROPERTY(QString launchStatus READ launchStatus NOTIFY progressChanged)
    /// 0..1, or -1 when indeterminate
    Q_PROPERTY(double launchProgress READ launchProgress NOTIFY progressChanged)
    Q_PROPERTY(bool hasLog READ hasLog NOTIFY stateChanged)

    // launch menu
    Q_PROPERTY(bool legacy READ legacy NOTIFY instanceIdChanged)
    /// old instances use texture packs instead of resource packs
    Q_PROPERTY(bool usesTexturePacks READ usesTexturePacks NOTIFY propertiesChanged)
    Q_PROPERTY(bool supportsDemo READ supportsDemo NOTIFY instanceIdChanged)
    Q_PROPERTY(bool supportsQuickPlayWorld READ supportsQuickPlayWorld NOTIFY instanceIdChanged)
    Q_PROPERTY(QVariantList accounts READ accounts NOTIFY accountsChanged)
    Q_PROPERTY(QVariantList profilers READ profilers NOTIFY profilerChanged)
    Q_PROPERTY(QString profiler READ profiler NOTIFY profilerChanged)

   public:
    explicit InstanceBridge(QObject* parent = nullptr);

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    bool valid() const { return m_inst != nullptr; }

    QString name() const;
    QString iconKey() const;
    QString iconSource() const;
    QString versionText() const;
    QString minecraftVersion() const;
    QString playTimeText() const;
    QString lastPlayedText() const;
    QString group() const;
    QString notes() const;
    void setNotes(const QString& notes);
    QString instanceRoot() const;
    QString gameRoot() const;
    bool crashed() const;
    bool broken() const;
    bool managedPack() const;
    QString managedPackType() const;

    bool running() const;
    bool launching() const;
    bool canLaunch() const;
    bool restartQueued() const { return m_restartQueued; }
    QString launchStatus() const;
    double launchProgress() const;
    bool hasLog() const;

    bool supportsDemo() const;
    bool legacy() const;
    bool usesTexturePacks() const;
    bool supportsQuickPlayWorld() const;
    QVariantList accounts() const;
    QVariantList profilers() const;
    QString profiler() const;

    /// mode: normal | offline | demo. accountId: profile id of the account to use ("" = default)
    Q_INVOKABLE bool launch(const QString& mode = "normal", const QString& accountId = QString());
    Q_INVOKABLE bool launchJoinServer(const QString& address);
    Q_INVOKABLE bool launchJoinWorld(const QString& world);
    Q_INVOKABLE bool kill();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void setProfiler(const QString& key);
    /// world folder names (for quick play)
    Q_INVOKABLE QStringList worlds() const;
    /// open a folder relative to the instance: "" (instance root), "game", "libraries", "logs" ...
    Q_INVOKABLE void openFolder(const QString& which);

    /// debug helpers: PRISM_MODERN_* environment variables, and whether a qrc:/ url exists
    Q_INVOKABLE QString environment(const QString& name) const;
    Q_INVOKABLE bool resourceExists(const QUrl& url) const;

    // --- game options (options.txt, read-only) ---
    Q_INVOKABLE QVariantList gameOptions() const;
    Q_INVOKABLE QString gameOptionsPath() const;

   signals:
    void instanceIdChanged();
    void propertiesChanged();
    void notesChanged();
    void stateChanged();
    void progressChanged();
    void accountsChanged();
    void profilerChanged();
    /// the instance was deleted
    void gone();

   private:
    void hookLaunchTask(LaunchTask* task);
    void hookAuxTask();
    QString m_id;
    QPointer<MinecraftInstance> m_inst;
    QPointer<LaunchTask> m_launchTask;
    QPointer<Task> m_auxTask;
    QList<QMetaObject::Connection> m_conns;
    QList<QMetaObject::Connection> m_taskConns;
    QList<QMetaObject::Connection> m_auxConns;
    bool m_restartQueued = false;
    int m_iconRev = 0;
};
