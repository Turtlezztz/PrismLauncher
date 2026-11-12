#pragma once

#include <QPixmap>
#include <QQmlEngine>
#include <QQuickAsyncImageProvider>
#include <QQuickImageProvider>
#include <functional>

/**
 * Image providers used by the resource/instance-content area of the modern UI. Registered lazily
 * (ResImages::ensure) so the shared frontend setup does not need to know about them.
 *
 *  image://resicon/<namespace>/<id>?v=N   pixmap supplied by a live C++ model (local mod icons, pack images, world icons)
 *  image://resremote/<percent-encoded url>  remote logo, downloaded through APPLICATION->network() and cached on disk
 *  image://resthumb/<absolute path>?v=N   downscaled thumbnail of a local image file (decoded off the UI thread, LRU cached)
 */
namespace ResImages {
using Source = std::function<QPixmap(const QString& id, const QSize& size)>;

void ensure(QQmlEngine* engine);
/// Register a pixmap source for image://resicon/<ns>/...  Must be called from the GUI thread.
void registerSource(const QString& ns, Source source);
void unregisterSource(const QString& ns);
/// Unique namespace for a model instance.
QString newNamespace(const QString& prefix);
/// URL for a remote image (empty if url is empty)
QString remoteUrl(const QString& url);
/// URL for a local image thumbnail
QString thumbUrl(const QString& path, qint64 stamp = 0);
void dropThumb(const QString& path);
}  // namespace ResImages

class ResIconProvider : public QQuickImageProvider {
   public:
    ResIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requestedSize) override;
};

class ResThumbProvider : public QQuickImageProvider {
   public:
    ResThumbProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
};

class ResRemoteImageProvider : public QQuickAsyncImageProvider {
   public:
    QQuickImageResponse* requestImageResponse(const QString& id, const QSize& requestedSize) override;
};
