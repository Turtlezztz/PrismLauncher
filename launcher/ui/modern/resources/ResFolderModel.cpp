#include "ResFolderModel.h"

#include <QHash>
#include <QLocale>
#include <QRegularExpression>
#include <QTextDocumentFragment>
#include <algorithm>

#include "Application.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "ResImages.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/mod/DataPack.h"
#include "minecraft/mod/DataPackFolderModel.h"
#include "minecraft/mod/Mod.h"
#include "minecraft/mod/ModFolderModel.h"
#include "minecraft/mod/ResourceFolderModel.h"
#include "minecraft/mod/ResourcePackFolderModel.h"
#include "minecraft/mod/ShaderPack.h"
#include "minecraft/mod/ShaderPackFolderModel.h"
#include "minecraft/mod/TexturePack.h"
#include "minecraft/mod/TexturePackFolderModel.h"
#include "modplatform/helpers/ExportToModList.h"
#include "settings/SettingsObject.h"
#include "ui/widgets/InfoFrame.h"

namespace {
// Several QML views may look at the same (shared, per-instance) folder model. Only stop watching when the last one goes away.
QHash<ResourceFolderModel*, int>& watchCounts()
{
    static QHash<ResourceFolderModel*, int> c;
    return c;
}
void retainWatch(ResourceFolderModel* m)
{
    if (watchCounts()[m]++ == 0) {
        m->startWatching();
    }
    m->update();
}
void releaseWatch(ResourceFolderModel* m)
{
    auto it = watchCounts().find(m);
    if (it == watchCounts().end()) {
        return;
    }
    if (--it.value() <= 0) {
        watchCounts().erase(it);
        m->stopWatching();
    }
}

SortType sortTypeFor(const QString& key)
{
    static const QHash<QString, SortType> map = {
        { "name", SortType::Name },         { "date", SortType::Date },         { "version", SortType::Version },
        { "enabled", SortType::Enabled },   { "packformat", SortType::PackFormat }, { "provider", SortType::Provider },
        { "size", SortType::Size },         { "side", SortType::Side },         { "mcversions", SortType::McVersions },
        { "loaders", SortType::Loaders },   { "releasetype", SortType::ReleaseType }, { "requires", SortType::Requires },
        { "requiredby", SortType::RequiredBy }, { "filename", SortType::Filename },
    };
    return map.value(key, SortType::Name);
}

QString plain(const QString& s)
{
    if (!s.contains('<') && !s.contains(u'§')) {
        return s;
    }
    QString t = s;
    t.remove(QRegularExpression("§."));
    return QTextDocumentFragment::fromHtml(t).toPlainText();
}
}  // namespace

ResFolderModel::ResFolderModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    m_iconNs = ResImages::newNamespace("folder");
    ResImages::registerSource(m_iconNs, [this](const QString& id, const QSize& size) { return iconFor(id, size); });
}

ResFolderModel::~ResFolderModel()
{
    ResImages::unregisterSource(m_iconNs);
    unbind();
}

void ResFolderModel::componentComplete()
{
    m_complete = true;
    ResImages::ensure(qmlEngine(this));
    rebind();
}

void ResFolderModel::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    m_instanceId = id;
    rebind();
}

void ResFolderModel::setKind(const QString& k)
{
    if (k == m_kind) {
        return;
    }
    m_kind = k;
    rebind();
}

void ResFolderModel::setFolderPath(const QString& p)
{
    if (p == m_folderPath) {
        return;
    }
    m_folderPath = p;
    rebind();
}

void ResFolderModel::unbind()
{
    for (auto& c : m_conns) {
        disconnect(c);
    }
    m_conns.clear();
    if (m_src) {
        releaseWatch(m_src);
    }
    setSourceModel(nullptr);
    m_src = nullptr;
    m_ownedSrc.reset();
    m_instance = nullptr;
}

