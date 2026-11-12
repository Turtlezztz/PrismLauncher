#include "NIInteraction.h"

#include <QCoreApplication>
#include <QEventLoop>

#include "ModernInteraction.h"
#include "NIBlockedModsModel.h"
#include "NIVersionModel.h"
#include "meta/Version.h"
#include "ui/pages/modplatform/atlauncher/AtlOptionalModDialog.h"

static NIInteraction* s_interaction = nullptr;

NIInteraction::NIInteraction(QObject* parent) : QObject(parent)
{
    install();
}

NIInteraction* NIInteraction::create(QQmlEngine*, QJSEngine*)
{
    if (!s_interaction) {
        s_interaction = new NIInteraction(QCoreApplication::instance());
    }
    QJSEngine::setObjectOwnership(s_interaction, QJSEngine::CppOwnership);
    return s_interaction;
}

NIInteraction* NIInteraction::instance()
{
    return s_interaction;
}

QVariant NIInteraction::request(const QString& kind, const QVariantMap& data)
{
    const int id = m_nextId++;
    QEventLoop loop;
    auto appConn = connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
    m_loops.insert(id, &loop);
    emit requested(id, kind, data);
    if (!m_results.contains(id)) {
        loop.exec(QEventLoop::DialogExec);
    }
    m_loops.remove(id);
    disconnect(appConn);
    return m_results.take(id);
}

void NIInteraction::respond(int id, const QVariant& result)
{
    m_results.insert(id, result);
    if (auto* loop = m_loops.value(id)) {
        loop->quit();
    }
}

void NIInteraction::install()
{
    ModernInteraction::questionHandler() = [this](const ModernInteraction::Question& q) -> int {
        QVariantMap d;
        d["title"] = q.title;
        d["text"] = q.text;
        d["kind"] = q.kind;
        d["buttons"] = q.buttons;
        d["cancelIndex"] = q.cancelIndex;
        d["items"] = q.items;
        d["confirmCheck"] = q.confirmCheck;
        auto r = request("question", d);
        bool ok = false;
        int idx = r.toInt(&ok);
        return ok && idx >= 0 ? idx : q.cancelIndex;
    };
    ModernInteraction::checklistHandler() = [this](const QString& title, const QString& text, const QStringList& items,
                                                  const QStringList& checked) -> std::optional<QStringList> {
        QVariantMap d;
        d["title"] = title;
        d["text"] = text;
        d["items"] = items;
        d["checked"] = checked;
        auto r = request("checklist", d);
        if (!r.isValid() || r.isNull()) {
            return std::nullopt;
        }
        return r.toStringList();
    };
    ModernInteraction::blockedModsHandler() = [this](const QString& title, const QString& text, QList<BlockedMod>& mods,
                                                    const QString& hashType) -> bool {
        auto* model = new NIBlockedModsModel(mods, hashType);
        QJSEngine::setObjectOwnership(model, QJSEngine::CppOwnership);
        QVariantMap d;
        d["title"] = title;
        d["text"] = text;
        d["model"] = QVariant::fromValue<QObject*>(model);
        auto r = request("blockedMods", d);
        model->stop();
        model->deleteLater();
        return r.toBool();
    };
    ModernInteraction::notifyHandler() = [this](const QString& title, const QString& text, const QString& kind) {
        emit notified(title, text, kind);
    };
}

// ---------------------------------------------------------------- ATLauncher

namespace {
class NIAtlSupport : public ATLauncher::UserInteractionSupport {
   public:
    std::optional<QList<QString>> chooseOptionalMods(const ATLauncher::PackVersion& version, QList<ATLauncher::VersionMod> mods) override
    {
        auto* self = NIInteraction::instance();
        if (!self) {
            return {};
        }
        auto* source = new AtlOptionalModListModel(nullptr, version, mods);
        auto* model = new NIAtlOptionalMods(source, nullptr);
        source->setParent(model);
        QJSEngine::setObjectOwnership(model, QJSEngine::CppOwnership);
        QVariantMap d;
        d["title"] = QObject::tr("Select optional mods");
        d["model"] = QVariant::fromValue<QObject*>(model);
        auto r = self->request("atlOptionalMods", d);
        std::optional<QList<QString>> out;
        if (r.toBool()) {
            out = source->getResult();
        }
        model->deleteLater();
        return out;
    }

