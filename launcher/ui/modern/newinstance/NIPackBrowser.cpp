#include "NIPackBrowser.h"

#include <QRegularExpression>

#include "Application.h"
#include "DesktopServices.h"
#include "InstanceImportTask.h"
#include "Markdown.h"
#include "StringUtils.h"
#include "Version.h"
#include "modplatform/flame/FlameAPI.h"
#include "modplatform/modrinth/ModrinthAPI.h"
#include "ui/pages/modplatform/atlauncher/AtlFilterModel.h"
#include "ui/pages/modplatform/atlauncher/AtlListModel.h"
#include "ui/pages/modplatform/flame/FlameModel.h"
#include "ui/pages/modplatform/ftb/FtbFilterModel.h"
#include "ui/pages/modplatform/ftb/FtbListModel.h"
#include "ui/pages/modplatform/import_ftb/ListModel.h"
#include "ui/pages/modplatform/legacy_ftb/ListModel.h"
#include "ui/pages/modplatform/modrinth/ModrinthModel.h"
#include "ui/pages/modplatform/technic/TechnicModel.h"
#include "modplatform/legacy_ftb/PackFetchTask.h"
#include "modplatform/legacy_ftb/PrivatePackManager.h"
#include "BuildConfig.h"
#include "NIInteraction.h"
#include "modplatform/atlauncher/ATLPackInstallTask.h"
#include "modplatform/ftb/FTBPackInstallTask.h"
#include "modplatform/import_ftb/PackInstallTask.h"
#include "modplatform/legacy_ftb/PackInstallTask.h"
#include "modplatform/technic/SingleZipPackInstallTask.h"
#include "modplatform/technic/SolderPackInstallTask.h"

NIPackBrowser::NIPackBrowser(QObject* parent) : QObject(parent), m_model(new NIPackListModel(this)), m_filter(new ModFilterWidget::Filter())
{
    m_filter->openSource = false;
    m_filter->hideInstalled = false;
    m_filter->side = ModPlatform::SideType::NoSide;
    m_searchTimer.setSingleShot(true);
    m_searchTimer.setInterval(350);
    connect(&m_searchTimer, &QTimer::timeout, this, &NIPackBrowser::search);
    // the selected pack's logo may arrive after it was selected
    connect(m_model, &QAbstractItemModel::dataChanged, this, [this] {
        if (m_selectedRow < 0 || m_selectedRow >= m_model->rowCount() || m_currentInfo.isEmpty()) {
            return;
        }
        const auto logo = m_model->data(m_model->index(m_selectedRow, 0), NIPackListModel::LogoRole);
        if (logo != m_currentInfo.value("logo")) {
            m_currentInfo["logo"] = logo;
            emit currentChanged();
        }
    });
}

NIPackBrowser::~NIPackBrowser() = default;

void NIPackBrowser::setPlatform(const QString& p)
{
    if (p == m_platform || !m_platform.isEmpty()) {
        return;  // set once
    }
    m_platform = p;
    if (p == "modrinth") {
        m_sortOptions = { tr("Relevance"), tr("Total downloads"), tr("Follows"), tr("Newest"), tr("Last updated") };
    } else if (p == "curseforge") {
        m_sortOptions = { tr("Featured"), tr("Popularity"), tr("Last updated"), tr("Name"), tr("Author"), tr("Total downloads") };
    }
    init();
    emit platformChanged();
}

void NIPackBrowser::setController(NIController* c)
{
    m_controller = c;
    emit controllerChanged();
}

void NIPackBrowser::setActive(bool a)
{
    if (a == m_active) {
        return;
    }
    m_active = a;
    emit activeChanged();
    if (!a) {
        if (m_platform == "ftb" && m_ftb->isMakingRequest()) {
            m_ftb->abortRequest();
        }
        return;
    }
    if (!m_initialized || (m_platform == "ftb" && m_ftb->wasAborted())) {
        m_initialized = true;
        if (m_platform == "modrinth" || m_platform == "curseforge" || m_platform == "technic") {
            m_filterChanged = true;  // the classic models skip a "same as before" query, force the first one
            search();
        } else if (m_platform == "atlauncher") {
            m_atl->request();
        } else if (m_platform == "ftb") {
            m_ftb->request();
        } else if (m_platform == "legacyftb") {
            m_legacyFetch->fetch();
            m_legacyPrivate->load();
            m_legacyFetch->fetchPrivate(m_legacyPrivate->getCurrentPackCodes().values());
            m_listLoading = true;
            emit loadingChanged();
        } else if (m_platform == "ftbapp") {
            m_ftbApp->update();
        }
    }
    suggestCurrent();
}

