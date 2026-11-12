#include "LogViewModel.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>

#include "Application.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "GZip.h"
#include "InstanceList.h"
#include "launch/LaunchTask.h"
#include "launch/LogModel.h"
#include "logs/LogParser.h"
#include "minecraft/MinecraftInstance.h"
#include "net/PasteUpload.h"
#include "settings/SettingsObject.h"
#include "ui/GuiUtil.h"

namespace {
constexpr int g_maxMclogsLines = 25000;
constexpr int g_initialMclogsLines = 10000;
constexpr int g_finalMclogsLines = 14900;

QString truncateForMclogs(const QString& log)
{
    const QStringList lines = log.split("\n");
    if (lines.size() <= g_maxMclogsLines) {
        return log;
    }
    QString out = lines.mid(0, g_initialMclogsLines).join("\n");
    out +=
        "\n\n\n\n\n\n\n\n\n\n"
        "------------------------------------------------------------\n"
        "----------------------- Log truncated ----------------------\n"
        "------------------------------------------------------------\n"
        "----- Middle portion omitted to fit mclo.gs size limits ----\n"
        "------------------------------------------------------------\n"
        "\n\n\n\n\n\n\n\n\n\n";
    out += lines.mid(lines.size() - g_finalMclogsLines - 1).join("\n");
    return out;
}
}  // namespace

LogViewModel::LogViewModel(QObject* parent) : QIdentityProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &LogViewModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &LogViewModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &LogViewModel::countChanged);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &LogViewModel::refreshFiles);
}

QHash<int, QByteArray> LogViewModel::roleNames() const
{
    return { { LineRole, "line" }, { LevelRole, "level" } };
}

QVariant LogViewModel::data(const QModelIndex& index, int role) const
{
    if (role == LineRole) {
        return QIdentityProxyModel::data(index, Qt::DisplayRole);
    }
    if (role == LevelRole) {
        return QIdentityProxyModel::data(index, LogModel::LevelRole);
    }
    return QIdentityProxyModel::data(index, role);
}

void LogViewModel::setMode(const QString& mode)
{
    if (mode == m_mode) {
        return;
    }
    m_mode = mode;
    rebuild();
}

void LogViewModel::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    m_instanceId = id;
    m_inst = APPLICATION->instances()->getInstanceById(id);
    rebuild();
}

void LogViewModel::setCurrentFile(const QString& file)
{
    if (file == m_currentFile) {
        return;
    }
    m_currentFile = file;
    if (m_mode == "launcher" && file.isEmpty()) {
        setLiveModel(APPLICATION->logModel.get());
    } else {
        loadFile();
    }
}

bool LogViewModel::live() const
{
    return m_mode == "console" || (m_mode == "launcher" && m_currentFile.isEmpty());
}

void LogViewModel::rebuild()
{
    disconnect(m_launchConn);
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    m_files.clear();
    if (m_mode == "console") {
        if (m_inst) {
            m_launchConn = connect(m_inst.data(), &BaseInstance::launchTaskChanged, this, &LogViewModel::attachLaunchTask);
            attachLaunchTask(m_inst->getLaunchTask());
        } else {
            setLiveModel(nullptr);
        }
    } else {
        refreshFiles();
        const QStringList paths = m_mode == "files" ? (m_inst ? m_inst->getLogFileSearchPaths() : QStringList{})
                                                    : QStringList{ QDir(APPLICATION->dataRoot()).filePath("logs") };
        for (const auto& p : paths) {
            if (QFileInfo(p).isDir()) {
                m_watcher.addPath(p);
            }
        }
        if (m_mode == "launcher" && m_currentFile.isEmpty()) {
            setLiveModel(APPLICATION->logModel.get());
        } else {
            if (m_currentFile.isEmpty() && !m_files.isEmpty()) {
                m_currentFile = m_files.first();
            }
            loadFile();
        }
    }
    emit filesChanged();
}

void LogViewModel::attachLaunchTask(LaunchTask* task)
{
    if (task) {
        m_liveHolder = task->getLogModel();
        setLiveModel(m_liveHolder.get());
        emit restarted();
    } else {
        // keep showing the last log if there is one
        if (!m_liveHolder) {
            setLiveModel(nullptr);
        }
    }
}

