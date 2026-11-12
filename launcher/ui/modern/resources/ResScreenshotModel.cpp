#include "ResScreenshotModel.h"

#include <QClipboard>
#include <QDir>
#include <QGuiApplication>
#include <QImage>
#include <QImageReader>
#include <QLocale>
#include <QMimeData>
#include <QUrl>
#include <algorithm>

#include "Application.h"
#include "BuildConfig.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "ResImages.h"
#include "ResTask.h"
#include "StringUtils.h"
#include "minecraft/MinecraftInstance.h"
#include "net/NetJob.h"
#include "screenshots/ImgurAPI.h"
#include "tasks/SequentialTask.h"

namespace {
bool isImage(const QString& name)
{
    const auto lower = name.toLower();
    return lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg");
}
}  // namespace

ResScreenshotModel::ResScreenshotModel(QObject* parent) : QAbstractListModel(parent)
{
    m_rescan.setSingleShot(true);
    m_rescan.setInterval(250);
    connect(&m_rescan, &QTimer::timeout, this, &ResScreenshotModel::scan);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_rescan.start(); });
}

void ResScreenshotModel::componentComplete()
{
    m_complete = true;
    ResImages::ensure(qmlEngine(this));
    auto id = m_instanceId;
    m_instanceId.clear();
    setInstanceId(id);
}

void ResScreenshotModel::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    m_instanceId = id;
    if (!m_complete) {
        return;
    }
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    m_folder.clear();
    if (auto* inst = APPLICATION->instances()->getInstanceById(id)) {
        m_folder = FS::PathCombine(inst->gameRoot(), "screenshots");
        FS::ensureFolderPathExists(m_folder);
        m_watcher.addPath(m_folder);
    }
    m_selected.clear();
    scan();
    emit sourceChanged();
    emit selectionChanged();
}

void ResScreenshotModel::scan()
{
    QList<Entry> files;
    if (!m_folder.isEmpty()) {
        const auto infos = QDir(m_folder).entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::Time);
        for (const auto& fi : infos) {
            if (isImage(fi.fileName())) {
                files << Entry{ fi.absoluteFilePath(), fi.fileName(), fi.lastModified(), fi.size() };
            }
        }
    }
    // keep stable rows when nothing changed (avoids thumbnail flicker)
    bool same = files.size() == m_files.size();
    for (int i = 0; same && i < files.size(); ++i) {
        same = files[i].path == m_files[i].path && files[i].modified == m_files[i].modified;
    }
    if (same) {
        return;
    }
    beginResetModel();
    m_files = files;
    QSet<QString> alive;
    for (const auto& f : m_files) {
        alive.insert(f.path);
    }
    m_selected.intersect(alive);
    endResetModel();
    emit countChanged();
    emit selectionChanged();
}

void ResScreenshotModel::refresh()
{
    scan();
}

QHash<int, QByteArray> ResScreenshotModel::roleNames() const
{
    return { { FileNameRole, "fileName" }, { BaseNameRole, "baseName" }, { PathRole, "path" },         { UrlRole, "url" },
             { ThumbRole, "thumb" },       { DateTextRole, "dateText" }, { SizeTextRole, "sizeText" }, { SelectedRole, "selected" } };
}

QVariant ResScreenshotModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_files.size()) {
        return {};
    }
    const auto& f = m_files.at(index.row());
    switch (role) {
        case FileNameRole:
            return f.fileName;
        case BaseNameRole:
            return QFileInfo(f.fileName).completeBaseName();
        case PathRole:
            return f.path;
        case UrlRole:
            return QUrl::fromLocalFile(f.path).toString() + "?t=" + QString::number(f.modified.toMSecsSinceEpoch());
        case ThumbRole:
            return ResImages::thumbUrl(f.path, f.modified.toMSecsSinceEpoch());
        case DateTextRole:
            return QLocale().toString(f.modified, QLocale::ShortFormat);
        case SizeTextRole:
            return StringUtils::humanReadableFileSize(static_cast<double>(f.size));
        case SelectedRole:
            return m_selected.contains(f.path);
        default:
            return {};
    }
}

QVariantMap ResScreenshotModel::get(int row) const
{
    QVariantMap m;
    if (row < 0 || row >= m_files.size()) {
        return m;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        m[QString::fromUtf8(it.value())] = data(index(row), it.key());
    }
    QImageReader reader(m_files.at(row).path);
    const auto sz = reader.size();
    m["dimensions"] = sz.isValid() ? QString("%1 × %2").arg(sz.width()).arg(sz.height()) : QString();
    return m;
}

void ResScreenshotModel::select(int row, const QString& mode)
{
    if (row < 0 || row >= m_files.size()) {
        return;
    }
    const auto id = m_files.at(row).path;
    if (mode == "toggle") {
        if (m_selected.contains(id)) {
            m_selected.remove(id);
        } else {
            m_selected.insert(id);
        }
        m_anchor = row;
    } else if (mode == "range" && m_anchor >= 0) {
        m_selected.clear();
        for (int i = qMin(m_anchor, row); i <= qMax(m_anchor, row) && i < m_files.size(); ++i) {
            m_selected.insert(m_files.at(i).path);
        }
    } else {
        m_selected = { id };
        m_anchor = row;
    }
    emit dataChanged(index(0), index(static_cast<int>(m_files.size()) - 1), { SelectedRole });
    emit selectionChanged();
}

