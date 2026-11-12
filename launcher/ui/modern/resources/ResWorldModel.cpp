#include "ResWorldModel.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QProcess>
#include <QUrl>

#include "Application.h"
#include "Commandline.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "InstanceModel.h"
#include "Json.h"
#include "ResImages.h"
#include "ResTask.h"
#include "StringUtils.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/World.h"
#include "minecraft/WorldList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "minecraft/launch/MinecraftTarget.h"
#include "settings/Setting.h"
#include "settings/SettingsObject.h"
#include "tasks/ConcurrentTask.h"
#include "tasks/SequentialTask.h"

namespace {
QHash<WorldList*, int>& worldWatchCounts()
{
    static QHash<WorldList*, int> c;
    return c;
}
}  // namespace

ResWorldModel::ResWorldModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    setSortCaseSensitivity(Qt::CaseInsensitive);
    connect(APPLICATION->settings()->getSetting("WorldTools").get(), &Setting::SettingChanged, this, &ResWorldModel::worldToolsChanged);
}

ResWorldModel::~ResWorldModel()
{
    if (m_worlds) {
        auto it = worldWatchCounts().find(m_worlds);
        if (it != worldWatchCounts().end() && --it.value() <= 0) {
            worldWatchCounts().erase(it);
            m_worlds->stopWatching();
        }
    }
}

void ResWorldModel::componentComplete()
{
    m_complete = true;
    ResImages::ensure(qmlEngine(this));
    rebind();
}

void ResWorldModel::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    m_instanceId = id;
    rebind();
}

void ResWorldModel::rebind()
{
    if (!m_complete) {
        return;
    }
    for (auto& c : m_conns) {
        disconnect(c);
    }
    m_conns.clear();
    if (m_worlds) {
        auto it = worldWatchCounts().find(m_worlds);
        if (it != worldWatchCounts().end() && --it.value() <= 0) {
            worldWatchCounts().erase(it);
            m_worlds->stopWatching();
        }
    }
    setSourceModel(nullptr);
    m_selected.clear();
    m_instance = APPLICATION->instances()->getInstanceById(m_instanceId);
    m_worlds = m_instance ? m_instance->worldList() : nullptr;
    if (m_worlds) {
        setSourceModel(m_worlds);
        if (worldWatchCounts()[m_worlds]++ == 0) {
            m_worlds->startWatching();
        }
        auto counts = [this] { emit countChanged(); };
        m_conns << connect(m_worlds, &QAbstractItemModel::rowsInserted, this, counts);
        m_conns << connect(m_worlds, &QAbstractItemModel::rowsRemoved, this, counts);
        m_conns << connect(m_worlds, &QAbstractItemModel::modelReset, this, [this] {
            QSet<QString> alive;
            for (const auto& w : m_worlds->allWorlds()) {
                alive.insert(w.folderName());
            }
            m_selected.intersect(alive);
            emit countChanged();
            emit selectionChanged();
        });
        m_conns << connect(m_instance, &BaseInstance::runningStatusChanged, this, &ResWorldModel::instanceRunningChanged);
        sort(0, Qt::AscendingOrder);
    }
    emit sourceChanged();
    emit countChanged();
    emit selectionChanged();
    emit instanceRunningChanged();
}

bool ResWorldModel::supportsJoin() const
{
    return m_instance && m_instance->traits().contains("feature:is_quick_play_singleplayer");
}

bool ResWorldModel::instanceRunning() const
{
    return m_instance && m_instance->isRunning();
}

QString ResWorldModel::dirPath() const
{
    return m_worlds ? m_worlds->dir().absolutePath() : QString();
}

void ResWorldModel::setFilterText(const QString& t)
{
    if (t == m_filterText) {
        return;
    }
    m_filterText = t;
    invalidateFilter();
    emit filterTextChanged();
    emit countChanged();
}

void ResWorldModel::setSortKey(const QString& k)
{
    if (k == m_sortKey) {
        return;
    }
    m_sortKey = k;
    invalidate();
    sort(0, Qt::AscendingOrder);
    emit sortChanged();
}

int ResWorldModel::totalCount() const
{
    return m_worlds ? static_cast<int>(m_worlds->size()) : 0;
}

bool ResWorldModel::filterAcceptsRow(int sourceRow, const QModelIndex&) const
{
    if (!m_worlds || sourceRow >= m_worlds->size()) {
        return false;
    }
    if (m_filterText.isEmpty()) {
        return true;
    }
    const auto& w = m_worlds->allWorlds().at(sourceRow);
    return w.name().contains(m_filterText, Qt::CaseInsensitive) || w.folderName().contains(m_filterText, Qt::CaseInsensitive);
}

bool ResWorldModel::lessThan(const QModelIndex& left, const QModelIndex& right) const
{
    const auto& l = m_worlds->allWorlds().at(left.row());
    const auto& r = m_worlds->allWorlds().at(right.row());
    if (m_sortKey == "lastPlayed" && l.lastPlayed() != r.lastPlayed()) {
        return l.lastPlayed() > r.lastPlayed();  // most recent first
    }
    if (m_sortKey == "size" && l.bytes() != r.bytes()) {
        return l.bytes() > r.bytes();
    }
    if (m_sortKey == "gameMode") {
        const auto lg = l.gameType().toTranslatedString(), rg = r.gameType().toTranslatedString();
        if (lg != rg) {
            return QString::localeAwareCompare(lg, rg) < 0;
        }
    }
    return QString::localeAwareCompare(l.name(), r.name()) < 0;
}

