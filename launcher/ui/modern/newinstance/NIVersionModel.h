#pragma once

#include <QQmlEngine>
#include <QSortFilterProxyModel>

#include "meta/VersionList.h"
#include "tasks/Task.h"

/**
 * QML list of versions from the metadata index (net.minecraft, net.fabricmc.fabric-loader, ...),
 * with type / parent-version / text filters. Sorted newest first.
 *
 *     NIVersionModel { id: mc; uid: "net.minecraft"; typeFilter: ["release"] }
 */
class NIVersionModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString uid READ uid WRITE setUid NOTIFY uidChanged)
    /// substrings matched against the version type ("release", "snapshot", "beta", "alpha", "experiment"); empty = all
    Q_PROPERTY(QStringList typeFilter READ typeFilter WRITE setTypeFilter NOTIFY filterChanged)
    /// when set, only versions whose parent (required net.minecraft version) equals this are shown
    Q_PROPERTY(QString parentFilter READ parentFilter WRITE setParentFilter NOTIFY filterChanged)
    Q_PROPERTY(bool parentFilterEnabled READ parentFilterEnabled WRITE setParentFilterEnabled NOTIFY filterChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY filterChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY loadingChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

   public:
    enum Roles { VersionRole = Qt::UserRole + 300, TypeRole, RecommendedRole, TimeRole, ParentRole };

    explicit NIVersionModel(QObject* parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString uid() const { return m_uid; }
    void setUid(const QString& uid);
    void setVersionList(Meta::VersionList::Ptr list);
    QStringList typeFilter() const { return m_typeFilter; }
    void setTypeFilter(const QStringList& f);
    QString parentFilter() const { return m_parentFilter; }
    void setParentFilter(const QString& p);
    bool parentFilterEnabled() const { return m_parentFilterEnabled; }
    void setParentFilterEnabled(bool on);
    QString search() const { return m_search; }
    void setSearch(const QString& s);
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    int count() const { return rowCount(); }

    Q_INVOKABLE void refresh(bool force = true);
    Q_INVOKABLE QString versionAt(int row) const;
    Q_INVOKABLE int indexOf(const QString& version) const;
    /// first recommended row (or 0), -1 if empty
    Q_INVOKABLE int recommendedRow() const;

    BaseVersion::Ptr versionPtr(int row) const;

   signals:
    void uidChanged();
    void filterChanged();
    void loadingChanged();
    void countChanged();
    void loaded();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

   private:
    void refilter();
    QString m_uid;
    Meta::VersionList::Ptr m_list;
    QStringList m_typeFilter;
    QString m_parentFilter;
    bool m_parentFilterEnabled = false;
    QString m_search;
    bool m_loading = false;
    QString m_error;
    Task::Ptr m_loadTask;
};