// --------------------------------------------------------------------------- init

void NIPackBrowser::init()
{
    auto sortKeys = [this](auto* filterModel) {
        m_sortOptions = filterModel->getAvailableSortings().keys();
        m_sortIndex = static_cast<int>(m_sortOptions.indexOf(filterModel->translateCurrentSorting()));
    };

    if (m_platform == "modrinth" || m_platform == "curseforge") {
        if (m_platform == "modrinth") {
            m_modrinth = new Modrinth::ModpackListModel(this);
            m_model->setSource(m_modrinth);
            auto [task, response] = ModrinthAPI::get().getModCategories();
            m_categoriesTask = task;
            connect(task.get(), &Task::succeeded, this, [this, response] {
                m_categories.clear();
                for (const auto& c : ModrinthAPI::loadCategories(*response, "modpack")) {
                    m_categories << QVariantMap{ { "id", c.id }, { "name", c.name } };
                }
                emit categoriesChanged();
            });
            task->start();
        } else {
            m_flame = new Flame::ListModel(this);
            m_model->setSource(m_flame);
            auto [task, response] = FlameAPI::getCategories(ModPlatform::ResourceType::Modpack);
            m_categoriesTask = task;
            connect(task.get(), &Task::succeeded, this, [this, response] {
                m_categories.clear();
                for (const auto& c : FlameAPI::get().loadModCategories(*response)) {
                    m_categories << QVariantMap{ { "id", c.id }, { "name", c.name } };
                }
                emit categoriesChanged();
            });
            task->start();
        }
        m_model->setExtra([](const QModelIndex& src, int role) -> QVariant {
            if (role != NIPackListModel::SubtitleRole) {
                return {};
            }
            auto pack = src.data(Qt::UserRole).value<ModPlatform::IndexedPack::Ptr>();
            if (!pack || pack->authors.isEmpty()) {
                return QString();
            }
            QStringList names;
            for (const auto& a : pack->authors) {
                names << a.name;
            }
            return tr("by %1").arg(names.join(", "));
        });
    } else if (m_platform == "technic") {
        m_technic = new Technic::ListModel(this);
        m_model->setSource(m_technic);
    } else if (m_platform == "atlauncher") {
        m_atl = new Atl::ListModel(this);
        m_atlFilter = new Atl::FilterModel(this);
        m_atlFilter->setSourceModel(m_atl);
        m_atlFilter->sort(0);
        m_model->setSource(m_atlFilter);
        sortKeys(m_atlFilter);
        m_model->setExtra([](const QModelIndex& src, int role) -> QVariant {
            if (role != NIPackListModel::SubtitleRole) {
                return {};
            }
            auto pack = src.data(Qt::UserRole).value<ATLauncher::IndexedPack>();
            return pack.versions.isEmpty() ? QString() : tr("Minecraft %1").arg(pack.versions.first().minecraft);
        });
        connect(m_atl, &QAbstractItemModel::modelReset, this, [this] {
            m_listLoading = false;
            emit loadingChanged();
        });
        connect(m_atl, &QAbstractItemModel::rowsInserted, this, [this] {
            m_listLoading = false;
            emit loadingChanged();
        });
        m_listLoading = true;
    } else if (m_platform == "ftb") {
        m_ftb = new Ftb::ListModel(this);
        m_ftbFilter = new Ftb::FilterModel(this);
        m_ftbFilter->setSourceModel(m_ftb);
        m_ftbFilter->sort(0);
        m_model->setSource(m_ftbFilter);
        sortKeys(m_ftbFilter);
        m_model->setExtra([](const QModelIndex& src, int role) -> QVariant {
            auto pack = src.data(Qt::UserRole).value<FTB::Modpack>();
            if (role == NIPackListModel::SummaryRole) {
                return pack.synopsis;
            }
            if (role == NIPackListModel::SubtitleRole) {
                QStringList names;
                for (const auto& a : pack.authors) {
                    names << a.name;
                }
                return names.isEmpty() ? QString() : tr("by %1").arg(names.join(", "));
            }
            return {};
        });
        connect(m_ftb, &QAbstractItemModel::rowsInserted, this, [this] {
            m_listLoading = false;
            emit loadingChanged();
        });
        m_listLoading = true;
    } else if (m_platform == "legacyftb") {
        m_legacyFetch = new LegacyFTB::PackFetchTask(APPLICATION->network());
        m_legacyFetch->setParent(this);
        m_legacyPrivate = std::make_unique<LegacyFTB::PrivatePackManager>();
        for (int i = 0; i < 3; i++) {
            m_legacyLists[i] = new LegacyFTB::ListModel(this);
            m_legacyFilters[i] = new LegacyFTB::FilterModel(this);
            m_legacyFilters[i]->setSourceModel(m_legacyLists[i]);
            m_legacyFilters[i]->sort(0);
        }
        m_model->setSource(m_legacyFilters[0]);
        sortKeys(m_legacyFilters[0]);
        m_model->setExtra([](const QModelIndex& src, int role) -> QVariant {
            if (role != NIPackListModel::SubtitleRole) {
                return {};
            }
            auto pack = src.data(Qt::UserRole).value<LegacyFTB::Modpack>();
            return tr("Minecraft %1 · by %2").arg(pack.mcVersion, pack.author);
        });
        connect(m_legacyFetch, &LegacyFTB::PackFetchTask::finished, this,
                [this](const LegacyFTB::ModpackList& publicPacks, const LegacyFTB::ModpackList& thirdParty) {
                    m_legacyLists[0]->fill(publicPacks);
                    m_legacyLists[1]->fill(thirdParty);
                    m_listLoading = false;
                    emit loadingChanged();
                });
        connect(m_legacyFetch, &LegacyFTB::PackFetchTask::failed, this, [this](const QString& reason) {
            m_listLoading = false;
            m_errorText = reason;
            emit loadingChanged();
            emit error(reason);
        });
        connect(m_legacyFetch, &LegacyFTB::PackFetchTask::privateFileDownloadFinished, this,
                [this](const LegacyFTB::Modpack& pack) { m_legacyLists[2]->addPack(pack); });
        connect(m_legacyFetch, &LegacyFTB::PackFetchTask::privateFileDownloadFailed, this,
                [this](const QString&, const QString& code) { emit privatePackFailed(code); });
    } else if (m_platform == "ftbapp") {
        m_ftbApp = new FTBImportAPP::ListModel(this);
        m_ftbAppFilter = new FTBImportAPP::FilterModel(this);
        m_ftbAppFilter->setSourceModel(m_ftbApp);
        m_ftbAppFilter->sort(0);
        m_model->setSource(m_ftbAppFilter);
        sortKeys(m_ftbAppFilter);
        m_model->setExtra([](const QModelIndex& src, int role) -> QVariant {
            auto pack = src.data(Qt::UserRole).value<FTBImportAPP::Modpack>();
            if (role == NIPackListModel::SummaryRole) {
                return tr("Version %1").arg(pack.version);
            }
            if (role == NIPackListModel::SubtitleRole) {
                return tr("Minecraft %1").arg(pack.mcVersion);
            }
            return {};
        });
    }
}