QHash<int, QByteArray> ResWorldModel::roleNames() const
{
    return { { NameRole, "name" },           { FolderNameRole, "folderName" }, { GameModeRole, "gameMode" },
             { LastPlayedTextRole, "lastPlayedText" }, { LastPlayedRole, "lastPlayed" }, { SizeTextRole, "sizeText" },
             { SeedRole, "seed" },           { IconSourceRole, "iconSource" }, { LinkedRole, "linked" },
             { SelectedRole, "selected" },   { PathRole, "path" } };
}

int ResWorldModel::sourceRow(int proxyRow) const
{
    if (!m_worlds || proxyRow < 0 || proxyRow >= rowCount()) {
        return -1;
    }
    return mapToSource(index(proxyRow, 0)).row();
}

const World* ResWorldModel::worldAt(int proxyRow) const
{
    const int s = sourceRow(proxyRow);
    if (s < 0 || s >= m_worlds->size()) {
        return nullptr;
    }
    return &m_worlds->allWorlds().at(s);
}

int ResWorldModel::rowOfFolder(const QString& folder) const
{
    for (int i = 0; i < rowCount(); ++i) {
        if (auto* w = worldAt(i); w && w->folderName() == folder) {
            return i;
        }
    }
    return -1;
}

QVariant ResWorldModel::data(const QModelIndex& idx, int role) const
{
    auto* w = worldAt(idx.row());
    if (!w) {
        return {};
    }
    switch (role) {
        case Qt::DisplayRole:
        case NameRole:
            return w->name();
        case FolderNameRole:
            return w->folderName();
        case GameModeRole:
            return w->gameType().toTranslatedString();
        case LastPlayedTextRole:
            return w->lastPlayed().isValid() ? InstanceModel::relativeTime(w->lastPlayed().toMSecsSinceEpoch()) : tr("Never");
        case LastPlayedRole:
            return w->lastPlayed().toMSecsSinceEpoch();
        case SizeTextRole:
            return w->bytes() >= 0 ? StringUtils::humanReadableFileSize(static_cast<double>(w->bytes())) : QString("…");
        case SeedRole:
            return QString::number(w->seed());
        case IconSourceRole: {
            const auto f = w->iconFile();
            if (f.isEmpty()) {
                return QString();
            }
            return QUrl::fromLocalFile(f).toString() + "?t=" + QString::number(QFileInfo(f).lastModified().toMSecsSinceEpoch());
        }
        case LinkedRole:
            return m_worlds->data(m_worlds->index(sourceRow(idx.row()), 0), WorldList::LinkedRole);
        case SelectedRole:
            return m_selected.contains(w->folderName());
        case PathRole:
            return w->container().absoluteFilePath();
        default:
            return {};
    }
}

int ResWorldModel::currentRow() const
{
    return m_current.isEmpty() ? -1 : rowOfFolder(m_current);
}

void ResWorldModel::select(int row, const QString& mode)
{
    auto* w = worldAt(row);
    if (!w) {
        return;
    }
    const auto id = w->folderName();
    if (mode == "toggle") {
        if (m_selected.contains(id)) {
            m_selected.remove(id);
        } else {
            m_selected.insert(id);
        }
        m_anchor = id;
    } else if (mode == "range" && !m_anchor.isEmpty()) {
        int a = rowOfFolder(m_anchor);
        if (a < 0) {
            a = row;
        }
        m_selected.clear();
        for (int i = qMin(a, row); i <= qMax(a, row); ++i) {
            if (auto* ww = worldAt(i)) {
                m_selected.insert(ww->folderName());
            }
        }
    } else {
        m_selected = { id };
        m_anchor = id;
    }
    m_current = id;
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { SelectedRole });
    }
    emit selectionChanged();
}

void ResWorldModel::selectAll()
{
    for (int i = 0; i < rowCount(); ++i) {
        if (auto* w = worldAt(i)) {
            m_selected.insert(w->folderName());
        }
    }
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { SelectedRole });
    }
    emit selectionChanged();
}

void ResWorldModel::clearSelection()
{
    m_selected.clear();
    m_current.clear();
    if (rowCount() > 0) {
        emit dataChanged(index(0, 0), index(rowCount() - 1, 0), { SelectedRole });
    }
    emit selectionChanged();
}

QVariantMap ResWorldModel::get(int row) const
{
    QVariantMap m;
    if (!worldAt(row)) {
        return m;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        m[QString::fromUtf8(it.value())] = data(index(row, 0), it.key());
    }
    m["lastPlayedFull"] = QLocale().toString(worldAt(row)->lastPlayed(), QLocale::ShortFormat);
    return m;
}

