#include "ResServerModel.h"

#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QPixmap>
#include <sstream>

#include "Application.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "ResImages.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "minecraft/launch/MinecraftTarget.h"
#include "ui/pages/instance/McClient.h"
#include "ui/pages/instance/McResolver.h"
#include "ui/widgets/InfoFrame.h"

#include <io/stream_reader.h>
#include <io/stream_writer.h>
#include <tag_compound.h>
#include <tag_list.h>
#include <tag_primitive.h>
#include <tag_string.h>

namespace {
std::unique_ptr<nbt::tag_compound> parseServersDat(const QString& filename)
{
    try {
        auto res = FS::read(filename);
        if (!res) {
            return nullptr;
        }
        const auto& input = res.value();
        std::istringstream foo(std::string(input.constData(), input.size()));
        auto pair = nbt::io::read_compound(foo);
        if (pair.first != "" || pair.second == nullptr) {
            return nullptr;
        }
        return std::move(pair.second);
    } catch (...) {
        return nullptr;
    }
}

bool serializeServerDat(const QString& filename, nbt::tag_compound* levelInfo)
{
    try {
        if (!FS::ensureFilePathExists(filename)) {
            return false;
        }
        std::ostringstream s;
        nbt::io::write_tag("", *levelInfo, s);
        QByteArray val(s.str().data(), static_cast<int>(s.str().size()));
        return FS::write(filename, val).has_value();
    } catch (...) {
        return false;
    }
}

const QHash<QString, QString>& namedColors()
{
    static const QHash<QString, QString> c = {
        { "black", "#000000" },     { "dark_blue", "#0000AA" }, { "dark_green", "#00AA00" }, { "dark_aqua", "#00AAAA" },
        { "dark_red", "#AA0000" },  { "dark_purple", "#AA00AA" }, { "gold", "#FFAA00" },     { "gray", "#AAAAAA" },
        { "dark_gray", "#555555" }, { "blue", "#5555FF" },      { "green", "#55FF55" },      { "aqua", "#55FFFF" },
        { "red", "#FF5555" },       { "light_purple", "#FF55FF" }, { "yellow", "#FFFF55" },  { "white", "#FFFFFF" },
    };
    return c;
}

QString chatToHtml(const QJsonValue& v)
{
    if (v.isString()) {
        return InfoFrame::renderColorCodes(v.toString().toHtmlEscaped()).remove("<html>").remove("</html>");
    }
    if (v.isArray()) {
        QString out;
        for (const auto& e : v.toArray()) {
            out += chatToHtml(e);
        }
        return out;
    }
    if (!v.isObject()) {
        return {};
    }
    const auto o = v.toObject();
    QString inner = chatToHtml(o.value("text"));
    for (const auto& e : o.value("extra").toArray()) {
        inner += chatToHtml(e);
    }
    QString open, close;
    const auto color = o.value("color").toString();
    if (!color.isEmpty()) {
        const QString hex = color.startsWith('#') ? color : namedColors().value(color);
        if (!hex.isEmpty()) {
            open += QString("<span style=\"color:%1\">").arg(hex);
            close.prepend("</span>");
        }
    }
    if (o.value("bold").toBool()) {
        open += "<b>";
        close.prepend("</b>");
    }
    if (o.value("italic").toBool()) {
        open += "<i>";
        close.prepend("</i>");
    }
    if (o.value("underlined").toBool()) {
        open += "<u>";
        close.prepend("</u>");
    }
    if (o.value("strikethrough").toBool()) {
        open += "<s>";
        close.prepend("</s>");
    }
    return open + inner + close;
}
}  // namespace

ResServerModel::ResServerModel(QObject* parent) : QAbstractListModel(parent)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(5000);
    connect(&m_saveTimer, &QTimer::timeout, this, &ResServerModel::saveInternal);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        if (m_locked) {
            load();
            refresh();
        }
    });
    m_iconNs = ResImages::newNamespace("server");
    ResImages::registerSource(m_iconNs, [this](const QString& id, const QSize& size) { return iconFor(id, size); });
}

ResServerModel::~ResServerModel()
{
    ResImages::unregisterSource(m_iconNs);
    saveNow();
}

void ResServerModel::componentComplete()
{
    m_complete = true;
    ResImages::ensure(qmlEngine(this));
    m_instance = APPLICATION->instances()->getInstanceById(m_instanceId);
    if (m_instance) {
        connect(m_instance, &BaseInstance::runningStatusChanged, this, [this](bool running) {
            if (running && !m_locked) {
                saveNow();
            }
            m_locked = running;
            updateWatcher();
            emit lockedChanged();
        });
        m_locked = m_instance->isRunning();
    }
    load();
    updateWatcher();
    emit sourceChanged();
    emit lockedChanged();
    refresh();
}

