#include "ImageProviders.h"

#include <QFile>
#include <QHash>
#include <QMutex>
#include <QPainter>
#include <QSvgRenderer>
#include <QUrlQuery>

#include "Application.h"
#include "icons/IconList.h"

namespace {
QHash<QString, QByteArray>& svgCache()
{
    static QHash<QString, QByteArray> cache;
    return cache;
}
QMutex& svgMutex()
{
    static QMutex m;
    return m;
}

QHash<QString, QPixmap>& pixmapStore()
{
    static QHash<QString, QPixmap> store;
    return store;
}
QMutex& pixmapMutex()
{
    static QMutex m;
    return m;
}
}  // namespace

QImage SvgIconProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    QString name = id;
    QString color = "#ffffff";
    const auto q = id.indexOf('?');
    if (q >= 0) {
        name = id.left(q);
        QUrlQuery query(id.mid(q + 1));
        if (query.hasQueryItem("color")) {
            color = query.queryItemValue("color", QUrl::FullyDecoded);
        }
    }

    QByteArray svg;
    {
        QMutexLocker lock(&svgMutex());
        auto it = svgCache().find(name);
        if (it == svgCache().end()) {
            QFile f(QString(":/qt/qml/PrismModern/qml/icons/%1.svg").arg(name));
            if (!f.open(QIODevice::ReadOnly)) {
                qWarning() << "Modern UI: missing icon" << name;
                f.setFileName(":/qt/qml/PrismModern/qml/icons/circle-alert.svg");
                f.open(QIODevice::ReadOnly);
            }
            it = svgCache().insert(name, f.readAll());
        }
        svg = *it;
    }
    svg.replace("currentColor", color.toUtf8());

    const QSize target = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(24, 24);
    QImage img(target, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QSvgRenderer renderer(svg);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    renderer.render(&p);
    p.end();
    if (size) {
        *size = target;
    }
    return img;
}

QPixmap InstanceIconProvider::requestPixmap(const QString& id, QSize* size, const QSize& requestedSize)
{
    const QSize target = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(64, 64);
    // strip cache-busting suffix ("key?v=3")
    QString key = id.section('?', 0, 0);
    QIcon icon = APPLICATION->icons()->getIcon(key);
    if (icon.isNull()) {
        icon = APPLICATION->icons()->getIcon("grass");
    }
    QPixmap pm = icon.pixmap(target);
    if (size) {
        *size = pm.size();
    }
    return pm;
}

QPixmap PixmapCacheProvider::requestPixmap(const QString& id, QSize* size, const QSize& requestedSize)
{
    QPixmap pm;
    {
        QMutexLocker lock(&pixmapMutex());
        pm = pixmapStore().value(id.section('?', 0, 0));
    }
    if (!pm.isNull() && requestedSize.isValid() && !requestedSize.isEmpty()) {
        pm = pm.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (size) {
        *size = pm.size();
    }
    return pm;
}

void PixmapCacheProvider::insert(const QString& key, const QPixmap& pixmap)
{
    QMutexLocker lock(&pixmapMutex());
    pixmapStore().insert(key, pixmap);
}

void PixmapCacheProvider::remove(const QString& key)
{
    QMutexLocker lock(&pixmapMutex());
    pixmapStore().remove(key);
}

bool PixmapCacheProvider::contains(const QString& key)
{
    QMutexLocker lock(&pixmapMutex());
    return pixmapStore().contains(key);
}
