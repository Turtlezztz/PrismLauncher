#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QUrl>

#include "modplatform/ModIndex.h"
#include "tasks/Task.h"

class MinecraftInstance;

/**
 * Managed modpack (Modrinth / CurseForge) info + updating for the instance "Modpack" tab.
 * Mirrors the classic ManagedPackPage.
 */
class ManagedPackBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY changed)
    /// the tab should be shown (Modrinth or CurseForge pack)
    Q_PROPERTY(bool supported READ supported NOTIFY changed)
    Q_PROPERTY(QString type READ type NOTIFY changed)
    Q_PROPERTY(QString platformName READ platformName NOTIFY changed)
    Q_PROPERTY(QString packName READ packName NOTIFY changed)
    Q_PROPERTY(QString packVersion READ packVersion NOTIFY changed)
    Q_PROPERTY(QString packId READ packId NOTIFY changed)
    Q_PROPERTY(QString versionId READ versionId NOTIFY changed)
    Q_PROPERTY(QString websiteUrl READ websiteUrl NOTIFY changed)
    /// pack without an id ("local" pack, updated from file/URL only)
    Q_PROPERTY(bool local READ local NOTIFY changed)
    Q_PROPERTY(QString customUrl READ customUrl WRITE setCustomUrl NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY versionsChanged)
    Q_PROPERTY(bool failed READ failed NOTIFY versionsChanged)
    Q_PROPERTY(QString failMessage READ failMessage NOTIFY versionsChanged)
    /// [{ name, version, current, date, type }]
    Q_PROPERTY(QVariantList versions READ versions NOTIFY versionsChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectionChanged)
    Q_PROPERTY(QString changelog READ changelog NOTIFY selectionChanged)
    Q_PROPERTY(bool updating READ updating NOTIFY updatingChanged)
    Q_PROPERTY(QString updateStatus READ updateStatus NOTIFY updatingChanged)
    Q_PROPERTY(double updateProgress READ updateProgress NOTIFY updatingChanged)

   public:
    explicit ManagedPackBridge(QObject* parent = nullptr);

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    bool supported() const;
    QString type() const;
    QString platformName() const;
    QString packName() const;
    QString packVersion() const;
    QString packId() const;
    QString versionId() const;
    QString websiteUrl() const;
    bool local() const;
    QString customUrl() const;
    void setCustomUrl(const QString& url);
    bool loading() const { return m_fetchJob && m_fetchJob->isRunning(); }
    bool failed() const { return m_failed; }
    QString failMessage() const { return m_failMessage; }
    QVariantList versions() const;
    int selectedIndex() const { return m_selected; }
    void setSelectedIndex(int index);
    QString changelog() const { return m_changelog; }
    bool updating() const { return m_task != nullptr; }
    QString updateStatus() const;
    double updateProgress() const;

    Q_INVOKABLE void reload();
    /// update to the selected version (or the custom URL for local packs). Confirm in QML first.
    Q_INVOKABLE void updateToSelected();
    /// pick a pack file and update from it. Confirm in QML first.
    Q_INVOKABLE void updateFromFile();
    /// "" if the URL is acceptable, else an error
    Q_INVOKABLE QString validateUrl(const QString& url) const;
    Q_INVOKABLE void updateFromUrl(const QString& url);
    Q_INVOKABLE QString selectedVersionName() const;

   signals:
    void changed();
    void versionsChanged();
    void selectionChanged();
    void updatingChanged();
    /// ok: success. warnings: non-fatal messages from the update
    void updateFinished(bool ok, const QString& message, const QString& warnings);

   private:
    void updatePack(const QUrl& url, bool trusted, const QString& versionId = {}, const QString& versionName = {});
    void setFailState(const QString& message);
    QString m_id;
    QPointer<MinecraftInstance> m_inst;
    Task::Ptr m_fetchJob;
    ModPlatform::IndexedPack m_pack;
    bool m_failed = false;
    QString m_failMessage;
    int m_selected = -1;
    QString m_changelog;
    Task* m_task = nullptr;
};
