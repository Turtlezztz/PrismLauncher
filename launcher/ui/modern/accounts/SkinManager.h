#pragma once

#include <QHash>
#include <QImage>
#include <QObject>
#include <QQmlEngine>
#include <QVariant>

#include <memory>

#include "minecraft/auth/MinecraftAccount.h"
#include "tasks/Task.h"

class SkinList;
class SkinModel;

/**
 * Skin & cape management for one account (classic SkinManageDialog).
 * The preview is a 2D front/back render (no OpenGL).
 *
 *   SkinManager { accountId: "…" }
 *   skins: [{ name, front, back, model, capeId, inUse }]   capes: [{ id, alias, preview }]
 */
class SkinManager : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)
    Q_PROPERTY(QVariantList skins READ skins NOTIFY skinsChanged)
    Q_PROPERTY(QVariantList capes READ capes NOTIFY capesChanged)
    Q_PROPERTY(QString selected READ selected WRITE setSelected NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedFront READ selectedFront NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedBack READ selectedBack NOTIFY selectionChanged)
    Q_PROPERTY(bool selectedSlim READ selectedSlim NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedCape READ selectedCape NOTIFY selectionChanged)
    Q_PROPERTY(bool showElytra READ showElytra WRITE setShowElytra NOTIFY capesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString busyText READ busyText NOTIFY busyChanged)
    Q_PROPERTY(QString folder READ folder NOTIFY accountIdChanged)

   public:
    explicit SkinManager(QObject* parent = nullptr);
    ~SkinManager() override;

    QString accountId() const { return m_accountId; }
    void setAccountId(const QString& id);
    QVariantList skins() const { return m_skins; }
    QVariantList capes() const;
    QString selected() const { return m_selected; }
    void setSelected(const QString& name);
    QString selectedFront() const;
    QString selectedBack() const;
    bool selectedSlim() const;
    QString selectedCape() const;
    bool showElytra() const { return m_showElytra; }
    void setShowElytra(bool on);
    bool busy() const { return m_busy; }
    QString busyText() const { return m_busyText; }
    QString folder() const;

    Q_INVOKABLE void setSlim(bool slim);
    Q_INVOKABLE void setCape(const QString& capeId);
    /// "" on success, else error
    Q_INVOKABLE QString installFromFile(const QString& path);
    Q_INVOKABLE QString browseAndInstall();
    Q_INVOKABLE void installFromUrl(const QString& url);
    Q_INVOKABLE void importFromUsername(const QString& username);
    Q_INVOKABLE bool rename(const QString& name, const QString& newName);
    /// "" on success, else error
    Q_INVOKABLE QString remove(const QString& name);
    Q_INVOKABLE void openFolder();
    /// Uploads the selected skin (model + cape) to the account.
    Q_INVOKABLE void apply();
    /// Resets the account's skin to the default one.
    Q_INVOKABLE void resetSkin();

   signals:
    void accountIdChanged();
    void skinsChanged();
    void capesChanged();
    void selectionChanged();
    void busyChanged();
    /// kind: success | error
    void notify(const QString& kind, const QString& message);
    void applied();

   private:
    void rebuild();
    void setupCapes();
    void setBusy(bool busy, const QString& text = QString());
    QString renderKey(SkinModel* skin, bool back);
    SkinModel* selectedSkin() const;

    QString m_accountId;
    MinecraftAccountPtr m_account;
    SkinList* m_list = nullptr;
    QVariantList m_skins;
    QString m_selected;
    QHash<QString, QImage> m_capes;
    QStringList m_capeOrder;
    bool m_showElytra = false;
    bool m_busy = false;
    QString m_busyText;
    Task::Ptr m_task;
};
