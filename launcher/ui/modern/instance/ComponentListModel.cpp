#include "ComponentListModel.h"

#include <QFileInfo>
#include <QRegularExpression>

#include "Application.h"
#include "InstanceList.h"
#include "minecraft/Component.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/auth/AccountList.h"
#include "settings/SettingsObject.h"
#include "tasks/SequentialTask.h"
#include "ui/GuiUtil.h"

ComponentListModel::ComponentListModel(QObject* parent) : QSortFilterProxyModel(parent)
{
    setFilterCaseSensitivity(Qt::CaseInsensitive);
    connect(this, &QAbstractItemModel::rowsInserted, this, &ComponentListModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &ComponentListModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &ComponentListModel::countChanged);
}

QHash<int, QByteArray> ComponentListModel::roleNames() const
{
    return {
        { UidRole, "uid" },
        { NameRole, "name" },
        { VersionRole, "version" },
        { EnabledRole, "componentEnabled" },
        { CanBeDisabledRole, "canBeDisabled" },
        { SeverityRole, "severity" },
        { ProblemsRole, "problems" },
        { RemovableRole, "removable" },
        { MoveableRole, "moveable" },
        { VersionChangeableRole, "versionChangeable" },
        { CustomizableRole, "customizable" },
        { RevertibleRole, "revertible" },
        { CustomRole, "custom" },
        { LoaderRole, "loader" },
        { DependencyOnlyRole, "dependencyOnly" },
        { ReleaseDateRole, "releaseDate" },
    };
}

void ComponentListModel::setInstanceId(const QString& id)
{
    if (id == m_id && m_inst) {
        return;
    }
    m_id = id;
    m_inst = APPLICATION->instances()->getInstanceById(id);
    m_profile = m_inst ? m_inst->getPackProfile() : nullptr;
    setSourceModel(m_profile.data());
    if (m_profile) {
        // make sure the components are loaded (the classic page reloads too)
        auto result = m_profile->reload(Net::Mode::Online);
        if (!result) {
            emit error(tr("Error"), result.error());
        }
        trackTask(m_profile->getCurrentTask().get());
        // dataChanged arrives for column 0 and 1 only with display roles; refresh all of ours
        connect(m_profile, &QAbstractItemModel::dataChanged, this, [this](const QModelIndex& tl, const QModelIndex& br) {
            emit dataChanged(mapFromSource(tl.siblingAtColumn(0)), mapFromSource(br.siblingAtColumn(0)));
        });
    }
    emit instanceIdChanged();
    emit countChanged();
}

void ComponentListModel::setFilterText(const QString& text)
{
    if (text == m_filter) {
        return;
    }
    m_filter = text;
    invalidateFilter();
    emit filterTextChanged();
    emit countChanged();
}

bool ComponentListModel::filterAcceptsRow(int sourceRow, const QModelIndex&) const
{
    if (m_filter.isEmpty() || !m_profile) {
        return true;
    }
    auto c = m_profile->getComponent(sourceRow);
    return c && (c->getName().contains(m_filter, Qt::CaseInsensitive) || c->getID().contains(m_filter, Qt::CaseInsensitive) ||
                 c->getVersion().contains(m_filter, Qt::CaseInsensitive));
}

