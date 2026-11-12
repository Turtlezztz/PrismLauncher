#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantList>
#include <memory>

#include "NIController.h"
#include "NIPackListModel.h"
#include "modplatform/ModIndex.h"
#include "modplatform/atlauncher/ATLPackIndex.h"
#include "modplatform/ftb/FTBPackManifest.h"
#include "modplatform/import_ftb/PackHelpers.h"
#include "modplatform/legacy_ftb/PackHelpers.h"
#include "tasks/Task.h"
#include "ui/pages/modplatform/technic/TechnicData.h"
#include "ui/widgets/ModFilterWidget.h"

class QSortFilterProxyModel;
class QAbstractListModel;
namespace Modrinth {
class ModpackListModel;
}
namespace Flame {
class ListModel;
}
namespace Technic {
class ListModel;
}
namespace Atl {
class ListModel;
class FilterModel;
}  // namespace Atl
namespace Ftb {
class ListModel;
class FilterModel;
}  // namespace Ftb
namespace LegacyFTB {
class ListModel;
class FilterModel;
class PackFetchTask;
class PrivatePackManager;
}  // namespace LegacyFTB
namespace FTBImportAPP {
class ListModel;
class FilterModel;
}  // namespace FTBImportAPP

/**
 * One modpack platform browser (the QML twin of FlamePage / ModrinthPage / AtlPage / FtbPage / LegacyFTB::Page /
 * ImportFTBPage / TechnicPage). Reuses the classic list models and install tasks; selecting a pack + version hands an
 * InstanceTask to the NIController.
 *
 *   platform: modrinth | curseforge | atlauncher | ftb | legacyftb | ftbapp | technic
 */