void ResFolderModel::rebind()
{
    if (!m_complete) {
        return;
    }
    unbind();
    m_selected.clear();
    m_anchorId.clear();
    m_currentId.clear();

    auto inst = APPLICATION->instances()->getInstanceById(m_instanceId);
    m_instance = inst;
    if (m_instance) {
        ResourceFolderModel* src = nullptr;
        if (m_kind == "mods") {
            src = m_instance->loaderModList();
        } else if (m_kind == "coremods") {
            src = m_instance->coreModList();
        } else if (m_kind == "nilmods") {
            src = m_instance->nilModList();
        } else if (m_kind == "resourcepacks") {
            src = m_instance->resourcePackList();
        } else if (m_kind == "texturepacks") {
            src = m_instance->texturePackList();
        } else if (m_kind == "shaderpacks") {
            src = m_instance->shaderPackList();
        } else if (m_kind == "datapacks") {
            src = m_instance->dataPackList();
        } else if (m_kind == "folderdatapacks" && !m_folderPath.isEmpty()) {
            bool isIndexed = !APPLICATION->settings()->get("ModMetadataDisabled").toBool();
            m_ownedSrc = std::make_unique<DataPackFolderModel>(m_folderPath, m_instance, isIndexed, true);
            src = m_ownedSrc.get();
        }
        m_src = src;
    }

    if (m_src) {
        setSourceModel(m_src);
        auto counts = [this] { emit countsChanged(); };
        m_conns << connect(m_src, &QAbstractItemModel::rowsInserted, this, counts);
        m_conns << connect(m_src, &QAbstractItemModel::rowsRemoved, this, [this] {
            // drop selections that vanished
            QSet<QString> alive;
            for (auto* r : m_src->allResources()) {
                alive.insert(r->internalId());
            }
            const auto before = m_selected.size();
            m_selected.intersect(alive);
            if (before != m_selected.size()) {
                emit selectionChanged();
            }
            emit countsChanged();
        });
        m_conns << connect(m_src, &QAbstractItemModel::modelReset, this, counts);
        m_conns << connect(m_src, &QAbstractItemModel::dataChanged, this, counts);
        m_conns << connect(m_src, &ResourceFolderModel::parseFinished, this, [this] {
            m_iconRev++;
            if (rowCount() > 0) {
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { IconSourceRole });
            }
            invalidate();
        });
        m_conns << connect(m_src, &ResourceFolderModel::updateFinished, this, [this] {
            m_loading = false;
            emit loadingChanged();
            emit countsChanged();
        });
        m_conns << connect(m_instance, &BaseInstance::runningStatusChanged, this, &ResFolderModel::instanceRunningChanged);
        m_loading = true;
        retainWatch(m_src);
        sort(0, m_sortDescending ? Qt::DescendingOrder : Qt::AscendingOrder);
    }
    emit sourceChanged();
    emit loadingChanged();
    emit countsChanged();
    emit selectionChanged();
    emit instanceRunningChanged();
}

bool ResFolderModel::isMods() const
{
    return m_kind == "mods" || m_kind == "coremods" || m_kind == "nilmods";
}

QString ResFolderModel::resourceType() const
{
    if (isMods()) {
        return "mod";
    }
    if (m_kind == "resourcepacks") {
        return "resourcepack";
    }
    if (m_kind == "texturepacks") {
        return "texturepack";
    }
    if (m_kind == "shaderpacks") {
        return "shaderpack";
    }
    return "datapack";
}

QString ResFolderModel::dirPath() const
{
    return m_src ? m_src->dir().absolutePath() : QString();
}

bool ResFolderModel::instanceRunning() const
{
    return m_instance && m_instance->isRunning();
}

bool ResFolderModel::hasModLoader() const
{
    return m_instance && m_instance->getPackProfile()->getModLoaders().has_value();
}

bool ResFolderModel::metadataDisabled() const
{
    return APPLICATION->settings()->get("ModMetadataDisabled").toBool();
}

bool ResFolderModel::dependenciesDisabled() const
{
    return APPLICATION->settings()->get("ModDependenciesDisabled").toBool();
}

void ResFolderModel::setFilterText(const QString& t)
{
    if (t == m_filterText) {
        return;
    }
    m_filterText = t;
    invalidateFilter();
    emit filterTextChanged();
    emit countsChanged();
}