// --------------------------------------------------------------------------- search

void NIPackBrowser::setSearchTerm(const QString& term)
{
    if (term == m_searchTerm) {
        return;
    }
    m_searchTerm = term;
    emit searchTermChanged();
    if (remoteSearch()) {
        m_searchTimer.start();
    } else {
        applyLocalSearch();
    }
}

void NIPackBrowser::setSortIndex(int i)
{
    if (i == m_sortIndex || i < 0 || i >= m_sortOptions.size()) {
        return;
    }
    m_sortIndex = i;
    emit sortIndexChanged();
    const auto key = m_sortOptions.at(i);
    if (m_atlFilter) {
        m_atlFilter->setSorting(m_atlFilter->getAvailableSortings().value(key));
    } else if (m_ftbFilter) {
        m_ftbFilter->setSorting(m_ftbFilter->getAvailableSortings().value(key));
    } else if (m_ftbAppFilter) {
        m_ftbAppFilter->setSorting(m_ftbAppFilter->getAvailableSortings().value(key));
    } else if (m_legacyFilters[0]) {
        auto s = m_legacyFilters[0]->getAvailableSortings().value(key);
        for (auto* f : m_legacyFilters) {
            f->setSorting(s);
        }
    } else {
        search();
    }
}

void NIPackBrowser::applyLocalSearch()
{
    if (m_atlFilter) {
        m_atlFilter->setSearchTerm(m_searchTerm);
    } else if (m_ftbFilter) {
        m_ftbFilter->setSearchTerm(m_searchTerm);
    } else if (m_ftbAppFilter) {
        m_ftbAppFilter->setSearchTerm(m_searchTerm);
    } else if (auto* f = currentLegacyFilter()) {
        static_cast<LegacyFTB::FilterModel*>(f)->setSearchTerm(m_searchTerm);
    }
}