void ResServerModel::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    saveNow();
    m_instanceId = id;
    if (m_complete) {
        if (m_instance) {
            m_instance->disconnect(this);
        }
        m_instance = APPLICATION->instances()->getInstanceById(m_instanceId);
        m_locked = m_instance && m_instance->isRunning();
        load();
        updateWatcher();
        emit sourceChanged();
        emit lockedChanged();
        refresh();
    }
}

QString ResServerModel::serversPath() const
{
    return m_instance ? FS::PathCombine(m_instance->gameRoot(), "servers.dat") : QString();
}

void ResServerModel::updateWatcher()
{
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    if (m_instance && m_locked) {
        m_watcher.addPath(m_instance->gameRoot());
    }
}

void ResServerModel::load()
{
    m_saveTimer.stop();
    m_dirty = false;
    beginResetModel();
    m_servers.clear();
    m_loaded = false;
    if (m_instance) {
        try {
            auto dat = parseServersDat(serversPath());
            if (dat) {
                auto& list = dat->at("servers").as<nbt::tag_list>();
                for (auto& iter : list) {
                    auto& tag = iter.as<nbt::tag_compound>();
                    Server s;
                    s.address = QString::fromUtf8(std::string(tag["ip"]).c_str());
                    s.name = QString::fromUtf8(std::string(tag["name"]).c_str());
                    if (tag.has_key("icon")) {
                        s.icon = QByteArray::fromBase64(std::string(tag["icon"]).c_str());
                    }
                    if (tag.has_key("acceptTextures", nbt::tag_type::Byte)) {
                        s.acceptTextures = tag["acceptTextures"].as<nbt::tag_byte>().get() ? 1 : 2;
                    }
                    m_servers << s;
                }
            }
            m_loaded = true;
        } catch (...) {
            m_loaded = !QFileInfo::exists(serversPath());
        }
    }
    if (m_current >= m_servers.size()) {
        m_current = -1;
    }
    endResetModel();
    emit countChanged();
    emit currentRowChanged();
    emit selectionChanged();
}

void ResServerModel::scheduleSave()
{
    if (!m_loaded) {
        qWarning() << "Server list should never save if it didn't successfully load";
        return;
    }
    m_dirty = true;
    m_saveTimer.start();
}

void ResServerModel::saveNow()
{
    if (m_dirty) {
        saveInternal();
    }
}

void ResServerModel::saveInternal()
{
    m_saveTimer.stop();
    m_dirty = false;
    if (!m_instance) {
        return;
    }
    nbt::tag_compound out;
    nbt::tag_list list;
    for (const auto& s : m_servers) {
        nbt::tag_compound tag;
        tag.insert("name", s.name.trimmed().toUtf8().toStdString());
        tag.insert("ip", s.address.trimmed().toUtf8().toStdString());
        if (!s.icon.isEmpty()) {
            tag.insert("icon", s.icon.toBase64().toStdString());
        }
        if (s.acceptTextures != 0) {
            tag.insert("acceptTextures", nbt::tag_byte(s.acceptTextures == 1));
        }
        list.push_back(std::move(tag));
    }
    out.insert("servers", nbt::value(std::move(list)));
    if (!serializeServerDat(serversPath(), &out)) {
        qWarning() << "Failed to save server list, will try again";
        scheduleSave();
    }
}

QHash<int, QByteArray> ResServerModel::roleNames() const
{
    return { { NameRole, "name" },         { AddressRole, "address" }, { AcceptTexturesRole, "acceptTextures" },
             { IconSourceRole, "iconSource" }, { StatusRole, "status" },   { MotdHtmlRole, "motdHtml" },
             { PlayersRole, "players" },   { MaxPlayersRole, "maxPlayers" }, { VersionRole, "version" },
             { PingRole, "ping" },         { ErrorRole, "error" },     { SelectedRole, "selected" } };
}

