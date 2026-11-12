#include "ModernLaunchHandler.h"

#include <QEventLoop>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegularExpression>

#include "Application.h"
#include "ImageProviders.h"
#include "LaunchController.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/auth/AccountList.h"
#include "net/RawHeaderProxy.h"
#include "tasks/Task.h"
#include "ui/dialogs/MSALoginDialog.h"

static ModernLaunchHandler* s_handler = nullptr;

ModernLaunchHandler::ModernLaunchHandler(QObject* parent) : QObject(parent) {}

ModernLaunchHandler* ModernLaunchHandler::instance()
{
    if (!s_handler) {
        s_handler = new ModernLaunchHandler(APPLICATION);
    }
    return s_handler;
}

ModernLaunchHandler* ModernLaunchHandler::create(QQmlEngine*, QJSEngine*)
{
    auto* h = instance();
    QJSEngine::setObjectOwnership(h, QJSEngine::CppOwnership);
    return h;
}

void ModernLaunchHandler::install(QQmlEngine* engine, QQuickWindow* window)
{
    auto* self = instance();
    if (!engine || !window || self->m_host) {
        return;
    }
    QQmlComponent component(engine, "PrismModern", "LaunchDialogHost");
    auto* obj = component.create();
    auto* item = qobject_cast<QQuickItem*>(obj);
    if (!item) {
        qWarning() << "Modern UI: could not create LaunchDialogHost:" << component.errorString();
        delete obj;
        return;
    }
    item->setParentItem(window->contentItem());
    item->setParent(window->contentItem());
    self->m_host = item;
    LaunchController::setInteraction(self);
}

QVariantMap ModernLaunchHandler::ask(const QString& kind, const QVariantMap& data)
{
    const int id = m_nextId++;
    Pending pending;
    QEventLoop loop;
    pending.loop = &loop;
    m_pending.insert(id, &pending);
    emit requested(id, kind, data);
    if (!pending.answered) {
        loop.exec(QEventLoop::DialogExec);
    }
    m_pending.remove(id);
    auto result = pending.result;
    result.insert("_id", id);
    return result;
}

void ModernLaunchHandler::respond(int id, const QVariantMap& result)
{
    auto* pending = m_pending.value(id);
    if (!pending || pending->answered) {
        return;
    }
    pending->answered = true;
    pending->result = result;
    if (pending->loop) {
        pending->loop->quit();
    }
}

bool ModernLaunchHandler::askOpenAccountManager()
{
    return ask("noAccounts", {}).value("accepted").toBool();
}

MinecraftAccountPtr ModernLaunchHandler::chooseAccount(const QString& message, bool* useAsGlobalDefault)
{
    auto* accounts = APPLICATION->accounts();
    QVariantList list;
    for (int i = 0; i < accounts->count(); i++) {
        auto account = accounts->at(i);
        QString face;
        auto pix = account->getFace();
        if (!pix.isNull()) {
            face = "face-" + account->profileId();
            PixmapCacheProvider::insert(face, pix);
            face = "image://pixmap/" + face;
        }
        list.append(QVariantMap{ { "id", account->profileId() },
                                 { "name", account->displayName() },
                                 { "type", account->typeString() },
                                 { "face", face } });
    }
    auto result = ask("chooseAccount", { { "message", message }, { "accounts", list } });
    const auto id = result.value("accountId").toString();
    if (!result.value("accepted").toBool() || id.isEmpty()) {
        return nullptr;
    }
    if (useAsGlobalDefault) {
        *useAsGlobalDefault = result.value("useAsDefault").toBool();
    }
    const int index = accounts->findAccountByProfileId(id);
    return index >= 0 ? accounts->at(index) : nullptr;
}

bool ModernLaunchHandler::askPlayDemo(const QString& text)
{
    return ask("playDemo", { { "text", text } }).value("accepted").toBool();
}

bool ModernLaunchHandler::askOfflineName(const QString& title, const QString& message, QString& name)
{
    auto result = ask("offlineName", { { "title", title }, { "text", message }, { "name", name } });
    if (!result.value("accepted").toBool()) {
        return false;
    }
    name = result.value("name").toString();
    return !name.isEmpty();
}

bool ModernLaunchHandler::setupProfile(MinecraftAccountPtr account)
{
    // the id is only known inside ask(), so reserve it here
    const int id = m_nextId;
    m_profileAccounts.insert(id, account);
    auto result = ask("profileSetup", { { "account", account->displayName() } });
    m_profileAccounts.remove(id);
    m_netTasks.remove(id);
    return result.value("accepted").toBool();
}

void ModernLaunchHandler::checkProfileName(int id, const QString& name)
{
    auto account = m_profileAccounts.value(id);
    if (!account) {
        return;
    }
    static const QRegularExpression s_permittedNames("^[a-zA-Z0-9_]{3,16}$");
    if (!s_permittedNames.match(name).hasMatch()) {
        emit profileNameChecked(id, name, "invalid", tr("Names must be 3 to 16 characters long and only use letters, digits and _."));
        return;
    }
    emit profileNameChecked(id, name, "pending", QString());
    QUrl url(QString("https://api.minecraftservices.com/minecraft/profile/name/%1/available").arg(name));
    auto headers = QList<Net::HeaderPair>{ { "Content-Type", "application/json" },
                                           { "Accept", "application/json" },
                                           { "Authorization", QString("Bearer %1").arg(account->accessToken()).toUtf8() } };
    auto [task, response] = Net::Request::makeByteArray(url);
    task->addHeaderProxy(std::make_unique<Net::RawHeaderProxy>(headers));
    task->setNetwork(APPLICATION->network());
    connect(task.get(), &Task::finished, this, [this, id, name, task, response] {
        if (task->error() != QNetworkReply::NoError) {
            emit profileNameChecked(id, name, "error", tr("Failed to check name availability."));
            return;
        }
        const auto status = QJsonDocument::fromJson(*response).object().value("status").toString("INVALID");
        if (status == "AVAILABLE") {
            emit profileNameChecked(id, name, "available", QString());
        } else if (status == "DUPLICATE") {
            emit profileNameChecked(id, name, "taken", tr("A Minecraft profile named %1 already exists.").arg(name));
        } else if (status == "NOT_ALLOWED") {
            emit profileNameChecked(id, name, "taken", tr("The name %1 is not allowed.").arg(name));
        } else {
            emit profileNameChecked(id, name, "error", tr("Unhandled profile name status: %1").arg(status));
        }
    });
    task->start();
}

