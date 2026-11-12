#pragma once

#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QSet>
#include <QSortFilterProxyModel>
#include <memory>

class MinecraftInstance;
class ResourceFolderModel;
class Resource;
class ResTaskHandle;

/**
 * QML view over one of an instance's external-resource folders (mods, resource packs, shader packs...),
 * wrapping the classic ResourceFolderModel and adding search, sorting, a state filter and multi-selection.
 *
 *   ResFolderModel { instanceId: "..."; kind: "mods" }
 * kind: mods | coremods | nilmods | resourcepacks | texturepacks | shaderpacks | datapacks | folderdatapacks (uses folderPath)
 */
class ResFolderModel : public QSortFilterProxyModel, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY sourceChanged)
    Q_PROPERTY(QString kind READ kind WRITE setKind NOTIFY sourceChanged)
    Q_PROPERTY(QString folderPath READ folderPath WRITE setFolderPath NOTIFY sourceChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY sourceChanged)
    Q_PROPERTY(bool isMods READ isMods NOTIFY sourceChanged)
    Q_PROPERTY(QString resourceType READ resourceType NOTIFY sourceChanged)  // mod | resourcepack | texturepack | shaderpack | datapack
    Q_PROPERTY(QString dirPath READ dirPath NOTIFY sourceChanged)
    Q_PROPERTY(bool instanceRunning READ instanceRunning NOTIFY instanceRunningChanged)
    Q_PROPERTY(bool hasModLoader READ hasModLoader NOTIFY sourceChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(QString stateFilter READ stateFilter WRITE setStateFilter NOTIFY stateFilterChanged)  // all | enabled | disabled | issues | updatable
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending WRITE setSortDescending NOTIFY sortChanged)
    Q_PROPERTY(int count READ count NOTIFY countsChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countsChanged)
    Q_PROPERTY(int enabledCount READ enabledCount NOTIFY countsChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(int currentRow READ currentRow NOTIFY selectionChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool metadataDisabled READ metadataDisabled CONSTANT)
    Q_PROPERTY(bool dependenciesDisabled READ dependenciesDisabled CONSTANT)

   public:
    enum Roles {
        InternalIdRole = Qt::UserRole + 1,
        NameRole,
        VersionRole,
        AuthorRole,
        ProviderRole,
        DescriptionRole,
        FileNameRole,
        SizeTextRole,
        DateTextRole,
        EnabledRole,
        SelectedRole,
        IconSourceRole,
        HasMetadataRole,
        UpdateLockedRole,
        IssuesRole,
        HomepageRole,
        SideRole,
        LoadersRole,
        McVersionsRole,
        ReleaseTypeRole,
        RequiresCountRole,
        RequiredByCountRole,
        PackFormatRole,
        IsFolderRole,
        LinkTipRole,
    };

    explicit ResFolderModel(QObject* parent = nullptr);
    ~ResFolderModel() override;

    void classBegin() override {}
    void componentComplete() override;

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    QString kind() const { return m_kind; }
    void setKind(const QString& k);
    QString folderPath() const { return m_folderPath; }
    void setFolderPath(const QString& p);
    bool valid() const { return m_src != nullptr; }
    bool isMods() const;
    QString resourceType() const;
    QString dirPath() const;
    bool instanceRunning() const;
    bool hasModLoader() const;
    QString filterText() const { return m_filterText; }
    void setFilterText(const QString& t);
    QString stateFilter() const { return m_stateFilter; }
    void setStateFilter(const QString& f);
    QString sortKey() const { return m_sortKey; }
    void setSortKey(const QString& k);
    bool sortDescending() const { return m_sortDescending; }
    void setSortDescending(bool d);
    int count() const { return rowCount(); }
    int totalCount() const;
    int enabledCount() const;
    int selectedCount() const { return static_cast<int>(m_selected.size()); }
    int currentRow() const;
    bool loading() const { return m_loading; }
    bool metadataDisabled() const;
    bool dependenciesDisabled() const;

    ResourceFolderModel* source() const { return m_src; }
    MinecraftInstance* instance() const { return m_instance; }
    QList<Resource*> selectedResources() const;

    // ---- selection ----
    /// mode: "single" (replace), "toggle" (ctrl/cmd), "range" (shift)
    Q_INVOKABLE void select(int row, const QString& mode = "single");
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE bool isSelected(int row) const;
    /// Summary of the selection used by QML for confirmations / enabling actions.
    Q_INVOKABLE QVariantMap selectionInfo() const;

    // ---- actions ----
    Q_INVOKABLE void toggleEnabled(int row);
    Q_INVOKABLE void setSelectedEnabled(bool enabled);
    /// Mods only: names of enabled mods that depend on the selection (for the delete/disable warning)
    Q_INVOKABLE QStringList dependentsOfSelection() const;
    Q_INVOKABLE void disableDependentsOfSelection();
    Q_INVOKABLE bool removeSelected();
    Q_INVOKABLE void installFiles(const QList<QUrl>& urls);
    Q_INVOKABLE void setSelectedUpdateLock(bool locked);
    Q_INVOKABLE void deleteSelectedMetadata();
    Q_INVOKABLE void viewSelectedHomepages();
    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void openConfigs();
    Q_INVOKABLE void refresh();
    /// Detailed info for the side panel. Returns {} for an invalid row.
    Q_INVOKABLE QVariantMap details(int row) const;
    Q_INVOKABLE int rowOf(const QString& internalId) const;

    // ---- export mod list (mods only) ----
    /// format: html | markdown | plaintext | json | csv; extras: authors, url, version, filename
    Q_INVOKABLE QString exportModList(const QString& format, bool authors, bool url, bool version, bool filename) const;
    Q_INVOKABLE QString exportModListCustom(const QString& lineTemplate) const;
    Q_INVOKABLE QString instanceName() const;

   signals:
    void sourceChanged();
    void filterTextChanged();
    void stateFilterChanged();
    void sortChanged();
    void countsChanged();
    void selectionChanged();
    void loadingChanged();
    void instanceRunningChanged();

   protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;
    bool lessThan(const QModelIndex& left, const QModelIndex& right) const override;

   private:
    void rebind();
    void unbind();
    Resource* resourceAt(int proxyRow) const;
    void emitSelectedChanged();
    QModelIndexList selectedSourceIndexes() const;
    QPixmap iconFor(const QString& internalId, const QSize& size) const;

    QString m_instanceId;
    QString m_kind = "mods";
    QString m_folderPath;
    bool m_complete = false;
    MinecraftInstance* m_instance = nullptr;
    QPointer<ResourceFolderModel> m_src;
    std::unique_ptr<ResourceFolderModel> m_ownedSrc;  // for folderdatapacks
    QString m_filterText;
    QString m_stateFilter = "all";
    QString m_sortKey = "name";
    bool m_sortDescending = false;
    QSet<QString> m_selected;
    QString m_anchorId;
    QString m_currentId;
    bool m_loading = false;
    QString m_iconNs;
    int m_iconRev = 0;
    QList<QMetaObject::Connection> m_conns;
};
