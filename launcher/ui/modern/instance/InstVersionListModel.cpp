#include "InstVersionListModel.h"

#include <QLocale>
#include <QSet>

#include "Application.h"
#include "BaseVersionList.h"
#include "Version.h"
#include "java/JavaInstallList.h"
#include "meta/Index.h"
#include "meta/VersionList.h"

InstVersionListModel::InstVersionListModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &InstVersionListModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &InstVersionListModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &InstVersionListModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &InstVersionListModel::countChanged);
}

QHash<int, QByteArray> InstVersionListModel::roleNames() const
{
    return {
        { VersionNameRole, "versionName" }, { DescriptorRole, "descriptor" }, { TypeRole, "type" },     { RecommendedRole, "recommended" },
        { LatestRole, "latest" },           { ParentRole, "parentVersion" },  { TimeRole, "time" },     { CurrentRole, "current" },
        { PathRole, "path" },               { ArchRole, "arch" },             { JavaMajorRole, "javaMajor" },
    };
}

void InstVersionListModel::setUid(const QString& uid)
{
    if (uid == m_uid) {
        return;
    }
    m_uid = uid;
    if (uid == "java") {
        m_list = APPLICATION->javalist();
    } else if (!uid.isEmpty()) {
        auto list = APPLICATION->metadataIndex()->get(uid);
        m_list = list.get();
    } else {
        m_list = nullptr;
    }
    setSourceModel(m_list.data());
    if (m_list && uid != "java") {
        // newest first (the metadata list isn't kept sorted when entries get merged in)
        setSortRole(BaseVersionList::SortRole);
        setDynamicSortFilter(true);
        sort(0, Qt::DescendingOrder);
    } else {
        sort(-1);
    }
    emit uidChanged();
    emit countChanged();
}

void InstVersionListModel::setSearch(const QString& s)
{
    if (s == m_search) {
        return;
    }
    m_search = s;
    invalidateFilter();
    emit filterChanged();
}

void InstVersionListModel::setParentVersion(const QString& v)
{
    if (v == m_parent) {
        return;
    }
    m_parent = v;
    invalidateFilter();
    emit filterChanged();
}

void InstVersionListModel::setBlockAll(bool b)
{
    if (b == m_blockAll) {
        return;
    }
    m_blockAll = b;
    invalidateFilter();
    emit filterChanged();
}

void InstVersionListModel::setTypes(const QStringList& t)
{
    if (t == m_types) {
        return;
    }
    m_types = t;
    invalidateFilter();
    emit filterChanged();
}

void InstVersionListModel::setJavaMajor(int m)
{
    if (m == m_javaMajor) {
        return;
    }
    m_javaMajor = m;
    invalidateFilter();
    emit filterChanged();
}

void InstVersionListModel::setCurrentVersion(const QString& v)
{
    if (v == m_current) {
        return;
    }
    m_current = v;
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { CurrentRole });
    }
    emit currentVersionChanged();
}

void InstVersionListModel::setExtraRecommended(const QString& v)
{
    m_extraRecommended = v;
    if (auto* meta = qobject_cast<Meta::VersionList*>(m_list.data())) {
        meta->clearExternalRecommends();
        if (!v.isEmpty()) {
            meta->addExternalRecommends({ v });
        }
    }
    emit uidChanged();
}

void InstVersionListModel::load(bool force)
{
    if (!m_list) {
        return;
    }
    m_error.clear();
    if (m_list->isLoaded() && !force) {
        emit loadingChanged();
        emit loaded();
        return;
    }
    m_loadTask = m_list->getLoadTask(force);
    if (!m_loadTask) {
        return;
    }
    connect(m_loadTask.get(), &Task::failed, this, [this](const QString& reason) { m_error = tr("Couldn't load the version list: %1").arg(reason); });
    connect(m_loadTask.get(), &Task::finished, this, [this] {
        emit loadingChanged();
        emit countChanged();
        emit loaded();
    });
    if (!m_loadTask->isRunning()) {
        m_loadTask->start();
    }
    emit loadingChanged();
}

