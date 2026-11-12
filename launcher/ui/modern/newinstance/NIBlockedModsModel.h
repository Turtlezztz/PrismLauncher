#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QQmlEngine>
#include <QSet>

#include "tasks/ConcurrentTask.h"
#include "ui/dialogs/BlockedModsDialog.h"

/**
 * Widget-free port of BlockedModsDialog's logic: watches the downloads / central mods folders (plus folders the user
 * adds or files the user drops), hashes candidate files and matches them against the blocked mods list.
 * Operates on the caller's QList<BlockedMod> in place (like the classic dialog).
 */
class NIBlockedModsModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by NiInteraction")
    Q_PROPERTY(QStringList watchedFolders READ watchedFolders NOTIFY changed)
    Q_PROPERTY(int matchedCount READ matchedCount NOTIFY changed)
    Q_PROPERTY(int total READ total CONSTANT)
    Q_PROPERTY(bool allMatched READ allMatched NOTIFY changed)

   public:
    enum Roles { NameRole = Qt::UserRole + 1, UrlRole, HashRole, MatchedRole, PathRole };
    NIBlockedModsModel(QList<BlockedMod>& mods, QString hashType, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override { return parent.isValid() ? 0 : static_cast<int>(m_mods.size()); }
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QStringList watchedFolders() const { return m_watcher.directories(); }
    int matchedCount() const;
    int total() const { return static_cast<int>(m_mods.size()); }
    bool allMatched() const { return matchedCount() == total(); }

    Q_INVOKABLE void start();
    Q_INVOKABLE void openMissing();
    Q_INVOKABLE void openUrl(int row);
    Q_INVOKABLE void addFolder(const QUrl& folder);
    Q_INVOKABLE void addFiles(const QList<QUrl>& files);
    Q_INVOKABLE void stop();

   signals:
    void changed();

   private:
    void refresh();
    void directoryChanged(const QString& path);
    void watchPath(const QString& path, bool recursive);
    void scanPaths();
    void scanPath(const QString& path, bool startTask);
    void runHashTask();
    void checkMatchHash(const QString& hash, const QString& path);
    bool checkValidPath(const QString& path);
    void validateMatchedMods();

    QList<BlockedMod>& m_mods;
    QString m_hashType;
    QFileSystemWatcher m_watcher;
    shared_qobject_ptr<ConcurrentTask> m_hashingTask;
    QSet<QString> m_pendingHashPaths;
    bool m_rehashPending = false;
};
