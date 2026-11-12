#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QSet>
#include <QTimer>

class MinecraftInstance;
class ResTaskHandle;

/**
 * QML model for an instance's screenshots folder. Thumbnails are served by image://resthumb (decoded off the UI thread, cached).
 *   ResScreenshotModel { instanceId: id }
 */
class ResScreenshotModel : public QAbstractListModel, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY sourceChanged)
    Q_PROPERTY(QString folder READ folder NOTIFY sourceChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(bool uploading READ uploading NOTIFY uploadingChanged)
    Q_PROPERTY(QString uploadHost READ uploadHost CONSTANT)

   public:
    enum Roles { FileNameRole = Qt::UserRole + 1, BaseNameRole, PathRole, UrlRole, ThumbRole, DateTextRole, SizeTextRole, SelectedRole };

    explicit ResScreenshotModel(QObject* parent = nullptr);
    void classBegin() override {}
    void componentComplete() override;

    int rowCount(const QModelIndex& parent = {}) const override { return parent.isValid() ? 0 : static_cast<int>(m_files.size()); }
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    QString folder() const { return m_folder; }
    int count() const { return rowCount(); }
    int selectedCount() const { return static_cast<int>(m_selected.size()); }
    bool uploading() const { return m_uploading; }
    QString uploadHost() const;

    Q_INVOKABLE void select(int row, const QString& mode = "single");
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE QStringList selectedPaths() const;
    Q_INVOKABLE QVariantMap get(int row) const;

    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void copyImage(int row);
    Q_INVOKABLE void copySelectedFiles();
    Q_INVOKABLE int deleteSelected();
    /// returns "" on success or an error message
    Q_INVOKABLE QString rename(int row, const QString& newBaseName);
    Q_INVOKABLE void addFiles(const QList<QUrl>& urls);
    /// Uploads the selection to imgur; the task's done() handler should then read lastUploadLink
    Q_INVOKABLE ResTaskHandle* uploadSelected();
    Q_INVOKABLE QString lastUploadLink() const { return m_lastLink; }
    Q_INVOKABLE void refresh();

   signals:
    void sourceChanged();
    void countChanged();
    void selectionChanged();
    void uploadingChanged();

   private:
    struct Entry {
        QString path;
        QString fileName;
        QDateTime modified;
        qint64 size = 0;
    };
    void scan();

    QString m_instanceId;
    QString m_folder;
    bool m_complete = false;
    QList<Entry> m_files;
    QSet<QString> m_selected;
    int m_anchor = -1;
    QFileSystemWatcher m_watcher;
    QTimer m_rescan;
    bool m_uploading = false;
    QString m_lastLink;
};
