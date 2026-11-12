#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QVariant>

#include "modplatform/atlauncher/ATLPackInstallTask.h"

class AtlOptionalModListModel;

/**
 * `NiInteraction` QML singleton: answers the questions core tasks ask while importing / installing
 * (see launcher/ModernInteraction.h) by showing QML dialogs (NiInteractionHost.qml, placed once in Main.qml).
 *
 * C++ side: request(kind, data) emits `requested` and spins a nested event loop until QML calls respond(id, result).
 * kinds: question | checklist | blockedMods | atlOptionalMods | chooseVersion
 */
class NIInteraction : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(NiInteraction)
    QML_SINGLETON

   public:
    static NIInteraction* create(QQmlEngine*, QJSEngine*);
    static NIInteraction* instance();

    /// blocking: returns the value QML passed to respond()
    QVariant request(const QString& kind, const QVariantMap& data);

    Q_INVOKABLE void respond(int id, const QVariant& result);
    /// Show a running TaskBridge in the global progress dialog (survives page changes).
    /// opts: { successText, openInstance: bool, failTitle }
    Q_INVOKABLE void track(QObject* task, const QVariantMap& opts = {}) { emit trackRequested(task, opts); }

    /// ATLauncher user interaction support (owned by the install task)
    static ATLauncher::UserInteractionSupport* makeAtlSupport();

   signals:
    void requested(int id, const QString& kind, const QVariantMap& data);
    void notified(const QString& title, const QString& text, const QString& kind);
    void trackRequested(QObject* task, const QVariantMap& opts);

   private:
    explicit NIInteraction(QObject* parent = nullptr);
    void install();
    int m_nextId = 1;
    QHash<int, QVariant> m_results;
    QHash<int, class QEventLoop*> m_loops;
};

/// QML-friendly wrapper around the classic ATLauncher optional mods model (dependencies, groups, share codes)
class NIAtlOptionalMods : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created by NiInteraction")
   public:
    enum Roles { NameRole = Qt::UserRole + 1, DescriptionRole, CheckedRole, ColorRole };
    NIAtlOptionalMods(AtlOptionalModListModel* source, QObject* parent);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void toggle(int row);
    Q_INVOKABLE void selectRecommended();
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void useShareCode(const QString& code);

   private:
    AtlOptionalModListModel* m_source;
};