void ResFolderModel::setStateFilter(const QString& f)
{
    if (f == m_stateFilter) {
        return;
    }
    m_stateFilter = f;
    invalidateFilter();
    emit stateFilterChanged();
    emit countsChanged();
}

void ResFolderModel::setSortKey(const QString& k)
{
    if (k == m_sortKey) {
        return;
    }
    m_sortKey = k;
    invalidate();
    sort(0, m_sortDescending ? Qt::DescendingOrder : Qt::AscendingOrder);
    emit sortChanged();
}

void ResFolderModel::setSortDescending(bool d)
{
    if (d == m_sortDescending) {
        return;
    }
    m_sortDescending = d;
    sort(0, m_sortDescending ? Qt::DescendingOrder : Qt::AscendingOrder);
    emit sortChanged();
}

int ResFolderModel::totalCount() const
{
    return m_src ? static_cast<int>(m_src->size()) : 0;
}

int ResFolderModel::enabledCount() const
{
    if (!m_src) {
        return 0;
    }
    int n = 0;
    for (qsizetype i = 0; i < m_src->size(); ++i) {
        n += m_src->at(static_cast<int>(i)).enabled() ? 1 : 0;
    }
    return n;
}

int ResFolderModel::currentRow() const
{
    return m_currentId.isEmpty() ? -1 : rowOf(m_currentId);
}

bool ResFolderModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    Q_UNUSED(sourceParent)
    if (!m_src || sourceRow < 0 || sourceRow >= m_src->size()) {
        return false;
    }
    const Resource& r = m_src->at(sourceRow);
    if (m_stateFilter == "enabled" && !r.enabled()) {
        return false;
    }
    if (m_stateFilter == "disabled" && r.enabled()) {
        return false;
    }
    if (m_stateFilter == "issues" && !r.hasIssues()) {
        return false;
    }
    if (m_stateFilter == "nometadata" && r.metadata()) {
        return false;
    }
    if (m_filterText.isEmpty()) {
        return true;
    }
    QRegularExpression re(m_filterText, QRegularExpression::CaseInsensitiveOption);
    if (!re.isValid()) {
        re = QRegularExpression(QRegularExpression::escape(m_filterText), QRegularExpression::CaseInsensitiveOption);
    }
    return r.applyFilter(re);
}

bool ResFolderModel::lessThan(const QModelIndex& left, const QModelIndex& right) const
{
    if (!m_src) {
        return false;
    }
    const Resource& l = m_src->at(left.row());
    const Resource& r = m_src->at(right.row());
    const auto type = sortTypeFor(m_sortKey);
    auto c = l.compare(r, type);
    if (c == 0 && type != SortType::Name) {
        c = l.compare(r, SortType::Name);
    }
    return c < 0;
}

QHash<int, QByteArray> ResFolderModel::roleNames() const
{
    return {
        { InternalIdRole, "internalId" },   { NameRole, "name" },
        { VersionRole, "version" },         { AuthorRole, "author" },
        { ProviderRole, "provider" },       { DescriptionRole, "description" },
        { FileNameRole, "fileName" },       { SizeTextRole, "sizeText" },
        { DateTextRole, "dateText" },       { EnabledRole, "enabled" },
        { SelectedRole, "selected" },       { IconSourceRole, "iconSource" },
        { HasMetadataRole, "hasMetadata" }, { UpdateLockedRole, "updateLocked" },
        { IssuesRole, "issues" },           { HomepageRole, "homepage" },
        { SideRole, "side" },               { LoadersRole, "loaders" },
        { McVersionsRole, "mcVersions" },   { ReleaseTypeRole, "releaseType" },
        { RequiresCountRole, "requiresCount" }, { RequiredByCountRole, "requiredByCount" },
        { PackFormatRole, "packFormat" },   { IsFolderRole, "isFolder" },
        { LinkTipRole, "linkTip" },
    };
}

Resource* ResFolderModel::resourceAt(int proxyRow) const
{
    if (!m_src || proxyRow < 0 || proxyRow >= rowCount()) {
        return nullptr;
    }
    const auto src = mapToSource(index(proxyRow, 0));
    if (!src.isValid() || src.row() >= m_src->size()) {
        return nullptr;
    }
    return &m_src->at(src.row());
}

