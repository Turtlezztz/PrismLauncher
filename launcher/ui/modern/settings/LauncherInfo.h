#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariant>

#include "QObjectPtr.h"

class NewsChecker;

/**
 * `LauncherInfo` QML singleton: build information for the About page (classic AboutDialog),
 * plus update checking glue (classic UpdateAvailableDialog) for the modern frontend.
 */
class LauncherInfo : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString platform READ platform CONSTANT)
    Q_PROPERTY(QString commit READ commit CONSTANT)
    Q_PROPERTY(QString buildDate READ buildDate CONSTANT)
    Q_PROPERTY(QString channel READ channel CONSTANT)
    Q_PROPERTY(QString gitUrl READ gitUrl CONSTANT)
    Q_PROPERTY(QString copyright READ copyright CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString buildInfo READ buildInfo CONSTANT)
    Q_PROPERTY(QVariantMap links READ links CONSTANT)

    // ---- updates ----
    Q_PROPERTY(bool updaterEnabled READ updaterEnabled NOTIFY updateStateChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateStateChanged)
    Q_PROPERTY(QString updateVersion READ updateVersion NOTIFY updateStateChanged)
    Q_PROPERTY(QString updateNotesHtml READ updateNotesHtml NOTIFY updateStateChanged)

   public:
    explicit LauncherInfo(QObject* parent = nullptr);
    static LauncherInfo* create(QQmlEngine*, QJSEngine*);

    QString name() const;
    QString version() const;
    QString platform() const;
    QString commit() const;
    QString buildDate() const;
    QString channel() const;
    QString gitUrl() const;
    QString copyright() const;
    QString qtVersion() const;
    QString buildInfo() const;
    QVariantMap links() const;

    Q_INVOKABLE QString creditsHtml() const;
    Q_INVOKABLE QString licenseHtml() const;

    bool updaterEnabled() const;
    bool updateAvailable() const { return m_respond != nullptr; }
    QString updateVersion() const { return m_updateVersion; }
    QString updateNotesHtml() const { return m_updateNotes; }

    Q_INVOKABLE void checkForUpdates();
    /// action: install | later | skip
    Q_INVOKABLE void respondToUpdate(const QString& action);

   signals:
    void updateStateChanged();
    /// emitted when the updater found a new version (QML shows a toast / dialog)
    void updateOffered(const QString& version);

   private:
    std::function<void(int)> m_respond;
    QString m_updateVersion;
    QString m_updateNotes;
};

/**
 * News feed (classic NewsChecker / NewsDialog).
 *   NewsFeed { id: feed }   feed.entries: [{ title, html, link }]
 */
class NewsFeed : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList entries READ entries NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString moreUrl READ moreUrl CONSTANT)
    Q_PROPERTY(bool enabled READ enabled CONSTANT)

   public:
    explicit NewsFeed(QObject* parent = nullptr);
    ~NewsFeed() override;

    QVariantList entries() const;
    bool loading() const;
    QString error() const { return m_error; }
    QString moreUrl() const;
    bool enabled() const;

    Q_INVOKABLE void reload();

   signals:
    void changed();

   private:
    NewsChecker* m_checker = nullptr;
    QString m_error;
};
