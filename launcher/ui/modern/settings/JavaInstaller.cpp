#include "JavaInstaller.h"

#include <algorithm>

#include "Application.h"
#include "FileSystem.h"
#include "InstanceList.h"
#include "SysInfo.h"
#include "java/download/ArchiveDownloadTask.h"
#include "java/download/ManifestDownloadTask.h"
#include "meta/Index.h"
#include "meta/VersionList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/VersionFile.h"

#if defined(Q_OS_MACOS)
#include "java/download/SymlinkTask.h"
#include "tasks/SequentialTask.h"
#endif

JavaInstaller::JavaInstaller(QObject* parent) : QObject(parent)
{
    QMetaObject::invokeMethod(
        this,
        [this] {
            computeRecommended();
            loadMajors(false);
        },
        Qt::QueuedConnection);
}

JavaInstaller::~JavaInstaller()
{
    if (m_task && m_task->isRunning()) {
        m_task->abort();
    }
}

QVariantList JavaInstaller::providers() const
{
    // same providers as the classic Java::InstallDialog
    return {
        QVariantMap{ { "uid", "net.minecraft.java" }, { "name", tr("Mojang") } },
        QVariantMap{ { "uid", "net.adoptium.java" }, { "name", tr("Adoptium") } },
        QVariantMap{ { "uid", "com.azul.java" }, { "name", tr("Azul Zulu") } },
        QVariantMap{ { "uid", "com.ibm.java" }, { "name", tr("IBM Semeru Open") } },
    };
}

void JavaInstaller::setProvider(const QString& uid)
{
    if (uid == m_provider) {
        return;
    }
    m_provider = uid;
    emit providerChanged();
    loadMajors(false);
}

void JavaInstaller::setInstanceId(const QString& id)
{
    if (id == m_instanceId) {
        return;
    }
    m_instanceId = id;
    emit instanceIdChanged();
    computeRecommended();
}

void JavaInstaller::setRecommendedOnly(bool on)
{
    if (on == m_recommendedOnly) {
        return;
    }
    m_recommendedOnly = on;
    emit majorsChanged();
}

QString JavaInstaller::majorName(const QString& version)
{
    if (version.startsWith("java")) {
        return "Java " + version.mid(4);
    }
    return version;
}

void JavaInstaller::computeRecommended()
{
    m_recommended.clear();
    if (!m_instanceId.isEmpty()) {
        if (auto* inst = APPLICATION->instances()->getInstanceById(m_instanceId)) {
            auto mc = inst->getPackProfile()->getComponent("net.minecraft");
            if (mc) {
                if (auto file = mc->getVersionFile()) {
                    for (auto major : file->compatibleJavaMajors) {
                        m_recommended << QString("Java %1").arg(major);
                    }
                }
            }
        }
        emit majorsChanged();
        return;
    }
    auto versions = APPLICATION->metadataIndex()->get("net.minecraft.java");
    if (!versions) {
        return;
    }
    auto fill = [this, versions] {
        m_recommended.clear();
        for (const auto& ver : versions->versions()) {
            m_recommended << majorName(ver->version());
        }
        emit majorsChanged();
    };
    if (versions->isLoaded()) {
        fill();
        return;
    }
    if (auto task = versions->getLoadTask()) {
        connect(task.get(), &Task::succeeded, this, fill);
        if (!task->isRunning()) {
            task->start();
        }
    }
}

QVariantList JavaInstaller::majors() const
{
    QVariantList out;
    for (int i = 0; i < m_majorList.size(); i++) {
        const auto& v = m_majorList[i];
        const auto name = majorName(v->version());
        const bool recommended = m_recommended.contains(name);
        if (m_recommendedOnly && !m_recommended.isEmpty() && !recommended) {
            continue;
        }
        out << QVariantMap{ { "id", v->version() }, { "name", name }, { "recommended", recommended } };
    }
    return out;
}

void JavaInstaller::loadMajors(bool force)
{
    m_majorList.clear();
    m_majorsError.clear();
    m_major.clear();
    m_builds.clear();
    m_selectedBuild = -1;
    emit majorChanged();
    emit buildsChanged();
    emit selectedBuildChanged();

    auto list = APPLICATION->metadataIndex()->get(m_provider);
    if (!list) {
        m_majorsError = tr("Couldn't load or download the Java version lists!");
        emit majorsChanged();
        return;
    }
    auto fill = [this, list] {
        m_loadingMajors = false;
        m_majorList = list->versions();
        // newest major first
        std::sort(m_majorList.begin(), m_majorList.end(), [](const Meta::Version::Ptr& a, const Meta::Version::Ptr& b) {
            return a->version().mid(4).toInt() > b->version().mid(4).toInt();
        });
        if (m_majorList.isEmpty()) {
            m_majorsError = tr("No Java versions are currently available in the meta.");
        }
        emit majorsChanged();
        // preselect the newest recommended major
        const auto visible = majors();
        if (!visible.isEmpty()) {
            setMajor(visible.first().toMap().value("id").toString());
        }
    };
    if (list->isLoaded() && !force) {
        fill();
        return;
    }
    m_loadingMajors = true;
    emit majorsChanged();
    m_majorsTask = list->getLoadTask(force);
    if (!m_majorsTask) {
        fill();
        return;
    }
    const auto provider = m_provider;
    connect(m_majorsTask.get(), &Task::succeeded, this, [this, provider, fill] {
        if (provider == m_provider) {
            fill();
        }
    });
    connect(m_majorsTask.get(), &Task::failed, this, [this, provider](const QString& reason) {
        if (provider != m_provider) {
            return;
        }
        m_loadingMajors = false;
        m_majorsError = tr("Couldn't load or download the Java version lists!") + "\n" + reason;
        emit majorsChanged();
    });
    if (!m_majorsTask->isRunning()) {
        m_majorsTask->start();
    }
}

