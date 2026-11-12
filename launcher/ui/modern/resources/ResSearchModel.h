#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QSet>

#include "modplatform/ModIndex.h"
#include "modplatform/ResourceAPI.h"
#include "tasks/Task.h"

class MinecraftInstance;
class ResourceFolderModel;
class ResTaskHandle;

/**
 * Search + selection model behind the modern resource download browser (classic ResourceDownloadDialog / ResourcePage /
 * ModModel). Talks to the platform APIs through ResourceAPI (ModrinthAPI / FlameAPI) and installs through
 * ResourceDownloadTask, with dependency resolution via GetModDependenciesTask.
 *
 *   ResSearchModel { instanceId: id; resourceType: "mod"; provider: "modrinth" }
 * resourceType: mod | resourcepack | texturepack | shaderpack | datapack
 */
class ResSearchModel : public QAbstractListModel, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY configChanged)
    Q_PROPERTY(QString resourceType READ resourceType WRITE setResourceType NOTIFY configChanged)
    /// optional: explicit target folder (data packs of a single world)
    Q_PROPERTY(QString targetFolder READ targetFolder WRITE setTargetFolder NOTIFY configChanged)
    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY providerChanged)  // modrinth | curseforge
    Q_PROPERTY(QStringList providers READ providers NOTIFY configChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(int sortIndex READ sortIndex WRITE setSortIndex NOTIFY sortIndexChanged)
    Q_PROPERTY(QVariantList sortOptions READ sortOptions NOTIFY providerChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY stateChanged)
    Q_PROPERTY(bool canFetchMoreResults READ canFetchMoreResults NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(int count READ count NOTIFY stateChanged)

    // ---- filters (mods) ----
    Q_PROPERTY(bool supportsFilters READ supportsFilters NOTIFY configChanged)
    Q_PROPERTY(QString instanceMcVersion READ instanceMcVersion NOTIFY configChanged)
    Q_PROPERTY(QStringList mcVersionOptions READ mcVersionOptions NOTIFY mcVersionOptionsChanged)
    Q_PROPERTY(bool showSnapshots READ showSnapshots WRITE setShowSnapshots NOTIFY mcVersionOptionsChanged)
    Q_PROPERTY(QStringList mcVersions READ mcVersions WRITE setMcVersions NOTIFY filterChanged)
    Q_PROPERTY(QVariantList loaderOptions READ loaderOptions CONSTANT)
    Q_PROPERTY(QStringList loaders READ loaders WRITE setLoaders NOTIFY filterChanged)
    Q_PROPERTY(QString side READ side WRITE setSide NOTIFY filterChanged)  // "" | client | server
    Q_PROPERTY(QStringList releaseTypes READ releaseTypes WRITE setReleaseTypes NOTIFY filterChanged)
    Q_PROPERTY(QVariantList categoryOptions READ categoryOptions NOTIFY categoryOptionsChanged)
    Q_PROPERTY(QStringList categories READ categories WRITE setCategories NOTIFY filterChanged)
    Q_PROPERTY(bool openSourceOnly READ openSourceOnly WRITE setOpenSourceOnly NOTIFY filterChanged)
    Q_PROPERTY(bool hideInstalled READ hideInstalled WRITE setHideInstalled NOTIFY filterChanged)
    Q_PROPERTY(int activeFilterCount READ activeFilterCount NOTIFY filterChanged)

    // ---- current project ----
    Q_PROPERTY(int currentRow READ currentRow WRITE setCurrentRow NOTIFY currentChanged)
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(QVariantList currentVersions READ currentVersions NOTIFY currentChanged)
    Q_PROPERTY(int currentVersionIndex READ currentVersionIndex WRITE setCurrentVersionIndex NOTIFY currentChanged)
    Q_PROPERTY(bool currentLoading READ currentLoading NOTIFY currentChanged)

    // ---- selection ----
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(QVariantList selectedItems READ selectedItems NOTIFY selectionChanged)

   public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        SummaryRole,
        AuthorsRole,
        LogoRole,
        InstalledRole,
        SelectedRole,
        ProjectIdRole,
        LoadingRole,
    };

    explicit ResSearchModel(QObject* parent = nullptr);
    ~ResSearchModel() override;

    void classBegin() override {}
    void componentComplete() override;

    int rowCount(const QModelIndex& parent = {}) const override { return parent.isValid() ? 0 : static_cast<int>(m_packs.size()); }
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& v);
    QString resourceType() const { return m_resourceType; }
    void setResourceType(const QString& v);
    QString targetFolder() const { return m_targetFolder; }
    void setTargetFolder(const QString& v);
    QString provider() const { return m_provider; }
    void setProvider(const QString& v);
    QStringList providers() const;
    QString searchText() const { return m_searchText; }
    void setSearchText(const QString& v);
    int sortIndex() const { return m_sortIndex; }
    void setSortIndex(int v);
    QVariantList sortOptions() const;
    bool searching() const { return m_searchJob && m_searchJob->isRunning(); }
    bool canFetchMoreResults() const { return m_canFetchMore; }
    QString error() const { return m_error; }
    int count() const { return static_cast<int>(m_packs.size()); }

    bool supportsFilters() const { return m_resourceType == "mod"; }
    QString instanceMcVersion() const;
    QStringList mcVersionOptions() const { return m_mcVersionOptions; }
    bool showSnapshots() const { return m_showSnapshots; }
    void setShowSnapshots(bool v);
    QStringList mcVersions() const { return m_mcVersions; }
    void setMcVersions(const QStringList& v);
    QVariantList loaderOptions() const;
    QStringList loaders() const { return m_loaders; }
    void setLoaders(const QStringList& v);
    QString side() const { return m_side; }
    void setSide(const QString& v);
    QStringList releaseTypes() const { return m_releaseTypes; }
    void setReleaseTypes(const QStringList& v);
    QVariantList categoryOptions() const { return m_categoryOptions; }
    QStringList categories() const { return m_categories; }
    void setCategories(const QStringList& v);
    bool openSourceOnly() const { return m_openSource; }
    void setOpenSourceOnly(bool v);
    bool hideInstalled() const { return m_hideInstalled; }
    void setHideInstalled(bool v);
    int activeFilterCount() const;

    int currentRow() const { return m_currentRow; }
    void setCurrentRow(int row);
    QVariantMap current() const;
    QVariantList currentVersions() const;
    int currentVersionIndex() const { return m_currentVersionIndex; }
    void setCurrentVersionIndex(int idx);
    bool currentLoading() const;

    int selectedCount() const { return static_cast<int>(m_selected.size()); }
    QVariantList selectedItems() const;

    /// Start a new search (debounce in QML).
    Q_INVOKABLE void search();
    Q_INVOKABLE void fetchMoreResults();
    Q_INVOKABLE void resetFilters();
    /// Select/deselect the project at `row` (picks the best matching version, loading versions first if needed)
    Q_INVOKABLE void toggleRow(int row);
    /// Select/deselect the current version of the current project
    Q_INVOKABLE void toggleCurrentVersion();
    Q_INVOKABLE bool isCurrentVersionSelected() const;
    Q_INVOKABLE void deselect(const QString& key);
    Q_INVOKABLE void clearSelection();
    /// Change-version mode: show exactly this project
    Q_INVOKABLE void openProject(const QString& provider, const QString& projectId);
    Q_INVOKABLE bool isSafeUrl(const QString& url) const;

    // ---- review & install ----
    /// Resolves dependencies (mods only, unless disabled). Emits reviewReady() when done (immediately if nothing to resolve).
    Q_INVOKABLE ResTaskHandle* prepareReview();
    /// rows of the review list: { key, name, fileName, provider, version, versionType, requiredBy, dependency, enabled }
    Q_INVOKABLE QVariantList reviewItems() const;
    Q_INVOKABLE void cancelReview();
    /// install everything selected except `excludedKeys`. Returns the running task.
    Q_INVOKABLE ResTaskHandle* install(const QStringList& excludedKeys);

   signals:
    void configChanged();
    void providerChanged();
    void searchTextChanged();
    void sortIndexChanged();
    void stateChanged();
    void filterChanged();
    void mcVersionOptionsChanged();
    void categoryOptionsChanged();
    void currentChanged();
    void selectionChanged();
    void reviewReady();
    /// non-fatal messages for toasts (kind: info | warning | error)
    void notice(const QString& message, const QString& kind);
    void installed();

   private:
    struct Selection {
        ModPlatform::IndexedPack::Ptr pack;
        ModPlatform::IndexedVersion version;
        QString reason = "standalone";
        QString dependentOn;
        bool dependency = false;
        bool maybeInstalled = false;
        QStringList requiredBy;
    };

    const ResourceAPI* api() const;
    ModPlatform::ResourceType platformType() const;
    ResourceFolderModel* baseModel() const;
    ResourceFolderModel* targetModelFor(ModPlatform::ResourceType type) const;
    void reconfigure();
    void loadMcVersions();
    void loadCategories();
    void resetDefaultsFromInstance();
    ResourceAPI::SearchArgs searchArgs() const;
    ResourceAPI::VersionSearchArgs versionArgs(const ModPlatform::IndexedPack::Ptr& pack) const;
    std::optional<ModPlatform::ModLoaderTypes> loaderFlags() const;
    std::optional<std::vector<Version>> versionFilter() const;
    bool checkPack(const ModPlatform::IndexedPack::Ptr& pack) const;
    bool checkVersion(const ModPlatform::IndexedVersion& v) const;
    bool isInstalled(const ModPlatform::IndexedPack::Ptr& pack) const;
    QVariant installedVersion(const ModPlatform::IndexedPack::Ptr& pack) const;
    void loadEntry(const ModPlatform::IndexedPack::Ptr& pack);
    void packUpdated(const ModPlatform::IndexedPack::Ptr& pack);
    int rowOfPack(const ModPlatform::IndexedPack* pack) const;
    static QString keyOf(const ModPlatform::IndexedPack& pack);
    int selectionIndex(const ModPlatform::IndexedPack& pack) const;
    void selectVersion(const ModPlatform::IndexedPack::Ptr& pack, const ModPlatform::IndexedVersion& v);
    int preferredVersionIndex(const ModPlatform::IndexedPack::Ptr& pack) const;
    void runJob(const Task::Ptr& job);
    void emitRowChanged(const ModPlatform::IndexedPack* pack);

    bool m_complete = false;
    QString m_instanceId;
    QString m_resourceType = "mod";
    QString m_targetFolder;
    QString m_provider = "modrinth";
    QPointer<MinecraftInstance> m_instance;
    std::unique_ptr<ResourceFolderModel> m_ownedTarget;

    QString m_searchText;
    int m_sortIndex = -1;
    QList<ModPlatform::IndexedPack::Ptr> m_packs;
    Task::Ptr m_searchJob;
    int m_searchGen = 0;
    int m_offset = 0;
    bool m_canFetchMore = false;
    QString m_error;
    QList<Task::Ptr> m_jobs;
    QSet<QString> m_loadingKeys;
    QSet<QString> m_toggleQueue;

    // filters
    QStringList m_mcVersionOptions;
    bool m_showSnapshots = false;
    QStringList m_mcVersions;
    QStringList m_loaders;
    QString m_side;
    QStringList m_releaseTypes;
    QVariantList m_categoryOptions;
    QStringList m_categories;
    bool m_openSource = false;
    bool m_hideInstalled = false;
    Task::Ptr m_categoriesJob;
    Task::Ptr m_mcVersionsJob;

    int m_currentRow = -1;
    int m_currentVersionIndex = -1;  // index into pack->versions

    QList<Selection> m_selected;
    QSet<QString> m_reviewDeps;  // keys of dependencies added by prepareReview()
};
