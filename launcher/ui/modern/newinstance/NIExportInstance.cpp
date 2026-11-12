#include "NIExportInstance.h"

#include <QDir>
#include <QFileSystemModel>
#include <QUrl>

#include "Application.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "MMCZip.h"
#include "TaskBridge.h"
#include "archive/ExportToZipTask.h"
#include "icons/IconList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/mod/ResourceFolderModel.h"
#include "modplatform/flame/FlamePackExportTask.h"
#include "modplatform/modrinth/ModrinthPackExportTask.h"
#include "settings/SettingsObject.h"

// ------------------------------------------------------------------- NIFileTreeModel

NIFileTreeModel::NIFileTreeModel(const QString& root, QObject* parent) : FileIgnoreProxy(root, parent) {}

int NIFileTreeModel::columnCount(const QModelIndex& parent) const
{
    return qMin(1, FileIgnoreProxy::columnCount(parent));
}

QHash<int, QByteArray> NIFileTreeModel::roleNames() const
{
    return { { NameRole, "fileName" }, { CheckRole, "checkValue" }, { IsDirRole, "isDir" }, { SizeRole, "sizeText" } };
}

QVariant NIFileTreeModel::data(const QModelIndex& index, int role) const
{
    switch (role) {
        case NameRole:
            return FileIgnoreProxy::data(index, Qt::DisplayRole);
        case CheckRole:
            return FileIgnoreProxy::data(index, Qt::CheckStateRole).toInt();
        case IsDirRole: {
            auto* fsm = qobject_cast<QFileSystemModel*>(sourceModel());
            return fsm && fsm->isDir(mapToSource(index));
        }
        case SizeRole: {
            auto* fsm = qobject_cast<QFileSystemModel*>(sourceModel());
            if (!fsm || fsm->isDir(mapToSource(index))) {
                return QString();
            }
            return QLocale().formattedDataSize(fsm->size(mapToSource(index)));
        }
        default:
            return FileIgnoreProxy::data(index, role);
    }
}

void NIFileTreeModel::toggle(const QModelIndex& index)
{
    const auto state = static_cast<Qt::CheckState>(FileIgnoreProxy::data(index, Qt::CheckStateRole).toInt());
    setData(index, state == Qt::Checked ? Qt::Unchecked : Qt::Checked, Qt::CheckStateRole);
}

// ------------------------------------------------------------------- NIExportInstance

NIExportInstance::NIExportInstance(QObject* parent) : QObject(parent) {}

NIExportInstance::~NIExportInstance() = default;

MinecraftInstance* NIExportInstance::instance() const
{
    return APPLICATION->instances()->getInstanceById(m_id);
}

QString NIExportInstance::instanceName() const
{
    auto* inst = instance();
    return inst ? inst->name() : QString();
}

void NIExportInstance::setInstanceId(const QString& id)
{
    m_id = id;
    if (auto* inst = instance()) {
        auto s = inst->settings();
        m_packName = s->get("ExportName").toString();
        m_packVersion = s->get("ExportVersion").toString();
        m_optionalFiles = s->get("ExportOptionalFiles").toBool();
        m_summary = s->get("ExportSummary").toString();
        m_author = s->get("ExportAuthor").toString();
        const int ram = s->get("ExportRecommendedRAM").toInt();
        m_ramEnabled = ram > 0;
        m_ram = ram > 0 ? ram : qMin(s->get("MaxMemAlloc").toInt(), 1024 * 12);
    }
    emit instanceChanged();
    emit optionsChanged();
    rebuildModel();
}

void NIExportInstance::setFormat(const QString& f)
{
    if (f == m_format) {
        return;
    }
    if (m_proxy) {
        m_proxy->saveBlockedPathsToFile(ignoreFileName());
    }
    m_format = f;
    rebuildModel();
}

QString NIExportInstance::ignoreFileName() const
{
    auto* inst = instance();
    return inst ? FS::PathCombine(inst->instanceRoot(), ".packignore") : QString();
}

void NIExportInstance::rebuildModel()
{
    auto* inst = instance();
    if (!inst) {
        return;
    }
    auto* oldProxy = m_proxy;
    auto* oldFs = m_fsModel;

    m_fsModel = new QFileSystemModel(this);
    const auto root = inst->instanceRoot();
    m_proxy = new NIFileTreeModel(root, this);
    const auto prefix = QDir(root).relativeFilePath(inst->gameRoot());
    for (auto path : { "logs", "crash-reports", ".cache", ".fabric", ".quilt" }) {
        m_proxy->ignoreFilesWithPath().insert(FS::PathCombine(prefix, path));
    }
    m_proxy->ignoreFilesWithName().append({ ".DS_Store", "thumbs.db", "Thumbs.db" });
    const bool pack = m_format != "zip";
    if (pack) {
        m_proxy->ignoreFilesWithSuffix().append(".pw.toml");
        const QDir instanceRoot(root);
        for (auto* resourceModel : inst->resourceLists()) {
            if (!resourceModel || !resourceModel->indexDir().exists() || resourceModel->dir() == resourceModel->indexDir()) {
                continue;
            }
            m_proxy->ignoreFilesWithPath().insert(instanceRoot.relativeFilePath(resourceModel->indexDir().absolutePath()));
        }
    }
    m_proxy->setSourceModel(m_fsModel);
    m_proxy->loadBlockedPathsFromFile(ignoreFileName());
    m_fsModel->setFilter(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::AllDirs | QDir::Hidden);
    const auto viewRoot = pack ? inst->gameRoot() : root;
    m_fsModel->setRootPath(viewRoot);
    m_proxy->sort(0, Qt::AscendingOrder);
    m_rootIndex = m_proxy->mapFromSource(m_fsModel->index(viewRoot));
    emit formatChanged();
    if (oldProxy) {
        oldProxy->deleteLater();
    }
    if (oldFs) {
        oldFs->deleteLater();
    }
}

