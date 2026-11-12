#include "NIPackListModel.h"

#include <QIcon>
#include <QRegularExpression>

#include "ImageProviders.h"
#include "ui/widgets/ProjectItem.h"

NIPackListModel::NIPackListModel(QObject* parent) : QIdentityProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &NIPackListModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &NIPackListModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &NIPackListModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &NIPackListModel::countChanged);
}

void NIPackListModel::setSource(QAbstractItemModel* model)
{
    disconnect(m_conn);
    setSourceModel(model);
    if (model) {
        // logos arrive as DecorationRole-only changes; re-announce them for every role so QML delegates refresh
        m_conn = connect(model, &QAbstractItemModel::dataChanged, this, [this](const QModelIndex& tl, const QModelIndex& br) {
            emit dataChanged(mapFromSource(tl), mapFromSource(br), {});
        });
    }
    emit countChanged();
}

QHash<int, QByteArray> NIPackListModel::roleNames() const
{
    return { { NameRole, "name" }, { SummaryRole, "summary" }, { LogoRole, "logo" }, { SubtitleRole, "subtitle" } };
}

QString NIPackListModel::stripHtml(const QString& html)
{
    static const QRegularExpression tags("<[^>]*>");
    QString out = html;
    out.replace("<br>", " ").replace("<br/>", " ").replace("<br />", " ");
    out.remove(tags);
    out.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ");
    return out.simplified();
}

QVariant NIPackListModel::data(const QModelIndex& index, int role) const
{
    if (!sourceModel() || !index.isValid()) {
        return {};
    }
    const auto src = mapToSource(index);
    if (m_extra && role >= NameRole) {
        auto v = m_extra(src, role);
        if (v.isValid()) {
            return v;
        }
    }
    switch (role) {
        case NameRole: {
            auto t = src.data(UserDataTypes::TITLE);
            return t.isValid() ? t : src.data(Qt::DisplayRole);
        }
        case SummaryRole: {
            auto d = src.data(UserDataTypes::DESCRIPTION);
            if (!d.isValid()) {
                d = src.data(Qt::ToolTipRole);
            }
            return stripHtml(d.toString());
        }
        case LogoRole: {
            const auto icon = src.data(Qt::DecorationRole).value<QIcon>();
            if (icon.isNull() || icon.name() == "screenshot-placeholder") {
                return QString();
            }
            const auto key = QString("nipack/%1").arg(icon.cacheKey());
            if (!PixmapCacheProvider::contains(key)) {
                auto sizes = icon.availableSizes();
                QSize size(128, 128);
                if (!sizes.isEmpty()) {
                    size = sizes.last().boundedTo(QSize(256, 256));
                }
                auto pm = icon.pixmap(size);
                if (pm.isNull()) {
                    return QString();
                }
                PixmapCacheProvider::insert(key, pm);
            }
            return "image://pixmap/" + key;
        }
        case SubtitleRole:
            return QString();
        default:
            return QIdentityProxyModel::data(index, role);
    }
}
