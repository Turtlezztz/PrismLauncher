#include "NIVersionModel.h"

#include "Application.h"
#include "meta/Index.h"

NIVersionModel::NIVersionModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setSortRole(BaseVersionList::SortRole);
    setDynamicSortFilter(true);
    connect(this, &QAbstractItemModel::rowsInserted, this, &NIVersionModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &NIVersionModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &NIVersionModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &NIVersionModel::countChanged);
}

QHash<int, QByteArray> NIVersionModel::roleNames() const
{
    return { { VersionRole, "version" }, { TypeRole, "type" }, { RecommendedRole, "recommended" }, { TimeRole, "time" }, { ParentRole, "parentVersion" } };
}

QVariant NIVersionModel::data(const QModelIndex& index, int role) const
{
    const auto src = mapToSource(index);
    switch (role) {
        case VersionRole:
            return sourceModel()->data(src, BaseVersionList::VersionRole);
        case TypeRole: {
            auto t = sourceModel()->data(src, BaseVersionList::TypeRole).toString();
            if (t == "old_alpha") {
                return QStringLiteral("alpha");
            }
            if (t == "old_beta") {
                return QStringLiteral("beta");
            }
            return t;
        }
        case RecommendedRole:
            return sourceModel()->data(src, BaseVersionList::RecommendedRole).toBool();
        case TimeRole: {
            auto t = sourceModel()->data(src, Meta::VersionList::TimeRole).toDateTime();
            return t.isValid() ? QLocale().toString(t.date(), QLocale::ShortFormat) : QString();
        }
        case ParentRole:
            return sourceModel()->data(src, BaseVersionList::ParentVersionRole);
        default:
            return QSortFilterProxyModel::data(index, role);
    }
}

void NIVersionModel::setUid(const QString& uid)
{
    if (uid == m_uid) {
        return;
    }
    m_uid = uid;
    emit uidChanged();
    setVersionList(uid.isEmpty() ? nullptr : APPLICATION->metadataIndex()->get(uid));
}

void NIVersionModel::setVersionList(Meta::VersionList::Ptr list)
{
    if (m_loadTask) {
        disconnect(m_loadTask.get(), nullptr, this, nullptr);
        m_loadTask.reset();
    }
    m_list = std::move(list);
    setSourceModel(m_list.get());
    sort(0, Qt::DescendingOrder);
    m_loading = false;
    m_error.clear();
    emit loadingChanged();
    emit countChanged();
    if (m_list && !m_list->isLoaded()) {
        refresh(false);
    } else if (m_list) {
        emit loaded();
    }
}

void NIVersionModel::refresh(bool force)
{
    if (!m_list) {
        return;
    }
    if (m_loadTask) {
        disconnect(m_loadTask.get(), nullptr, this, nullptr);
    }
    m_loadTask = m_list->getLoadTask(force);
    if (!m_loadTask) {
        return;
    }
    m_loading = true;
    m_error.clear();
    emit loadingChanged();
    connect(m_loadTask.get(), &Task::succeeded, this, [this] {
        m_loading = false;
        emit loadingChanged();
        emit countChanged();
        emit loaded();
    });
    connect(m_loadTask.get(), &Task::failed, this, [this](const QString& reason) {
        m_loading = false;
        m_error = reason;
        emit loadingChanged();
    });
    connect(m_loadTask.get(), &Task::aborted, this, [this] {
        m_loading = false;
        emit loadingChanged();
    });
    if (!m_loadTask->isRunning()) {
        m_loadTask->start();
    }
}

void NIVersionModel::setTypeFilter(const QStringList& f)
{
    if (f == m_typeFilter) {
        return;
    }
    m_typeFilter = f;
    refilter();
}

void NIVersionModel::setParentFilter(const QString& p)
{
    if (p == m_parentFilter) {
        return;
    }
    m_parentFilter = p;
    refilter();
}

void NIVersionModel::setParentFilterEnabled(bool on)
{
    if (on == m_parentFilterEnabled) {
        return;
    }
    m_parentFilterEnabled = on;
    refilter();
}

void NIVersionModel::setSearch(const QString& s)
{
    if (s == m_search) {
        return;
    }
    m_search = s;
    refilter();
}

void NIVersionModel::refilter()
{
    invalidateFilter();
    emit filterChanged();
    emit countChanged();
}

bool NIVersionModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    auto idx = sourceModel()->index(sourceRow, 0, sourceParent);
    if (!m_typeFilter.isEmpty()) {
        const auto type = idx.data(BaseVersionList::TypeRole).toString();
        bool ok = false;
        for (const auto& f : m_typeFilter) {
            if (type.contains(f)) {
                ok = true;
                break;
            }
        }
        if (!ok) {
            return false;
        }
    }
    if (m_parentFilterEnabled && idx.data(BaseVersionList::ParentVersionRole).toString() != m_parentFilter) {
        return false;
    }
    if (!m_search.isEmpty() && !idx.data(BaseVersionList::VersionRole).toString().contains(m_search, Qt::CaseInsensitive)) {
        return false;
    }
    return true;
}

QString NIVersionModel::versionAt(int row) const
{
    return data(index(row, 0), VersionRole).toString();
}

int NIVersionModel::indexOf(const QString& version) const
{
    for (int i = 0; i < rowCount(); i++) {
        if (versionAt(i) == version) {
            return i;
        }
    }
    return -1;
}

int NIVersionModel::recommendedRow() const
{
    if (rowCount() == 0) {
        return -1;
    }
    for (int i = 0; i < rowCount(); i++) {
        if (data(index(i, 0), RecommendedRole).toBool()) {
            return i;
        }
    }
    return 0;
}

BaseVersion::Ptr NIVersionModel::versionPtr(int row) const
{
    if (row < 0 || row >= rowCount()) {
        return {};
    }
    return QSortFilterProxyModel::data(index(row, 0), BaseVersionList::VersionPointerRole).value<BaseVersion::Ptr>();
}
