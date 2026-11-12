#include "NIController.h"

#include <QDir>
#include <QUrl>

#include "Application.h"
#include "InstanceList.h"
#include "InstanceTask.h"
#include "TaskBridge.h"
#include "icons/IconList.h"
#include "settings/SettingsObject.h"

NIController::NIController(QObject* parent) : QObject(parent)
{
    refreshInstanceDirs();
}

NIController::~NIController() = default;

void NIController::setIconKey(const QString& key)
{
    m_iconKey = key.isEmpty() ? QStringLiteral("default") : key;
    m_importIcon = false;
    emit iconChanged();
}

QString NIController::iconSource() const
{
    if (m_importIcon && !m_importIconPath.isEmpty()) {
        return QUrl::fromLocalFile(m_importIconPath).toString();
    }
    return "image://instanceicon/" + m_iconKey;
}

QString NIController::lastDir() const
{
    return APPLICATION->settings()->get("LastUsedInstDirForNewInstance").toString();
}

QString NIController::lastGroup() const
{
    return APPLICATION->settings()->get("LastUsedGroupForNewInstance").toString();
}

bool NIController::templateAvailable() const
{
    const auto dir = APPLICATION->settings()->get("TemplateDir").toString();
    return !dir.isEmpty() && QDir(dir).exists();
}

bool NIController::flameSupported() const
{
    return APPLICATION->capabilities() & Application::SupportsFlame;
}

void NIController::refreshInstanceDirs()
{
    m_dirs.clear();
    auto add = [this](const QString& dir, const QString& label) {
        if (dir.isEmpty()) {
            return;
        }
        const auto canonical = QDir(dir).canonicalPath();
        if (canonical.isEmpty()) {
            return;
        }
        QVariantMap m;
        m["path"] = canonical;
        m["label"] = label.isEmpty() ? canonical : label;
        m_dirs << m;
    };
    const auto instDir = APPLICATION->settings()->get("InstanceDir").toString();
    add(instDir, tr("Default (%1)").arg(instDir));
    for (const auto& dir : APPLICATION->settings()->get("AdditionalInstanceDirs").toStringList()) {
        add(dir, {});
    }
    emit instanceDirsChanged();
}

void NIController::setSuggestedPack(const QString& name, const QString& version, InstanceTask* task)
{
    m_task.reset(task);
    m_suggestedName = name;
    m_suggestedVersion = version;
    if (!task) {
        clearSuggestedIcon();
    }
    emit suggestionChanged();
}

void NIController::setSuggestedIconFromFile(const QString& path, const QString& name)
{
    m_importIcon = true;
    m_importIconPath = path;
    m_importIconName = name;
    emit iconChanged();
}

void NIController::clearSuggestedIcon()
{
    if (m_importIcon) {
        m_importIcon = false;
        emit iconChanged();
    }
}

TaskBridge* NIController::create(const QString& name, const QString& group, const QString& dir, bool copyTemplate)
{
    if (!m_task) {
        emit error(tr("Nothing to create yet. Pick a version or a modpack first."));
        return nullptr;
    }
    auto finalName = name.trimmed();
    if (finalName.isEmpty()) {
        finalName = m_suggestedName.trimmed();
    }
    if (finalName.isEmpty()) {
        emit error(tr("Please enter a name for the instance."));
        return nullptr;
    }
    if (!dir.isEmpty() && !QDir(dir).exists()) {
        refreshInstanceDirs();
        emit error(tr("The instance directory \"%1\" is no longer accessible. Please choose another location.").arg(dir));
        return nullptr;
    }

    // install the modpack logo as an icon now (classic: importIconNow)
    auto iconKey = m_iconKey;
    if (m_importIcon) {
        APPLICATION->icons()->installIcon(m_importIconPath, m_importIconName);
        iconKey = m_importIconName.mid(0, m_importIconName.lastIndexOf('.'));
        m_importIcon = false;
    }

    APPLICATION->settings()->set("LastUsedGroupForNewInstance", group);
    APPLICATION->settings()->set("LastUsedInstDirForNewInstance", dir);

    InstanceTask* task = m_task.release();
    task->setName(finalName);
    task->setOriginalName(m_suggestedName.trimmed(), m_suggestedVersion);
    task->setGroup(group);
    task->setIcon(iconKey);
    task->setTargetDir(dir);
    task->setCopyTemplateDir(copyTemplate);
    emit suggestionChanged();

    // the bridge outlives the page (navigation while creating must not kill the task)
    auto* bridge = TaskBridge::createDetached();
    Task::Ptr wrapped(APPLICATION->instances()->wrapInstanceTask(task));
    connect(APPLICATION->instances(), &InstanceList::instanceSelectRequest, bridge, [bridge](const QString& id) {
        if (bridge->running()) {
            bridge->setResultId(id);
        }
    });
    bridge->setTask(wrapped, tr("Creating “%1”").arg(finalName));
    bridge->start();
    return bridge;
}
