#include "NIIconModel.h"

#include <QDir>
#include <QFileInfo>

#include "Application.h"
#include "DesktopServices.h"
#include "icons/IconList.h"
#include "icons/IconUtils.h"

NIIconModel::NIIconModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setSourceModel(APPLICATION->icons());
    setDynamicSortFilter(true);
    sort(0);
    connect(this, &QAbstractItemModel::rowsInserted, this, &NIIconModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &NIIconModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &NIIconModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &NIIconModel::countChanged);
    connect(APPLICATION->icons(), &IconList::iconUpdated, this, [this] {
        m_revision++;
        if (rowCount() > 0) {
            emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { SourceRole });
        }
    });
}

QHash<int, QByteArray> NIIconModel::roleNames() const
{
    return { { KeyRole, "key" }, { NameRole, "name" }, { SourceRole, "source" }, { RemovableRole, "removable" }, { BuiltInRole, "builtIn" } };
}

QVariant NIIconModel::data(const QModelIndex& index, int role) const
{
    const auto key = QSortFilterProxyModel::data(index, Qt::UserRole).toString();
    switch (role) {
        case KeyRole:
            return key;
        case NameRole:
            return QSortFilterProxyModel::data(index, Qt::DisplayRole);
        case SourceRole:
            return QString("image://instanceicon/%1?v=%2").arg(key).arg(m_revision);
        case RemovableRole:
            return APPLICATION->icons()->iconFileExists(key);
        case BuiltInRole: {
            const auto* icon = APPLICATION->icons()->icon(key);
            return icon && icon->isBuiltIn();
        }
        default:
            return QSortFilterProxyModel::data(index, role);
    }
}

void NIIconModel::setSearch(const QString& s)
{
    if (s == m_search) {
        return;
    }
    m_search = s;
    invalidateFilter();
    emit searchChanged();
    emit countChanged();
}

void NIIconModel::setCategory(const QString& c)
{
    if (c == m_category) {
        return;
    }
    m_category = c;
    invalidateFilter();
    emit categoryChanged();
    emit countChanged();
}

QString NIIconModel::iconFilter() const
{
    return IconUtils::getIconFilter();
}

bool NIIconModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    auto* model = static_cast<IconList*>(sourceModel());
    const auto idx = model->index(sourceRow, 0, sourceParent);
    if (!m_search.isEmpty() && !idx.data(Qt::DisplayRole).toString().contains(m_search, Qt::CaseInsensitive)) {
        return false;
    }
    if (m_category == "all") {
        return true;
    }
    const auto* icon = model->icon(idx.data(Qt::UserRole).toString());
    if (!icon) {
        return false;
    }
    const bool builtin = icon->isBuiltIn();
    const bool legacy = builtin && icon->name().endsWith("_legacy", Qt::CaseInsensitive);
    bool modpack = false;
    if (!builtin) {
        const auto& name = icon->name();
        for (const auto* prefix : { "curseforge_", "modrinth_", "ftb_", "technic_", "atl_" }) {
            if (name.startsWith(prefix, Qt::CaseInsensitive)) {
                modpack = true;
            }
        }
    }
    if (m_category == "legacy") {
        return legacy;
    }
    if (m_category == "modpacks") {
        return modpack;
    }
    if (m_category == "modern") {
        return builtin && !legacy;
    }
    if (m_category == "custom") {
        return !builtin && !modpack;
    }
    return true;
}

bool NIIconModel::lessThan(const QModelIndex& left, const QModelIndex& right) const
{
    const auto l = sourceModel()->data(left, Qt::UserRole).toString();
    const auto r = sourceModel()->data(right, Qt::UserRole).toString();
    const bool ls = l.contains(QDir::separator());
    const bool rs = r.contains(QDir::separator());
    if (ls != rs) {
        return !ls;
    }
    return l.localeAwareCompare(r) < 0;
}

int NIIconModel::indexOf(const QString& key) const
{
    auto* list = APPLICATION->icons();
    const int src = list->getIconIndex(key);
    if (src < 0) {
        return -1;
    }
    return mapFromSource(list->index(src)).row();
}

QString NIIconModel::addIcons(const QList<QUrl>& files)
{
    QStringList paths;
    for (const auto& u : files) {
        if (u.isLocalFile()) {
            paths << u.toLocalFile();
        }
    }
    if (paths.isEmpty()) {
        return {};
    }
    APPLICATION->icons()->installIcons(paths);
    return QFileInfo(paths.first()).completeBaseName();
}

bool NIIconModel::removeIcon(const QString& key)
{
    if (APPLICATION->icons()->trashIcon(key)) {
        return true;
    }
    return APPLICATION->icons()->deleteIcon(key);
}

bool NIIconModel::canRemove(const QString& key) const
{
    return APPLICATION->icons()->iconFileExists(key);
}

void NIIconModel::openFolder(const QString& key)
{
    DesktopServices::openPath(APPLICATION->icons()->iconDirectory(key), true);
}