QVariant ComponentListModel::data(const QModelIndex& index, int role) const
{
    if (role < UidRole || !m_profile) {
        return QSortFilterProxyModel::data(index, role);
    }
    const int row = mapToSource(index).row();
    auto c = m_profile->getComponent(row);
    if (!c) {
        return {};
    }
    switch (role) {
        case UidRole:
            return c->getID();
        case NameRole:
            return c->getName();
        case VersionRole:
            return m_profile->data(m_profile->index(row, PackProfile::VersionColumn), Qt::DisplayRole);
        case EnabledRole:
            return c->isEnabled();
        case CanBeDisabledRole:
            return c->canBeDisabled();
        case SeverityRole:
            switch (c->getProblemSeverity()) {
                case ProblemSeverity::Warning:
                    return QStringLiteral("warning");
                case ProblemSeverity::Error:
                    return QStringLiteral("error");
                default:
                    return QString();
            }
        case ProblemsRole: {
            QVariantList list;
            for (const auto& p : c->getProblems()) {
                list.append(QVariantMap{ { "severity", p.m_severity == ProblemSeverity::Error ? "error" : "warning" },
                                         { "text", p.m_description } });
            }
            return list;
        }
        case RemovableRole:
            return c->isRemovable();
        case MoveableRole:
            return c->isMoveable();
        case VersionChangeableRole:
            return c->isVersionChangeable();
        case CustomizableRole:
            return c->isCustomizable();
        case RevertibleRole:
            return c->isRevertible();
        case CustomRole:
            return c->isCustom();
        case LoaderRole:
            return c->isKnownModloader();
        case DependencyOnlyRole:
            return c->m_dependencyOnly;
        case ReleaseDateRole: {
            auto dt = c->getReleaseDateTime();
            return dt.isValid() ? dt.toString("d MMM yyyy") : QString();
        }
        default:
            return {};
    }
}

QVariantMap ComponentListModel::get(const QString& uid) const
{
    QVariantMap map;
    const int src = sourceRowOf(uid);
    if (src < 0) {
        return map;
    }
    auto idx = mapFromSource(m_profile->index(src, 0));
    if (!idx.isValid()) {
        // filtered out: still answer from the source row
        return map;
    }
    const auto names = roleNames();
    for (auto it = names.begin(); it != names.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return map;
}

int ComponentListModel::sourceRowOf(const QString& uid) const
{
    if (!m_profile) {
        return -1;
    }
    for (int i = 0; i < m_profile->rowCount(); i++) {
        if (m_profile->getComponent(i)->getID() == uid) {
            return i;
        }
    }
    return -1;
}

bool ComponentListModel::busy() const
{
    return m_task && m_task->isRunning();
}

QString ComponentListModel::busyStatus() const
{
    return busy() ? m_task->getStatus() : QString();
}

double ComponentListModel::busyProgress() const
{
    if (!busy() || m_task->getTotalProgress() <= 0) {
        return -1;
    }
    return double(m_task->getProgress()) / double(m_task->getTotalProgress());
}

bool ComponentListModel::autoUpdateMinecraft() const
{
    return m_inst && m_inst->settings()->get("UseLatestMinecraftVersion").toBool();
}

void ComponentListModel::trackTask(Task* task)
{
    if (m_task) {
        disconnect(m_task, nullptr, this, nullptr);
    }
    m_task = task;
    if (task) {
        connect(task, &Task::status, this, &ComponentListModel::busyChanged);
        connect(task, &Task::progress, this, &ComponentListModel::busyChanged);
        connect(task, &Task::started, this, &ComponentListModel::busyChanged);
        connect(task, &Task::finished, this, [this] {
            emit busyChanged();
            // problems / versions may have changed
            if (rowCount() > 0) {
                emit dataChanged(index(0, 0), index(rowCount() - 1, 0));
            }
        });
    }
    emit busyChanged();
}

void ComponentListModel::setEnabled(const QString& uid, bool enabled)
{
    const int row = sourceRowOf(uid);
    if (row < 0) {
        return;
    }
    auto c = m_profile->getComponent(row);
    if (c->isEnabled() != enabled) {
        c->setEnabled(enabled);
    }
}

void ComponentListModel::moveUp(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row >= 0) {
        m_profile->move(row, PackProfile::MoveUp);
    }
}

void ComponentListModel::moveDown(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row >= 0) {
        m_profile->move(row, PackProfile::MoveDown);
    }
}

QString ComponentListModel::remove(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row < 0) {
        return tr("Component not found");
    }
    if (!m_profile->remove(row)) {
        return tr("Couldn't remove file");
    }
    reload();
    return {};
}

