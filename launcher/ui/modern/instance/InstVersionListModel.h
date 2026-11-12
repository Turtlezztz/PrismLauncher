#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QSortFilterProxyModel>
#include <QStringList>

#include "tasks/Task.h"

class BaseVersionList;

/**
 * Filterable list of versions of a metadata component (uid) or of detected Java installations (uid = "java").
 * Used by InstVersionSelectDialog / the loader installer / Java auto-detect.
 */
class InstVersionListModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT

    /// metadata uid, e.g. "net.minecraft", or "java" for detected Java installs
    Q_PROPERTY(QString uid READ uid WRITE setUid NOTIFY uidChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY filterChanged)
    /// only versions whose parent (Minecraft) version is this one or empty
    Q_PROPERTY(QString parentVersion READ parentVersion WRITE setParentVersion NOTIFY filterChanged)
    /// hide everything (e.g. loader not available for this Minecraft version)
    Q_PROPERTY(bool blockAll READ blockAll WRITE setBlockAll NOTIFY filterChanged)
    /// allowed version types ("release", "snapshot", "old_beta", "old_alpha", "experiment"); empty = all
    Q_PROPERTY(QStringList types READ types WRITE setTypes NOTIFY filterChanged)
    /// only Java installs of this major version (0 = any)
    Q_PROPERTY(int javaMajor READ javaMajor WRITE setJavaMajor NOTIFY filterChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion WRITE setCurrentVersion NOTIFY currentVersionChanged)
    /// additional version to mark as recommended (e.g. LWJGL required by Minecraft)
    Q_PROPERTY(QString extraRecommended READ extraRecommended WRITE setExtraRecommended NOTIFY uidChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY loadingChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    /// distinct types present in the list (for filter chips)
    Q_PROPERTY(QStringList availableTypes READ availableTypes NOTIFY countChanged)

   public:
    enum Roles {
        VersionNameRole = Qt::UserRole + 300,
        DescriptorRole,
        TypeRole,
        RecommendedRole,
        LatestRole,
        ParentRole,
        TimeRole,
        CurrentRole,
        PathRole,
        ArchRole,
        JavaMajorRole,
    };
    explicit InstVersionListModel(QObject* parent = nullptr);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString uid() const { return m_uid; }
    void setUid(const QString& uid);
    QString search() const { return m_search; }
    void setSearch(const QString& s);
    QString parentVersion() const { return m_parent; }
    void setParentVersion(const QString& v);
    bool blockAll() const { return m_blockAll; }
    void setBlockAll(bool b);
    QStringList types() const { return m_types; }
    void setTypes(const QStringList& t);
    int javaMajor() const { return m_javaMajor; }
    void setJavaMajor(int m);
    QString currentVersion() const { return m_current; }
    void setCurrentVersion(const QString& v);
    QString extraRecommended() const { return m_extraRecommended; }
    void setExtraRecommended(const QString& v);
    bool loading() const { return m_loadTask && m_loadTask->isRunning(); }
    QString errorString() const { return m_error; }
    int count() const { return rowCount(); }
    QStringList availableTypes() const;

    Q_INVOKABLE void load(bool force = false);
    Q_INVOKABLE QVariantMap get(int row) const;
    /// row of the current version, else the recommended one, else 0 (-1 if empty)
    Q_INVOKABLE int preferredRow() const;
    Q_INVOKABLE int rowOf(const QString& descriptor) const;
    /// "minimum Minecraft version" helper: true if `mc` < `oldest` (Version compare)
    Q_INVOKABLE static bool versionLess(const QString& a, const QString& b);

   signals:
    void uidChanged();
    void filterChanged();
    void currentVersionChanged();
    void loadingChanged();
    void countChanged();
    void loaded();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

   private:
    QPointer<BaseVersionList> m_list;
    QString m_uid;
    QString m_search;
    QString m_parent;
    bool m_blockAll = false;
    QStringList m_types;
    int m_javaMajor = 0;
    QString m_current;
    QString m_extraRecommended;
    QString m_error;
    Task::Ptr m_loadTask;
};