QVariant ResFolderModel::data(const QModelIndex& idx, int role) const
{
    auto* r = resourceAt(idx.row());
    if (!r) {
        return {};
    }
    auto* mod = isMods() ? static_cast<Mod*>(r) : nullptr;
    switch (role) {
        case Qt::DisplayRole:
        case NameRole:
            return plain(r->name());
        case InternalIdRole:
            return r->internalId();
        case VersionRole:
            return r->version();
        case AuthorRole:
            if (mod) {
                return mod->authors().join(", ");
            }
            return {};
        case ProviderRole: {
            auto p = r->provider();
            return p == "Unknown" ? QString() : p;
        }
        case DescriptionRole: {
            QString d;
            if (mod) {
                d = mod->description();
            } else if (m_kind == "texturepacks") {
                d = static_cast<TexturePack*>(r)->description();
            } else if (resourceType() == "resourcepack" || resourceType() == "datapack") {
                d = static_cast<DataPack*>(r)->description();
            }
            d = plain(d).simplified();
            return d.length() > 220 ? d.left(217) + "…" : d;
        }
        case FileNameRole:
            return r->fileinfo().fileName();
        case SizeTextRole:
            return r->sizeStr();
        case DateTextRole:
            return QLocale().toString(r->dateTimeChanged(), QLocale::ShortFormat);
        case EnabledRole:
            return r->enabled();
        case SelectedRole:
            return m_selected.contains(r->internalId());
        case IconSourceRole: {
            const bool hasImage = isMods() || resourceType() != "shaderpack";
            if (!hasImage) {
                return QString();
            }
            return QString("image://resicon/%1/%2?v=%3")
                .arg(m_iconNs, QString::fromLatin1(QUrl::toPercentEncoding(r->internalId())))
                .arg(m_iconRev);
        }
        case HasMetadataRole:
            return r->metadata() != nullptr;
        case UpdateLockedRole:
            return r->lockUpdate();
        case IssuesRole:
            return r->issues().join("\n");
        case HomepageRole:
            return r->homepage();
        case SideRole:
            return mod ? mod->side() : QString();
        case LoadersRole:
            return mod ? mod->loaders() : QString();
        case McVersionsRole:
            return mod ? mod->mcVersionsString() : QString();
        case ReleaseTypeRole:
            return mod ? mod->releaseType() : QString();
        case RequiresCountRole:
            return mod ? mod->requiresCount() : 0;
        case RequiredByCountRole:
            return mod ? mod->requiredByCount() : 0;
        case PackFormatRole:
            if (resourceType() == "resourcepack" || resourceType() == "datapack") {
                return static_cast<DataPack*>(r)->packFormatStr();
            }
            return {};
        case IsFolderRole:
            return r->fileinfo().isDir();
        case LinkTipRole: {
            QString tip;
            if (m_src && r->isSymLinkUnder(m_src->instDirPath())) {
                tip = tr("Symbolically linked from elsewhere. Editing it also changes the original.\n%1")
                          .arg(r->fileinfo().canonicalFilePath());
            } else if (r->isMoreThanOneHardLink()) {
                tip = tr("Hard linked elsewhere. Editing it also changes the original.");
            }
            return tip;
        }
        default:
            return {};
    }
}

QPixmap ResFolderModel::iconFor(const QString& internalId, const QSize& size) const
{
    if (!m_src) {
        return {};
    }
    auto res = m_src->find(internalId);
    if (!res) {
        return {};
    }
    if (isMods()) {
        return static_cast<Mod*>(res.get())->icon(size, Qt::KeepAspectRatio);
    }
    if (m_kind == "texturepacks") {
        return static_cast<TexturePack*>(res.get())->image(size, Qt::KeepAspectRatio);
    }
    if (resourceType() == "resourcepack" || resourceType() == "datapack") {
        return static_cast<DataPack*>(res.get())->image(size, Qt::KeepAspectRatio);
    }
    return {};
}

