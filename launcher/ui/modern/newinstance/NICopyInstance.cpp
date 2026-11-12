#include "NICopyInstance.h"

#include "Application.h"
#include "FileSystem.h"
#include "InstanceCopyTask.h"
#include "InstanceList.h"
#include "TaskBridge.h"
#include "minecraft/MinecraftInstance.h"

NICopyInstance::NICopyInstance(QObject* parent) : QObject(parent) {}

void NICopyInstance::setInstanceId(const QString& id)
{
    m_id = id;
    if (auto* inst = APPLICATION->instances()->getInstanceById(id)) {
        auto detected = FS::statFS(inst->instanceRoot()).fsType;
        m_cloneSupported = FS::canCloneOnFS(detected);
        m_linkSupported = FS::canLinkOnFS(detected);
        m_fs = FS::getFilesystemTypeName(detected);
    }
    emit instanceChanged();
}

QString NICopyInstance::originalName() const
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    return inst ? inst->name() : QString();
}

QString NICopyInstance::originalIcon() const
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    return inst ? inst->iconKey() : QString();
}

QString NICopyInstance::originalGroup() const
{
    return APPLICATION->instances()->getInstanceGroup(m_id);
}

TaskBridge* NICopyInstance::copy(const QString& name, const QString& group, const QString& iconKey)
{
    auto* inst = APPLICATION->instances()->getInstanceById(m_id);
    if (!inst || name.trimmed().isEmpty()) {
        return nullptr;
    }
    // keep link/clone options consistent the same way the classic dialog's checkbox logic does
    InstanceCopyPrefs prefs = m_prefs;
    if (!m_cloneSupported) {
        prefs.enableUseClone(false);
    }
    if (!m_linkSupported || prefs.isUseCloneEnabled()) {
        prefs.enableUseSymLinks(false);
        prefs.enableUseHardLinks(false);
    }
    const bool links = prefs.isUseSymLinksEnabled() || prefs.isUseHardLinksEnabled();
    if (!links) {
        prefs.enableLinkRecursively(false);
        prefs.enableDontLinkSaves(false);
    }
    auto* task = new InstanceCopyTask(inst, prefs);
    task->setName(name.trimmed());
    task->setGroup(group);
    task->setIcon(iconKey);
    auto* bridge = TaskBridge::createDetached();
    connect(APPLICATION->instances(), &InstanceList::instanceSelectRequest, bridge, [bridge](const QString& id) {
        if (bridge->running()) {
            bridge->setResultId(id);
        }
    });
    bridge->setTask(Task::Ptr(APPLICATION->instances()->wrapInstanceTask(task)), tr("Copying “%1”").arg(inst->name()));
    bridge->start();
    return bridge;
}
