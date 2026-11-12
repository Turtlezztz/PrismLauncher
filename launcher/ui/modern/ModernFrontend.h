#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QUrl>

#include "ModernFrontendInterface.h"

class Application;
class QQmlApplicationEngine;
#include <QQuickWindow>

/**
 * Owns the QML engine and the main window of the modern frontend.
 * Exposed to QML as the `Shell` singleton: QML listens to its *Requested signals to navigate.
 */
class ModernFrontend : public QObject, public ModernFrontendInterface {
    Q_OBJECT
    QML_NAMED_ELEMENT(Shell)
    QML_SINGLETON
    /// First-run onboarding steps still to show (see Application::pendingSetupSteps)
    Q_PROPERTY(QStringList setupSteps READ setupSteps NOTIFY setupStepsChanged)
    /// Debug: env PRISM_MODERN_SCREENSHOT=<file.png> grabs the window after startup (and PRISM_MODERN_PAGE=<Page> navigates first)
    Q_PROPERTY(QString debugScreenshotPath READ debugScreenshotPath CONSTANT)
    Q_PROPERTY(QString debugStartPage READ debugStartPage CONSTANT)

   public:
    /// factory registered with Application::setModernFrontendFactory
    static ModernFrontendInterface* createFrontend(Application* app);
    /// QML singleton factory
    static ModernFrontend* create(QQmlEngine* qmlEngine, QJSEngine* jsEngine);
    static ModernFrontend* instance();

    void showMain(bool minimized) override;
    void showInstance(MinecraftInstance* instance, const QString& page) override;
    void processURLs(const QList<QUrl>& urls) override;
    void showLauncherLog() override;
    void showSettings(const QString& page) override;
    bool isMainVisible() const override;

    QQmlApplicationEngine* engine() const { return m_engine; }
    QQuickWindow* window() const { return m_window; }

    /// Called from QML when the main window closes.
    Q_INVOKABLE void mainWindowClosed();
    /// Persist / restore window geometry ("x,y,w,h,maximized")
    Q_INVOKABLE QString savedGeometry() const;
    Q_INVOKABLE void saveGeometry(const QString& geometry);

    QStringList setupSteps() const;
    /// Mark onboarding as finished.
    Q_INVOKABLE void finishSetup();
    QString debugScreenshotPath() const { return qEnvironmentVariable("PRISM_MODERN_SCREENSHOT"); }
    QString debugStartPage() const { return qEnvironmentVariable("PRISM_MODERN_PAGE"); }
    /// Debug helper: quit the app (used after debug screenshots)
    Q_INVOKABLE void debugQuit();
    /// Debug helper: save a screenshot of the main window
    Q_INVOKABLE bool grabWindowTo(const QString& path);

   signals:
    void instanceRequested(const QString& instanceId, const QString& page);
    void settingsRequested(const QString& page);
    void importRequested(const QList<QUrl>& urls);
    void launcherLogRequested();
    void setupStepsChanged();

   private:
    explicit ModernFrontend(QObject* parent = nullptr);
    void ensureEngine();

    QQmlApplicationEngine* m_engine = nullptr;
    QPointer<QQuickWindow> m_window;
    QList<QUrl> m_pendingImports;
};