bool ResWorldModel::anySelectedHasIcon() const
{
    if (!m_worlds) {
        return false;
    }
    for (const auto& w : m_worlds->allWorlds()) {
        if (m_selected.contains(w.folderName()) && !w.iconFile().isEmpty()) {
            return true;
        }
    }
    return false;
}

QStringList ResWorldModel::worldTools() const
{
    return Json::toMap(APPLICATION->settings()->get("WorldTools").toString()).keys();
}

ResTaskHandle* ResWorldModel::runWithWatchPaused(Task* task, const QString& title)
{
    if (!task) {
        return nullptr;
    }
    QPointer<WorldList> worlds = m_worlds;
    if (worlds) {
        worlds->stopWatching();
    }
    auto* h = ResTaskHandle::run(Task::Ptr(task), title, this);
    connect(h, &ResTaskHandle::done, this, [worlds] {
        if (worlds) {
            worlds->startWatching();
            worlds->update();
        }
    });
    return h;
}

ResTaskHandle* ResWorldModel::addWorlds(const QList<QUrl>& zips)
{
    if (!m_worlds || zips.isEmpty()) {
        return nullptr;
    }
    auto* seq = new SequentialTask(tr("Adding worlds"));
    for (const auto& u : zips) {
        auto t = m_worlds->createInstallWorldTask(QFileInfo(u.isLocalFile() ? u.toLocalFile() : u.toString()));
        if (t) {
            seq->addTask(Task::Ptr(t.release()));
        }
    }
    return runWithWatchPaused(seq, tr("Adding worlds…"));
}

ResTaskHandle* ResWorldModel::copyWorld(int row, const QString& name)
{
    const int s = sourceRow(row);
    if (s < 0 || name.trimmed().isEmpty()) {
        return nullptr;
    }
    auto t = m_worlds->createCopyWorldTask(s, name.trimmed());
    return runWithWatchPaused(t.release(), tr("Copying world…"));
}

ResTaskHandle* ResWorldModel::deleteSelected()
{
    if (!m_worlds || m_selected.isEmpty()) {
        return nullptr;
    }
    auto* task = new ConcurrentTask(tr("Deleting worlds"));
    for (int i = 0; i < m_worlds->size(); ++i) {
        if (m_selected.contains(m_worlds->allWorlds().at(i).folderName())) {
            if (auto del = m_worlds->createDeleteWorldTask(i)) {
                task->addTask(Task::Ptr(del.release()));
            }
        }
    }
    m_selected.clear();
    m_current.clear();
    emit selectionChanged();
    return runWithWatchPaused(task, tr("Deleting worlds…"));
}

bool ResWorldModel::renameWorld(int row, const QString& name)
{
    const int s = sourceRow(row);
    if (s < 0 || name.trimmed().isEmpty()) {
        return false;
    }
    return (*m_worlds)[s].rename(name.trimmed());
}

void ResWorldModel::resetSelectedIcons()
{
    if (!m_worlds) {
        return;
    }
    for (int i = 0; i < m_worlds->size(); ++i) {
        if (m_selected.contains(m_worlds->allWorlds().at(i).folderName())) {
            m_worlds->resetIcon(i);
        }
    }
    emit selectionChanged();
}

void ResWorldModel::copySeed(int row)
{
    if (auto* w = worldAt(row)) {
        QGuiApplication::clipboard()->setText(QString::number(w->seed()));
    }
}

void ResWorldModel::openFolder(int row)
{
    if (auto* w = worldAt(row)) {
        DesktopServices::openPath(w->container().absoluteFilePath(), true);
    } else if (m_worlds) {
        DesktopServices::openPath(m_worlds->dir().absolutePath(), true);
    }
}

bool ResWorldModel::join(int row)
{
    auto* w = worldAt(row);
    if (!w || !supportsJoin()) {
        return false;
    }
    return APPLICATION->launch(m_instance, LaunchMode::Normal, std::make_shared<MinecraftTarget>(MinecraftTarget::parse(w->folderName(), true)));
}

void ResWorldModel::refresh()
{
    if (m_worlds) {
        m_worlds->update();
    }
}

QString ResWorldModel::launchTool(int row, const QString& toolName)
{
    auto* w = worldAt(row);
    if (!w) {
        return tr("No world selected.");
    }
    const auto tools = Json::toMap(APPLICATION->settings()->get("WorldTools").toString());
    const auto command = tools.value(toolName).toString();
    QProcessEnvironment vars;
    const auto folderPath = w->container().absoluteFilePath();
    vars.insert("WORLD_PATH", folderPath);
    auto args = Commandline::process(command, vars);
    if (args.isEmpty()) {
        return tr("The tool command is empty.");
    }
    const auto program = args.takeFirst();
    auto* process = new QProcess(this);
    process->setWorkingDirectory(folderPath);
    connect(process, &QProcess::finished, process, &QObject::deleteLater);
    process->start(program, args);
    if (!process->waitForStarted()) {
        const auto err = process->errorString();
        process->deleteLater();
        return tr("The tool could not be started: %1").arg(err);
    }
    return {};
}

QString ResWorldModel::datapacksFolder(int row) const
{
    auto* w = worldAt(row);
    return w ? FS::PathCombine(w->container().absoluteFilePath(), "datapacks") : QString();
}