class NIPackBrowser : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString platform READ platform WRITE setPlatform NOTIFY platformChanged)
    Q_PROPERTY(NIController* controller READ controller WRITE setController NOTIFY controllerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(NIPackListModel* model READ model CONSTANT)
    Q_PROPERTY(QString searchTerm READ searchTerm WRITE setSearchTerm NOTIFY searchTermChanged)
    Q_PROPERTY(QStringList sortOptions READ sortOptions NOTIFY platformChanged)
    Q_PROPERTY(int sortIndex READ sortIndex WRITE setSortIndex NOTIFY sortIndexChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool canLoadMore READ canLoadMore NOTIFY loadingChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY loadingChanged)
    Q_PROPERTY(bool remoteSearch READ remoteSearch NOTIFY platformChanged)

    // selection / details
    Q_PROPERTY(int selectedRow READ selectedRow NOTIFY selectionChanged)
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(QVariantList versions READ versions NOTIFY versionsChanged)
    Q_PROPERTY(bool versionsLoading READ versionsLoading NOTIFY versionsChanged)
    Q_PROPERTY(int versionIndex READ versionIndex NOTIFY versionsChanged)

    // filters (modrinth / curseforge)
    Q_PROPERTY(bool supportsFilters READ supportsFilters NOTIFY platformChanged)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY categoriesChanged)
    Q_PROPERTY(int activeFilterCount READ activeFilterCount NOTIFY filterChanged)

    // legacy FTB: public | thirdParty | private
    Q_PROPERTY(QString legacyTab READ legacyTab WRITE setLegacyTab NOTIFY legacyTabChanged)
    // FTB app import: instances folder
    Q_PROPERTY(QString ftbAppPath READ ftbAppPath NOTIFY ftbAppPathChanged)

   public:
    explicit NIPackBrowser(QObject* parent = nullptr);
    ~NIPackBrowser() override;

    QString platform() const { return m_platform; }
    void setPlatform(const QString& p);
    NIController* controller() const { return m_controller; }
    void setController(NIController* c);
    bool active() const { return m_active; }
    void setActive(bool a);
    NIPackListModel* model() const { return m_model; }
    QString searchTerm() const { return m_searchTerm; }
    void setSearchTerm(const QString& term);
    QStringList sortOptions() const { return m_sortOptions; }
    int sortIndex() const { return m_sortIndex; }
    void setSortIndex(int i);
    bool loading() const;
    bool canLoadMore() const;
    QString errorText() const { return m_errorText; }
    bool remoteSearch() const { return m_platform == "modrinth" || m_platform == "curseforge" || m_platform == "technic"; }

    int selectedRow() const { return m_selectedRow; }
    QVariantMap current() const { return m_currentInfo; }
    QVariantList versions() const { return m_versions; }
    bool versionsLoading() const { return m_versionsLoading; }
    int versionIndex() const { return m_versionIndex; }

    bool supportsFilters() const { return m_platform == "modrinth" || m_platform == "curseforge"; }
    QVariantList categories() const { return m_categories; }
    int activeFilterCount() const;

    QString legacyTab() const { return m_legacyTab; }
    void setLegacyTab(const QString& tab);
    QString ftbAppPath() const;

    Q_INVOKABLE void search();
    Q_INVOKABLE void fetchMore();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void select(int row);
    Q_INVOKABLE void selectVersion(int index);
    /// { mcVersions: [..], loaders: ["fabric",..], categories: [ids], openSource: bool, releaseTypes: ["release",..], excludeDisclosures: [..] }
    Q_INVOKABLE void setFilter(const QVariantMap& filter);
    Q_INVOKABLE QVariantMap filter() const { return m_filterMap; }
    Q_INVOKABLE void openUrl(const QString& url);

    // legacy FTB private packs
    Q_INVOKABLE void addPrivatePack(const QString& code);
    Q_INVOKABLE void removePrivatePack(int row);
    Q_INVOKABLE void forgetPrivatePackCode(const QString& code);
    // FTB app
    Q_INVOKABLE void setFtbAppPath(const QUrl& dir);

   signals:
    void platformChanged();
    void controllerChanged();
    void activeChanged();
    void searchTermChanged();
    void sortIndexChanged();
    void loadingChanged();
    void selectionChanged();
    void currentChanged();
    void versionsChanged();
    void categoriesChanged();
    void filterChanged();
    void legacyTabChanged();
    void ftbAppPathChanged();
    void error(const QString& message);
    /// legacy FTB: fetching a private pack code failed — ask whether to forget it
    void privatePackFailed(const QString& code);

   private:
    void init();
    void watchJob(const Task::Ptr& job);
    void clearSelection();
    void suggestCurrent();
    void setVersions(const QVariantList& list, int index = 0);
    // per platform
    void selectIndexed(int row);
    void updateIndexedInfo();
    void suggestIndexed();
    void selectTechnic(int row);
    void technicMetadataLoaded();
    void technicSolderLoaded(QByteArray* response);
    void selectAtl(int row);
    void selectFtb(int row);
    void selectLegacy(int row);
    void selectFtbApp(int row);
    void suggestFtbAppIcon();
    QAbstractItemModel* currentLegacyModel() const;
    QSortFilterProxyModel* currentLegacyFilter() const;
    void applyLocalSearch();

    QString m_platform;
    QPointer<NIController> m_controller;
    bool m_active = false;
    bool m_initialized = false;
    NIPackListModel* m_model;
    QString m_searchTerm = QStringLiteral("");  // non-null: the classic models compare isNull() too
    QStringList m_sortOptions;
    int m_sortIndex = 0;
    QTimer m_searchTimer;
    Task::Ptr m_watchedJob;
    bool m_listLoading = false;
    QString m_errorText;

    int m_selectedRow = -1;
    QVariantMap m_currentInfo;
    QVariantList m_versions;
    bool m_versionsLoading = false;
    int m_versionIndex = -1;
    Task::Ptr m_detailsJob;
    Task::Ptr m_versionsJob;

    // filters
    std::shared_ptr<ModFilterWidget::Filter> m_filter;
    bool m_filterChanged = false;
    QVariantMap m_filterMap;
    QVariantList m_categories;
    Task::Ptr m_categoriesTask;

    // models
    Modrinth::ModpackListModel* m_modrinth = nullptr;
    Flame::ListModel* m_flame = nullptr;
    ModPlatform::IndexedPack::Ptr m_indexed;

    Technic::ListModel* m_technic = nullptr;
    Technic::Modpack m_technicPack;

    Atl::ListModel* m_atl = nullptr;
    Atl::FilterModel* m_atlFilter = nullptr;
    ATLauncher::IndexedPack m_atlPack;

    Ftb::ListModel* m_ftb = nullptr;
    Ftb::FilterModel* m_ftbFilter = nullptr;
    FTB::Modpack m_ftbPack;

    QString m_legacyTab = "public";
    LegacyFTB::ListModel* m_legacyLists[3] = { nullptr, nullptr, nullptr };
    LegacyFTB::FilterModel* m_legacyFilters[3] = { nullptr, nullptr, nullptr };
    LegacyFTB::PackFetchTask* m_legacyFetch = nullptr;
    std::unique_ptr<LegacyFTB::PrivatePackManager> m_legacyPrivate;
    LegacyFTB::Modpack m_legacyPack;

    FTBImportAPP::ListModel* m_ftbApp = nullptr;
    FTBImportAPP::FilterModel* m_ftbAppFilter = nullptr;
    FTBImportAPP::Modpack m_ftbAppPack;
};