void ResScreenshotModel::selectAll()
{
    for (const auto& f : m_files) {
        m_selected.insert(f.path);
    }
    if (!m_files.isEmpty()) {
        emit dataChanged(index(0), index(static_cast<int>(m_files.size()) - 1), { SelectedRole });
    }
    emit selectionChanged();
}

void ResScreenshotModel::clearSelection()
{
    m_selected.clear();
    if (!m_files.isEmpty()) {
        emit dataChanged(index(0), index(static_cast<int>(m_files.size()) - 1), { SelectedRole });
    }
    emit selectionChanged();
}

QStringList ResScreenshotModel::selectedPaths() const
{
    QStringList out;
    for (const auto& f : m_files) {
        if (m_selected.contains(f.path)) {
            out << f.path;
        }
    }
    return out;
}

void ResScreenshotModel::openFolder()
{
    DesktopServices::openPath(m_folder, true);
}

void ResScreenshotModel::copyImage(int row)
{
    if (row < 0 || row >= m_files.size()) {
        return;
    }
    const QImage image(m_files.at(row).path);
    if (!image.isNull()) {
        QGuiApplication::clipboard()->setImage(image, QClipboard::Clipboard);
    }
}

void ResScreenshotModel::copySelectedFiles()
{
    const auto paths = selectedPaths();
    if (paths.isEmpty()) {
        return;
    }
    QList<QUrl> urls;
    for (const auto& p : paths) {
        urls << QUrl::fromLocalFile(p);
    }
    auto* mime = new QMimeData();
    mime->setUrls(urls);
    QGuiApplication::clipboard()->setMimeData(mime);
}

int ResScreenshotModel::deleteSelected()
{
    int n = 0;
    for (const auto& p : selectedPaths()) {
        if (FS::trash(p) || QFile::remove(p)) {
            ResImages::dropThumb(p);
            n++;
        }
    }
    m_selected.clear();
    scan();
    emit selectionChanged();
    return n;
}

QString ResScreenshotModel::rename(int row, const QString& newBaseName)
{
    if (row < 0 || row >= m_files.size()) {
        return tr("Nothing selected.");
    }
    const auto name = newBaseName.trimmed();
    if (name.isEmpty() || name.contains('/') || name.contains('\\')) {
        return tr("Invalid file name.");
    }
    const QFileInfo fi(m_files.at(row).path);
    const auto target = FS::PathCombine(fi.absolutePath(), name + "." + fi.suffix());
    if (target == fi.absoluteFilePath()) {
        return {};
    }
    if (QFileInfo::exists(target)) {
        return tr("A file with that name already exists.");
    }
    if (!QFile::rename(fi.absoluteFilePath(), target)) {
        return tr("Could not rename the file.");
    }
    ResImages::dropThumb(fi.absoluteFilePath());
    m_selected.remove(fi.absoluteFilePath());
    scan();
    return {};
}

void ResScreenshotModel::addFiles(const QList<QUrl>& urls)
{
    for (const auto& u : urls) {
        const QFileInfo fi(u.isLocalFile() ? u.toLocalFile() : u.toString());
        if (!fi.isFile() || !isImage(fi.fileName()) || fi.absolutePath() == QDir(m_folder).absolutePath()) {
            continue;
        }
        auto target = FS::PathCombine(m_folder, fi.fileName());
        int i = 1;
        while (QFileInfo::exists(target)) {
            target = FS::PathCombine(m_folder, QString("%1_%2.%3").arg(fi.completeBaseName()).arg(i++).arg(fi.suffix()));
        }
        QFile::copy(fi.absoluteFilePath(), target);
    }
    scan();
}

QString ResScreenshotModel::uploadHost() const
{
    return QUrl(BuildConfig.IMGUR_BASE_URL).host();
}

ResTaskHandle* ResScreenshotModel::uploadSelected()
{
    const auto paths = selectedPaths();
    if (paths.isEmpty() || m_uploading) {
        return nullptr;
    }
    m_lastLink.clear();
    auto job = makeShared<NetJob>("Screenshot Upload", APPLICATION->network());
    Task::Ptr root;
    std::function<void()> collect;
    if (paths.size() == 1) {
        auto [req, result] = ImgurAPI::makeUpload(std::make_shared<ScreenShot>(QFileInfo(paths.first())));
        job->addNetAction(req);
        root = job;
        collect = [this, result] { m_lastLink = *result; };
    } else {
        QList<ScreenShot::Ptr> shots;
        for (const auto& p : paths) {
            auto shot = std::make_shared<ScreenShot>(QFileInfo(p));
            shots << shot;
            job->addNetAction(ImgurAPI::makeUpload(shot).first);
        }
        auto albumJob = makeShared<NetJob>("Imgur Album Creation", APPLICATION->network());
        auto [album, result] = ImgurAPI::makeAlbum(shots);
        albumJob->addNetAction(album);
        auto seq = makeShared<SequentialTask>();
        seq->addTask(job);
        seq->addTask(albumJob);
        root = seq;
        collect = [this, result] {
            if (!result->id.isEmpty()) {
                m_lastLink = QString("https://imgur.com/a/%1").arg(result->id);
            }
        };
    }
    m_uploading = true;
    emit uploadingChanged();
    auto* h = ResTaskHandle::run(root, tr("Uploading screenshots…"), this);
    connect(h, &ResTaskHandle::done, this, [this, collect](bool ok) {
        if (ok) {
            collect();
            if (!m_lastLink.isEmpty()) {
                QGuiApplication::clipboard()->setText(m_lastLink);
            }
        }
        m_uploading = false;
        emit uploadingChanged();
    });
    return h;
}
