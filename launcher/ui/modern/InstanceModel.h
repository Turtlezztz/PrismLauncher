#pragma once

#include <QQmlEngine>
#include <QSet>
#include <QSortFilterProxyModel>

/**
 * QML-friendly view over APPLICATION->instances(), with search + sorting.
 * Access via `App.instances`.
 */
class InstanceModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use App.instances")
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)  // "name" | "lastPlayed"
    Q_PROPERTY(QString groupFilter READ groupFilter WRITE setGroupFilter NOTIFY groupFilterChanged)  // "" = all
    Q_PROPERTY(int count READ count NOTIFY countChanged)

   public:
    enum Roles {
        IdRole = Qt::UserRole + 100,
        NameRole,
        IconSourceRole,
        IconKeyRole,
        GroupRole,
        RunningRole,
        CanLaunchRole,
        CrashedRole,
        BrokenRole,
        StatusTextRole,
        LastLaunchRole,      // ms since epoch, 0 = never
        LastPlayedTextRole,  // "2 hours ago"
        PlayTimeTextRole,
        ManagedPackRole,
        ManagedPackTypeRole,
        NotesRole,
    };

    explicit InstanceModel(QObject* parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString filterText() const { return m_filterText; }
    void setFilterText(const QString& text);
    QString sortMode() const { return m_sortMode; }
    void setSortMode(const QString& mode);
    QString groupFilter() const { return m_groupFilter; }
    void setGroupFilter(const QString& group);
    int count() const { return rowCount(); }

    /// row in this proxy for the given instance id (-1 if hidden / missing)
    Q_INVOKABLE int indexOf(const QString& id) const;
    /// all role values for one instance as a map
    Q_INVOKABLE QVariantMap get(const QString& id) const;

    static QString relativeTime(qint64 msecs);

   signals:
    void filterTextChanged();
    void sortModeChanged();
    void groupFilterChanged();
    void countChanged();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;
    bool lessThan(const QModelIndex& left, const QModelIndex& right) const override;

   private:
    QString m_filterText;
    QString m_sortMode = "name";
    QString m_groupFilter;
    QHash<QString, int> m_iconRevision;
    QSet<QObject*> m_hooked;
    QString versionText(class MinecraftInstance* inst) const;
};
