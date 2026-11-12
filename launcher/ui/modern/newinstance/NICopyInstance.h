#pragma once

#include <QObject>
#include <QQmlEngine>

#include "InstanceCopyPrefs.h"

class TaskBridge;

/**
 * Backend of CopyInstanceDialog.qml (classic CopyInstanceDialog): copy options + filesystem capabilities, and the copy task.
 */
class NICopyInstance : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceChanged)
    Q_PROPERTY(QString originalName READ originalName NOTIFY instanceChanged)
    Q_PROPERTY(QString originalIcon READ originalIcon NOTIFY instanceChanged)
    Q_PROPERTY(QString originalGroup READ originalGroup NOTIFY instanceChanged)
    Q_PROPERTY(bool cloneSupported READ cloneSupported NOTIFY instanceChanged)
    Q_PROPERTY(bool linkSupported READ linkSupported NOTIFY instanceChanged)
    Q_PROPERTY(QString filesystem READ filesystem NOTIFY instanceChanged)

    Q_PROPERTY(bool copySaves READ copySaves WRITE set_copySaves NOTIFY prefsChanged)
    Q_PROPERTY(bool keepPlaytime READ keepPlaytime WRITE set_keepPlaytime NOTIFY prefsChanged)
    Q_PROPERTY(bool copyGameOptions READ copyGameOptions WRITE set_copyGameOptions NOTIFY prefsChanged)
    Q_PROPERTY(bool copyResourcePacks READ copyResourcePacks WRITE set_copyResourcePacks NOTIFY prefsChanged)
    Q_PROPERTY(bool copyShaderPacks READ copyShaderPacks WRITE set_copyShaderPacks NOTIFY prefsChanged)
    Q_PROPERTY(bool copyServers READ copyServers WRITE set_copyServers NOTIFY prefsChanged)
    Q_PROPERTY(bool copyMods READ copyMods WRITE set_copyMods NOTIFY prefsChanged)
    Q_PROPERTY(bool copyScreenshots READ copyScreenshots WRITE set_copyScreenshots NOTIFY prefsChanged)
    Q_PROPERTY(bool useSymLinks READ useSymLinks WRITE set_useSymLinks NOTIFY prefsChanged)
    Q_PROPERTY(bool linkRecursively READ linkRecursively WRITE set_linkRecursively NOTIFY prefsChanged)
    Q_PROPERTY(bool useHardLinks READ useHardLinks WRITE set_useHardLinks NOTIFY prefsChanged)
    Q_PROPERTY(bool dontLinkSaves READ dontLinkSaves WRITE set_dontLinkSaves NOTIFY prefsChanged)
    Q_PROPERTY(bool useClone READ useClone WRITE set_useClone NOTIFY prefsChanged)

   public:
    bool copySaves() const { return m_prefs.isCopySavesEnabled(); }
    void set_copySaves(bool v)
    {
        m_prefs.enableCopySaves(v);
        emit prefsChanged();
    }
    bool keepPlaytime() const { return m_prefs.isKeepPlaytimeEnabled(); }
    void set_keepPlaytime(bool v)
    {
        m_prefs.enableKeepPlaytime(v);
        emit prefsChanged();
    }
    bool copyGameOptions() const { return m_prefs.isCopyGameOptionsEnabled(); }
    void set_copyGameOptions(bool v)
    {
        m_prefs.enableCopyGameOptions(v);
        emit prefsChanged();
    }
    bool copyResourcePacks() const { return m_prefs.isCopyResourcePacksEnabled(); }
    void set_copyResourcePacks(bool v)
    {
        m_prefs.enableCopyResourcePacks(v);
        emit prefsChanged();
    }
    bool copyShaderPacks() const { return m_prefs.isCopyShaderPacksEnabled(); }
    void set_copyShaderPacks(bool v)
    {
        m_prefs.enableCopyShaderPacks(v);
        emit prefsChanged();
    }
    bool copyServers() const { return m_prefs.isCopyServersEnabled(); }
    void set_copyServers(bool v)
    {
        m_prefs.enableCopyServers(v);
        emit prefsChanged();
    }
    bool copyMods() const { return m_prefs.isCopyModsEnabled(); }
    void set_copyMods(bool v)
    {
        m_prefs.enableCopyMods(v);
        emit prefsChanged();
    }
    bool copyScreenshots() const { return m_prefs.isCopyScreenshotsEnabled(); }
    void set_copyScreenshots(bool v)
    {
        m_prefs.enableCopyScreenshots(v);
        emit prefsChanged();
    }
    bool useSymLinks() const { return m_prefs.isUseSymLinksEnabled(); }
    void set_useSymLinks(bool v)
    {
        m_prefs.enableUseSymLinks(v);
        emit prefsChanged();
    }
    bool linkRecursively() const { return m_prefs.isLinkRecursivelyEnabled(); }
    void set_linkRecursively(bool v)
    {
        m_prefs.enableLinkRecursively(v);
        emit prefsChanged();
    }
    bool useHardLinks() const { return m_prefs.isUseHardLinksEnabled(); }
    void set_useHardLinks(bool v)
    {
        m_prefs.enableUseHardLinks(v);
        emit prefsChanged();
    }
    bool dontLinkSaves() const { return m_prefs.isDontLinkSavesEnabled(); }
    void set_dontLinkSaves(bool v)
    {
        m_prefs.enableDontLinkSaves(v);
        emit prefsChanged();
    }
    bool useClone() const { return m_prefs.isUseCloneEnabled(); }
    void set_useClone(bool v)
    {
        m_prefs.enableUseClone(v);
        emit prefsChanged();
    }

   public:
    explicit NICopyInstance(QObject* parent = nullptr);

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    QString originalName() const;
    QString originalIcon() const;
    QString originalGroup() const;
    bool cloneSupported() const { return m_cloneSupported; }
    bool linkSupported() const { return m_linkSupported; }
    QString filesystem() const { return m_fs; }

    Q_INVOKABLE TaskBridge* copy(const QString& name, const QString& group, const QString& iconKey);

   signals:
    void instanceChanged();
    void prefsChanged();

   private:
    QString m_id;
    InstanceCopyPrefs m_prefs;
    bool m_cloneSupported = false;
    bool m_linkSupported = false;
    QString m_fs;
};
