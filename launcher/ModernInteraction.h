#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <functional>
#include <optional>

#include "ui/dialogs/BlockedModsDialog.h"  // BlockedMod

/**
 * Hooks that let the modern Qt Quick frontend (ui/modern) answer the interactive questions that core tasks
 * (instance import / creation / modpack install) ask while they run.
 *
 * The classic UI never installs handlers, so every call site keeps using its widget dialog:
 *     if (ModernInteraction::active()) { ...ask through the hook... } else { ...classic QDialog... }
 *
 * Handlers are synchronous (they run a nested event loop, exactly like QDialog::exec()).
 */
namespace ModernInteraction {

struct Question {
    QString title;
    QString text;          // may contain simple HTML
    QString kind = "question";  // question | info | warning | error
    QStringList buttons;   // labels; index 0 is the primary action
    int cancelIndex = -1;  // value returned when the dialog is dismissed (Esc / close)
    QStringList items;     // optional list shown below the text (e.g. file names)
    QString confirmCheck;  // optional "I understand" checkbox that must be ticked before button 0 is enabled
};

/// returns the index of the clicked button, or Question::cancelIndex when dismissed
using QuestionHandler = std::function<int(const Question&)>;
/// returns the checked items, or std::nullopt when cancelled
using ChecklistHandler =
    std::function<std::optional<QStringList>(const QString& title, const QString& text, const QStringList& items, const QStringList& checked)>;
/// returns true to continue (mods may have been matched to local files), false to abort
using BlockedModsHandler =
    std::function<bool(const QString& title, const QString& text, QList<BlockedMod>& mods, const QString& hashType)>;
/// non-blocking notification (toast / message)
using NotifyHandler = std::function<void(const QString& title, const QString& text, const QString& kind)>;

inline QuestionHandler& questionHandler()
{
    static QuestionHandler h;
    return h;
}
inline ChecklistHandler& checklistHandler()
{
    static ChecklistHandler h;
    return h;
}
inline BlockedModsHandler& blockedModsHandler()
{
    static BlockedModsHandler h;
    return h;
}
inline NotifyHandler& notifyHandler()
{
    static NotifyHandler h;
    return h;
}

/// The "untrusted mods" warning (classic UntrustedModsDialog) as a question; button 0 = proceed
inline Question untrustedModsQuestion(const QStringList& paths)
{
    Question q;
    q.title = QObject::tr("Easy There!");
    q.text = QObject::tr("The modpack you are installing includes mods which are not hosted on Modrinth or CurseForge.<br><br>"
                         "<b>Malicious mods are often distributed through links sent on platforms such as Discord.</b> "
                         "We strongly recommend only importing modpacks from trusted sources.");
    q.kind = "warning";
    q.items = paths;
    q.buttons = { QObject::tr("Install anyway"), QObject::tr("Cancel") };
    q.cancelIndex = 1;
    q.confirmCheck = QObject::tr("I trust this modpack and wish to proceed regardless");
    return q;
}

/// true when the modern frontend is answering interactions
inline bool active()
{
    return static_cast<bool>(questionHandler());
}

inline int ask(const Question& q)
{
    return questionHandler() ? questionHandler()(q) : q.cancelIndex;
}

/// Ok/Cancel style helper: true when the primary button was chosen
inline bool confirm(const QString& title, const QString& text, const QString& kind, const QString& ok, const QString& cancel)
{
    Question q;
    q.title = title;
    q.text = text;
    q.kind = kind;
    q.buttons = { ok, cancel };
    q.cancelIndex = 1;
    return ask(q) == 0;
}

inline std::optional<QStringList> checklist(const QString& title, const QString& text, const QStringList& items, const QStringList& checked)
{
    if (!checklistHandler()) {
        return std::nullopt;
    }
    return checklistHandler()(title, text, items, checked);
}

inline bool blockedMods(const QString& title, const QString& text, QList<BlockedMod>& mods, const QString& hashType)
{
    return blockedModsHandler() ? blockedModsHandler()(title, text, mods, hashType) : false;
}

inline void notify(const QString& title, const QString& text, const QString& kind)
{
    if (notifyHandler()) {
        notifyHandler()(title, text, kind);
    }
}

}  // namespace ModernInteraction