QVariant ResServerModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_servers.size()) {
        return {};
    }
    const auto& s = m_servers.at(index.row());
    switch (role) {
        case Qt::DisplayRole:
        case NameRole:
            return s.name;
        case AddressRole:
            return s.address;
        case AcceptTexturesRole:
            return s.acceptTextures;
        case IconSourceRole:
            return s.icon.isEmpty() ? QString() : QString("image://resicon/%1/%2?v=%3").arg(m_iconNs).arg(index.row()).arg(s.iconRev);
        case StatusRole:
            return s.status;
        case MotdHtmlRole:
            return s.motdHtml;
        case PlayersRole:
            return s.players;
        case MaxPlayersRole:
            return s.maxPlayers;
        case VersionRole:
            return s.version;
        case PingRole:
            return s.ping;
        case ErrorRole:
            return s.error;
        case SelectedRole:
            return s.selected;
        default:
            return {};
    }
}

QPixmap ResServerModel::iconFor(const QString& id, const QSize& size) const
{
    bool ok = false;
    const int row = id.toInt(&ok);
    if (!ok || row < 0 || row >= m_servers.size()) {
        return {};
    }
    QPixmap px;
    px.loadFromData(m_servers.at(row).icon);
    if (!px.isNull() && size.isValid()) {
        px = px.scaled(size, Qt::KeepAspectRatio, Qt::FastTransformation);
    }
    return px;
}

void ResServerModel::rowChanged(int row)
{
    if (row >= 0 && row < m_servers.size()) {
        emit dataChanged(index(row), index(row));
    }
}

void ResServerModel::setCurrentRow(int r)
{
    if (r < -1 || r >= m_servers.size()) {
        r = -1;
    }
    if (r == m_current) {
        return;
    }
    m_current = r;
    emit currentRowChanged();
}

int ResServerModel::selectedCount() const
{
    int n = 0;
    for (const auto& s : m_servers) {
        n += s.selected ? 1 : 0;
    }
    return n;
}

void ResServerModel::select(int row, const QString& mode)
{
    if (row < 0 || row >= m_servers.size()) {
        return;
    }
    if (mode == "toggle") {
        m_servers[row].selected = !m_servers[row].selected;
        m_anchor = row;
    } else if (mode == "range" && m_anchor >= 0) {
        for (int i = 0; i < m_servers.size(); ++i) {
            m_servers[i].selected = i >= qMin(m_anchor, row) && i <= qMax(m_anchor, row);
        }
    } else {
        for (int i = 0; i < m_servers.size(); ++i) {
            m_servers[i].selected = i == row;
        }
        m_anchor = row;
    }
    emit dataChanged(index(0), index(static_cast<int>(m_servers.size()) - 1), { SelectedRole });
    setCurrentRow(row);
    emit selectionChanged();
}

void ResServerModel::clearSelection()
{
    for (auto& s : m_servers) {
        s.selected = false;
    }
    if (!m_servers.isEmpty()) {
        emit dataChanged(index(0), index(static_cast<int>(m_servers.size()) - 1), { SelectedRole });
    }
    setCurrentRow(-1);
    emit selectionChanged();
}

QVariantMap ResServerModel::get(int row) const
{
    QVariantMap m;
    if (row < 0 || row >= m_servers.size()) {
        return m;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        m[QString::fromUtf8(it.value())] = data(index(row), it.key());
    }
    return m;
}

int ResServerModel::addServer(const QString& name, const QString& address, int acceptTextures)
{
    if (m_locked || !m_instance) {
        return -1;
    }
    int pos = m_current >= 0 ? m_current + 1 : static_cast<int>(m_servers.size());
    beginInsertRows({}, pos, pos);
    Server s;
    s.name = name.isEmpty() ? tr("Minecraft Server") : name;
    s.address = address;
    s.acceptTextures = acceptTextures;
    m_servers.insert(pos, s);
    endInsertRows();
    if (!m_loaded) {
        m_loaded = true;  // the file didn't exist before
    }
    scheduleSave();
    emit countChanged();
    select(pos);
    ping(pos);
    return pos;
}

void ResServerModel::setServer(int row, const QString& name, const QString& address, int acceptTextures)
{
    if (m_locked || row < 0 || row >= m_servers.size()) {
        return;
    }
    auto& s = m_servers[row];
    const bool addressChanged = s.address != address;
    s.name = name;
    s.address = address;
    s.acceptTextures = acceptTextures;
    rowChanged(row);
    scheduleSave();
    if (addressChanged) {
        ping(row);
    }
}

bool ResServerModel::removeSelected()
{
    if (m_locked) {
        return false;
    }
    bool removed = false;
    for (int i = static_cast<int>(m_servers.size()) - 1; i >= 0; --i) {
        if (m_servers.at(i).selected) {
            beginRemoveRows({}, i, i);
            m_servers.removeAt(i);
            endRemoveRows();
            removed = true;
        }
    }
    if (removed) {
        m_current = -1;
        scheduleSave();
        emit countChanged();
        emit currentRowChanged();
        emit selectionChanged();
    }
    return removed;
}

