#include "ModernFrontend.h"

#include <cstdio>
#include <cstdlib>

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>

#include "Application.h"
#include "ImageProviders.h"
#include "minecraft/MinecraftInstance.h"
#include "settings/SettingsObject.h"

static ModernFrontend* s_instance = nullptr;

ModernFrontend::ModernFrontend(QObject* parent) : QObject(parent) {}

ModernFrontendInterface* ModernFrontend::createFrontend(Application* app)
{
    if (!s_instance) {
        s_instance = new ModernFrontend(app);
    }
    return s_instance;
}

ModernFrontend* ModernFrontend::instance()
{
    return s_instance;
}

ModernFrontend* ModernFrontend::create(QQmlEngine*, QJSEngine*)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

void ModernFrontend::ensureEngine()
{
    if (m_engine) {
        return;
    }
    // "Basic" is the lightest built-in style and fully customizable; every control is restyled by our components anyway.
    QQuickStyle::setStyle("Basic");

    m_engine = new QQmlApplicationEngine(this);
    m_engine->addImageProvider("icon", new SvgIconProvider());
    m_engine->addImageProvider("instanceicon", new InstanceIconProvider());
    m_engine->addImageProvider("pixmap", new PixmapCacheProvider());

    QObject::connect(
        m_engine, &QQmlApplicationEngine::objectCreationFailed, this, [] { qCritical() << "Modern UI: failed to create main window"; },
        Qt::QueuedConnection);

    m_engine->loadFromModule("PrismModern", "Main");
    const auto roots = m_engine->rootObjects();
    if (!roots.isEmpty()) {
        m_window = qobject_cast<QQuickWindow*>(roots.first());
    }
}

void ModernFrontend::showMain(bool minimized)
{
    ensureEngine();
    if (!m_window) {
        return;
    }
    if (minimized) {
        m_window->showMinimized();
    } else {
        if (m_window->visibility() == QWindow::Minimized || !m_window->isVisible()) {
            m_window->show();
        }
        m_window->raise();
        m_window->requestActivate();
    }
    if (!m_pendingImports.isEmpty()) {
        auto urls = m_pendingImports;
        m_pendingImports.clear();
        emit importRequested(urls);
    }
}

void ModernFrontend::showInstance(MinecraftInstance* instance, const QString& page)
{
    if (!instance) {
        return;
    }
    showMain(false);
    emit instanceRequested(instance->id(), page);
}

void ModernFrontend::processURLs(const QList<QUrl>& urls)
{
    if (!m_window) {
        m_pendingImports.append(urls);
        return;
    }
    emit importRequested(urls);
}

void ModernFrontend::showLauncherLog()
{
    showMain(false);
    emit launcherLogRequested();
}

void ModernFrontend::showSettings(const QString& page)
{
    showMain(false);
    emit settingsRequested(page);
}

bool ModernFrontend::isMainVisible() const
{
    return m_window && m_window->isVisible();
}

void ModernFrontend::mainWindowClosed()
{
    APPLICATION->notifyModernMainClosed();
}

QString ModernFrontend::savedGeometry() const
{
    return APPLICATION->settings()->get("ModernWindowGeometry").toString();
}

void ModernFrontend::saveGeometry(const QString& geometry)
{
    APPLICATION->settings()->set("ModernWindowGeometry", geometry);
}

QStringList ModernFrontend::setupSteps() const
{
    return APPLICATION->pendingSetupSteps();
}

void ModernFrontend::finishSetup()
{
    APPLICATION->clearPendingSetupSteps();
    emit setupStepsChanged();
}

void ModernFrontend::debugQuit()
{
    // Debug screenshots only: exit immediately without running teardown (avoids shutdown crashes / crash reports).
    std::fflush(nullptr);
    std::_Exit(0);
}

bool ModernFrontend::grabWindowTo(const QString& path)
{
    if (!m_window) {
        return false;
    }
    return m_window->grabWindow().save(path);
}