    QString chooseVersion(Meta::VersionList::Ptr vlist, QString minecraftVersion) override
    {
        auto* self = NIInteraction::instance();
        QString recommended;
        for (const auto& v : vlist->versions()) {
            if (!minecraftVersion.isNull()) {
                const auto& reqs = v->requiredSet();
                auto iter = std::find_if(reqs.begin(), reqs.end(), [](const Meta::Require& req) { return req.uid == "net.minecraft"; });
                if (iter == reqs.end() || iter->equalsVersion != minecraftVersion) {
                    continue;
                }
            }
            if (recommended.isEmpty() || v->isRecommended()) {
                recommended = v->descriptor();
                if (v->isRecommended()) {
                    break;
                }
            }
        }
        if (!self) {
            return recommended;
        }
        auto* model = new NIVersionModel();
        QJSEngine::setObjectOwnership(model, QJSEngine::CppOwnership);
        model->setParentFilter(minecraftVersion);
        model->setParentFilterEnabled(!minecraftVersion.isNull());
        model->setVersionList(vlist);
        QVariantMap d;
        d["title"] = QObject::tr("Choose Version");
        d["text"] = minecraftVersion.isNull() ? QString() : QObject::tr("Versions for Minecraft %1").arg(minecraftVersion);
        d["model"] = QVariant::fromValue<QObject*>(model);
        d["current"] = recommended;
        auto r = self->request("chooseVersion", d).toString();
        model->deleteLater();
        return r.isEmpty() ? recommended : r;
    }

    void displayMessage(QString message) override
    {
        if (auto* self = NIInteraction::instance()) {
            QVariantMap d;
            d["title"] = QObject::tr("Installing");
            d["text"] = message.toHtmlEscaped().replace("\n", "<br>");
            d["kind"] = "info";
            d["buttons"] = QStringList{ QObject::tr("OK") };
            d["cancelIndex"] = 0;
            self->request("question", d);
        }
    }
};
}  // namespace

ATLauncher::UserInteractionSupport* NIInteraction::makeAtlSupport()
{
    return new NIAtlSupport();
}

// ---------------------------------------------------------------- NIAtlOptionalMods

NIAtlOptionalMods::NIAtlOptionalMods(AtlOptionalModListModel* source, QObject* parent) : QAbstractListModel(parent), m_source(source)
{
    connect(source, &QAbstractItemModel::dataChanged, this, [this] {
        if (rowCount() > 0) {
            emit dataChanged(index(0), index(rowCount() - 1));
        }
    });
    connect(source, &QAbstractItemModel::modelReset, this, [this] {
        beginResetModel();
        endResetModel();
    });
}

int NIAtlOptionalMods::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_source->rowCount({});
}

QHash<int, QByteArray> NIAtlOptionalMods::roleNames() const
{
    return { { NameRole, "name" }, { DescriptionRole, "description" }, { CheckedRole, "checked" }, { ColorRole, "modColor" } };
}

QVariant NIAtlOptionalMods::data(const QModelIndex& index, int role) const
{
    const int row = index.row();
    switch (role) {
        case NameRole:
            return m_source->data(m_source->index(row, AtlOptionalModListModel::NameColumn), Qt::DisplayRole);
        case DescriptionRole:
            return m_source->data(m_source->index(row, AtlOptionalModListModel::DescriptionColumn), Qt::DisplayRole);
        case CheckedRole:
            return m_source->data(m_source->index(row, AtlOptionalModListModel::EnabledColumn), Qt::CheckStateRole).toInt() == Qt::Checked;
        case ColorRole: {
            auto c = m_source->data(m_source->index(row, AtlOptionalModListModel::NameColumn), Qt::ForegroundRole);
            return c.isValid() ? c.value<QColor>().name() : QString();
        }
        default:
            return {};
    }
}

void NIAtlOptionalMods::toggle(int row)
{
    m_source->setData(m_source->index(row, AtlOptionalModListModel::EnabledColumn), {}, Qt::CheckStateRole);
}

void NIAtlOptionalMods::selectRecommended()
{
    m_source->selectRecommended();
}

void NIAtlOptionalMods::clearAll()
{
    m_source->clearAll();
}

void NIAtlOptionalMods::useShareCode(const QString& code)
{
    m_source->useShareCode(code);
}
