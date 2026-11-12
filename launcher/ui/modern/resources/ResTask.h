#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QStringList>

#include "tasks/Task.h"

/**
 * QML view of a running launcher Task (progress, status, abort).
 * Bridges create these and hand them to QML; show them with `ResTaskDialog { handle: ... }`.
 * The handle owns (shares) the task, and deletes itself a while after the task finished.
 */
class ResTaskHandle : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by resource bridges")
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString details READ details NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)  // 0..1, -1 = indeterminate
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(bool finished READ finished NOTIFY changed)
    Q_PROPERTY(bool succeeded READ succeeded NOTIFY changed)
    Q_PROPERTY(bool canAbort READ canAbort NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QStringList warnings READ warnings NOTIFY changed)

   public:
    ResTaskHandle(Task::Ptr task, const QString& title, QObject* parent = nullptr);
    ~ResTaskHandle() override;

    /// Convenience: create a handle, start the task, return the handle (owned by `parent`).
    static ResTaskHandle* run(Task::Ptr task, const QString& title, QObject* parent);

    QString title() const { return m_title; }
    QString status() const { return m_status; }
    QString details() const { return m_details; }
    double progress() const { return m_progress; }
    bool running() const { return m_running; }
    bool finished() const { return m_finished; }
    bool succeeded() const { return m_succeeded; }
    bool canAbort() const;
    QString error() const { return m_error; }
    QStringList warnings() const { return m_warnings; }
    Task* task() const { return m_task.get(); }

    void start();
    Q_INVOKABLE void abort();

   signals:
    void changed();
    /// ok=false with an empty error means the task was aborted.
    void done(bool ok, const QString& error, const QStringList& warnings);

   private:
    void finish(bool ok, const QString& error);

    Task::Ptr m_task;
    QString m_title;
    QString m_status;
    QString m_details;
    double m_progress = -1;
    bool m_running = false;
    bool m_finished = false;
    bool m_succeeded = false;
    QString m_error;
    QStringList m_warnings;
};