bool ResServerModel::moveUp(int row)
{
    if (m_locked || row <= 0 || row >= m_servers.size()) {
        return false;
    }
    beginMoveRows({}, row, row, {}, row - 1);
    m_servers.swapItemsAt(row - 1, row);
    endMoveRows();
    scheduleSave();
    if (m_current == row) {
        m_current = row - 1;
        emit currentRowChanged();
    }
    // icons are addressed by row
    m_servers[row].iconRev++;
    m_servers[row - 1].iconRev++;
    emit dataChanged(index(row - 1), index(row), { IconSourceRole });
    return true;
}

bool ResServerModel::moveDown(int row)
{
    if (m_locked || row < 0 || row + 1 >= m_servers.size()) {
        return false;
    }
    beginMoveRows({}, row, row, {}, row + 2);
    m_servers.swapItemsAt(row + 1, row);
    endMoveRows();
    scheduleSave();
    if (m_current == row) {
        m_current = row + 1;
        emit currentRowChanged();
    }
    m_servers[row].iconRev++;
    m_servers[row + 1].iconRev++;
    emit dataChanged(index(row), index(row + 1), { IconSourceRole });
    return true;
}

void ResServerModel::refresh()
{
    for (int i = 0; i < m_servers.size(); ++i) {
        ping(i);
    }
}

void ResServerModel::ping(int row)
{
    if (row < 0 || row >= m_servers.size()) {
        return;
    }
    auto& s = m_servers[row];
    const int gen = ++s.pingGen;
    s.status = "pinging";
    s.error.clear();
    rowChanged(row);
    const QString address = s.address;
    auto target = MinecraftTarget::parse(address, false);
    auto timer = std::make_shared<QElapsedTimer>();
    QPointer<ResServerModel> self(this);
    // find the row again by address + generation, rows may move while pinging
    auto findRow = [self, address, gen]() -> int {
        if (!self) {
            return -1;
        }
        for (int i = 0; i < self->m_servers.size(); ++i) {
            if (self->m_servers[i].address == address && self->m_servers[i].pingGen == gen) {
                return i;
            }
        }
        return -1;
    };
    auto fail = [self, findRow](const QString& err) {
        const int r = findRow();
        if (r < 0) {
            return;
        }
        auto& sv = self->m_servers[r];
        sv.status = "offline";
        sv.error = err;
        self->rowChanged(r);
    };
    auto* resolver = new McResolver(nullptr, target.address, target.port);
    connect(resolver, &McResolver::succeeded, this, [self, findRow, fail, timer, domain = target.address](QString ip, int port) {
        auto* client = new McClient(nullptr, domain, ip, static_cast<uint16_t>(port));
        timer->start();
        QObject::connect(client, &McClient::succeeded, self, [self, findRow, timer](QJsonObject data) {
            const int r = findRow();
            if (r < 0) {
                return;
            }
            auto& sv = self->m_servers[r];
            sv.status = "online";
            sv.ping = static_cast<int>(timer->elapsed());
            const auto players = data.value("players").toObject();
            sv.players = players.value("online").toInt(-1);
            sv.maxPlayers = players.value("max").toInt(-1);
            sv.version = data.value("version").toObject().value("name").toString();
            sv.motdHtml = chatToHtml(data.value("description"));
            const auto fav = data.value("favicon").toString();
            if (fav.startsWith("data:image/png;base64,")) {
                const auto bytes = QByteArray::fromBase64(fav.mid(22).toLatin1());
                if (bytes != sv.icon && !self->m_locked) {
                    sv.icon = bytes;
                    sv.iconRev++;
                    self->scheduleSave();
                }
            }
            self->rowChanged(r);
        });
        QObject::connect(client, &McClient::failed, self, fail);
        QObject::connect(client, &McClient::finished, client, &QObject::deleteLater);
        client->getStatusData();
    });
    connect(resolver, &McResolver::failed, this, fail);
    connect(resolver, &McResolver::finished, resolver, &QObject::deleteLater);
    resolver->ping();
}

bool ResServerModel::join(int row)
{
    if (!m_instance || row < 0 || row >= m_servers.size()) {
        return false;
    }
    saveNow();
    return APPLICATION->launch(m_instance, LaunchMode::Normal,
                               std::make_shared<MinecraftTarget>(MinecraftTarget::parse(m_servers.at(row).address, false)));
}