void NIPackBrowser::watchJob(const Task::Ptr& job)
{
    if (m_watchedJob) {
        disconnect(m_watchedJob.get(), nullptr, this, nullptr);
    }
    m_watchedJob = job;
    m_errorText.clear();
    if (job) {
        connect(job.get(), &Task::finished, this, [this] {
            m_watchedJob.reset();
            emit loadingChanged();
        });
        connect(job.get(), &Task::failed, this, [this](const QString& reason) { m_errorText = reason; });
    }
    emit loadingChanged();
}

void NIPackBrowser::search()
{
    m_searchTimer.stop();
    if (!m_initialized) {
        return;
    }
    if (m_modrinth || m_flame) {
        // the classic models abort + restart in a way that drops "#id" lookups; wait for the running query instead
        auto running = m_modrinth ? m_modrinth->activeSearchJob() : m_flame->activeSearchJob();
        if (running) {
            if (!m_searchQueued) {
                m_searchQueued = true;
                connect(
                    running.get(), &Task::finished, this,
                    [this] {
                        m_searchQueued = false;
                        search();
                    },
                    Qt::QueuedConnection);
            }
            return;
        }
        clearSelection();
        const bool changed = m_filterChanged;
        m_filterChanged = false;
        if (m_modrinth) {
            m_modrinth->searchWithTerm(m_searchTerm, m_sortIndex, m_filter, changed);
            watchJob(m_modrinth->activeSearchJob());
            if (m_searchTerm.startsWith('#') && !m_searchTerm.mid(1).trimmed().isEmpty()) {
                // "#<id>" opens one project directly: select it when it arrives
                const auto term = m_searchTerm;
                auto selectOne = [this, term] {
                    if (m_searchTerm == term && m_model->rowCount() == 1) {
                        select(0);
                    }
                };
                if (auto job = m_modrinth->activeSearchJob()) {
                    connect(job.get(), &Task::finished, this, selectOne, Qt::QueuedConnection);
                } else {
                    selectOne();
                }
            }
        } else {
            m_flame->searchWithTerm(m_searchTerm, m_sortIndex, m_filter, changed);
            watchJob(m_flame->activeSearchJob());
        }
    } else if (m_technic) {
        clearSelection();
        m_technic->searchWithTerm(m_searchTerm);
        watchJob(m_technic->activeSearchJob());
    } else {
        applyLocalSearch();
    }
}

void NIPackBrowser::refresh()
{
    if (m_atl) {
        m_listLoading = true;
        emit loadingChanged();
        m_atl->request();
    } else if (m_ftb) {
        m_listLoading = true;
        emit loadingChanged();
        m_ftb->request();
    } else if (m_ftbApp) {
        m_ftbApp->update();
    } else if (m_legacyFetch) {
        m_listLoading = true;
        emit loadingChanged();
        m_legacyFetch->fetch();
    } else {
        m_filterChanged = true;  // force the classic models to re-run the same query
        search();
    }
}

bool NIPackBrowser::loading() const
{
    return (m_watchedJob && m_watchedJob->isRunning()) || m_listLoading;
}

