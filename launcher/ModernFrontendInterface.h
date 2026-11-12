#pragma once

#include <QList>
#include <QString>
#include <QUrl>

class MinecraftInstance;

/**
 * Bridge between the core Application and the modern Qt Quick frontend (ui/modern).
 *
 * The frontend lives in a separate static library (Launcher_modern) that links against
 * Launcher_logic, so the core only talks to it through this interface. main.cpp registers
 * a factory via Application::setModernFrontendFactory().
 */
class ModernFrontendInterface {
   public:
    virtual ~ModernFrontendInterface() = default;

    /// Show (or raise) the main window.
    virtual void showMain(bool minimized) = 0;
    /// Navigate to an instance. `page` is one of the classic page ids ("console", "mods", "version", ...).
    virtual void showInstance(MinecraftInstance* instance, const QString& page) = 0;
    /// Import zip files / modpack URLs / curseforge:// links etc.
    virtual void processURLs(const QList<QUrl>& urls) = 0;
    /// Show the launcher's own log viewer.
    virtual void showLauncherLog() = 0;
    /// Open global settings, optionally on a specific page id.
    virtual void showSettings(const QString& page) = 0;
    /// Is the main window currently open?
    virtual bool isMainVisible() const = 0;
};
