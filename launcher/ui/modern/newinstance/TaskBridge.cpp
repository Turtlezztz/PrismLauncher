#include "TaskBridge.h"

#include <QCoreApplication>
#include <QJSEngine>
#include <QTimer>

TaskBridge::TaskBridge(QObject* parent) : QObject(parent), m_abortText(tr("Cancel")) {}

TaskBridge* TaskBridge::createDetached()
{
    auto* bridge = new TaskBridge(QCoreApplication::instance());
    QJSEngine::setObjectOwnership(bridge, QJSEngine::CppOwnership);
    connect(bridge, &TaskBridge::taskFinished, bridge, [bridge] { QTimer::singleShot(120000, bridge, &QObject::deleteLater); });
    return bridge;
}

TaskBridge::~TaskBridge()
{
    if (m_task) {
        disconnect(m_task.get(), nullptr, this, nullptr);
    }
}

void TaskBridge::setTask(Task::Ptr task, const QString& title)
{
    if (m_task) {
        disconnect(m_task.get(), nullptr, this, nullptr);
    }
    m_task = std::move(task);
    m_title = title;
    emit titleChanged();
    if (!m_task) {
        return;
    }
    auto* t = m_task.get();
    m_canAbort = t->canAbort();
    m_status = t->getStatus();
    m_details = t->getDetails();

    connect(t, &Task::status, this, [this](const QString& s) {
        m_status = s;
        emit statusChanged();
    });
    connect(t, &Task::details, this, [this](const QString& d) {
        m_details = d;
        emit statusChanged();
    });
    connect(t, &Task::progress, this, [this](qint64 cur, qint64 total) {
        m_progress = cur;
        m_total = total;
        emit progressChanged();
    });
    connect(t, &Task::abortStatusChanged, this, [this](bool can) {
        m_canAbort = can;
        emit abortChanged();
    });
    connect(t, &Task::abortButtonTextChanged, this, [this](const QString& text) {
        m_abortText = text;
        emit abortChanged();
    });
    connect(t, &Task::stepProgress, this, [this](const TaskStepProgress& step) {
        bool found = false;
        for (auto& s : m_steps) {
            if (s.uid == step.uid) {
                s = step;
                found = true;
                break;
            }
        }
        if (!found) {
            m_steps.append(step);
        }
        // coalesce: downloads can emit thousands of updates per second
        if (!m_stepsDirty) {
            m_stepsDirty = true;
            QTimer::singleShot(100, this, [this] {
                m_stepsDirty = false;
                // drop finished steps so the list only shows what is happening now
                m_steps.removeIf([](const TaskStepProgress& s) { return s.isDone(); });
                emit stepsChanged();
            });
        }
    });
    connect(t, &Task::started, this, [this] {
        m_running = true;
        emit stateChanged();
    });
    connect(t, &Task::succeeded, this, [this] {
        m_succeeded = true;
        emit taskSucceeded();
    });
    connect(t, &Task::failed, this, [this](const QString& reason) {
        m_failReason = reason;
        emit taskFailed(reason);
    });
    connect(t, &Task::aborted, this, [this] {
        m_aborted = true;
        emit taskAborted();
    });
    connect(t, &Task::finished, this, [this] {
        m_running = false;
        m_finished = true;
        if (m_task) {
            m_warnings = m_task->warnings();
        }
        m_steps.clear();
        emit stepsChanged();
        emit stateChanged();
        emit taskFinished();
    });
    emit statusChanged();
    emit abortChanged();
    emit stateChanged();
}

void TaskBridge::setResultId(const QString& id)
{
    if (m_resultId != id) {
        m_resultId = id;
        emit resultIdChanged();
    }
}

double TaskBridge::fraction() const
{
    if (m_total <= 0) {
        return -1;
    }
    return qBound(0.0, double(m_progress) / double(m_total), 1.0);
}

QVariantList TaskBridge::steps() const
{
    QVariantList out;
    for (const auto& s : m_steps) {
        QVariantMap m;
        m["status"] = s.status;
        m["details"] = s.details;
        m["fraction"] = s.total > 0 ? qBound(0.0, double(s.current) / double(s.total), 1.0) : -1.0;
        switch (s.state) {
            case TaskStepState::Waiting:
                m["state"] = "waiting";
                break;
            case TaskStepState::Running:
                m["state"] = "running";
                break;
            case TaskStepState::Failed:
                m["state"] = "failed";
                break;
            case TaskStepState::Succeeded:
                m["state"] = "succeeded";
                break;
        }
        out << m;
        if (out.size() >= 6) {
            break;
        }
    }
    return out;
}

void TaskBridge::start()
{
    if (!m_task || m_task->isRunning() || m_task->isFinished()) {
        return;
    }
    m_running = true;
    emit stateChanged();
    // start from the event loop so QML can bind to the bridge first
    QTimer::singleShot(0, this, [this] {
        if (m_task && !m_task->isRunning() && !m_task->isFinished()) {
            m_task->start();
        }
    });
}

bool TaskBridge::abort()
{
    if (!m_task || !m_task->isRunning()) {
        return false;
    }
    return m_task->abort();
}