void LogViewModel::setLiveModel(LogModel* model)
{
    m_message.clear();
    m_model = model;
    setSourceModel(model);
    if (model) {
        model->setColorLines(m_colorLines);
    }
    emit sourceChanged();
    emit optionsChanged();
    emit countChanged();
}

void LogViewModel::refreshFiles()
{
    QString basePath;
    QStringList searchPaths;
    if (m_mode == "files") {
        if (!m_inst) {
            return;
        }
        basePath = m_inst->gameRoot();
        searchPaths = m_inst->getLogFileSearchPaths();
    } else if (m_mode == "launcher") {
        basePath = APPLICATION->dataRoot();
        searchPaths = { QDir(basePath).filePath("logs") };
    } else {
        return;
    }
    QDir baseDir(basePath);
    QStringList result;
    for (const auto& searchPath : searchPaths) {
        QDir searchDir(searchPath);
        QStringList filters{ "*.log", "*.log.gz" };
        if (QFileInfo(searchPath).absoluteFilePath() != QFileInfo(basePath).absoluteFilePath()) {
            filters.append("*.txt");
        }
        for (const auto& name : searchDir.entryList(filters, QDir::Files | QDir::Readable, QDir::SortFlag::Time)) {
            result.append(baseDir.relativeFilePath(searchDir.filePath(name)));
        }
    }
    if (result != m_files) {
        m_files = result;
        emit filesChanged();
    }
}

QString LogViewModel::currentFilePath() const
{
    if (m_currentFile.isEmpty()) {
        return {};
    }
    const QString base = m_mode == "files" && m_inst ? m_inst->gameRoot() : APPLICATION->dataRoot();
    return FS::PathCombine(base, m_currentFile);
}

void LogViewModel::loadFile()
{
    m_message.clear();
    if (!m_fileModel) {
        m_fileModel = new LogModel(this);
    }
    SettingsObject* settings = m_inst ? m_inst->settings() : APPLICATION->settings();
    m_fileModel->setMaxLines(getConsoleMaxLines(settings));
    m_fileModel->setStopOnOverflow(shouldStopOnConsoleOverflow(settings));
    m_fileModel->setOverflowMessage(tr("Cannot display this log since the log length surpassed %1 lines.").arg(m_fileModel->getMaxLines()));
    m_fileModel->suspend(false);
    m_fileModel->clear();
    setSourceModel(nullptr);

    const auto path = currentFilePath();
    if (path.isEmpty() || !QFile::exists(path)) {
        m_model = nullptr;
        m_message = m_files.isEmpty() ? tr("No log files found.") : QString();
        emit sourceChanged();
        emit countChanged();
        return;
    }
    QFile file(path);
    if (!file.open(QFile::ReadOnly)) {
        m_model = nullptr;
        m_message = tr("Unable to open %1 for reading: %2").arg(m_currentFile, file.errorString());
        emit sourceChanged();
        emit countChanged();
        return;
    }
    if (file.size() > (1024LL * 1024LL * 12LL)) {
        m_model = nullptr;
        m_message = tr("The file (%1) is too big. You may want to open it in a viewer optimized for large files.").arg(file.fileName());
        emit sourceChanged();
        emit countChanged();
        return;
    }
    const bool launcherLog = m_mode == "launcher";
    MessageLevel last = MessageLevel::Unknown;
    auto handleLine = [this, &last, launcherLog](QString line) {
        if (!line.isEmpty() && line.back() == '\n') {
            line.resize(line.size() - 1);
        }
        if (!line.isEmpty() && line.back() == '\r') {
            line.resize(line.size() - 1);
        }
        if (line.isEmpty()) {
            return false;
        }
        MessageLevel level = MessageLevel::Unknown;
        QString tmp = line;
        level = launcherLog ? MessageLevel::takeFromLauncherLine(tmp) : LogParser::guessLevel(line, last);
        last = level;
        m_fileModel->append(level, line);
        return m_fileModel->isOverFlow();
    };
    if (file.fileName().endsWith(".gz")) {
        QByteArray buffer;
        auto error = GZip::readGzFileByBlocks(&file, [handleLine, &buffer](const QByteArray& d) {
            const auto block = buffer + d;
            auto view = QByteArrayView{ block };
            qsizetype nl = -1;
            while ((nl = view.indexOf('\n')) != -1) {
                if (handleLine(QString::fromUtf8(view.first(nl)))) {
                    buffer.clear();
                    return false;
                }
                view = view.sliced(nl + 1);
            }
            buffer = QByteArray{ view };
            return true;
        });
        if (!error.isEmpty()) {
            m_message = tr("The file (%1) encountered an error when reading: %2.").arg(file.fileName(), error);
        }
        if (!buffer.isEmpty()) {
            handleLine(QString::fromUtf8(buffer));
        }
    } else {
        while (!file.atEnd() && !handleLine(QString::fromUtf8(file.readLine()))) {
        }
    }
    m_model = m_fileModel;
    setSourceModel(m_fileModel);
    m_fileModel->setColorLines(m_colorLines);
    emit sourceChanged();
    emit countChanged();
    emit restarted();
}

