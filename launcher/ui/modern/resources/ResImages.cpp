#include "ResImages.h"

#include <QCache>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImageReader>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QSaveFile>
#include <QThreadPool>
#include <QUrl>

#include "Application.h"
#include "FileSystem.h"

namespace {
QHash<QString, ResImages::Source>& sources()
{
    static QHash<QString, ResImages::Source> s;
    return s;
}

QMutex& cacheMutex()
{
    static QMutex m;
    return m;
}
// decoded remote logos, keyed by url
QCache<QString, QImage>& remoteCache()
{
    static QCache<QString, QImage> c(400);
    return c;
}
// screenshot thumbnails, keyed by path; cost = kilobytes
QCache<QString, QImage>& thumbCache()
{
    static QCache<QString, QImage> c(48 * 1024);
    return c;
}

QImage scaledFor(const QImage& img, const QSize& requested, int fallback)
{
    if (img.isNull()) {
        return img;
    }
    QSize target = requested.isValid() && !requested.isEmpty() ? requested : QSize(fallback, fallback);
    if (img.width() <= target.width() && img.height() <= target.height()) {
        return img;
    }
    return img.scaled(target, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}

QString logoCacheDir()
{
    return FS::PathCombine(APPLICATION->dataRoot(), "cache", "modern-logos");
}
}  // namespace

namespace ResImages {
void ensure(QQmlEngine* engine)
{
    if (!engine) {
        return;
    }
    if (!engine->imageProvider("resicon")) {
        engine->addImageProvider("resicon", new ResIconProvider());
    }
    if (!engine->imageProvider("resremote")) {
        engine->addImageProvider("resremote", new ResRemoteImageProvider());
    }
    if (!engine->imageProvider("resthumb")) {
        engine->addImageProvider("resthumb", new ResThumbProvider());
    }
}

void registerSource(const QString& ns, Source source)
{
    sources().insert(ns, std::move(source));
}

void unregisterSource(const QString& ns)
{
    sources().remove(ns);
}

QString newNamespace(const QString& prefix)
{
    static int counter = 0;
    return QString("%1%2").arg(prefix).arg(++counter);
}

QString remoteUrl(const QString& url)
{
    if (url.isEmpty()) {
        return {};
    }
    return "image://resremote/" + QString::fromLatin1(QUrl::toPercentEncoding(url));
}

QString thumbUrl(const QString& path, qint64 stamp)
{
    return "image://resthumb/" + QString::fromLatin1(QUrl::toPercentEncoding(path)) + "?v=" + QString::number(stamp);
}

void dropThumb(const QString& path)
{
    QMutexLocker lock(&cacheMutex());
    const auto keys = thumbCache().keys();
    for (const auto& k : keys) {
        if (k.startsWith(path + "|")) {
            thumbCache().remove(k);
        }
    }
}
}  // namespace ResImages

QPixmap ResIconProvider::requestPixmap(const QString& id, QSize* size, const QSize& requestedSize)
{
    const QString clean = id.section('?', 0, 0);
    const QString ns = clean.section('/', 0, 0);
    const QString rest = QUrl::fromPercentEncoding(clean.section('/', 1).toUtf8());
    QPixmap pm;
    auto it = sources().constFind(ns);
    if (it != sources().constEnd() && *it) {
        pm = (*it)(rest, requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(64, 64));
    }
    if (size) {
        *size = pm.size();
    }
    return pm;
}

QImage ResThumbProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    const QString path = QUrl::fromPercentEncoding(id.section('?', 0, 0).toUtf8());
    const QSize target = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(320, 180);
    const QString key = path + "|" + QString::number(target.width()) + "x" + QString::number(target.height());
    {
        QMutexLocker lock(&cacheMutex());
        if (auto* hit = thumbCache().object(key)) {
            if (size) {
                *size = hit->size();
            }
            return *hit;
        }
    }
    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize full = reader.size();
    if (full.isValid() && (full.width() > target.width() || full.height() > target.height())) {
        // cover-fit: scale so that the smaller side fills the target
        QSize s = full.scaled(target, Qt::KeepAspectRatioByExpanding);
        reader.setScaledSize(s);
    }
    QImage img = reader.read();
    if (!img.isNull()) {
        QMutexLocker lock(&cacheMutex());
        thumbCache().insert(key, new QImage(img), qMax<qsizetype>(1, img.sizeInBytes() / 1024));
    }
    if (size) {
        *size = img.size();
    }
    return img;
}

