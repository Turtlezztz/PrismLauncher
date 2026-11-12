#include "NIVanillaSource.h"

#include "Version.h"
#include "minecraft/VanillaInstanceCreationTask.h"

static QString loaderUid(const QString& key)
{
    if (key == "neoforge") {
        return "net.neoforged";
    }
    if (key == "forge") {
        return "net.minecraftforge";
    }
    if (key == "fabric") {
        return "net.fabricmc.fabric-loader";
    }
    if (key == "quilt") {
        return "org.quiltmc.quilt-loader";
    }
    if (key == "liteloader") {
        return "com.mumfrey.liteloader";
    }
    return {};
}

NIVanillaSource::NIVanillaSource(QObject* parent)
    : QObject(parent), m_versions(new NIVersionModel(this)), m_loaderVersions(new NIVersionModel(this))
{
    m_versions->setTypeFilter({ "release" });
    connect(m_versions, &NIVersionModel::loaded, this, [this] {
        if (!m_version) {
            selectVersion(m_versions->recommendedRow());
        }
    });
    connect(m_loaderVersions, &NIVersionModel::loaded, this, [this] {
        if (!m_loaderVersion || m_loaderVersions->indexOf(m_loaderVersion->descriptor()) < 0) {
            selectLoaderVersion(m_loaderVersions->recommendedRow());
        }
    });
}

void NIVanillaSource::setController(NIController* c)
{
    m_controller = c;
    emit controllerChanged();
}

void NIVanillaSource::setActive(bool a)
{
    if (a == m_active) {
        return;
    }
    m_active = a;
    emit activeChanged();
    if (a) {
        if (m_versions->uid().isEmpty()) {
            m_versions->setUid("net.minecraft");
        }
        suggestCurrent();
    }
}

QString NIVanillaSource::loaderName(const QString& key)
{
    if (key == "neoforge") {
        return "NeoForge";
    }
    if (key == "forge") {
        return "Forge";
    }
    if (key == "fabric") {
        return "Fabric";
    }
    if (key == "quilt") {
        return "Quilt";
    }
    if (key == "liteloader") {
        return "LiteLoader";
    }
    return {};
}

void NIVanillaSource::setLoader(const QString& loader)
{
    if (loader == m_loader) {
        return;
    }
    m_loader = loader;
    m_loaderVersion.reset();
    updateLoaderList();
    emit selectionChanged();
    suggestCurrent();
}

QString NIVanillaSource::selectedVersion() const
{
    return m_version ? m_version->descriptor() : QString();
}

QString NIVanillaSource::selectedLoaderVersion() const
{
    return m_loaderVersion ? m_loaderVersion->descriptor() : QString();
}

QString NIVanillaSource::loaderEmptyText() const
{
    if (!m_version) {
        return tr("No Minecraft version is selected.");
    }
    if (m_loader == "none") {
        return tr("No mod loader is selected.");
    }
    return tr("No versions are currently available for Minecraft %1").arg(m_version->descriptor());
}

void NIVanillaSource::selectVersion(int row)
{
    auto v = m_versions->versionPtr(row);
    if (!v) {
        return;
    }
    m_version = v;
    m_loaderVersion.reset();
    updateLoaderList();
    emit selectionChanged();
    suggestCurrent();
}

void NIVanillaSource::selectLoaderVersion(int row)
{
    m_loaderVersion = m_loaderVersions->versionPtr(row);
    emit selectionChanged();
    suggestCurrent();
}

void NIVanillaSource::updateLoaderList()
{
    const auto uid = loaderUid(m_loader);
    if (!m_version || uid.isEmpty()) {
        m_loaderVersions->setParentFilter("AAA");  // empty list, like the classic page
        m_loaderVersions->setParentFilterEnabled(true);
        m_loaderVersions->setUid({});
        return;
    }
    const auto mc = m_version->descriptor();
    if (m_loader == "fabric" || m_loader == "quilt") {
        // Fabric/Quilt are not tied to a Minecraft version in the metadata; only supported from 1.14
        if (Version(mc) >= Version("1.14")) {
            m_loaderVersions->setParentFilterEnabled(false);
        } else {
            m_loaderVersions->setParentFilter("AAA");
            m_loaderVersions->setParentFilterEnabled(true);
        }
    } else {
        m_loaderVersions->setParentFilter(mc);
        m_loaderVersions->setParentFilterEnabled(true);
    }
    if (m_loaderVersions->uid() == uid) {
        if (!m_loaderVersions->loading()) {
            selectLoaderVersion(m_loaderVersions->recommendedRow());
        }
    } else {
        m_loaderVersions->setUid(uid);
    }
}

void NIVanillaSource::suggestCurrent()
{
    if (!m_active || !m_controller) {
        return;
    }
    if (!m_version) {
        m_controller->setSuggestedPack();
        return;
    }
    if (m_loader == "none" || !m_loaderVersion) {
        m_controller->setSuggestedPack(m_version->descriptor(), {}, new VanillaCreationTask(m_version));
    } else {
        m_controller->setSuggestedPack(QString("%1 %2").arg(m_version->descriptor(), loaderName(m_loader)), {},
                                       new VanillaCreationTask(m_version, loaderUid(m_loader), m_loaderVersion));
    }
    m_controller->clearSuggestedIcon();
}
