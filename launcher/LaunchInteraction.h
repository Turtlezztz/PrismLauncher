// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>

#include "minecraft/auth/MinecraftAccount.h"

class Task;
class MinecraftInstance;

/**
 * Optional replacement for the widget dialogs LaunchController shows while launching.
 *
 * The modern (Qt Quick) frontend installs an implementation with LaunchController::setInteraction().
 * When none is installed (classic UI), LaunchController keeps using its widget dialogs.
 *
 * All "ask*" methods are blocking: they return once the user has answered (implementations typically
 * spin a local event loop, just like QDialog::exec()).
 */
class LaunchInteraction {
   public:
    virtual ~LaunchInteraction() = default;

    /// No valid account exists. Return true if the user wants to open the account manager (the launch then continues as demo/aborts).
    virtual bool askOpenAccountManager() = 0;
    /// Let the user pick the account to use. Returns nullptr when cancelled.
    virtual MinecraftAccountPtr chooseAccount(const QString& message, bool* useAsGlobalDefault) = 0;
    /// The account doesn't own the game (or none was selected). `text` explains why. Return true to play the demo.
    virtual bool askPlayDemo(const QString& text) = 0;
    /// Ask for an offline/demo player name. Returns false when cancelled.
    virtual bool askOfflineName(const QString& title, const QString& message, QString& name) = 0;
    /// The account has no Minecraft profile yet; let the user create one. Returns true once a profile was created.
    virtual bool setupProfile(MinecraftAccountPtr account) = 0;
    /// Refreshing `account` failed for `reason`. Return a freshly authenticated replacement, or nullptr to abort.
    virtual MinecraftAccountPtr reauthenticate(MinecraftAccountPtr account, const QString& reason) = 0;
    /// Block until `task` finishes, showing its progress. With `skippable`, the user may abort it.
    virtual void waitForTask(Task* task, bool skippable) = 0;
    /// Show the progress of a task the launch is running (non-blocking).
    virtual void showTaskProgress(MinecraftInstance* instance, Task* task) = 0;
    /// "Kill Minecraft?" confirmation.
    virtual bool confirmKill(MinecraftInstance* instance) = 0;
    /// Show an error (non-blocking).
    virtual void showError(const QString& title, const QString& message) = 0;
    /// Profiler is ready; wait until the user wants to continue. Set `disableProfiler` to turn it off for next launches.
    virtual void waitForProfiler(const QString& message, bool* disableProfiler) = 0;
    /// Return an error message if the JVM arguments are not acceptable, or an empty string.
    virtual QString checkJvmArgs(const QString& args) = 0;
    /// The launch failed with `reason`.
    virtual void launchFailed(MinecraftInstance* instance, const QString& reason) = 0;
};
