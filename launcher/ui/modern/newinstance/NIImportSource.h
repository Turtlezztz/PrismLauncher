#pragma once

#include <QMap>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QUrl>

#include "NIController.h"
#include "modplatform/ModIndex.h"
#include "tasks/Task.h"

class TaskBridge;

/**
 * "Import" source (classic ImportPage) + handling of dropped / opened URLs (classic MainWindow::processURLs).
 *
 *  - setText(): local .zip / .mrpack, http(s) URL or curseforge:// link -> InstanceImportTask suggestion
 *  - processUrls(): deep links (curseforge://, prismlauncher://install, prismlauncher://import?url=, modrinth://modpack/...),
 *    remote downloads, local modpacks and resource files (mods, resource packs, worlds...) that go into an existing instance.
 */
class NIImportSource : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(NIController* controller READ controller WRITE setController NOTIFY controllerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    /// "", "file", "url", "curseforge", "invalid"
    Q_PROPERTY(QString kind READ kind NOTIFY stateChanged)
    Q_PROPERTY(QString hint READ hint NOTIFY stateChanged)
    Q_PROPERTY(bool resolving READ resolving NOTIFY stateChanged)

   public:
    explicit NIImportSource(QObject* parent = nullptr);

    NIController* controller() const { return m_controller; }
    void setController(NIController* c);
    bool active() const { return m_active; }
    void setActive(bool a);
    QString text() const { return m_text; }
    void setText(const QString& t);
    QString kind() const { return m_kind; }
    QString hint() const { return m_hint; }
    bool resolving() const { return m_resolving; }

    Q_INVOKABLE void setExtraInfo(const QVariantMap& info);
    Q_INVOKABLE QString urlToPath(const QUrl& url) const { return url.isLocalFile() ? url.toLocalFile() : url.toString(); }

    /// Handle URLs from drag & drop / the OS (see class comment). Results arrive through the signals below.
    Q_INVOKABLE void processUrls(const QList<QUrl>& urls);
    /// continue after the user confirmed a prismlauncher://import download
    Q_INVOKABLE void confirmDownload(const QUrl& url, bool accepted);
    /// install a resource file into an instance (after the user picked one); returns "" or an error
    Q_INVOKABLE QString installResource(const QString& path, int type, const QString& instanceId);

   signals:
    void controllerChanged();
    void activeChanged();
    void textChanged();
    void stateChanged();
    void error(const QString& message);
    /// a modpack/instance archive to import (path or URL) -> show the Import source with it
    void packRequested(const QString& source, const QVariantMap& extraInfo);
    /// modrinth://modpack/<id>
    void modrinthPackRequested(const QString& packId);
    /// a resource file that has to be installed into an existing instance
    void resourceRequested(const QString& path, int type, const QString& typeName);
    /// ask the user before downloading a modpack from an external import link
    void downloadConfirmationRequested(const QUrl& url, const QString& host);
    /// a download is running (show progress)
    void taskStarted(TaskBridge* task);

   private:
    void updateState();
    void suggest(const QString& name, const QUrl& url);
    void processNext();
    void downloadThenIdentify(const QUrl& url);
    void identifyLocal(const QString& path);

    QPointer<NIController> m_controller;
    bool m_active = false;
    QString m_text;
    QString m_kind;
    QString m_hint;
    bool m_resolving = false;
    QMap<QString, QString> m_extraInfo;
    Task::Ptr m_job;

    // URL processing state
    QList<QUrl> m_queue;
    QMap<QString, QString> m_pendingExtra;
    ModPlatform::IndexedVersion m_pendingVersion;
    bool m_busy = false;
};
