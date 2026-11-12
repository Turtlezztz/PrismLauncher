#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QSet>
#include <QSortFilterProxyModel>

class MinecraftInstance;
class WorldList;
class World;
class ResTaskHandle;

/**
 * QML model for an instance's singleplayer worlds (classic WorldListPage over WorldList).
 *   ResWorldModel { instanceId: id }
 */
class ResWorldModel : public QSortFilterProxyModel, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY sourceChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY sourceChanged)
    Q_PROPERTY(bool supportsJoin READ supportsJoin NOTIFY sourceChanged)
    Q_PROPERTY(bool instanceRunning READ instanceRunning NOTIFY instanceRunningChanged)
    Q_PROPERTY(QString dirPath READ dirPath NOTIFY sourceChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged)  // name | lastPlayed | size | gameMode
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(int currentRow READ currentRow NOTIFY selectionChanged)
    Q_PROPERTY(QStringList worldTools READ worldTools NOTIFY worldToolsChanged)

   public:
    enum Roles {
        NameRole = Qt::UserRole + 100,
        FolderNameRole,
        GameModeRole,
        LastPlayedTextRole,
        LastPlayedRole,
        SizeTextRole,
        SeedRole,
        IconSourceRole,
        LinkedRole,
        SelectedRole,
        PathRole,
    };

    explicit ResWorldModel(QObject* parent = nullptr);
    ~ResWorldModel() override;
    void classBegin() override {}
    void componentComplete() override;

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    bool valid() const { return m_worlds != nullptr; }
    bool supportsJoin() const;
    bool instanceRunning() const;
    QString dirPath() const;
    QString filterText() const { return m_filterText; }
    void setFilterText(const QString& t);
    QString sortKey() const { return m_sortKey; }
    void setSortKey(const QString& k);
    int count() const { return rowCount(); }
    int totalCount() const;
    int selectedCount() const { return static_cast<int>(m_selected.size()); }
    int currentRow() const;
    QStringList worldTools() const;

    Q_INVOKABLE void select(int row, const QString& mode = "single");
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE bool anySelectedHasIcon() const;

    Q_INVOKABLE ResTaskHandle* addWorlds(const QList<QUrl>& zips);
    Q_INVOKABLE ResTaskHandle* copyWorld(int row, const QString& name);
    Q_INVOKABLE ResTaskHandle* deleteSelected();
    Q_INVOKABLE bool renameWorld(int row, const QString& name);
    Q_INVOKABLE void resetSelectedIcons();
    Q_INVOKABLE void copySeed(int row);
    Q_INVOKABLE void openFolder(int row = -1);
    Q_INVOKABLE bool join(int row);
    Q_INVOKABLE void refresh();
    /// returns "" on success or an error message
    Q_INVOKABLE QString launchTool(int row, const QString& toolName);
    Q_INVOKABLE QString datapacksFolder(int row) const;

   signals:
    void sourceChanged();
    void filterTextChanged();
    void sortChanged();
    void countChanged();
    void selectionChanged();
    void instanceRunningChanged();
    void worldToolsChanged();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;
    bool lessThan(const QModelIndex& left, const QModelIndex& right) const override;

   private:
    void rebind();
    const World* worldAt(int proxyRow) const;
    int sourceRow(int proxyRow) const;
    int rowOfFolder(const QString& folder) const;
    ResTaskHandle* runWithWatchPaused(class Task* task, const QString& title);

    QString m_instanceId;
    bool m_complete = false;
    QPointer<MinecraftInstance> m_instance;
    QPointer<WorldList> m_worlds;
    QString m_filterText;
    QString m_sortKey = "lastPlayed";
    QSet<QString> m_selected;
    QString m_anchor;
    QString m_current;
    QList<QMetaObject::Connection> m_conns;
};
