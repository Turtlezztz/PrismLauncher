#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

#include "tasks/Task.h"

/**
 * QML view of a core Task (status, details, progress, sub-step progress, warnings, abort).
 * Used by `TaskProgressDialog.qml`. Any bridge that runs a Task can hand one of these to QML:
 *
 *     auto* bridge = new TaskBridge(this);
 *     bridge->setTask(task, tr("Creating instance"));   // takes shared ownership
 *     bridge->start();
 *     return bridge;   // QML: TaskProgressDialog { task: bridge }
 */
class TaskBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by C++ bridges")

    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString details READ details NOTIFY statusChanged)
    Q_PROPERTY(qint64 progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(qint64 total READ total NOTIFY progressChanged)
    /// 0..1, or -1 when indeterminate
    Q_PROPERTY(double fraction READ fraction NOTIFY progressChanged)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY stateChanged)
    Q_PROPERTY(bool succeeded READ succeeded NOTIFY stateChanged)
    Q_PROPERTY(bool aborted READ aborted NOTIFY stateChanged)
    Q_PROPERTY(QString failReason READ failReason NOTIFY stateChanged)
    Q_PROPERTY(QStringList warnings READ warnings NOTIFY stateChanged)
    Q_PROPERTY(bool canAbort READ canAbort NOTIFY abortChanged)
    Q_PROPERTY(QString abortText READ abortText NOTIFY abortChanged)
    /// [{ status, details, fraction, state: "waiting|running|failed|succeeded" }] for multi-step tasks (downloads)
    Q_PROPERTY(QVariantList steps READ steps NOTIFY stepsChanged)
    /// free-form result for callers (e.g. the id of a created instance)
    Q_PROPERTY(QString resultId READ resultId NOTIFY resultIdChanged)

   public:
    explicit TaskBridge(QObject* parent = nullptr);
    ~TaskBridge() override;

    /// A bridge owned by the application (C++ ownership) that deletes itself a while after the task finished.
    /// Use this for tasks that must survive the page that started them.
    static TaskBridge* createDetached();

    void setTask(Task::Ptr task, const QString& title = {});
    Task* task() const { return m_task.get(); }
    void setResultId(const QString& id);

    QString title() const { return m_title; }
    QString status() const { return m_status; }
    QString details() const { return m_details; }
    qint64 progress() const { return m_progress; }
    qint64 total() const { return m_total; }
    double fraction() const;
    bool running() const { return m_running; }
    bool finished() const { return m_finished; }
    bool succeeded() const { return m_succeeded; }
    bool aborted() const { return m_aborted; }
    QString failReason() const { return m_failReason; }
    QStringList warnings() const { return m_warnings; }
    bool canAbort() const { return m_canAbort; }
    QString abortText() const { return m_abortText; }
    QVariantList steps() const;
    QString resultId() const { return m_resultId; }

    /// start the task (no-op if already started)
    Q_INVOKABLE void start();
    Q_INVOKABLE bool abort();

   signals:
    void titleChanged();
    void statusChanged();
    void progressChanged();
    void stateChanged();
    void abortChanged();
    void stepsChanged();
    void resultIdChanged();
    void taskSucceeded();
    void taskFailed(const QString& reason);
    void taskAborted();
    void taskFinished();

   private:
    Task::Ptr m_task;
    QString m_title;
    QString m_status;
    QString m_details;
    qint64 m_progress = 0;
    qint64 m_total = -1;
    bool m_running = false;
    bool m_finished = false;
    bool m_succeeded = false;
    bool m_aborted = false;
    bool m_canAbort = false;
    QString m_abortText;
    QString m_failReason;
    QStringList m_warnings;
    QString m_resultId;
    QList<TaskStepProgress> m_steps;
    bool m_stepsDirty = false;
};
