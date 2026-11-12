#pragma once

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QFileSystemWatcher>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QTimer>
#include <optional>

class MinecraftInstance;

/**
 * QML model for an instance's multiplayer server list (servers.dat), with live status pings
 * (MOTD, players, version, latency). Port of the classic ServersPage model.
 *   ResServerModel { instanceId: id }
 */
class ResServerModel : public QAbstractListModel, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY sourceChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY sourceChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY lockedChanged)  // instance is running: list is read-only
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int currentRow READ currentRow WRITE setCurrentRow NOTIFY currentRowChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)

   public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        AddressRole,
        AcceptTexturesRole,  // 0 ask, 1 always, 2 never
        IconSourceRole,
        StatusRole,  // pinging | online | offline
        MotdHtmlRole,
        PlayersRole,
        MaxPlayersRole,
        VersionRole,
        PingRole,
        ErrorRole,
        SelectedRole,
    };

    struct Server {
        QString name;
        QString address;
        int acceptTextures = 0;
        QByteArray icon;
        int iconRev = 0;
        // status
        QString status = "pinging";
        QString motdHtml;
        int players = -1;
        int maxPlayers = -1;
        QString version;
        int ping = -1;
        QString error;
        int pingGen = 0;
        bool selected = false;
    };

    explicit ResServerModel(QObject* parent = nullptr);
    ~ResServerModel() override;
    void classBegin() override {}
    void componentComplete() override;

    int rowCount(const QModelIndex& parent = {}) const override { return parent.isValid() ? 0 : static_cast<int>(m_servers.size()); }
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    bool valid() const { return m_instance != nullptr; }
    bool locked() const { return m_locked; }
    int count() const { return rowCount(); }
    int currentRow() const { return m_current; }
    void setCurrentRow(int r);
    int selectedCount() const;

    Q_INVOKABLE void select(int row, const QString& mode = "single");
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE QVariantMap get(int row) const;
    /// Adds a server after the current one; returns its row (-1 if locked)
    Q_INVOKABLE int addServer(const QString& name, const QString& address, int acceptTextures = 0);
    Q_INVOKABLE void setServer(int row, const QString& name, const QString& address, int acceptTextures);
    Q_INVOKABLE bool removeSelected();
    Q_INVOKABLE bool moveUp(int row);
    Q_INVOKABLE bool moveDown(int row);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool join(int row);
    Q_INVOKABLE void saveNow();

   signals:
    void sourceChanged();
    void lockedChanged();
    void countChanged();
    void currentRowChanged();
    void selectionChanged();

   private:
    QString serversPath() const;
    void load();
    void scheduleSave();
    void saveInternal();
    void ping(int row);
    void updateWatcher();
    void rowChanged(int row);
    QPixmap iconFor(const QString& id, const QSize& size) const;

    QString m_instanceId;
    bool m_complete = false;
    QPointer<MinecraftInstance> m_instance;
    QList<Server> m_servers;
    bool m_loaded = false;
    bool m_locked = false;
    bool m_dirty = false;
    int m_current = -1;
    int m_anchor = -1;
    QTimer m_saveTimer;
    QFileSystemWatcher m_watcher;
    QString m_iconNs;
};