void LogViewModel::reload()
{
    if (live()) {
        return;
    }
    refreshFiles();
    loadFile();
}

bool LogViewModel::wrap() const
{
    return m_model ? m_model->wrapLines() : true;
}

void LogViewModel::setWrap(bool on)
{
    if (m_model) {
        m_model->setLineWrap(on);
    }
    emit optionsChanged();
}

bool LogViewModel::colorLines() const
{
    return m_model ? m_model->colorLines() : m_colorLines;
}

void LogViewModel::setColorLines(bool on)
{
    m_colorLines = on;
    if (m_model) {
        m_model->setColorLines(on);
    }
    emit optionsChanged();
}

bool LogViewModel::following() const
{
    return m_model ? !m_model->suspended() : true;
}

void LogViewModel::setFollowing(bool on)
{
    if (m_model) {
        m_model->suspend(!on);
    }
    emit optionsChanged();
}

QString LogViewModel::fontFamily() const
{
    return APPLICATION->settings()->get("ConsoleFont").toString();
}

int LogViewModel::fontSize() const
{
    bool ok = false;
    int size = APPLICATION->settings()->get("ConsoleFontSize").toInt(&ok);
    return ok && size > 0 ? size : 11;
}

QString LogViewModel::plainText() const
{
    return m_model ? m_model->toPlainText() : QString();
}

void LogViewModel::copyAll()
{
    if (!m_model) {
        return;
    }
    if (m_mode == "console") {
        m_model->append(MessageLevel::Launcher,
                        QString("Clipboard copy at: %1").arg(QDateTime::currentDateTime().toString(Qt::RFC2822Date)));
    }
    GuiUtil::setClipboardText(m_model->toPlainText());
}

void LogViewModel::copyLine(int row)
{
    if (row >= 0 && row < rowCount()) {
        GuiUtil::setClipboardText(data(index(row, 0), LineRole).toString());
    }
}

void LogViewModel::clear()
{
    if (m_model) {
        m_model->clear();
    }
}

int LogViewModel::find(const QString& text, int from, bool backwards) const
{
    const int n = rowCount();
    if (text.isEmpty() || n == 0) {
        return -1;
    }
    for (int i = 1; i <= n; i++) {
        int r = backwards ? from - i : from + i;
        r = ((r % n) + n) % n;
        if (data(index(r, 0), LineRole).toString().contains(text, Qt::CaseInsensitive)) {
            return r;
        }
    }
    return -1;
}

int LogViewModel::matchCount(const QString& text) const
{
    if (text.isEmpty()) {
        return 0;
    }
    int n = 0;
    for (int r = 0; r < rowCount(); r++) {
        if (data(index(r, 0), LineRole).toString().contains(text, Qt::CaseInsensitive)) {
            n++;
        }
    }
    return n;
}

QString LogViewModel::deleteCurrentFile()
{
    const auto path = currentFilePath();
    if (path.isEmpty()) {
        return tr("No file selected.");
    }
    if (!FS::trash(path)) {
        QFile file(path);
        if (!file.remove()) {
            return tr("Unable to delete %1: %2").arg(m_currentFile, file.errorString());
        }
    }
    m_currentFile.clear();
    refreshFiles();
    if (m_mode == "launcher") {
        setLiveModel(APPLICATION->logModel.get());
    } else {
        if (!m_files.isEmpty()) {
            m_currentFile = m_files.first();
        }
        loadFile();
    }
    return {};
}

