#pragma once

#include <QQmlEngine>
#include <QSortFilterProxyModel>
#include <QUrl>

/**
 * Icons from APPLICATION->icons() for IconPickerDialog.qml (classic IconPickerDialog): search + category filter,
 * add icons from files, remove custom icons.
 * Roles: key, name, source (image://instanceicon/<key>?v=<rev>), removable, builtIn
 */
class NIIconModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
    /// all | modern | legacy | modpacks | custom
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString iconFilter READ iconFilter CONSTANT)

   public:
    enum Roles { KeyRole = Qt::UserRole + 800, NameRole, SourceRole, RemovableRole, BuiltInRole };
    explicit NIIconModel(QObject* parent = nullptr);

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString search() const { return m_search; }
    void setSearch(const QString& s);
    QString category() const { return m_category; }
    void setCategory(const QString& c);
    int count() const { return rowCount(); }
    QString iconFilter() const;

    Q_INVOKABLE int indexOf(const QString& key) const;
    /// returns the key of the first added icon ("" if none)
    Q_INVOKABLE QString addIcons(const QList<QUrl>& files);
    Q_INVOKABLE bool removeIcon(const QString& key);
    Q_INVOKABLE bool canRemove(const QString& key) const;
    Q_INVOKABLE void openFolder(const QString& key);

   signals:
    void searchChanged();
    void categoryChanged();
    void countChanged();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;
    bool lessThan(const QModelIndex& left, const QModelIndex& right) const override;

   private:
    QString m_search;
    QString m_category = "all";
    int m_revision = 0;
};