QString NIExportInstance::suggestedFileName() const
{
    QString name = instanceName();
    if (m_format != "zip" && !m_packName.isEmpty()) {
        name = m_packName;
    }
    name = FS::RemoveInvalidFilenameChars(name);
    return name + (m_format == "modrinth" ? ".mrpack" : ".zip");
}

QUrl NIExportInstance::suggestedFolder() const
{
    return QUrl::fromLocalFile(QDir::homePath());
}

void NIExportInstance::saveSettings()
{
    auto* inst = instance();
    if (!inst) {
        return;
    }
    if (m_proxy) {
        m_proxy->saveBlockedPathsToFile(ignoreFileName());
    }
    if (m_format == "zip") {
        return;
    }
    auto s = inst->settings();
    s->set("ExportName", m_packName);
    s->set("ExportVersion", m_packVersion);
    s->set("ExportOptionalFiles", m_optionalFiles);
    if (m_format == "modrinth") {
        s->set("ExportSummary", m_summary);
    } else {
        s->set("ExportAuthor", m_author);
        if (m_ramEnabled) {
            s->set("ExportRecommendedRAM", m_ram);
        } else {
            s->reset("ExportRecommendedRAM");
        }
    }
}

// classic ExportInstanceDialog: copy a custom icon into the instance folder so the zip carries it
static void saveIconIntoInstance(MinecraftInstance* inst)
{
    auto iconKey = inst->iconKey();
    auto* mmcIcon = APPLICATION->icons()->icon(iconKey);
    if (!mmcIcon || mmcIcon->isBuiltIn()) {
        return;
    }
    auto path = mmcIcon->getFilePath();
    if (!path.isNull()) {
        QFileInfo inInfo(path);
        FS::copy(path, FS::PathCombine(inst->instanceRoot(), inInfo.fileName()))();
        return;
    }
    auto& icon = mmcIcon->m_images[mmcIcon->type()].icon;
    auto sizes = icon.availableSizes();
    if (sizes.isEmpty()) {
        return;
    }
    QSize largest = sizes[0];
    for (auto size : sizes) {
        if (largest.width() * largest.height() < size.width() * size.height()) {
            largest = size;
        }
    }
    icon.pixmap(largest).save(FS::PathCombine(inst->instanceRoot(), iconKey + ".png"));
}

TaskBridge* NIExportInstance::exportTo(const QUrl& file)
{
    auto* inst = instance();
    if (!inst || !m_proxy) {
        return nullptr;
    }
    QString output = file.isLocalFile() ? file.toLocalFile() : file.toString();
    if (output.isEmpty()) {
        return nullptr;
    }
    saveSettings();
    auto filter = std::bind(&FileIgnoreProxy::filterFile, m_proxy, std::placeholders::_1);
    Task::Ptr task;
    QString title;
    if (m_format == "zip") {
        if (!output.endsWith(".zip")) {
            output.append(".zip");
        }
        saveIconIntoInstance(inst);
        QFileInfoList files;
        if (!MMCZip::collectFileListRecursively(inst->instanceRoot(), nullptr, &files, filter)) {
            emit error(tr("Unable to export instance"));
            return nullptr;
        }
        task = makeShared<MMCZip::ExportToZipTask>(output, inst->instanceRoot(), files, "", true);
        title = tr("Exporting “%1”").arg(inst->name());
    } else if (m_format == "modrinth") {
        if (!(output.endsWith(".zip") || output.endsWith(".mrpack"))) {
            output.append(".mrpack");
        }
        const QString name = m_packName.isEmpty() ? inst->name() : m_packName;
        task = Task::Ptr(new ModrinthPackExportTask(name, m_packVersion, m_summary, m_optionalFiles, inst, output, filter));
        title = tr("Exporting Modrinth pack");
    } else {
        if (!output.endsWith(".zip")) {
            output.append(".zip");
        }
        FlamePackExportOptions options{};
        options.name = m_packName.isEmpty() ? inst->name() : m_packName;
        options.version = m_packVersion;
        options.author = m_author;
        options.optionalFiles = m_optionalFiles;
        options.instance = inst;
        options.output = output;
        options.filter = filter;
        options.recommendedRAM = m_ramEnabled ? m_ram : 0;
        task = Task::Ptr(new FlamePackExportTask(std::move(options)));
        title = tr("Exporting CurseForge pack");
    }
    // the proxy must outlive the task (it filters files while exporting)
    auto* bridge = TaskBridge::createDetached();
    m_proxy->setParent(bridge);
    m_fsModel->setParent(bridge);
    m_proxy = nullptr;
    m_fsModel = nullptr;
    bridge->setTask(task, title);
    bridge->setResultId(output);
    bridge->start();
    rebuildModel();
    return bridge;
}
