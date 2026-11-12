#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QVariantMap>

#include "LaunchInteraction.h"
#include "net/Request.h"

class QEventLoop;
class QQuickWindow;
class QQuickItem;

/**
 * Modern-UI implementation of the LaunchController dialogs (`LaunchUi` singleton in QML).
 *
 * Blocking questions are sent to QML through `requested(id, kind, data)` and answered with `respond(id, result)`;
 * a local event loop keeps LaunchController's synchronous flow intact. The QML side lives in
 * qml/pages/instance/LaunchDialogHost.qml, which install() creates inside the main window.
 *
 * kinds: noAccounts | chooseAccount | playDemo | offlineName | profileSetup | reauth | progress | confirmKill | profiler
 */
class ModernLaunchHandler : public QObject, public LaunchInteraction {
    Q_OBJECT
    QML_NAMED_ELEMENT(LaunchUi)
    QML_SINGLETON

   public:
    static ModernLaunchHandler* instance();
    static ModernLaunchHandler* create(QQmlEngine*, QJSEngine*);
    /// Create the QML dialog host in `window` and register with LaunchController.
    static void install(QQmlEngine* engine, QQuickWindow* window);

    // LaunchInteraction
    bool askOpenAccountManager() override;
    MinecraftAccountPtr chooseAccount(const QString& message, bool* useAsGlobalDefault) override;
    bool askPlayDemo(const QString& text) override;
    bool askOfflineName(const QString& title, const QString& message, QString& name) override;
    bool setupProfile(MinecraftAccountPtr account) override;
    MinecraftAccountPtr reauthenticate(MinecraftAccountPtr account, const QString& reason) override;
    void waitForTask(Task* task, bool skippable) override;
    void showTaskProgress(MinecraftInstance* instance, Task* task) override;
    bool confirmKill(MinecraftInstance* instance) override;
    void showError(const QString& title, const QString& message) override;
    void waitForProfiler(const QString& message, bool* disableProfiler) override;
    QString checkJvmArgs(const QString& args) override;
    void launchFailed(MinecraftInstance* instance, const QString& reason) override;

    /// Answer a pending request.
    Q_INVOKABLE void respond(int id, const QVariantMap& result);
    /// Profile setup: check if a name is available. Answers with profileNameChecked().
    Q_INVOKABLE void checkProfileName(int id, const QString& name);
    /// Profile setup: create the profile. Answers with profileCreated() or the request completes.
    Q_INVOKABLE void createProfile(int id, const QString& name);
    /// The auxiliary task (e.g. game update) the launch of `instanceId` is running, if any.
    Task* taskFor(const QString& instanceId) const { return m_tasks.value(instanceId); }

   signals:
    void requested(int id, const QString& kind, const QVariantMap& data);
    /// a request ended from the C++ side (e.g. the task the progress dialog waited for finished)
    void requestFinished(int id);
    void progressChanged(int id, const QString& status, qint64 current, qint64 total);
    void errorRaised(const QString& title, const QString& message);
    void launchFailedFor(const QString& instanceId, const QString& instanceName, const QString& reason);
    void instanceTaskChanged(const QString& instanceId);
    /// status: available | taken | invalid | error | pending
    void profileNameChecked(int id, const QString& name, const QString& status, const QString& message);
    void profileCreateFailed(int id, const QString& message);

   private:
    explicit ModernLaunchHandler(QObject* parent = nullptr);
    QVariantMap ask(const QString& kind, const QVariantMap& data);

    struct Pending {
        QEventLoop* loop = nullptr;
        QVariantMap result;
        bool answered = false;
    };
    int m_nextId = 1;
    QHash<int, Pending*> m_pending;
    QHash<QString, QPointer<Task>> m_tasks;
    QHash<int, MinecraftAccountPtr> m_profileAccounts;
    QHash<int, Net::Request::Ptr> m_netTasks;
    QPointer<QQuickItem> m_host;
};