int ResFolderModel::rowOf(const QString& internalId) const
{
    for (int i = 0; i < rowCount(); ++i) {
        if (auto* r = resourceAt(i); r && r->internalId() == internalId) {
            return i;
        }
    }
    return -1;
}

// ---------------- selection ----------------

void ResFolderModel::emitSelectedChanged()
{
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { SelectedRole });
    }
    emit selectionChanged();
}

void ResFolderModel::select(int row, const QString& mode)
{
    auto* r = resourceAt(row);
    if (!r) {
        return;
    }
    const auto id = r->internalId();
    if (mode == "toggle") {
        if (m_selected.contains(id)) {
            m_selected.remove(id);
        } else {
            m_selected.insert(id);
        }
        m_anchorId = id;
    } else if (mode == "range" && !m_anchorId.isEmpty()) {
        int a = rowOf(m_anchorId);
        if (a < 0) {
            a = row;
        }
        m_selected.clear();
        for (int i = qMin(a, row); i <= qMax(a, row); ++i) {
            if (auto* rr = resourceAt(i)) {
                m_selected.insert(rr->internalId());
            }
        }
    } else {
        m_selected.clear();
        m_selected.insert(id);
        m_anchorId = id;
    }
    m_currentId = id;
    emitSelectedChanged();
}

void ResFolderModel::selectAll()
{
    for (int i = 0; i < rowCount(); ++i) {
        if (auto* r = resourceAt(i)) {
            m_selected.insert(r->internalId());
        }
    }
    emitSelectedChanged();
}

void ResFolderModel::clearSelection()
{
    if (m_selected.isEmpty() && m_currentId.isEmpty()) {
        return;
    }
    m_selected.clear();
    m_currentId.clear();
    emitSelectedChanged();
}

bool ResFolderModel::isSelected(int row) const
{
    auto* r = resourceAt(row);
    return r && m_selected.contains(r->internalId());
}

QList<Resource*> ResFolderModel::selectedResources() const
{
    QList<Resource*> out;
    if (!m_src) {
        return out;
    }
    for (auto* r : m_src->allResources()) {
        if (m_selected.contains(r->internalId())) {
            out << r;
        }
    }
    return out;
}

QModelIndexList ResFolderModel::selectedSourceIndexes() const
{
    QModelIndexList out;
    if (!m_src) {
        return out;
    }
    for (int i = 0; i < m_src->size(); ++i) {
        if (m_selected.contains(m_src->at(i).internalId())) {
            out << m_src->index(i, 0);
        }
    }
    return out;
}

QVariantMap ResFolderModel::selectionInfo() const
{
    const auto sel = selectedResources();
    bool anyFolder = false, anyHomepage = false, anyUnlocked = false, anyLocked = false, allLocked = !sel.isEmpty();
    for (auto* r : sel) {
        anyFolder |= r->fileinfo().isDir();
        anyHomepage |= !r->homepage().isEmpty();
        anyUnlocked |= r->metadata() && !r->lockUpdate();
        anyLocked |= r->metadata() && r->lockUpdate();
        allLocked &= r->lockUpdate();
    }
    return {
        { "count", sel.size() },
        { "anyFolder", anyFolder },
        { "firstName", sel.isEmpty() ? QString() : plain(sel.first()->name()) },
        { "firstFile", sel.isEmpty() ? QString() : sel.first()->fileinfo().fileName() },
        { "anyHomepage", anyHomepage },
        { "canLock", anyUnlocked },
        { "canUnlock", anyLocked },
        { "allLocked", allLocked },
        { "canChangeVersion", sel.size() == 1 && sel.first()->metadata() != nullptr },
    };
}

// ---------------- actions ----------------

void ResFolderModel::toggleEnabled(int row)
{
    auto* r = resourceAt(row);
    if (!r || !m_src) {
        return;
    }
    auto src = mapToSource(index(row, 0));
    m_src->setResourceEnabled({ src }, EnableAction::TOGGLE);
}

void ResFolderModel::setSelectedEnabled(bool enabled)
{
    if (!m_src) {
        return;
    }
    m_src->setResourceEnabled(selectedSourceIndexes(), enabled ? EnableAction::ENABLE : EnableAction::DISABLE);
}

