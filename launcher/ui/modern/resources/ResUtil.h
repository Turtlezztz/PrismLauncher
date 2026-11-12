#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>

/**
 * `ResUtil` QML singleton: small helpers for the instance-content / resource-browser area.
 */
class ResUtil : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

   public:
    explicit ResUtil(QObject* parent = nullptr) : QObject(parent) {}
    static ResUtil* create(QQmlEngine* engine, QJSEngine*);

    /// Write text to a file chosen with a FileDialog. Returns "" or an error message.
    Q_INVOKABLE QString saveText(const QUrl& file, const QString& text) const;
    Q_INVOKABLE void copyText(const QString& text) const;
    /// Which mod folders apply to this instance: ["mods", "coremods"?, "nilmods"?]
    Q_INVOKABLE QStringList modFolders(const QString& instanceId) const;
    Q_INVOKABLE QString instanceName(const QString& instanceId) const;
    Q_INVOKABLE bool instanceRunning(const QString& instanceId) const;
    Q_INVOKABLE QString centralModsDir() const;
    Q_INVOKABLE QUrl localUrl(const QString& path) const { return QUrl::fromLocalFile(path); }
    Q_INVOKABLE void openPath(const QString& path) const;
};
