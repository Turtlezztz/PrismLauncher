#include "AccountFlows.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QJsonObject>
#include <QPainter>
#include <QRegularExpression>

#include "Application.h"
#include "DesktopServices.h"
#include "Handle.h"
#include "ImageProviders.h"
#include "AccountsModel.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/AuthFlow.h"
#include "net/RawHeaderProxy.h"

#include "qrencode.h"

namespace {
QPixmap renderQr(const QString& data, int size)
{
    QPixmap pixmap(size, size);
    pixmap.fill(Qt::white);
    Handle<QRcode, QRcode_free> qr{ QRcode_encodeString(data.toUtf8().constData(), 0, QRecLevel::QR_ECLEVEL_M, QRencodeMode::QR_MODE_8, 1) };
    if (!qr) {
        return {};
    }
    QPainter painter(&pixmap);
    painter.setPen(Qt::NoPen);
    painter.setBrush(Qt::black);
    const int qrSize = qr->width;
    const double scale = 0.86 * double(size) / qrSize;
    const double offset = (size - qrSize * scale) / 2;
    for (int y = 0; y < qrSize; y++) {
        for (int x = 0; x < qrSize; x++) {
            if (qr->data[y * qrSize + x] & 1) {
                painter.drawRect(QRectF(offset + x * scale, offset + y * scale, scale + 0.5, scale + 0.5));
            }
        }
    }
    return pixmap;
}
}  // namespace

// ---------------------------------------------------------------- MsaLogin

MsaLogin::MsaLogin(QObject* parent) : QObject(parent) {}

MsaLogin::~MsaLogin()
{
    if (m_running) {
        if (m_browserTask) {
            m_browserTask->disconnect(this);
            m_browserTask->abort();
        }
        if (m_deviceTask) {
            m_deviceTask->disconnect(this);
            m_deviceTask->abort();
        }
    }
}

void MsaLogin::start()
{
    if (m_running) {
        return;
    }
    m_running = true;
    m_deviceState = "waiting";
    m_browserState = "waiting";
    m_deviceStatus = tr("Please wait…");
    m_browserStatus = tr("Please wait…");
    m_code.clear();
    m_verifyUrl.clear();
    m_displayUrl.clear();
    m_qrSource.clear();
    m_browserUrl.clear();

    m_account = MinecraftAccount::createBlankMSA();

    m_browserTask.reset(new AuthFlow(m_account->accountData(), AuthFlow::Action::Login));
    connect(m_browserTask.get(), &Task::status, this, [this](const QString& s) {
        m_browserStatus = s;
        emit stateChanged();
    });
    connect(m_browserTask.get(), &AuthFlow::authorizeWithBrowser, this, [this](const QUrl& url) {
        m_browserUrl = url;
        m_browserState = "ready";
        emit stateChanged();
    });
    connect(m_browserTask.get(), &Task::succeeded, this, &MsaLogin::finish);
    connect(m_browserTask.get(), &Task::failed, this, [this](const QString& reason) {
        m_browserState = "failed";
        m_browserStatus = reason;
        emit stateChanged();
        checkBothFailed();
    });

    m_deviceTask.reset(new AuthFlow(m_account->accountData(), AuthFlow::Action::DeviceCode));
    connect(m_deviceTask.get(), &Task::status, this, [this](const QString& s) {
        m_deviceStatus = s;
        emit stateChanged();
    });
    connect(m_deviceTask.get(), &AuthFlow::authorizeWithBrowserWithExtra, this, [this](QString url, QString code, int expiresIn) {
        m_displayUrl = url;
        if (url == "https://www.microsoft.com/link" && !code.isEmpty()) {
            url += QString("?otc=%1").arg(code);
        }
        m_verifyUrl = url;
        m_code = code;
        m_expiresIn = expiresIn;
        const auto key = QString("msa-qr/%1").arg(++m_qrSerial);
        PixmapCacheProvider::insert(key, renderQr(url, 360));
        m_qrSource = "image://pixmap/" + key;
        m_deviceState = "code";
        emit stateChanged();
    });
    connect(m_deviceTask.get(), &Task::succeeded, this, &MsaLogin::finish);
    connect(m_deviceTask.get(), &Task::failed, this, [this](const QString& reason) {
        m_deviceState = "failed";
        m_deviceStatus = reason;
        emit stateChanged();
        checkBothFailed();
    });
    emit stateChanged();

    QMetaObject::invokeMethod(m_browserTask.get(), &Task::start, Qt::QueuedConnection);
    QMetaObject::invokeMethod(m_deviceTask.get(), &Task::start, Qt::QueuedConnection);
}

void MsaLogin::checkBothFailed()
{
    if (m_deviceState == "failed" && m_browserState == "failed") {
        m_running = false;
        emit stateChanged();
        emit failed(m_deviceStatus.isEmpty() ? m_browserStatus : m_deviceStatus);
    }
}

void MsaLogin::finish()
{
    if (!m_running) {
        return;
    }
    m_running = false;
    // stop the other flow
    for (auto& task : { m_browserTask, m_deviceTask }) {
        if (task) {
            task->disconnect(this);
            if (task->isRunning()) {
                task->abort();
            }
        }
    }
    auto* list = APPLICATION->accounts();
    list->addAccount(m_account);
    if (m_makeDefault || list->count() == 1) {
        list->setDefaultAccount(m_account);
    }
    emit stateChanged();
    emit succeeded(m_account->profileName());
}