QStringList ResFolderModel::dependentsOfSelection() const
{
    QStringList out;
    auto* mods = qobject_cast<ModFolderModel*>(m_src.data());
    if (!mods) {
        return out;
    }
    for (const auto& idx : mods->getAffectedMods(selectedSourceIndexes(), EnableAction::DISABLE)) {
        const auto& m = mods->at(idx.row());
        out << QString("%1 (%2)").arg(plain(m.name()), m.internalId());
    }
    return out;
}

void ResFolderModel::disableDependentsOfSelection()
{
    auto* mods = qobject_cast<ModFolderModel*>(m_src.data());
    if (!mods) {
        return;
    }
    auto affected = mods->getAffectedMods(selectedSourceIndexes(), EnableAction::DISABLE);
    if (!affected.isEmpty()) {
        mods->setResourceEnabled(affected, EnableAction::DISABLE);
    }
}

bool ResFolderModel::removeSelected()
{
    if (!m_src) {
        return false;
    }
    auto idx = selectedSourceIndexes();
    if (idx.isEmpty()) {
        return false;
    }
    const bool ok = m_src->deleteResources(idx);
    m_selected.clear();
    m_currentId.clear();
    emit selectionChanged();
    return ok;
}

void ResFolderModel::installFiles(const QList<QUrl>& urls)
{
    if (!m_src) {
        return;
    }
    int n = 0;
    for (const auto& u : urls) {
        const QString path = u.isLocalFile() ? u.toLocalFile() : u.toString();
        if (!path.isEmpty() && m_src->installResource(path)) {
            n++;
        }
    }
    if (n > 0) {
        m_src->update();
    }
}

void ResFolderModel::setSelectedUpdateLock(bool locked)
{
    if (!m_src) {
        return;
    }
    m_src->setUpdateLock(selectedSourceIndexes(), locked ? EnableAction::ENABLE : EnableAction::DISABLE);
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { UpdateLockedRole });
    }
    emit selectionChanged();
}

void ResFolderModel::deleteSelectedMetadata()
{
    if (!m_src) {
        return;
    }
    m_src->deleteMetadata(selectedSourceIndexes());
}

void ResFolderModel::viewSelectedHomepages()
{
    for (auto* r : selectedResources()) {
        const auto url = r->homepage();
        if (!url.isEmpty()) {
            DesktopServices::openUrl(url);
        }
    }
}

void ResFolderModel::openFolder()
{
    if (m_src) {
        DesktopServices::openPath(m_src->dir().absolutePath(), true);
    }
}

void ResFolderModel::openConfigs()
{
    if (m_instance) {
        DesktopServices::openPath(m_instance->instanceConfigFolder(), true);
    }
}

void ResFolderModel::refresh()
{
    if (m_src) {
        m_loading = m_src->update() || m_loading;
        emit loadingChanged();
    }
}