bool NIPackBrowser::canLoadMore() const
{
    auto* src = m_modrinth ? static_cast<QAbstractItemModel*>(m_modrinth) : static_cast<QAbstractItemModel*>(m_flame);
    return src && !loading() && src->canFetchMore({});
}

void NIPackBrowser::fetchMore()
{
    auto* src = m_modrinth ? static_cast<QAbstractItemModel*>(m_modrinth) : static_cast<QAbstractItemModel*>(m_flame);
    if (!src || loading() || !src->canFetchMore({})) {
        return;
    }
    src->fetchMore({});
    watchJob(m_modrinth ? m_modrinth->activeSearchJob() : m_flame->activeSearchJob());
}

// --------------------------------------------------------------------------- filters

int NIPackBrowser::activeFilterCount() const
{
    int n = 0;
    for (const auto& key : { "mcVersions", "loaders", "categories", "releaseTypes", "excludeDisclosures" }) {
        if (!m_filterMap.value(key).toList().isEmpty()) {
            n++;
        }
    }
    if (m_filterMap.value("openSource").toBool()) {
        n++;
    }
    return n;
}

void NIPackBrowser::setFilter(const QVariantMap& f)
{
    auto filter = std::make_shared<ModFilterWidget::Filter>();
    filter->hideInstalled = false;
    filter->side = ModPlatform::SideType::NoSide;
    for (const auto& v : f.value("mcVersions").toStringList()) {
        filter->versions.emplace_back(v);
    }
    ModPlatform::ModLoaderTypes loaders;
    for (const auto& l : f.value("loaders").toStringList()) {
        if (l == "neoforge") {
            loaders |= ModPlatform::NeoForge;
        } else if (l == "forge") {
            loaders |= ModPlatform::Forge;
        } else if (l == "fabric") {
            loaders |= ModPlatform::Fabric;
        } else if (l == "quilt") {
            loaders |= ModPlatform::Quilt;
        } else if (l == "liteloader") {
            loaders |= ModPlatform::LiteLoader;
        } else if (l == "cauldron") {
            loaders |= ModPlatform::Cauldron;
        } else if (l == "babric") {
            loaders |= ModPlatform::Babric;
        } else if (l == "bta") {
            loaders |= ModPlatform::BTA;
        } else if (l == "legacyfabric") {
            loaders |= ModPlatform::LegacyFabric;
        } else if (l == "ornithe") {
            loaders |= ModPlatform::Ornithe;
        } else if (l == "rift") {
            loaders |= ModPlatform::Rift;
        }
    }
    filter->loaders = loaders;
    filter->categoryIds = f.value("categories").toStringList();
    filter->openSource = f.value("openSource").toBool();
    filter->releases = ModPlatform::IndexedVersionType::fromStringList(f.value("releaseTypes").toStringList());
    for (const auto& d : f.value("excludeDisclosures").toStringList()) {
        auto t = ModPlatform::DisclosureType::fromString(d);
        if (t.isValid()) {
            filter->excludeDisclosureTypes.push_back(t);
        }
    }
    m_filterChanged = *filter != *m_filter;
    m_filter = filter;
    m_filterMap = f;
    emit filterChanged();
    if (m_filterChanged) {
        search();
    }
}

// --------------------------------------------------------------------------- selection

void NIPackBrowser::clearSelection()
{
    m_selectedRow = -1;
    m_currentInfo.clear();
    m_indexed.reset();
    m_versions.clear();
    m_versionIndex = -1;
    m_versionsLoading = false;
    emit selectionChanged();
    emit currentChanged();
    emit versionsChanged();
    if (m_active && m_controller) {
        m_controller->setSuggestedPack();
    }
}

void NIPackBrowser::setVersions(const QVariantList& list, int index)
{
    m_versions = list;
    m_versionIndex = list.isEmpty() ? -1 : qBound(0, index, static_cast<int>(list.size()) - 1);
    if (m_versionIndex >= 0 && m_versions.at(m_versionIndex).toMap().value("disabled").toBool()) {
        m_versionIndex = -1;
    }
    emit versionsChanged();
    suggestCurrent();
}

