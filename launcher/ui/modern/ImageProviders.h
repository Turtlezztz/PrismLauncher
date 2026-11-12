#pragma once

#include <QQuickImageProvider>

/**
 * image://icon/<name>?color=<#rrggbb>
 * Renders a bundled SVG line icon (qml/icons/<name>.svg), replacing `currentColor` with the requested color.
 * Use the `Icon` QML component instead of calling this directly.
 */
class SvgIconProvider : public QQuickImageProvider {
   public:
    SvgIconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
};

/**
 * image://instanceicon/<iconKey>
 * Renders an instance icon from the launcher's IconList.
 */
class InstanceIconProvider : public QQuickImageProvider {
   public:
    InstanceIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override;
};

/**
 * image://pixmap/<key>
 * Serves pixmaps registered at runtime from C++ via PixmapCacheProvider::insert (e.g. mod logos, skins, screenshots thumbs).
 */
class PixmapCacheProvider : public QQuickImageProvider {
   public:
    PixmapCacheProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override;

    static void insert(const QString& key, const QPixmap& pixmap);
    static void remove(const QString& key);
    static bool contains(const QString& key);
};