QVariantMap ResFolderModel::details(int row) const
{
    auto* r = resourceAt(row);
    if (!r) {
        return {};
    }
    QVariantMap m;
    const QString nameHtml = InfoFrame::renderColorCodes(r->name());
    m["name"] = plain(r->name());
    m["nameHtml"] = nameHtml;
    m["internalId"] = r->internalId();
    m["version"] = r->version();
    m["homepage"] = r->homepage();
    m["fileName"] = r->fileinfo().fileName();
    m["path"] = r->fileinfo().absoluteFilePath();
    m["size"] = r->sizeStr();
    m["date"] = QLocale().toString(r->dateTimeChanged(), QLocale::LongFormat);
    m["enabled"] = r->enabled();
    m["provider"] = r->provider() == "Unknown" ? QString() : r->provider();
    m["hasMetadata"] = r->metadata() != nullptr;
    m["updateLocked"] = r->lockUpdate();
    m["issues"] = r->issues();
    m["iconSource"] = data(index(row, 0), IconSourceRole);
    m["isFolder"] = r->fileinfo().isDir();
    m["linkTip"] = data(index(row, 0), LinkTipRole);
    if (auto meta = r->metadata()) {
        m["projectId"] = meta->projectId.toString();
        m["metaVersion"] = meta->versionNumber;
        m["slug"] = meta->slug;
        m["providerKey"] = meta->provider == ModPlatform::ResourceProvider::FLAME ? "curseforge" : "modrinth";
    }
    QString desc;
    if (isMods()) {
        auto* mod = static_cast<Mod*>(r);
        desc = mod->description();
        m["authors"] = mod->authors();
        m["modId"] = mod->modId();
        m["side"] = mod->side();
        m["loaders"] = mod->loaders();
        m["mcVersions"] = mod->mcVersionsString();
        m["releaseType"] = mod->releaseType();
        m["issueTracker"] = mod->issueTracker();
        QStringList lic;
        for (const auto& l : mod->licenses()) {
            QString t;
            if (!l.name.isEmpty()) {
                t = l.url.isEmpty() ? l.name : QString("<a href=\"%1\">%2</a>").arg(l.url, l.name);
            } else if (!l.url.isEmpty()) {
                t = QString("<a href=\"%1\">%1</a>").arg(l.url);
            }
            if (!l.description.isEmpty() && l.description != l.name) {
                t += " " + l.description;
            }
            if (!t.isEmpty()) {
                lic << t;
            }
        }
        m["licenseHtml"] = lic.join("<br>");
        if (auto* mods = qobject_cast<ModFolderModel*>(m_src.data())) {
            m["requires"] = mods->requiresList(mod->modId());
            m["requiredBy"] = mods->requiredByList(mod->modId());
        }
    } else if (m_kind == "texturepacks") {
        desc = static_cast<TexturePack*>(r)->description();
    } else if (resourceType() == "resourcepack" || resourceType() == "datapack") {
        auto* dp = static_cast<DataPack*>(r);
        desc = dp->description();
        m["packFormat"] = dp->packFormatStr();
    }
    m["descriptionHtml"] = desc.isEmpty() ? QString() : InfoFrame::renderColorCodes(desc);
    return m;
}

QString ResFolderModel::instanceName() const
{
    return m_instance ? m_instance->name() : QString();
}

QString ResFolderModel::exportModList(const QString& format, bool authors, bool url, bool version, bool filename) const
{
    auto* mods = qobject_cast<ModFolderModel*>(m_src.data());
    if (!mods) {
        return {};
    }
    QList<Mod*> list;
    const auto sel = selectedResources();
    if (sel.isEmpty()) {
        list = mods->allMods();
    } else {
        for (auto* r : sel) {
            list << static_cast<Mod*>(r);
        }
    }
    std::ranges::sort(list, [](const Mod* a, const Mod* b) { return a->name() < b->name(); });
    ExportToModList::Formats f = ExportToModList::PLAINTXT;
    if (format == "html") {
        f = ExportToModList::HTML;
    } else if (format == "markdown") {
        f = ExportToModList::MARKDOWN;
    } else if (format == "json") {
        f = ExportToModList::JSON;
    } else if (format == "csv") {
        f = ExportToModList::CSV;
    }
    ExportToModList::OptionalData opt = ExportToModList::None;
    if (authors) {
        opt |= ExportToModList::Authors;
    }
    if (url) {
        opt |= ExportToModList::Url;
    }
    if (version) {
        opt |= ExportToModList::Version;
    }
    if (filename) {
        opt |= ExportToModList::FileName;
    }
    return ExportToModList::exportToModList(list, f, opt);
}

QString ResFolderModel::exportModListCustom(const QString& lineTemplate) const
{
    auto* mods = qobject_cast<ModFolderModel*>(m_src.data());
    if (!mods) {
        return {};
    }
    QList<Mod*> list;
    const auto sel = selectedResources();
    if (sel.isEmpty()) {
        list = mods->allMods();
    } else {
        for (auto* r : sel) {
            list << static_cast<Mod*>(r);
        }
    }
    std::ranges::sort(list, [](const Mod* a, const Mod* b) { return a->name() < b->name(); });
    return ExportToModList::exportToModList(list, lineTemplate);
}