void ComponentListModel::customize(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row < 0) {
        return;
    }
    if (!m_profile->getComponent(row)->getVersionFile()) {
        emit error(tr("Cannot customize"), tr("The component's files are not available yet. Try again once the instance is updated."));
        return;
    }
    if (!m_profile->customize(row)) {
        emit error(tr("Cannot customize"), tr("Failed to customize the component."));
    }
}

void ComponentListModel::revert(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row < 0) {
        return;
    }
    if (!m_profile->revertToBase(row)) {
        emit error(tr("Cannot revert"), tr("Failed to revert the component."));
    }
}

void ComponentListModel::edit(const QString& uid)
{
    const int row = sourceRowOf(uid);
    if (row < 0) {
        return;
    }
    const auto filename = m_profile->getComponent(row)->getFilename();
    if (!QFileInfo::exists(filename)) {
        emit error(tr("Cannot edit"), tr("The file %1 doesn't exist.").arg(filename));
        return;
    }
    APPLICATION->openJsonEditor(filename);
}

QString ComponentListModel::recommendedVersionFor(const QString& uid) const
{
    if (!m_profile || (uid != "org.lwjgl" && uid != "org.lwjgl3")) {
        return {};
    }
    auto minecraft = m_profile->getComponent("net.minecraft");
    if (!minecraft) {
        return {};
    }
    for (const auto& req : minecraft->m_cachedRequires) {
        if (req.uid == uid) {
            return !req.equalsVersion.isEmpty() ? req.equalsVersion : req.suggests;
        }
    }
    return {};
}

void ComponentListModel::changeVersion(const QString& uid, const QString& version)
{
    if (!m_profile || version.isEmpty()) {
        return;
    }
    bool important = false;
    if (uid == "net.minecraft") {
        important = true;
        if (APPLICATION->settings()->get("AutomaticJavaSwitch").toBool() && m_inst->settings()->get("AutomaticJava").toBool() &&
            m_inst->settings()->get("OverrideJavaLocation").toBool()) {
            m_inst->settings()->set("OverrideJavaLocation", false);
            m_inst->settings()->set("JavaPath", "");
        }
        if (m_inst->settings()->get("UseLatestMinecraftVersion").toBool()) {
            m_inst->settings()->set("UseLatestMinecraftVersion", false);
        }
    }
    m_profile->setComponentVersion(uid, version, important);
    m_profile->resolve(Net::Mode::Online);
    trackTask(m_profile->getCurrentTask().get());
}

void ComponentListModel::addJarMods()
{
    auto list = GuiUtil::browseForFiles("jarmod", tr("Select jar mods"), tr("Minecraft.jar mods") + " (*.zip *.jar)",
                                        APPLICATION->settings()->get("CentralModsDir").toString(), nullptr);
    if (!list.empty()) {
        m_profile->installJarMods(list);
    }
}

void ComponentListModel::replaceMinecraftJar()
{
    auto jarPath = GuiUtil::browseForFile("jar", tr("Select jar"), tr("Minecraft.jar replacement") + " (*.jar)",
                                          APPLICATION->settings()->get("CentralModsDir").toString(), nullptr);
    if (!jarPath.isEmpty()) {
        m_profile->installCustomJar(jarPath);
    }
}

void ComponentListModel::importComponents()
{
    auto list = GuiUtil::browseForFiles("component", tr("Select components"), tr("Components") + " (*.json)",
                                        APPLICATION->settings()->get("CentralModsDir").toString(), nullptr);
    if (!list.isEmpty() && !m_profile->installComponents(list)) {
        emit error(tr("Failed to import components"), tr("Some components could not be imported. Check logs for details"));
    }
}

void ComponentListModel::addAgents()
{
    auto list = GuiUtil::browseForFiles("agent", tr("Select agents"), tr("Java agents") + " (*.jar)",
                                        APPLICATION->settings()->get("CentralModsDir").toString(), nullptr);
    if (!list.isEmpty()) {
        m_profile->installAgents(list);
    }
}

