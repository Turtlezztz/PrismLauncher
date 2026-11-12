#include "AccountsModel.h"

#include <QPainter>
#include <QRegularExpression>

#include "Application.h"
#include "ImageProviders.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/AuthFlow.h"
#include "settings/SettingsObject.h"

static AccountsModel* s_accountsModel = nullptr;

static QString stateKey(AccountState state)
{
    switch (state) {
        case AccountState::Unchecked:
            return "unchecked";
        case AccountState::Offline:
            return "offline";
        case AccountState::Working:
            return "working";
        case AccountState::Online:
            return "online";
        case AccountState::Disabled:
            return "disabled";
        case AccountState::Errored:
            return "errored";
        case AccountState::Expired:
            return "expired";
        case AccountState::Gone:
            return "gone";
    }
    return "unknown";
}

static QString stateText(AccountState state)
{
    switch (state) {
        case AccountState::Unchecked:
            return QObject::tr("Unchecked", "Account status");
        case AccountState::Offline:
            return QObject::tr("Offline", "Account status");
        case AccountState::Online:
            return QObject::tr("Ready", "Account status");
        case AccountState::Working:
            return QObject::tr("Working", "Account status");
        case AccountState::Errored:
            return QObject::tr("Errored", "Account status");
        case AccountState::Expired:
            return QObject::tr("Expired", "Account status");
        case AccountState::Disabled:
            return QObject::tr("Disabled", "Account status");
        case AccountState::Gone:
            return QObject::tr("Gone", "Account status");
    }
    return QObject::tr("Unknown", "Account status");
}

AccountsModel::AccountsModel(QObject* parent) : QIdentityProxyModel(parent)
{
    auto* list = APPLICATION->accounts();
    setSourceModel(list);
    connect(list, &AccountList::listChanged, this, &AccountsModel::countChanged);
    connect(list, &AccountList::defaultAccountChanged, this, &AccountsModel::defaultChanged);
    connect(list, &AccountList::listChanged, this, &AccountsModel::defaultChanged);
    connect(list, &AccountList::listActivityChanged, this, &AccountsModel::busyChanged);
    connect(list, &AccountList::listActivityChanged, this, &AccountsModel::defaultChanged);
    connect(list, &QAbstractItemModel::dataChanged, this, &AccountsModel::defaultChanged);
}

AccountsModel* AccountsModel::create(QQmlEngine*, QJSEngine*)
{
    if (!s_accountsModel) {
        s_accountsModel = new AccountsModel(APPLICATION);
    }
    QJSEngine::setObjectOwnership(s_accountsModel, QJSEngine::CppOwnership);
    return s_accountsModel;
}

QHash<int, QByteArray> AccountsModel::roleNames() const
{
    return {
        { AccountIdRole, "accountId" },   { NameRole, "name" },
        { TypeKeyRole, "typeKey" },       { TypeTextRole, "typeText" },
        { StateRole, "accountState" },           { StatusTextRole, "statusText" },
        { IsDefaultRole, "isDefault" },   { BusyRole, "busy" },
        { FaceUrlRole, "faceUrl" },       { HasProfileRole, "hasProfile" },
        { OwnsMinecraftRole, "ownsMinecraft" }, { LastErrorRole, "lastError" },
        { CanManageSkinsRole, "canManageSkins" },
    };
}

QString AccountsModel::faceUrlFor(const MinecraftAccountPtr& account)
{
    if (!account) {
        return {};
    }
    const auto& skinData = account->accountData()->minecraftProfile.skin.data;
    if (skinData.isEmpty()) {
        return {};
    }
    const auto key = QString("acc-face/%1-%2").arg(account->internalId()).arg(qHash(skinData));
    if (!PixmapCacheProvider::contains(key)) {
        auto face = account->getFace(64, 64);
        if (face.isNull()) {
            return {};
        }
        PixmapCacheProvider::insert(key, face);
    }
    return "image://pixmap/" + key;
}