void NIPackBrowser::select(int row)
{
    if (row < 0 || row >= m_model->rowCount()) {
        clearSelection();
        return;
    }
    m_selectedRow = row;
    emit selectionChanged();
    if (m_modrinth || m_flame) {
        selectIndexed(row);
    } else if (m_technic) {
        selectTechnic(row);
    } else if (m_atl) {
        selectAtl(row);
    } else if (m_ftb) {
        selectFtb(row);
    } else if (m_legacyFetch) {
        selectLegacy(row);
    } else if (m_ftbApp) {
        selectFtbApp(row);
    }
}

void NIPackBrowser::selectVersion(int index)
{
    if (index < 0 || index >= m_versions.size() || m_versions.at(index).toMap().value("disabled").toBool()) {
        return;
    }
    m_versionIndex = index;
    emit versionsChanged();
    suggestCurrent();
}

void NIPackBrowser::openUrl(const QString& url)
{
    DesktopServices::openUrl(QUrl(url));
}

void NIPackBrowser::suggestCurrent()
{
    if (!m_active || !m_controller) {
        return;
    }
    if (m_selectedRow < 0 || m_versionIndex < 0) {
        m_controller->setSuggestedPack();
        return;
    }
    const auto version = m_versions.at(m_versionIndex).toMap();
    const auto versionName = version.value("name").toString();
    QPointer<NIController> ctl = m_controller;
    auto iconCb = [ctl](const QString& prefix) {
        return [ctl, prefix](const QString& path) {
            if (ctl) {
                ctl->setSuggestedIconFromFile(path, prefix);
            }
        };
    };

    if (m_indexed) {
        suggestIndexed();
    } else if (m_technic) {
        if (m_technicPack.broken) {
            m_controller->setSuggestedPack();
            return;
        }
        if (!m_technicPack.isSolder) {
            m_controller->setSuggestedPack(m_technicPack.name, versionName,
                                           new Technic::SingleZipPackInstallTask(m_technicPack.url, m_technicPack.minecraftVersion));
        } else {
            m_controller->setSuggestedPack(m_technicPack.name, versionName,
                                           new Technic::SolderPackInstallTask(APPLICATION->network(), m_technicPack.url, m_technicPack.slug,
                                                                              versionName, m_technicPack.minecraftVersion));
        }
        m_technic->getLogo(m_technicPack.logoName, m_technicPack.logoUrl, iconCb("technic_" + m_technicPack.logoName));
    } else if (m_atl) {
        m_controller->setSuggestedPack(m_atlPack.name, versionName,
                                       new ATLauncher::PackInstallTask(NIInteraction::makeAtlSupport(), m_atlPack.name, versionName));
        auto url = QString(BuildConfig.ATL_DOWNLOAD_SERVER_URL + "launcher/images/%1").arg(m_atlPack.safeName);
        m_atl->getLogo(m_atlPack.safeName, url, iconCb("atl_" + m_atlPack.safeName));
    } else if (m_ftb) {
        m_controller->setSuggestedPack(m_ftbPack.name, versionName, new FTB::PackInstallTask(m_ftbPack, versionName, nullptr));
        for (const auto& art : m_ftbPack.art) {
            if (art.type == "square") {
                m_ftb->getLogo(m_ftbPack.safeName, art.url, iconCb("ftb_" + m_ftbPack.safeName));
            }
        }
    } else if (m_legacyFetch) {
        if (m_legacyPack.broken) {
            m_controller->setSuggestedPack();
            return;
        }
        m_controller->setSuggestedPack(m_legacyPack.name, versionName,
                                       new LegacyFTB::PackInstallTask(APPLICATION->network(), m_legacyPack, versionName));
        QString logoName = m_legacyPack.logo;
        if (!logoName.toLower().startsWith("ftb")) {
            logoName = "ftb_" + logoName;
        }
        const int idx = m_legacyPack.type == LegacyFTB::PackType::ThirdParty ? 1 : m_legacyPack.type == LegacyFTB::PackType::Private ? 2 : 0;
        m_legacyLists[idx]->getLogo(m_legacyPack.logo, iconCb(logoName));
    } else if (m_ftbApp) {
        m_controller->setSuggestedPack(m_ftbAppPack.name, {}, new FTBImportAPP::PackInstallTask(m_ftbAppPack));
        suggestFtbAppIcon();
    }
}
