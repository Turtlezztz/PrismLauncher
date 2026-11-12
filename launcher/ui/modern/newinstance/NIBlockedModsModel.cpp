#include "NIBlockedModsModel.h"

#include <QDir>
#include <QDirListing>
#include <QFileInfo>
#include <QUrl>

#include "Application.h"
#include "DesktopServices.h"
#include "modplatform/helpers/HashUtils.h"
#include "settings/SettingsObject.h"

NIBlockedModsModel::NIBlockedModsModel(QList<BlockedMod>& mods, QString hashType, QObject* parent)
    : QAbstractListModel(parent), m_mods(mods), m_hashType(std::move(hashType))
{
    m_hashingTask = shared_qobject_ptr<ConcurrentTask>(
        new ConcurrentTask("MakeHashesTask", APPLICATION->settings()->get("NumberOfConcurrentTasks").toInt()));
    connect(m_hashingTask.get(), &Task::finished, this, [this] {
        if (m_rehashPending) {
            runHashTask();
        }
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &NIBlockedModsModel::directoryChanged);
}

QHash<int, QByteArray> NIBlockedModsModel::roleNames() const
{
    return { { NameRole, "name" }, { UrlRole, "websiteUrl" }, { HashRole, "hash" }, { MatchedRole, "matched" }, { PathRole, "localPath" } };
}

QVariant NIBlockedModsModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_mods.size()) {
        return {};
    }
    const auto& m = m_mods.at(index.row());
    switch (role) {
        case NameRole:
            return m.name;
        case UrlRole:
            return m.websiteUrl;
        case HashRole:
            return m.hash;
        case MatchedRole:
            return m.matched;
        case PathRole:
            return m.localPath;
        default:
            return {};
    }
}

int NIBlockedModsModel::matchedCount() const
{
    return static_cast<int>(std::ranges::count_if(m_mods, [](const BlockedMod& m) { return m.matched; }));
}

void NIBlockedModsModel::start()
{
    const QString downloadsFolder = APPLICATION->settings()->get("DownloadsDir").toString();
    const QString modsFolder = APPLICATION->settings()->get("CentralModsDir").toString();
    watchPath(downloadsFolder, APPLICATION->settings()->get("DownloadsDirWatchRecursive").toBool());
    watchPath(modsFolder, true);
    scanPaths();
    refresh();
}

void NIBlockedModsModel::stop()
{
    disconnect(&m_watcher, nullptr, this, nullptr);
    if (m_hashingTask->isRunning()) {
        m_hashingTask->abort();
    }
}

void NIBlockedModsModel::refresh()
{
    if (!m_mods.isEmpty()) {
        emit dataChanged(index(0), index(static_cast<int>(m_mods.size()) - 1));
    }
    emit changed();
}

void NIBlockedModsModel::openMissing()
{
    for (const auto& mod : m_mods) {
        if (!mod.matched) {
            DesktopServices::openUrl(QUrl(mod.websiteUrl));
        }
    }
}

void NIBlockedModsModel::openUrl(int row)
{
    if (row >= 0 && row < m_mods.size()) {
        DesktopServices::openUrl(QUrl(m_mods.at(row).websiteUrl));
    }
}

void NIBlockedModsModel::addFolder(const QUrl& folder)
{
    const auto dir = folder.isLocalFile() ? folder.toLocalFile() : folder.toString();
    if (dir.isEmpty()) {
        return;
    }
    m_watcher.addPath(dir);
    scanPath(dir, true);
    refresh();
}

void NIBlockedModsModel::addFiles(const QList<QUrl>& files)
{
    for (auto url : files) {
        if (url.scheme().isEmpty()) {
            url.setScheme("file");
        }
        if (!url.isLocalFile()) {
            continue;
        }
        const auto path = url.toLocalFile();
        QFileInfo fi(path);
        if (fi.isDir()) {
            m_watcher.addPath(path);
            scanPath(path, false);
            continue;
        }
        m_pendingHashPaths.insert(path);
        m_watcher.addPath(fi.dir().absolutePath());
    }
    scanPaths();
    refresh();
}

void NIBlockedModsModel::directoryChanged(const QString& path)
{
    validateMatchedMods();
    scanPath(path, true);
}