bool InstVersionListModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    if (m_blockAll || !m_list) {
        return false;
    }
    const auto idx = m_list->index(sourceRow, 0, sourceParent);
    if (!m_parent.isEmpty()) {
        const auto parent = m_list->data(idx, BaseVersionList::ParentVersionRole).toString();
        if (!parent.isEmpty() && parent != m_parent) {
            return false;
        }
    }
    if (!m_types.isEmpty()) {
        const auto type = m_list->data(idx, BaseVersionList::TypeRole).toString();
        if (!type.isEmpty() && !m_types.contains(type)) {
            return false;
        }
    }
    if (m_javaMajor > 0 && m_list->data(idx, BaseVersionList::JavaMajorRole).toString() != QString::number(m_javaMajor)) {
        return false;
    }
    if (!m_search.isEmpty()) {
        const auto name = m_list->data(idx, BaseVersionList::VersionRole).toString();
        const auto path = m_list->data(idx, BaseVersionList::PathRole).toString();
        if (!name.contains(m_search, Qt::CaseInsensitive) && !path.contains(m_search, Qt::CaseInsensitive)) {
            return false;
        }
    }
    return true;
}

QVariant InstVersionListModel::data(const QModelIndex& index, int role) const
{
    if (role < VersionNameRole || !m_list) {
        return QSortFilterProxyModel::data(index, role);
    }
    const auto src = mapToSource(index);
    auto get = [&](int r) { return m_list->data(src, r); };
    switch (role) {
        case VersionNameRole:
            return get(BaseVersionList::VersionRole);
        case DescriptorRole:
            return get(BaseVersionList::VersionIdRole);
        case TypeRole:
            return get(BaseVersionList::TypeRole);
        case RecommendedRole:
            return get(BaseVersionList::RecommendedRole).toBool();
        case LatestRole:
            return get(BaseVersionList::LatestRole).toBool();
        case ParentRole:
            return get(BaseVersionList::ParentVersionRole);
        case TimeRole: {
            const auto t = get(Meta::VersionList::TimeRole);
            if (t.typeId() == QMetaType::QDateTime) {
                const auto dt = t.toDateTime();
                return dt.isValid() ? QLocale(QLocale::English).toString(dt.date(), "d MMM yyyy") : QString();
            }
            return t.toString();
        }
        case CurrentRole:
            return !m_current.isEmpty() && get(BaseVersionList::VersionIdRole).toString() == m_current;
        case PathRole:
            return get(BaseVersionList::PathRole);
        case ArchRole:
            return get(BaseVersionList::CPUArchitectureRole);
        case JavaMajorRole:
            return get(BaseVersionList::JavaMajorRole);
        default:
            return {};
    }
}

QStringList InstVersionListModel::availableTypes() const
{
    QStringList out;
    if (!m_list || m_uid == "java") {
        return out;
    }
    QSet<QString> seen;
    for (int i = 0; i < m_list->rowCount(QModelIndex()); i++) {
        const auto t = m_list->data(m_list->index(i, 0), BaseVersionList::TypeRole).toString();
        if (!t.isEmpty() && !seen.contains(t)) {
            seen.insert(t);
            out << t;
        }
    }
    return out;
}

QVariantMap InstVersionListModel::get(int row) const
{
    QVariantMap map;
    if (row < 0 || row >= rowCount()) {
        return map;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(index(row, 0), it.key()));
    }
    return map;
}

int InstVersionListModel::rowOf(const QString& descriptor) const
{
    for (int i = 0; i < rowCount(); i++) {
        if (data(index(i, 0), DescriptorRole).toString() == descriptor) {
            return i;
        }
    }
    return -1;
}

int InstVersionListModel::preferredRow() const
{
    if (rowCount() == 0) {
        return -1;
    }
    if (!m_current.isEmpty()) {
        if (int r = rowOf(m_current); r >= 0) {
            return r;
        }
    }
    for (int i = 0; i < rowCount(); i++) {
        if (data(index(i, 0), RecommendedRole).toBool()) {
            return i;
        }
    }
    return 0;
}

bool InstVersionListModel::versionLess(const QString& a, const QString& b)
{
    return Version(a) < Version(b);
}
