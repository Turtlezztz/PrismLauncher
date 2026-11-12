#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QSortFilterProxyModel>

#include "tasks/Task.h"

class MinecraftInstance;
class PackProfile;

/**
 * The instance's component list (PackProfile) for the Version tab, plus all its actions.
 * Actions address components by uid, so filtering doesn't matter.
 */
class ComponentListModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceIdChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString busyStatus READ busyStatus NOTIFY busyChanged)
    /// 0..1 or -1
    Q_PROPERTY(double busyProgress READ busyProgress NOTIFY busyChanged)
    Q_PROPERTY(bool autoUpdateMinecraft READ autoUpdateMinecraft NOTIFY instanceIdChanged)

   public:
    enum Roles {
        UidRole = Qt::UserRole + 200,
        NameRole,
        VersionRole,
        EnabledRole,
        CanBeDisabledRole,
        SeverityRole,  // "" | warning | error
        ProblemsRole,  // list of { severity, text }
        RemovableRole,
        MoveableRole,
        VersionChangeableRole,
        CustomizableRole,
        RevertibleRole,
        CustomRole,
        LoaderRole,
        DependencyOnlyRole,
        ReleaseDateRole,
    };

    explicit ComponentListModel(QObject* parent = nullptr);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    QString filterText() const { return m_filter; }
    void setFilterText(const QString& text);
    int count() const { return rowCount(); }
    bool busy() const;
    QString busyStatus() const;
    double busyProgress() const;
    bool autoUpdateMinecraft() const;

    /// all role values of a component
    Q_INVOKABLE QVariantMap get(const QString& uid) const;
    Q_INVOKABLE void setEnabled(const QString& uid, bool enabled);
    Q_INVOKABLE void moveUp(const QString& uid);
    Q_INVOKABLE void moveDown(const QString& uid);
    /// remove (custom components need confirmation in QML first). Returns "" or an error.
    Q_INVOKABLE QString remove(const QString& uid);
    Q_INVOKABLE void customize(const QString& uid);
    Q_INVOKABLE void revert(const QString& uid);
    /// open the component's json file in the external editor
    Q_INVOKABLE void edit(const QString& uid);
    /// set a component to a version descriptor (handles the Minecraft-specific bits like the classic page)
    Q_INVOKABLE void changeVersion(const QString& uid, const QString& version);
    /// version that should be suggested for this uid (e.g. LWJGL required by Minecraft)
    Q_INVOKABLE QString recommendedVersionFor(const QString& uid) const;

    // --- adding things ---
    Q_INVOKABLE void addJarMods();
    Q_INVOKABLE void replaceMinecraftJar();
    Q_INVOKABLE void importComponents();
    Q_INVOKABLE void addAgents();
    /// "" if ok, or a reason why uid/name can't be used
    Q_INVOKABLE QString validateEmpty(const QString& uid, const QString& name) const;
    Q_INVOKABLE void addEmpty(const QString& uid, const QString& name);
    Q_INVOKABLE QString suggestUid(const QString& name) const;

    // --- loaders ---
    /// enabled, non-custom components known to conflict with installing `uid`
    Q_INVOKABLE QVariantList loaderConflicts(const QString& uid) const;
    /// action: disable | remove
    Q_INVOKABLE void resolveConflict(const QString& uid, const QString& action);
    Q_INVOKABLE void installLoader(const QString& uid, const QString& version);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void downloadAll();

   signals:
    void instanceIdChanged();
    void filterTextChanged();
    void countChanged();
    void busyChanged();
    void error(const QString& title, const QString& message);
    void info(const QString& message);

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

   private:
    void trackTask(Task* task);
    int sourceRowOf(const QString& uid) const;
    QPointer<MinecraftInstance> m_inst;
    QPointer<PackProfile> m_profile;
    QString m_id;
    QString m_filter;
    QPointer<Task> m_task;
    Task::Ptr m_ownedTask;
};