void NIBlockedModsModel::watchPath(const QString& path, bool recursive)
{
    auto toWatch = QFileInfo(path);
    if (!toWatch.isReadable()) {
        return;
    }
    auto toWatchPath = toWatch.canonicalFilePath();
    if (m_watcher.directories().contains(toWatchPath)) {
        return;
    }
    m_watcher.addPath(toWatchPath);
    if (!toWatch.isDir() || !recursive) {
        return;
    }
    for (const auto& entry : QDirListing(toWatchPath, QDirListing::IteratorFlag::DirsOnly | QDirListing::IteratorFlag::ResolveSymlinks)) {
        watchPath(entry.canonicalFilePath(), recursive);
    }
}

void NIBlockedModsModel::scanPaths()
{
    for (const auto& dir : m_watcher.directories()) {
        scanPath(dir, false);
    }
    runHashTask();
}

void NIBlockedModsModel::scanPath(const QString& path, bool startTask)
{
    for (const auto& entry : QDirListing(path, QDirListing::IteratorFlag::FilesOnly | QDirListing::IteratorFlag::ResolveSymlinks |
                                                   QDirListing::IteratorFlag::IncludeHidden)) {
        const auto file = entry.absoluteFilePath();
        if (checkValidPath(file)) {
            m_pendingHashPaths.insert(file);
        }
    }
    if (startTask) {
        runHashTask();
    }
}

void NIBlockedModsModel::runHashTask()
{
    if (m_hashingTask->isRunning()) {
        m_rehashPending = true;
        return;
    }
    m_rehashPending = false;
    if (m_pendingHashPaths.isEmpty()) {
        return;
    }
    for (const auto& path : std::as_const(m_pendingHashPaths)) {
        auto hashTask = Hashing::createHasher(path, m_hashType);
        connect(hashTask.get(), &Task::succeeded, this, [this, hashTask, path] { checkMatchHash(hashTask->getResult(), path); });
        m_hashingTask->addTask(hashTask);
    }
    m_pendingHashPaths.clear();
    m_hashingTask->start();
}

void NIBlockedModsModel::checkMatchHash(const QString& hash, const QString& path)
{
    auto downloadDir = QFileInfo(APPLICATION->settings()->get("DownloadsDir").toString()).absoluteFilePath();
    auto moveFiles = APPLICATION->settings()->get("MoveModsFromDownloadsDir").toBool();
    for (auto& mod : m_mods) {
        if (mod.matched) {
            continue;
        }
        if (mod.hash.compare(hash, Qt::CaseInsensitive) == 0) {
            mod.matched = true;
            mod.localPath = path;
            if (moveFiles) {
                mod.move = QFileInfo(path).absoluteFilePath().startsWith(downloadDir);
            }
            refresh();
            return;
        }
    }
}

bool NIBlockedModsModel::checkValidPath(const QString& path)
{
    const QString filename = QFileInfo(path).fileName();
    auto lax = [](QString a, QString b) {
        a = a.toLower();
        b = b.toLower();
        for (QChar sep : { '-', '+', '.', '_' }) {
            a.replace(sep, ' ');
            b.replace(sep, ' ');
        }
        return a.simplified() == b.simplified();
    };
    auto downloadDir = QFileInfo(APPLICATION->settings()->get("DownloadsDir").toString()).absoluteFilePath();
    auto moveFiles = APPLICATION->settings()->get("MoveModsFromDownloadsDir").toBool();
    for (auto& mod : m_mods) {
        if (mod.name.compare(filename, Qt::CaseInsensitive) == 0) {
            if (!mod.matched && mod.hash.isEmpty()) {
                mod.matched = true;
                mod.localPath = path;
                if (moveFiles) {
                    mod.move = QFileInfo(path).absoluteFilePath().startsWith(downloadDir);
                }
                return false;
            }
            return true;
        }
        if (lax(filename, mod.name)) {
            return true;
        }
    }
    return false;
}

void NIBlockedModsModel::validateMatchedMods()
{
    bool changedAny = false;
    for (auto& mod : m_mods) {
        if (mod.matched) {
            QFileInfo file(mod.localPath);
            if (!file.exists() || !file.isFile()) {
                mod.localPath.clear();
                mod.matched = false;
                changedAny = true;
            }
        }
    }
    if (changedAny) {
        refresh();
    }
}
