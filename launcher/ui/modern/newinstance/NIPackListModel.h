#pragma once

#include <QIdentityProxyModel>
#include <QQmlEngine>
#include <functional>

/**
 * Exposes any classic modpack list model (Flame/Modrinth/ATL/FTB/Technic...) to QML with uniform roles:
 *   name, summary, logo (image://pixmap/... once downloaded, "" until then), subtitle
 * The classic models download logos asynchronously and report them via DecorationRole (QIcon).
 */
class NIPackListModel : public QIdentityProxyModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by NIPackBrowser")
    Q_PROPERTY(int count READ count NOTIFY countChanged)

   public:
    enum Roles { NameRole = Qt::UserRole + 500, SummaryRole, LogoRole, SubtitleRole };
    using ExtraFn = std::function<QVariant(const QModelIndex& sourceIndex, int role)>;

    explicit NIPackListModel(QObject* parent = nullptr);

    void setSource(QAbstractItemModel* model);
    /// optional per-platform provider for SubtitleRole (and overrides of the others)
    void setExtra(ExtraFn fn) { m_extra = std::move(fn); }

    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role) const override;
    int count() const { return rowCount(); }

    static QString stripHtml(const QString& html);

   signals:
    void countChanged();

   private:
    ExtraFn m_extra;
    QMetaObject::Connection m_conn;
};