QString ComponentListModel::suggestUid(const QString& name) const
{
    auto proto = name.toLower();
    static const QRegularExpression s_removeChars("[^a-z]");
    proto.remove(s_removeChars);
    return proto.isEmpty() ? QString() : "org.multimc.custom." + proto;
}

QString ComponentListModel::validateEmpty(const QString& uid, const QString& name) const
{
    if (name.trimmed().isEmpty()) {
        return tr("Enter a name.");
    }
    if (uid.trimmed().isEmpty()) {
        return tr("Enter a uid.");
    }
    if (sourceRowOf(uid.trimmed()) >= 0) {
        return tr("A component with this uid already exists.");
    }
    return {};
}

void ComponentListModel::addEmpty(const QString& uid, const QString& name)
{
    if (!validateEmpty(uid, name).isEmpty()) {
        return;
    }
    m_profile->installEmpty(uid.trimmed(), name.trimmed());
}

QVariantList ComponentListModel::loaderConflicts(const QString& uid) const
{
    QVariantList out;
    if (!m_profile) {
        return out;
    }
    auto known = Component::KNOWN_MODLOADERS.find(uid);
    if (known == Component::KNOWN_MODLOADERS.cend()) {
        return out;
    }
    for (const auto& conflictId : known->knownConflictingComponents) {
        auto c = m_profile->getComponent(conflictId);
        if (c && c->isEnabled() && !c->isCustom()) {
            out.append(QVariantMap{ { "uid", c->getID() },
                                    { "name", c->getName() },
                                    { "version", c->getVersion() },
                                    { "canDisable", c->canBeDisabled() },
                                    { "canRemove", c->isRemovable() } });
        }
    }
    return out;
}

void ComponentListModel::resolveConflict(const QString& uid, const QString& action)
{
    auto c = m_profile ? m_profile->getComponent(uid) : nullptr;
    if (!c) {
        return;
    }
    if (action == "disable") {
        c->setEnabled(false);
    } else if (action == "remove") {
        m_profile->remove(uid);
    }
    m_profile->resolve(Net::Mode::Online);
    trackTask(m_profile->getCurrentTask().get());
}

void ComponentListModel::installLoader(const QString& uid, const QString& version)
{
    if (!m_profile || version.isEmpty()) {
        return;
    }
    if (auto c = m_profile->getComponent(uid); c && !c->isEnabled()) {
        c->setEnabled(true);
    }
    m_profile->setComponentVersion(uid, version);
    if (auto c = m_profile->getComponent(uid)) {
        c->setEnabled(true);
    }
    m_profile->resolve(Net::Mode::Online);
    trackTask(m_profile->getCurrentTask().get());
}

void ComponentListModel::reload()
{
    if (!m_profile) {
        return;
    }
    auto result = m_profile->reload(Net::Mode::Online);
    if (!result) {
        emit error(tr("Error"), result.error());
    }
    trackTask(m_profile->getCurrentTask().get());
}

void ComponentListModel::downloadAll()
{
    if (!m_inst) {
        return;
    }
    if (!APPLICATION->accounts()->anyAccountIsValid()) {
        emit error(tr("Error"), tr("Cannot download Minecraft or update instances unless you have at least one account added.\n"
                                   "Please add a Microsoft account."));
        return;
    }
    auto updateTasks = m_inst->createUpdateTask();
    if (updateTasks.isEmpty()) {
        emit info(tr("Everything is already downloaded."));
        return;
    }
    auto task = makeShared<SequentialTask>();
    for (const auto& t : updateTasks) {
        task->addTask(t);
    }
    m_ownedTask = task;
    connect(task.get(), &Task::failed, this, [this](const QString& reason) { emit error(tr("Error updating instance"), reason); });
    connect(task.get(), &Task::succeeded, this, [this] { emit info(tr("All files downloaded.")); });
    trackTask(task.get());
    task->start();
}
