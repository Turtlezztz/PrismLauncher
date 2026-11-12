#include "InstanceModel.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include "Application.h"
#include "InstanceList.h"
#include "MMCTime.h"
#include "icons/IconList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "tasks/Task.h"
#include "settings/SettingsObject.h"

InstanceModel::InstanceModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setSourceModel(APPLICATION->instances());
    setDynamicSortFilter(true);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    m_sortMode = APPLICATION->settings()->get("InstSortMode").toString() == "LastLaunch" ? "lastPlayed" : "name";
    sort(0);

    connect(this, &QAbstractItemModel::rowsInserted, this, &InstanceModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &InstanceModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &InstanceModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &InstanceModel::countChanged);

    // Icons can change content without changing key; bump a revision so QML reloads the image.
    connect(static_cast<QAbstractItemModel*>(APPLICATION->icons()), &QAbstractItemModel::dataChanged, this, [this] {
        for (auto& rev : m_iconRevision) {
            rev++;
        }
        if (rowCount() > 0) {
            emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { IconSourceRole });
        }
    });
    // running state is not always reported through dataChanged
    auto hookInstance = [this](int first, int last) {
        auto* list = APPLICATION->instances();
        for (int i = first; i <= last; i++) {
            auto* inst = list->at(i);
            if (!inst) {
                continue;
            }
            if (m_hooked.contains(inst)) {
                continue;
            }
            m_hooked.insert(inst);
            connect(inst, &QObject::destroyed, this, [this, inst] { m_hooked.remove(inst); });
            connect(inst, &BaseInstance::runningStatusChanged, this, [this, id = inst->id()] {
                int row = indexOf(id);
                if (row >= 0) {
                    emit dataChanged(index(row, 0), index(row, 0));
                }
            });
        }
    };
    auto* src = APPLICATION->instances();
    hookInstance(0, src->count() - 1);
    connect(src, &QAbstractItemModel::rowsInserted, this, [hookInstance](const QModelIndex&, int f, int l) { hookInstance(f, l); });
    connect(src, &QAbstractItemModel::modelReset, this, [hookInstance] { hookInstance(0, APPLICATION->instances()->count() - 1); });
}

QHash<int, QByteArray> InstanceModel::roleNames() const
{
    return {
        { IdRole, "instanceId" },
        { NameRole, "name" },
        { IconSourceRole, "iconSource" },
        { IconKeyRole, "iconKey" },
        { GroupRole, "group" },
        { RunningRole, "running" },
        { CanLaunchRole, "canLaunch" },
        { CrashedRole, "crashed" },
        { BrokenRole, "broken" },
        { StatusTextRole, "statusText" },
        { LastLaunchRole, "lastLaunch" },
        { LastPlayedTextRole, "lastPlayedText" },
        { PlayTimeTextRole, "playTimeText" },
        { ManagedPackRole, "managedPack" },
        { ManagedPackTypeRole, "managedPackType" },
        { NotesRole, "notes" },
    };
}

QString InstanceModel::relativeTime(qint64 msecs)
{
    if (msecs <= 0) {
        return tr("Never played");
    }
    const auto secs = QDateTime::fromMSecsSinceEpoch(msecs).secsTo(QDateTime::currentDateTime());
    if (secs < 60) {
        return tr("Just now");
    }
    if (secs < 3600) {
        { int n = int(secs / 60); return n == 1 ? tr("1 minute ago") : tr("%1 minutes ago").arg(n); }
    }
    if (secs < 86400) {
        { int n = int(secs / 3600); return n == 1 ? tr("1 hour ago") : tr("%1 hours ago").arg(n); }
    }
    if (secs < 86400 * 30) {
        { int n = int(secs / 86400); return n == 1 ? tr("Yesterday") : tr("%1 days ago").arg(n); }
    }
    return QDateTime::fromMSecsSinceEpoch(msecs).toString("d MMM yyyy");
}

QVariant InstanceModel::data(const QModelIndex& idx, int role) const
{
    if (role < IdRole) {
        return QSortFilterProxyModel::data(idx, role);
    }
    auto srcIdx = mapToSource(idx);
    auto* inst = static_cast<MinecraftInstance*>(sourceModel()->data(srcIdx, InstanceList::InstancePointerRole).value<void*>());
    if (!inst) {
        return {};
    }
    switch (role) {
        case IdRole:
            return inst->id();
        case NameRole:
            return inst->name();
        case IconKeyRole:
            return inst->iconKey();
        case IconSourceRole:
            return QString("image://instanceicon/%1?v=%2").arg(inst->iconKey()).arg(m_iconRevision.value(inst->iconKey()));
        case GroupRole:
            return APPLICATION->instances()->getInstanceGroup(inst->id());
        case RunningRole:
            return inst->isRunning();
        case CanLaunchRole:
            return inst->canLaunch();
        case CrashedRole:
            return inst->hasCrashed();
        case BrokenRole:
            return inst->hasVersionBroken();
        case StatusTextRole:
            return versionText(inst);
        case LastLaunchRole:
            return inst->lastLaunch();
        case LastPlayedTextRole:
            return relativeTime(inst->lastLaunch());
        case PlayTimeTextRole:
            return Time::prettifyDuration(inst->totalTimePlayed(), APPLICATION->settings()->get("ShowGameTimeWithoutDays").toBool());
        case ManagedPackRole:
            return inst->isManagedPack();
        case ManagedPackTypeRole:
            return inst->getManagedPackType();
        case NotesRole:
            return inst->notes();
        default:
            return {};
    }
}