QVariant AccountsModel::data(const QModelIndex& index, int role) const
{
    if (role < AccountIdRole) {
        return QIdentityProxyModel::data(index, role);
    }
    auto* list = APPLICATION->accounts();
    if (!index.isValid() || index.row() < 0 || index.row() >= list->count()) {
        return {};
    }
    auto account = list->at(index.row());
    switch (role) {
        case AccountIdRole:
            return account->internalId();
        case NameRole:
            return account->profileName().isEmpty() ? tr("No profile") : account->profileName();
        case TypeKeyRole:
            return account->typeString();
        case TypeTextRole:
            return account->accountType() == AccountType::MSA ? tr("Microsoft") : tr("Offline");
        case StateRole:
            return stateKey(account->accountState());
        case StatusTextRole:
            return stateText(account->accountState());
        case IsDefaultRole:
            return account == list->defaultAccount();
        case BusyRole:
            return account->isActive();
        case FaceUrlRole:
            return faceUrlFor(account);
        case HasProfileRole:
            return account->hasProfile();
        case OwnsMinecraftRole:
            return account->ownsMinecraft();
        case LastErrorRole:
            return account->lastError();
        case CanManageSkinsRole:
            return account->accountType() != AccountType::Offline && !account->isActive() && account->hasProfile();
        default:
            return {};
    }
}

int AccountsModel::count() const
{
    return APPLICATION->accounts()->count();
}

QString AccountsModel::defaultId() const
{
    auto acc = APPLICATION->accounts()->defaultAccount();
    return acc ? acc->internalId() : QString();
}

QString AccountsModel::defaultName() const
{
    auto acc = APPLICATION->accounts()->defaultAccount();
    return acc ? acc->profileName() : QString();
}

QString AccountsModel::defaultFaceUrl() const
{
    return faceUrlFor(APPLICATION->accounts()->defaultAccount());
}

bool AccountsModel::anyValid() const
{
    return APPLICATION->accounts()->anyAccountIsValid();
}

bool AccountsModel::msaSupported() const
{
    return APPLICATION->capabilities() & Application::SupportsMSA;
}

bool AccountsModel::busy() const
{
    return APPLICATION->accounts()->isActive();
}

int AccountsModel::rowOf(const QString& accountId) const
{
    auto* list = APPLICATION->accounts();
    for (int i = 0; i < list->count(); i++) {
        if (list->at(i)->internalId() == accountId) {
            return i;
        }
    }
    return -1;
}

MinecraftAccountPtr AccountsModel::findAccount(const QString& accountId)
{
    auto* list = APPLICATION->accounts();
    for (int i = 0; i < list->count(); i++) {
        if (list->at(i)->internalId() == accountId) {
            return list->at(i);
        }
    }
    return nullptr;
}

QVariantMap AccountsModel::get(const QString& accountId) const
{
    const int row = rowOf(accountId);
    if (row < 0) {
        return {};
    }
    QVariantMap out;
    const auto idx = index(row, 0);
    const auto roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        out.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return out;
}

void AccountsModel::setDefault(const QString& accountId)
{
    if (auto acc = findAccount(accountId)) {
        APPLICATION->accounts()->setDefaultAccount(acc);
    }
}

void AccountsModel::clearDefault()
{
    APPLICATION->accounts()->setDefaultAccount(nullptr);
}

void AccountsModel::remove(const QString& accountId)
{
    const int row = rowOf(accountId);
    if (row >= 0) {
        APPLICATION->accounts()->removeAccount(APPLICATION->accounts()->index(row));
    }
}

void AccountsModel::refresh(const QString& accountId)
{
    APPLICATION->accounts()->requestRefresh(accountId);
}

void AccountsModel::move(const QString& accountId, int delta)
{
    const int row = rowOf(accountId);
    if (row >= 0) {
        APPLICATION->accounts()->moveAccount(APPLICATION->accounts()->index(row), delta);
    }
}

bool AccountsModel::isValidOfflineName(const QString& name) const
{
    static const QRegularExpression s_username("^[A-Za-z0-9_]{3,16}$");
    return s_username.match(name).hasMatch();
}

QString AccountsModel::addOffline(const QString& name)
{
    if (!anyValid()) {
        return tr("You must add a Microsoft account that owns Minecraft before you can add an offline account.");
    }
    if (name.isEmpty()) {
        return tr("Please enter a username.");
    }
    auto* list = APPLICATION->accounts();
    if (const MinecraftAccountPtr account = MinecraftAccount::createOffline(name)) {
        account->login()->start();  // completes synchronously for offline accounts
        list->addAccount(account);
        if (list->count() == 1) {
            list->setDefaultAccount(account);
        }
        return {};
    }
    return tr("Could not create the offline account.");
}

QString AccountsModel::lastOfflineName() const
{
    return APPLICATION->settings()->get("LastOfflinePlayerName").toString();
}
