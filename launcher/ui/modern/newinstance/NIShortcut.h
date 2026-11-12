#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include <QVariantList>

/**
 * Backend of CreateShortcutDialog.qml (classic CreateShortcutDialog).
 */
class NIShortcut : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceChanged)
    Q_PROPERTY(QString instanceName READ instanceName NOTIFY instanceChanged)
    Q_PROPERTY(QString iconKey READ iconKey NOTIFY instanceChanged)
    /// [{ value: "desktop"|"applications"|"other", text }]
    Q_PROPERTY(QVariantList targets READ targets CONSTANT)
    Q_PROPERTY(bool quickJoinSupported READ quickJoinSupported NOTIFY instanceChanged)
    /// [{ value: <world name>, text }]
    Q_PROPERTY(QVariantList worlds READ worlds NOTIFY instanceChanged)
    /// [{ value: <profile name>, text }]
    Q_PROPERTY(QVariantList accounts READ accounts CONSTANT)
    Q_PROPERTY(int defaultAccount READ defaultAccount CONSTANT)
    Q_PROPERTY(QString otherExtension READ otherExtension CONSTANT)

   public:
    explicit NIShortcut(QObject* parent = nullptr);

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    QString instanceName() const;
    QString iconKey() const;
    QVariantList targets() const;
    bool quickJoinSupported() const { return m_quickJoin; }
    QVariantList worlds() const { return m_worlds; }
    QVariantList accounts() const;
    int defaultAccount() const;
    QString otherExtension() const;

    /// suggested file for "Other..." (desktop folder + name)
    Q_INVOKABLE QUrl suggestedOtherFile(const QString& name) const;

    /**
     * Create the shortcut. launchTarget: "" (instance) | "world" | "server".
     * For target "other", otherFile is the file chosen in a save dialog. Returns "" on success or an error message.
     */
    Q_INVOKABLE QString create(const QString& name, const QString& target, const QString& launchTarget, const QString& world,
                               const QString& server, const QString& account, const QString& iconKey, const QUrl& otherFile);

   signals:
    void instanceChanged();

   private:
    QString m_id;
    bool m_quickJoin = false;
    QVariantList m_worlds;
};
