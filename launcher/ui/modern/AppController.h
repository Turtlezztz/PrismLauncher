#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include <QVariant>

#include "InstanceModel.h"
class MinecraftInstance;

/**
 * The `App` QML singleton: global launcher state + actions that don't belong to a specific feature area.
 * Feature areas (instance pages, settings, accounts, modplatforms...) get their own bridge classes.
 */
class AppController : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(App)
    QML_SINGLETON

    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString platform READ platform CONSTANT)
    Q_PROPERTY(InstanceModel* instances READ instances CONSTANT)
    Q_PROPERTY(QStringList groups READ groups NOTIFY groupsChanged)
    Q_PROPERTY(bool canUndoDelete READ canUndoDelete NOTIFY canUndoDeleteChanged)
    Q_PROPERTY(int runningCount READ runningCount NOTIFY runningCountChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)            // system | dark | light
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY accentChanged)        // #rrggbb
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY reduceMotionChanged)
    // --- the background cat (same settings as the classic main window) ---
    Q_PROPERTY(bool catEnabled READ catEnabled NOTIFY catChanged)                          // "EnableCat"
    Q_PROPERTY(bool catVisible READ catVisible WRITE setCatVisible NOTIFY catChanged)     // "TheCat"
    Q_PROPERTY(QUrl catSource READ catSource NOTIFY catChanged)                           // current cat pack image (seasonal aware)
    Q_PROPERTY(qreal catOpacity READ catOpacity NOTIFY catChanged)                        // 0..1 ("CatOpacity")
    Q_PROPERTY(QString catFit READ catFit NOTIFY catChanged)                              // fit | fill | stretch ("CatFit")

   public:
    explicit AppController(QObject* parent = nullptr);
    static AppController* create(QQmlEngine*, QJSEngine*);
    static AppController* instance();

    QString appName() const;
    QString version() const;
    QString platform() const;
    InstanceModel* instances() const { return m_instances; }
    QStringList groups() const;
    bool canUndoDelete() const;
    int runningCount() const;

    QString theme() const;
    void setTheme(const QString& theme);
    QString accent() const;
    void setAccent(const QString& accent);
    bool reduceMotion() const;
    void setReduceMotion(bool on);

    bool catEnabled() const;
    bool catVisible() const;
    void setCatVisible(bool visible);
    QUrl catSource() const;
    qreal catOpacity() const;
    QString catFit() const;

    // --- instance actions ---
    Q_INVOKABLE bool launch(const QString& instanceId, bool offline = false, const QString& profileName = QString());
    Q_INVOKABLE bool kill(const QString& instanceId);
    /// Returns "" on success or an error message. Moves to trash when possible.
    Q_INVOKABLE QString deleteInstance(const QString& instanceId);
    Q_INVOKABLE bool undoDelete();
    Q_INVOKABLE bool renameInstance(const QString& instanceId, const QString& newName);
    Q_INVOKABLE void setInstanceGroup(const QString& instanceId, const QString& group);
    Q_INVOKABLE void renameGroup(const QString& from, const QString& to);
    Q_INVOKABLE void deleteGroup(const QString& group);
    Q_INVOKABLE void setInstanceIcon(const QString& instanceId, const QString& iconKey);
    Q_INVOKABLE void openInstanceFolder(const QString& instanceId, const QString& subPath = QString());
    Q_INVOKABLE bool instanceExists(const QString& instanceId) const;
    Q_INVOKABLE QStringList instanceShortcuts(const QString& instanceId) const;

    // --- launcher-wide actions ---
    /// which: root | instances | centralMods | skins | iconThemes | widgetThemes | catPacks | icons | logs | java | templates
    Q_INVOKABLE void openFolder(const QString& which);
    Q_INVOKABLE void openUrl(const QString& url);
    Q_INVOKABLE void openPath(const QString& path);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE QString urlToLocalFile(const QUrl& url) const;

    // --- settings access (APPLICATION->settings()) ---
    Q_INVOKABLE QVariant setting(const QString& key) const;
    Q_INVOKABLE void setSetting(const QString& key, const QVariant& value);
    Q_INVOKABLE void resetSetting(const QString& key);

    /// Switch back to the classic widget UI (takes effect on restart).
    Q_INVOKABLE void useClassicUi(bool classic);
    Q_INVOKABLE void restart();

    /// Show a toast from C++ or QML. kind: info | success | warning | error
    Q_INVOKABLE void notify(const QString& message, const QString& kind = "info");

   signals:
    void groupsChanged();
    void canUndoDeleteChanged();
    void runningCountChanged();
    void themeChanged();
    void accentChanged();
    void reduceMotionChanged();
    void catChanged();
    void settingChanged(const QString& key, const QVariant& value);
    void toast(const QString& message, const QString& kind);

   private:
    MinecraftInstance* find(const QString& id) const;
    InstanceModel* m_instances = nullptr;
};