void ModernLaunchHandler::createProfile(int id, const QString& name)
{
    auto account = m_profileAccounts.value(id);
    if (!account) {
        return;
    }
    QUrl url("https://api.minecraftservices.com/minecraft/profile");
    auto headers = QList<Net::HeaderPair>{ { "Content-Type", "application/json" },
                                           { "Accept", "application/json" },
                                           { "Authorization", QString("Bearer %1").arg(account->accessToken()).toUtf8() } };
    auto [task, response] = Net::Request::makeByteArray(url, QString("{\"profileName\":\"%1\"}").arg(name).toUtf8());
    task->addHeaderProxy(std::make_unique<Net::RawHeaderProxy>(headers));
    task->setNetwork(APPLICATION->network());
    m_netTasks.insert(id, task);
    connect(task.get(), &Task::finished, this, [this, id, task, response] {
        if (task->error() == QNetworkReply::NoError) {
            respond(id, { { "accepted", true } });
            emit requestFinished(id);
            return;
        }
        auto obj = QJsonDocument::fromJson(*response).object();
        QString message = tr("Network error: %1 (HTTP %2)").arg(task->errorString()).arg(task->replyStatusCode());
        if (obj.contains("errorMessage")) {
            message += "\n" + obj.value("errorMessage").toString();
        }
        emit profileCreateFailed(id, message);
    });
    task->start();
}

MinecraftAccountPtr ModernLaunchHandler::reauthenticate(MinecraftAccountPtr account, const QString& reason)
{
    auto result = ask("reauth", { { "reason", reason }, { "account", account->profileName() } });
    if (!result.value("accepted").toBool() || account->accountType() != AccountType::MSA) {
        return nullptr;
    }
    // The Microsoft login flow is still the classic dialog (shared with the accounts page).
    return MSALoginDialog::newAccount(nullptr);
}

void ModernLaunchHandler::waitForTask(Task* task, bool skippable)
{
    if (!task || task->isFinished()) {
        return;
    }
    const int id = m_nextId;
    auto c1 = connect(task, &Task::status, this, [this, id, task](const QString& s) {
        emit progressChanged(id, s, task->getProgress(), task->getTotalProgress());
    });
    auto c2 = connect(task, &Task::progress, this,
                      [this, id, task](qint64 cur, qint64 total) { emit progressChanged(id, task->getStatus(), cur, total); });
    auto c3 = connect(task, &Task::finished, this, [this, id] {
        respond(id, { { "finished", true } });
        emit requestFinished(id);
    });
    auto result = ask("progress", { { "status", task->getStatus() }, { "skippable", skippable } });
    disconnect(c1);
    disconnect(c2);
    disconnect(c3);
    if (result.value("skip").toBool() && !task->isFinished()) {
        task->abort();
    }
}

void ModernLaunchHandler::showTaskProgress(MinecraftInstance* instance, Task* task)
{
    if (!instance || !task) {
        return;
    }
    const auto id = instance->id();
    m_tasks.insert(id, task);
    connect(task, &Task::finished, this, [this, id] {
        m_tasks.remove(id);
        emit instanceTaskChanged(id);
    });
    connect(task, &QObject::destroyed, this, [this, id] {
        m_tasks.remove(id);
        emit instanceTaskChanged(id);
    });
    emit instanceTaskChanged(id);
}

bool ModernLaunchHandler::confirmKill(MinecraftInstance* instance)
{
    return ask("confirmKill", { { "name", instance ? instance->name() : QString() } }).value("accepted").toBool();
}

void ModernLaunchHandler::showError(const QString& title, const QString& message)
{
    emit errorRaised(title, message);
}

void ModernLaunchHandler::waitForProfiler(const QString& message, bool* disableProfiler)
{
    auto result = ask("profiler", { { "text", message } });
    if (disableProfiler) {
        *disableProfiler = result.value("disable").toBool();
    }
}

QString ModernLaunchHandler::checkJvmArgs(const QString& args)
{
    static const QRegularExpression s_memRegex("-Xm[sx]");
    static const QRegularExpression s_versionRegex("-version:.*");
    QString error;
    if (args.contains("-XX:PermSize=") || args.contains(s_memRegex) || args.contains("-XX-MaxHeapSize") ||
        args.contains("-XX:InitialHeapSize")) {
        error = tr("You tried to manually set a JVM memory option (using \"-XX:PermSize\", \"-XX-MaxHeapSize\", \"-XX:InitialHeapSize\", "
                   "\"-Xmx\" or \"-Xms\"). Use the dedicated memory settings instead.");
    } else if (args.contains(s_versionRegex)) {
        error = tr("You tried to pass a required Java version argument to the JVM (using \"-version:xxx\"). This is not safe and is not "
                   "allowed.");
    }
    if (!error.isEmpty()) {
        emit errorRaised(tr("JVM arguments warning"), error);
    }
    return error;
}

void ModernLaunchHandler::launchFailed(MinecraftInstance* instance, const QString& reason)
{
    emit launchFailedFor(instance->id(), instance->name(), reason);
}
