#pragma once

#include <QFileSystemWatcher>
#include <QIdentityProxyModel>
#include <QPointer>
#include <QQmlEngine>

#include "QObjectPtr.h"
#include "net/NetJob.h"

class LogModel;
class LaunchTask;
class MinecraftInstance;

/**
 * A log for the modern log views (console, other logs, launcher log).
 *
 * mode:
 *   "console"  - the live log of `instanceId`'s current / last launch
 *   "files"    - log files of `instanceId` (logs/, crash-reports/ ...), pick one with `currentFile`
 *   "launcher" - the launcher's own log; currentFile "" = live log, otherwise a file from <data>/logs
 *
 * Roles: line, level (MessageLevel value: 0 unknown, 1 stdout, 2 stderr, 3 launcher, 4 trace, 5 debug, 6 info,
 *        7 message, 8 warning, 9 error, 10 fatal)
 */
class LogViewModel : public QIdentityProxyModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY sourceChanged)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY sourceChanged)
    Q_PROPERTY(QString currentFile READ currentFile WRITE setCurrentFile NOTIFY sourceChanged)
    Q_PROPERTY(QStringList files READ files NOTIFY filesChanged)
    Q_PROPERTY(bool hasSource READ hasSource NOTIFY sourceChanged)
    Q_PROPERTY(bool live READ live NOTIFY sourceChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool wrap READ wrap WRITE setWrap NOTIFY optionsChanged)
    Q_PROPERTY(bool colorLines READ colorLines WRITE setColorLines NOTIFY optionsChanged)
    /// keep appending new lines (classic "Keep updating"); false suspends the live model
    Q_PROPERTY(bool following READ following WRITE setFollowing NOTIFY optionsChanged)
    Q_PROPERTY(bool uploading READ uploading NOTIFY uploadingChanged)
    Q_PROPERTY(QString message READ message NOTIFY sourceChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily CONSTANT)
    Q_PROPERTY(int fontSize READ fontSize CONSTANT)

   public:
    enum Roles { LineRole = Qt::UserRole + 400, LevelRole };
    explicit LogViewModel(QObject* parent = nullptr);
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    QString mode() const { return m_mode; }
    void setMode(const QString& mode);
    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    QString currentFile() const { return m_currentFile; }
    void setCurrentFile(const QString& file);
    QStringList files() const { return m_files; }
    bool hasSource() const { return m_model != nullptr; }
    bool live() const;
    int count() const { return rowCount(); }
    bool wrap() const;
    void setWrap(bool on);
    bool colorLines() const;
    void setColorLines(bool on);
    bool following() const;
    void setFollowing(bool on);
    bool uploading() const { return m_upload != nullptr; }
    QString message() const { return m_message; }
    QString fontFamily() const;
    int fontSize() const;

    Q_INVOKABLE QString plainText() const;
    Q_INVOKABLE void copyAll();
    Q_INVOKABLE void copyLine(int row);
    Q_INVOKABLE void clear();
    /// next row (after `from`, wrapping) whose line contains `text`; -1 if none
    Q_INVOKABLE int find(const QString& text, int from, bool backwards) const;
    /// all rows containing `text` (capped)
    Q_INVOKABLE int matchCount(const QString& text) const;
    Q_INVOKABLE void reload();
    Q_INVOKABLE void refreshFiles();
    /// "" on success
    Q_INVOKABLE QString deleteCurrentFile();
    /// returns the files that could not be deleted
    Q_INVOKABLE QStringList cleanFiles();
    Q_INVOKABLE QString currentFilePath() const;
    Q_INVOKABLE void openLogsFolder();

    /// info for the upload confirmation: { host, lines, maxLines, tooLong }
    Q_INVOKABLE QVariantMap uploadInfo() const;
    /// start uploading (after the user confirmed). truncate: shorten logs above the mclo.gs limit
    Q_INVOKABLE void upload(const QString& name, bool truncate);

   signals:
    void sourceChanged();
    void filesChanged();
    void countChanged();
    void optionsChanged();
    void uploadingChanged();
    void uploadFinished(const QString& url);
    void uploadFailed(const QString& reason);
    /// the live model was reset (e.g. new launch) - views should scroll to the end
    void restarted();

   private:
    void rebuild();
    void setLiveModel(LogModel* model);
    void loadFile();
    void attachLaunchTask(LaunchTask* task);

    QString m_mode = "console";
    QString m_instanceId;
    QString m_currentFile;
    QStringList m_files;
    QString m_message;
    QPointer<MinecraftInstance> m_inst;
    QPointer<LogModel> m_model;
    shared_qobject_ptr<LogModel> m_liveHolder;
    LogModel* m_fileModel = nullptr;
    QMetaObject::Connection m_launchConn;
    QFileSystemWatcher m_watcher;
    NetJob::Ptr m_upload;
    bool m_colorLines = true;
};