QStringList LogViewModel::cleanFiles()
{
    QStringList failed;
    const QString base = m_mode == "files" && m_inst ? m_inst->gameRoot() : APPLICATION->dataRoot();
    for (const auto& item : m_files) {
        const auto path = FS::PathCombine(base, item);
        if (FS::trash(path)) {
            continue;
        }
        if (!QFile::remove(path)) {
            failed << item;
        }
    }
    m_currentFile.clear();
    refreshFiles();
    if (m_mode == "launcher") {
        setLiveModel(APPLICATION->logModel.get());
    } else {
        loadFile();
    }
    return failed;
}

void LogViewModel::openLogsFolder()
{
    QString path;
    if (m_mode == "launcher") {
        path = QDir(APPLICATION->dataRoot()).filePath("logs");
    } else if (m_inst) {
        path = QDir(m_inst->gameRoot()).filePath("logs");
    }
    if (!path.isEmpty()) {
        QDir().mkpath(path);
        DesktopServices::openPath(path, true);
    }
}

QVariantMap LogViewModel::uploadInfo() const
{
    auto pasteType = PasteUpload::Type(APPLICATION->settings()->get("PastebinType").toInt());
    auto baseURL = APPLICATION->settings()->get("PastebinCustomAPIBase").toString();
    if (baseURL.isEmpty()) {
        baseURL = pasteType.defaultBase();
    }
    const int lines = m_model ? m_model->rowCount() : 0;
    return { { "host", QUrl(baseURL).host() },
             { "lines", lines },
             { "maxLines", g_maxMclogsLines },
             { "keepFirst", g_initialMclogsLines },
             { "keepLast", g_finalMclogsLines },
             { "tooLong", pasteType == PasteUpload::Type::Mclogs && lines > g_maxMclogsLines } };
}

void LogViewModel::upload(const QString& name, bool truncate)
{
    Q_UNUSED(name)
    if (!m_model || m_upload) {
        return;
    }
    auto pasteType = PasteUpload::Type(APPLICATION->settings()->get("PastebinType").toInt());
    auto baseURL = APPLICATION->settings()->get("PastebinCustomAPIBase").toString();
    if (baseURL.isEmpty()) {
        baseURL = pasteType.defaultBase();
    }
    if (!QUrl(baseURL).isValid()) {
        emit uploadFailed(tr("The paste service URL is not valid."));
        return;
    }
    if (m_mode == "console") {
        m_model->append(MessageLevel::Launcher,
                        QString("Log upload triggered at: %1").arg(QDateTime::currentDateTime().toString(Qt::RFC2822Date)));
    }
    QString text = m_model->toPlainText();
    if (truncate) {
        text = truncateForMclogs(text);
    }
    m_upload = NetJob::Ptr(new NetJob("Log Upload", APPLICATION->network()));
    auto [pasteJob, pasteLink] = pasteType.make(std::move(text), baseURL);
    m_upload->addNetAction(pasteJob);
    QPointer<LogModel> model = m_model;
    const bool console = m_mode == "console";
    connect(m_upload.get(), &Task::failed, this, [this, model, console](const QString& reason) {
        if (console && model) {
            model->append(MessageLevel::Error, QString("Log upload failed: %1").arg(reason));
        }
        emit uploadFailed(reason);
    });
    connect(m_upload.get(), &Task::succeeded, this, [this, pasteLink, model, console] {
        if (pasteLink->isEmpty()) {
            emit uploadFailed(tr("The upload link is empty"));
            return;
        }
        GuiUtil::setClipboardText(*pasteLink);
        if (console && model) {
            model->append(MessageLevel::Launcher, QString("Log uploaded to: %1").arg(*pasteLink));
        }
        emit uploadFinished(*pasteLink);
    });
    connect(m_upload.get(), &Task::finished, this, [this] {
        m_upload.reset();
        emit uploadingChanged();
    });
    emit uploadingChanged();
    m_upload->start();
}