void InstanceModel::setFilterText(const QString& text)
{
    if (text == m_filterText) {
        return;
    }
    m_filterText = text;
    invalidateFilter();
    emit filterTextChanged();
    emit countChanged();
}

void InstanceModel::setSortMode(const QString& mode)
{
    if (mode == m_sortMode) {
        return;
    }
    m_sortMode = mode;
    APPLICATION->settings()->set("InstSortMode", mode == "lastPlayed" ? "LastLaunch" : "Name");
    invalidate();
    sort(0);
    emit sortModeChanged();
}

void InstanceModel::setGroupFilter(const QString& group)
{
    if (group == m_groupFilter) {
        return;
    }
    m_groupFilter = group;
    invalidateFilter();
    emit groupFilterChanged();
    emit countChanged();
}

int InstanceModel::indexOf(const QString& id) const
{
    for (int i = 0; i < rowCount(); i++) {
        if (data(index(i, 0), IdRole).toString() == id) {
            return i;
        }
    }
    return -1;
}

QVariantMap InstanceModel::get(const QString& id) const
{
    QVariantMap map;
    int row = indexOf(id);
    if (row < 0) {
        return map;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(index(row, 0), it.key()));
    }
    return map;
}

QString InstanceModel::versionText(MinecraftInstance* inst) const
{
    auto* profile = inst->getPackProfile();
    if (!profile) {
        return {};
    }
    QString mc = profile->getComponentVersion("net.minecraft");
    // If the profile isn't loaded yet, read mmc-pack.json directly (cheap, no network, no resolve).
    QHash<QString, QString> fromFile;
    if (mc.isEmpty()) {
        QFile f(QDir(inst->instanceRoot()).filePath("mmc-pack.json"));
        if (f.open(QIODevice::ReadOnly)) {
            const auto comps = QJsonDocument::fromJson(f.readAll()).object().value("components").toArray();
            for (const auto& c : comps) {
                const auto o = c.toObject();
                fromFile.insert(o.value("uid").toString(), o.value("version").toString(o.value("cachedVersion").toString()));
            }
        }
        mc = fromFile.value("net.minecraft");
    }
    static const QList<QPair<QString, QString>> loaders = {
        { "net.neoforged", "NeoForge" },
        { "net.minecraftforge", "Forge" },
        { "net.fabricmc.fabric-loader", "Fabric" },
        { "org.quiltmc.quilt-loader", "Quilt" },
        { "com.mumfrey.liteloader", "LiteLoader" },
    };
    QStringList parts;
    parts << (mc.isEmpty() ? tr("Minecraft") : tr("Minecraft %1").arg(mc));
    for (const auto& [uid, label] : loaders) {
        const auto v = fromFile.isEmpty() ? profile->getComponentVersion(uid) : fromFile.value(uid);
        if (!v.isEmpty()) {
            parts << QString("%1 %2").arg(label, v);
            break;
        }
    }
    return parts.join(QStringLiteral("  ·  "));
}

bool InstanceModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    auto idx = sourceModel()->index(sourceRow, 0, sourceParent);
    auto* inst = static_cast<BaseInstance*>(sourceModel()->data(idx, InstanceList::InstancePointerRole).value<void*>());
    if (!inst) {
        return false;
    }
    if (!m_groupFilter.isEmpty()) {
        const auto group = APPLICATION->instances()->getInstanceGroup(inst->id());
        if (m_groupFilter == "__ungrouped__" ? !group.isEmpty() : group != m_groupFilter) {
            return false;
        }
    }
    if (m_filterText.isEmpty()) {
        return true;
    }
    return inst->name().contains(m_filterText, Qt::CaseInsensitive) ||
           APPLICATION->instances()->getInstanceGroup(inst->id()).contains(m_filterText, Qt::CaseInsensitive);
}

bool InstanceModel::lessThan(const QModelIndex& left, const QModelIndex& right) const
{
    auto* a = static_cast<BaseInstance*>(sourceModel()->data(left, InstanceList::InstancePointerRole).value<void*>());
    auto* b = static_cast<BaseInstance*>(sourceModel()->data(right, InstanceList::InstancePointerRole).value<void*>());
    if (!a || !b) {
        return false;
    }
    if (m_sortMode == "lastPlayed" && a->lastLaunch() != b->lastLaunch()) {
        return a->lastLaunch() > b->lastLaunch();
    }
    return QString::localeAwareCompare(a->name(), b->name()) < 0;
}