void MsaLogin::cancel()
{
    if (!m_running) {
        return;
    }
    m_running = false;
    for (auto& task : { m_browserTask, m_deviceTask }) {
        if (task) {
            task->disconnect(this);
            task->abort();
        }
    }
    emit stateChanged();
    emit cancelled();
}

bool MsaLogin::openBrowser()
{
    if (!m_browserUrl.isValid()) {
        return false;
    }
    if (!DesktopServices::openUrl(m_browserUrl)) {
        QGuiApplication::clipboard()->setText(m_browserUrl.toString());
    }
    return true;
}

void MsaLogin::openVerifyUrl()
{
    if (!m_verifyUrl.isEmpty()) {
        DesktopServices::openUrl(QUrl(m_verifyUrl));
    }
}

// ---------------------------------------------------------------- ProfileSetup

ProfileSetup::ProfileSetup(QObject* parent) : QObject(parent)
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        if (!m_checking && !m_queued.isNull()) {
            checkName(m_queued);
        }
    });
}

void ProfileSetup::setAccountId(const QString& id)
{
    if (id == m_accountId) {
        return;
    }
    m_accountId = id;
    m_account = AccountsModel::findAccount(id);
    emit accountIdChanged();
}

void ProfileSetup::setStatus(const QString& status, const QString& message)
{
    m_status = status;
    m_message = message;
    emit statusChanged();
}

void ProfileSetup::nameEdited(const QString& name)
{
    static const QRegularExpression s_permitted("^[a-zA-Z0-9_]{3,16}$");
    if (!s_permitted.match(name).hasMatch()) {
        m_timer.stop();
        setStatus("notset", tr("Name must be 3–16 characters long and use only letters, numbers and underscores."));
        return;
    }
    m_queued = name;
    setStatus("pending");
    m_timer.start(1000);
}

void ProfileSetup::checkName(const QString& name)
{
    if (!m_account) {
        setStatus("error", tr("Account not found."));
        return;
    }
    m_current = name;
    m_checking = true;
    QUrl url(QString("https://api.minecraftservices.com/minecraft/profile/name/%1/available").arg(name));
    auto headers = QList<Net::HeaderPair>{ { "Content-Type", "application/json" },
                                           { "Accept", "application/json" },
                                           { "Authorization", QString("Bearer %1").arg(m_account->accessToken()).toUtf8() } };
    if (m_checkTask) {
        disconnect(m_checkTask.get(), nullptr, this, nullptr);
    }
    auto [task, response] = Net::Request::makeByteArray(url);
    m_checkTask = task;
    m_checkTask->addHeaderProxy(std::make_unique<Net::RawHeaderProxy>(headers));
    connect(m_checkTask.get(), &Task::finished, this, [this, response, name] {
        m_checking = false;
        if (m_checkTask->error() == QNetworkReply::NoError) {
            const auto status = QJsonDocument::fromJson(*response).object().value("status").toString("INVALID");
            if (status == "AVAILABLE") {
                setStatus("available", tr("“%1” is available.").arg(name));
            } else if (status == "DUPLICATE") {
                setStatus("exists", tr("Minecraft profile with name %1 already exists.").arg(name));
            } else if (status == "NOT_ALLOWED") {
                setStatus("exists", tr("The name %1 is not allowed.").arg(name));
            } else {
                setStatus("error", tr("Unhandled profile name status: %1").arg(status));
            }
        } else {
            setStatus("error", tr("Failed to check name availability."));
        }
        // the user typed something else meanwhile
        if (m_queued != name && m_status != "notset") {
            m_timer.start(0);
        }
    });
    m_checkTask->setNetwork(APPLICATION->network());
    m_checkTask->start();
}

void ProfileSetup::submit()
{
    if (m_working || m_status != "available" || !m_account) {
        return;
    }
    const QString profileName = m_current;
    QUrl url("https://api.minecraftservices.com/minecraft/profile");
    auto headers = QList<Net::HeaderPair>{ { "Content-Type", "application/json" },
                                           { "Accept", "application/json" },
                                           { "Authorization", QString("Bearer %1").arg(m_account->accessToken()).toUtf8() } };
    const QByteArray payload = QJsonDocument(QJsonObject{ { "profileName", profileName } }).toJson(QJsonDocument::Compact);
    auto [task, response] = Net::Request::makeByteArray(url, payload);
    m_setupTask = task;
    m_setupTask->addHeaderProxy(std::make_unique<Net::RawHeaderProxy>(headers));
    connect(m_setupTask.get(), &Task::finished, this, [this, response] {
        m_working = false;
        if (m_setupTask->error() == QNetworkReply::NoError) {
            setStatus("available");
            // fetch the new profile into the account
            APPLICATION->accounts()->requestRefresh(m_account->internalId());
            emit finished(true);
            return;
        }
        QString msg = tr("Network Error: %1\nHTTP Status: %2").arg(m_setupTask->errorString(), QString::number(m_setupTask->replyStatusCode()));
        const auto obj = QJsonDocument::fromJson(*response).object();
        if (obj.contains("errorMessage")) {
            msg += "\n" + obj.value("errorMessage").toString();
        } else if (!response->isEmpty()) {
            msg += "\n" + QString::fromUtf8(*response);
        }
        setStatus("error", tr("The server responded with the following error:") + "\n" + msg);
    });
    m_setupTask->setNetwork(APPLICATION->network());
    m_working = true;
    emit statusChanged();
    m_setupTask->start();
}