void JavaInstaller::setMajor(const QString& major)
{
    if (major == m_major) {
        return;
    }
    m_major = major;
    emit majorChanged();
    loadBuilds(false);
}

QVariantList JavaInstaller::builds() const
{
    QVariantList out;
    for (int i = 0; i < m_builds.size(); i++) {
        const auto& b = m_builds[i];
        out << QVariantMap{ { "index", i },
                            { "name", b->m_name },
                            { "version", b->version.toString() },
                            { "vendor", b->vendor },
                            { "packageType", b->packageType },
                            { "released", b->releaseTime.date().toString(Qt::ISODate) } };
    }
    return out;
}

void JavaInstaller::loadBuilds(bool force)
{
    m_builds.clear();
    m_buildsError.clear();
    m_selectedBuild = -1;
    emit selectedBuildChanged();

    Meta::Version::Ptr version;
    for (const auto& v : m_majorList) {
        if (v->version() == m_major) {
            version = v;
        }
    }
    if (!version) {
        emit buildsChanged();
        return;
    }
    auto fill = [this, version] {
        m_loadingBuilds = false;
        m_builds.clear();
        const QString arch = SysInfo::getSupportedJavaArchitecture();
        if (version->data()) {
            for (const auto& rt : version->data()->runtimes) {
                if (!arch.isEmpty() && rt->runtimeOS == arch) {
                    m_builds << rt;
                }
            }
        }
        std::sort(m_builds.begin(), m_builds.end(), [](const Java::MetadataPtr& a, const Java::MetadataPtr& b) { return *b < *a; });
        if (m_builds.isEmpty()) {
            m_buildsError = tr("No Java versions are currently available for your OS.");
        }
        emit buildsChanged();
        if (!m_builds.isEmpty()) {
            setSelectedBuild(0);
        }
    };
    if (version->isLoaded() && !force) {
        fill();
        return;
    }
    m_loadingBuilds = true;
    emit buildsChanged();
    m_buildsTask = version->loadTask(Net::Mode::Online, force);
    const auto major = m_major;
    connect(m_buildsTask.get(), &Task::succeeded, this, [this, major, fill] {
        if (major == m_major) {
            fill();
        }
    });
    connect(m_buildsTask.get(), &Task::failed, this, [this, major](const QString& reason) {
        if (major != m_major) {
            return;
        }
        m_loadingBuilds = false;
        m_buildsError = tr("Couldn't load or download the Java version lists!") + "\n" + reason;
        emit buildsChanged();
    });
    if (!m_buildsTask->isRunning()) {
        m_buildsTask->start();
    }
}

void JavaInstaller::setSelectedBuild(int index)
{
    if (index == m_selectedBuild) {
        return;
    }
    m_selectedBuild = index;
    emit selectedBuildChanged();
}

void JavaInstaller::reload()
{
    computeRecommended();
    loadMajors(true);
}

void JavaInstaller::install()
{
    if (m_task || m_selectedBuild < 0 || m_selectedBuild >= m_builds.size()) {
        return;
    }
    auto meta = m_builds[m_selectedBuild];
    m_finalPath = FS::PathCombine(APPLICATION->javaPath(), meta->m_name);
    Task::Ptr task;
    switch (meta->downloadType) {
        case Java::DownloadType::Manifest:
            task = makeShared<Java::ManifestDownloadTask>(meta->url, m_finalPath, meta->checksumType, meta->checksumHash);
            break;
        case Java::DownloadType::Archive:
            task = makeShared<Java::ArchiveDownloadTask>(meta->url, m_finalPath, meta->checksumType, meta->checksumHash);
            break;
        case Java::DownloadType::Unknown:
            FS::deletePath(m_finalPath);
            emit installFinished(false, tr("Could not determine Java download type!"));
            return;
    }
#if defined(Q_OS_MACOS)
    auto seq = makeShared<SequentialTask>(tr("Install Java"));
    seq->addTask(task);
    seq->addTask(makeShared<Java::SymlinkTask>(m_finalPath));
    task = seq;
#endif
    m_task = task;
    m_progress = 0;
    m_status = tr("Downloading %1…").arg(meta->m_name);
    connect(task.get(), &Task::progress, this, [this](qint64 cur, qint64 total) {
        m_progress = total > 0 ? double(cur) / double(total) : 0;
        emit installStateChanged();
    });
    connect(task.get(), &Task::status, this, [this](const QString& s) {
        if (!s.isEmpty()) {
            m_status = s;
            emit installStateChanged();
        }
    });
    connect(task.get(), &Task::succeeded, this, [this, meta] {
        m_task.reset();
        emit installStateChanged();
        emit installFinished(true, tr("%1 was installed.").arg(meta->m_name));
    });
    connect(task.get(), &Task::failed, this, [this](const QString& reason) {
        FS::deletePath(m_finalPath);
        m_task.reset();
        emit installStateChanged();
        emit installFinished(false, tr("Java download failed: %1").arg(reason));
    });
    connect(task.get(), &Task::aborted, this, [this] {
        FS::deletePath(m_finalPath);
        m_task.reset();
        emit installStateChanged();
        emit installFinished(false, QString());
    });
    emit installStateChanged();
    task->start();
}

void JavaInstaller::cancel()
{
    if (m_task) {
        m_task->abort();
    }
}
