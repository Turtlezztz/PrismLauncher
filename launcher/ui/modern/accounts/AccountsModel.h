#pragma once

#include <QIdentityProxyModel>
#include <QQmlEngine>

#include "minecraft/auth/MinecraftAccount.h"

/**
 * `Accounts` QML singleton: the launcher's account list (APPLICATION->accounts()) as a QML model plus actions.
 * Mirrors the classic AccountListPage.
 *
 * Roles: accountId, name, typeKey (msa|offline), typeText, state, statusText, isDefault, busy, faceUrl,
 *        hasProfile, ownsMinecraft, lastError, canManageSkins
 */
class AccountsModel : public QIdentityProxyModel {
    Q_OBJECT
    QML_NAMED_ELEMENT(Accounts)
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString defaultId READ defaultId NOTIFY defaultChanged)
    Q_PROPERTY(QString defaultName READ defaultName NOTIFY defaultChanged)
    Q_PROPERTY(QString defaultFaceUrl READ defaultFaceUrl NOTIFY defaultChanged)
    Q_PROPERTY(bool anyValid READ anyValid NOTIFY countChanged)
    Q_PROPERTY(bool msaSupported READ msaSupported CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

   public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 100,
        NameRole,
        TypeKeyRole,
        TypeTextRole,
        StateRole,
        StatusTextRole,
        IsDefaultRole,
        BusyRole,
        FaceUrlRole,
        HasProfileRole,
        OwnsMinecraftRole,
        LastErrorRole,
        CanManageSkinsRole,
    };

    explicit AccountsModel(QObject* parent = nullptr);
    static AccountsModel* create(QQmlEngine*, QJSEngine*);

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;

    int count() const;
    QString defaultId() const;
    QString defaultName() const;
    QString defaultFaceUrl() const;
    bool anyValid() const;
    bool msaSupported() const;
    bool busy() const;

    /// { accountId, name, typeKey, statusText, faceUrl, ... } for a single account (empty map when not found)
    Q_INVOKABLE QVariantMap get(const QString& accountId) const;
    Q_INVOKABLE void setDefault(const QString& accountId);
    Q_INVOKABLE void clearDefault();
    Q_INVOKABLE void remove(const QString& accountId);
    Q_INVOKABLE void refresh(const QString& accountId);
    Q_INVOKABLE void move(const QString& accountId, int delta);
    Q_INVOKABLE bool isValidOfflineName(const QString& name) const;
    /// Returns "" on success or an error message.
    Q_INVOKABLE QString addOffline(const QString& name);
    Q_INVOKABLE QString lastOfflineName() const;

    static MinecraftAccountPtr findAccount(const QString& accountId);
    static QString faceUrlFor(const MinecraftAccountPtr& account);

   signals:
    void countChanged();
    void defaultChanged();
    void busyChanged();

   private:
    int rowOf(const QString& accountId) const;
};
