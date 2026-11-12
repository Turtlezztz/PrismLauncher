#include "ResTask.h"

#include <QTimer>

ResTaskHandle::ResTaskHandle(Task::Ptr task, const QString& title, QObject* parent) : QObject(parent), m_task(std::move(task)), m_title(title)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    auto* t = m_task.get();
    connect(t, &Task::status, this, [this](const QString& s) {
        m_status = s;
        emit changed();
    });
    connect(t, &Task::details, this, [this](const QString& s) {
        m_details = s;
        emit changed();
    });
    connect(t, &Task::progress, this, [this](qint64 cur, qint64 total) {
        m_progress = total > 0 ? qBound(0.0, double(cur) / double(total), 1.0) : -1;
        emit changed();
    });
    connect(t, &Task::abortStatusChanged, this, &ResTaskHandle::changed);
    connect(t, &Task::warningLogged, this, [this](const QString& w) {
        m_warnings << w;
        emit changed();
    });
    connect(t, &Task::succeeded, this, [this] { finish(true, {}); });
    connect(t, &Task::failed, this, [this](const QString& reason) { finish(false, reason.isEmpty() ? tr("Unknown error") : reason); });
    connect(t, &Task::aborted, this, [this] { finish(false, {}); });
}

ResTaskHandle::~ResTaskHandle()
{
    if (m_task && m_task->isRunning()) {
        m_task->disconnect(this);
    }
}

ResTaskHandle* ResTaskHandle::run(Task::Ptr task, const QString& title, QObject* parent)
{
    auto* h = new ResTaskHandle(std::move(task), title, parent);
    // start on the next event loop turn so QML can bind to the handle first
    QTimer::singleShot(0, h, &ResTaskHandle::start);
    return h;
}

bool ResTaskHandle::canAbort() const
{
    return m_task && m_running && m_task->canAbort();
}

void ResTaskHandle::start()
{
    if (m_running || m_finished || !m_task) {
        return;
    }
    m_running = true;
    m_status = m_task->getStatus();
    emit changed();
    if (m_task->isRunning()) {
        return;
    }
    m_task->start();
}

void ResTaskHandle::abort()
{
    if (m_task && m_task->isRunning()) {
        m_task->abort();
    }
}

void ResTaskHandle::finish(bool ok, const QString& error)
{
    if (m_finished) {
        return;
    }
    m_running = false;
    m_finished = true;
    m_succeeded = ok;
    m_error = error;
    for (const auto& w : m_task->warnings()) {
        if (!m_warnings.contains(w)) {
            m_warnings << w;
        }
    }
    m_progress = 1;
    emit changed();
    emit done(ok, error, m_warnings);
}