namespace {
class ResRemoteResponse : public QQuickImageResponse {
   public:
    QQuickTextureFactory* textureFactory() const override { return QQuickTextureFactory::textureFactoryForImage(m_image); }
    QString errorString() const override { return m_error; }

    void finishWith(const QImage& img, const QString& error = {})
    {
        m_image = img;
        m_error = img.isNull() && error.isEmpty() ? QStringLiteral("no image") : error;
        if (!img.isNull()) {
            m_error.clear();
        }
        emit finished();
    }

   private:
    QImage m_image;
    QString m_error;
};

void decodeAsync(QPointer<ResRemoteResponse> resp, QByteArray data, QString url, QSize requested)
{
    QThreadPool::globalInstance()->start([resp, data = std::move(data), url, requested] {
        QImage img;
        img.loadFromData(data);
        img = scaledFor(img, requested, 128);
        if (!img.isNull()) {
            QMutexLocker lock(&cacheMutex());
            remoteCache().insert(url + "|" + QString::number(requested.width()), new QImage(img));
        }
        if (resp) {
            QMetaObject::invokeMethod(resp, [resp, img] {
                if (resp) {
                    resp->finishWith(img);
                }
            }, Qt::QueuedConnection);
        }
    });
}
}  // namespace

QQuickImageResponse* ResRemoteImageProvider::requestImageResponse(const QString& id, const QSize& requestedSize)
{
    auto* resp = new ResRemoteResponse();
    const QString url = QUrl::fromPercentEncoding(id.toUtf8());
    const QString key = url + "|" + QString::number(requestedSize.width());
    QPointer<ResRemoteResponse> guard(resp);
    {
        QMutexLocker lock(&cacheMutex());
        if (auto* hit = remoteCache().object(key)) {
            QImage img = *hit;
            QMetaObject::invokeMethod(resp, [guard, img] {
                if (guard) {
                    guard->finishWith(img);
                }
            }, Qt::QueuedConnection);
            return resp;
        }
    }
    const QString file =
        FS::PathCombine(logoCacheDir(), QString(QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex()));

    // network + disk bookkeeping happens on the GUI thread
    QMetaObject::invokeMethod(qApp, [guard, url, file, requestedSize] {
        if (!guard) {
            return;
        }
        if (QFileInfo::exists(file)) {
            QFile f(file);
            if (f.open(QIODevice::ReadOnly)) {
                decodeAsync(guard, f.readAll(), url, requestedSize);
                return;
            }
        }
        const QUrl qurl(url);
        if (!qurl.isValid() || !(qurl.scheme() == "http" || qurl.scheme() == "https")) {
            guard->finishWith({}, QStringLiteral("invalid url"));
            return;
        }
        QNetworkRequest req(qurl);
        req.setHeader(QNetworkRequest::UserAgentHeader, APPLICATION->getUserAgent());
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        auto* reply = APPLICATION->network()->get(req);
        QObject::connect(reply, &QNetworkReply::finished, reply, [guard, reply, url, file, requestedSize] {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                if (guard) {
                    guard->finishWith({}, reply->errorString());
                }
                return;
            }
            const QByteArray data = reply->readAll();
            QDir().mkpath(QFileInfo(file).absolutePath());
            QSaveFile out(file);
            if (out.open(QIODevice::WriteOnly)) {
                out.write(data);
                out.commit();
            }
            if (guard) {
                decodeAsync(guard, data, url, requestedSize);
            }
        });
    }, Qt::QueuedConnection);
    return resp;
}
