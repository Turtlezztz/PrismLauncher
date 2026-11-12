#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QUrl>

#include "QObjectPtr.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "net/Request.h"

class AuthFlow;

/**
 * Microsoft sign-in (classic MSALoginDialog). Runs the device-code flow and the browser (OAuth) flow side by side;
 * whichever completes first wins.
 *
 *   MsaLogin { id: login; onSucceeded: name => ... }
 *   login.start()   login.cancel()
 */
class MsaLogin : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    /// waiting | code | failed
    Q_PROPERTY(QString deviceState READ deviceState NOTIFY stateChanged)
    Q_PROPERTY(QString deviceStatus READ deviceStatus NOTIFY stateChanged)
    Q_PROPERTY(QString code READ code NOTIFY stateChanged)
    Q_PROPERTY(QString verifyUrl READ verifyUrl NOTIFY stateChanged)
    Q_PROPERTY(QString displayUrl READ displayUrl NOTIFY stateChanged)
    Q_PROPERTY(QString qrSource READ qrSource NOTIFY stateChanged)
    Q_PROPERTY(int expiresIn READ expiresIn NOTIFY stateChanged)
    /// waiting | ready | failed
    Q_PROPERTY(QString browserState READ browserState NOTIFY stateChanged)
    Q_PROPERTY(QString browserStatus READ browserStatus NOTIFY stateChanged)
    /// make the new account the default one (always) instead of only when it is the first
    Q_PROPERTY(bool makeDefault MEMBER m_makeDefault NOTIFY stateChanged)

   public:
    explicit MsaLogin(QObject* parent = nullptr);
    ~MsaLogin() override;

    bool running() const { return m_running; }
    QString deviceState() const { return m_deviceState; }
    QString deviceStatus() const { return m_deviceStatus; }
    QString code() const { return m_code; }
    QString verifyUrl() const { return m_verifyUrl; }
    QString displayUrl() const { return m_displayUrl; }
    QString qrSource() const { return m_qrSource; }
    int expiresIn() const { return m_expiresIn; }
    QString browserState() const { return m_browserState; }
    QString browserStatus() const { return m_browserStatus; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void cancel();
    /// Opens the browser sign-in page (falls back to copying the URL). Returns false when no URL is ready yet.
    Q_INVOKABLE bool openBrowser();
    Q_INVOKABLE void openVerifyUrl();

   signals:
    void stateChanged();
    void succeeded(const QString& profileName);
    void failed(const QString& message);
    void cancelled();

   private:
    void finish();
    void checkBothFailed();

    MinecraftAccountPtr m_account;
    shared_qobject_ptr<AuthFlow> m_browserTask;
    shared_qobject_ptr<AuthFlow> m_deviceTask;
    bool m_running = false;
    bool m_makeDefault = false;
    QString m_deviceState = "waiting";
    QString m_deviceStatus;
    QString m_code;
    QString m_verifyUrl;
    QString m_displayUrl;
    QString m_qrSource;
    int m_expiresIn = 0;
    QString m_browserState = "waiting";
    QString m_browserStatus;
    QUrl m_browserUrl;
    int m_qrSerial = 0;
};

/**
 * Create a Minecraft profile (name) for an account that doesn't have one yet (classic ProfileSetupDialog).
 */
class ProfileSetup : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)
    /// notset | pending | available | exists | error
    Q_PROPERTY(QString nameStatus READ nameStatus NOTIFY statusChanged)
    Q_PROPERTY(QString message READ message NOTIFY statusChanged)
    Q_PROPERTY(bool working READ working NOTIFY statusChanged)

   public:
    explicit ProfileSetup(QObject* parent = nullptr);

    QString accountId() const { return m_accountId; }
    void setAccountId(const QString& id);
    QString nameStatus() const { return m_status; }
    QString message() const { return m_message; }
    bool working() const { return m_working; }

    /// Call whenever the name field changes; availability is checked after a short pause.
    Q_INVOKABLE void nameEdited(const QString& name);
    Q_INVOKABLE void submit();

   signals:
    void accountIdChanged();
    void statusChanged();
    void finished(bool ok);

   private:
    void setStatus(const QString& status, const QString& message = QString());
    void checkName(const QString& name);

    QString m_accountId;
    MinecraftAccountPtr m_account;
    QString m_status = "notset";
    QString m_message;
    bool m_working = false;
    bool m_checking = false;
    QString m_queued;
    QString m_current;
    QTimer m_timer;
    Net::Request::Ptr m_checkTask;
    Net::Request::Ptr m_setupTask;
};
