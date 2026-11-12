#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>

#include "NIController.h"
#include "NIVersionModel.h"

/**
 * "Custom" source (classic CustomPage): Minecraft version + optional mod loader and loader version.
 */
class NIVanillaSource : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(NIController* controller READ controller WRITE setController NOTIFY controllerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(NIVersionModel* versions READ versions CONSTANT)
    Q_PROPERTY(NIVersionModel* loaderVersions READ loaderVersions CONSTANT)
    /// none | neoforge | forge | fabric | quilt | liteloader
    Q_PROPERTY(QString loader READ loader WRITE setLoader NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedVersion READ selectedVersion NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedLoaderVersion READ selectedLoaderVersion NOTIFY selectionChanged)
    /// explanation shown when the loader list is empty
    Q_PROPERTY(QString loaderEmptyText READ loaderEmptyText NOTIFY selectionChanged)

   public:
    explicit NIVanillaSource(QObject* parent = nullptr);

    NIController* controller() const { return m_controller; }
    void setController(NIController* c);
    bool active() const { return m_active; }
    void setActive(bool a);
    NIVersionModel* versions() const { return m_versions; }
    NIVersionModel* loaderVersions() const { return m_loaderVersions; }
    QString loader() const { return m_loader; }
    void setLoader(const QString& loader);
    QString selectedVersion() const;
    QString selectedLoaderVersion() const;
    QString loaderEmptyText() const;

    Q_INVOKABLE void selectVersion(int row);
    Q_INVOKABLE void selectLoaderVersion(int row);
    Q_INVOKABLE static QString loaderName(const QString& key);

   signals:
    void controllerChanged();
    void activeChanged();
    void selectionChanged();

   private:
    void updateLoaderList();
    void suggestCurrent();
    QPointer<NIController> m_controller;
    bool m_active = false;
    NIVersionModel* m_versions;
    NIVersionModel* m_loaderVersions;
    QString m_loader = "none";
    BaseVersion::Ptr m_version;
    BaseVersion::Ptr m_loaderVersion;
};
