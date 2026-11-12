#include "LauncherInfo.h"

#include <QFile>
#include <QSysInfo>

#include "Application.h"
#include "BuildConfig.h"
#include "Markdown.h"
#include "StringUtils.h"
#include "news/NewsChecker.h"
#include "news/NewsEntry.h"
#include "ui/dialogs/UpdateAvailableDialog.h"
#include "updater/ExternalUpdater.h"

static LauncherInfo* s_launcherInfo = nullptr;

LauncherInfo::LauncherInfo(QObject* parent) : QObject(parent)
{
    // Present available updates in QML instead of the widget dialog.
    ExternalUpdater::s_offerHook = [this](const QString& versionName, const QString& notes, std::function<void(int)> respond) {
        if (m_respond) {
            m_respond(UpdateAvailableDialog::DontInstall);
        }
        m_respond = std::move(respond);
        m_updateVersion = versionName;
        m_updateNotes = StringUtils::htmlListPatch(markdownToHTML(notes));
        emit updateStateChanged();
        emit updateOffered(versionName);
    };
}

LauncherInfo* LauncherInfo::create(QQmlEngine*, QJSEngine*)
{
    if (!s_launcherInfo) {
        s_launcherInfo = new LauncherInfo(APPLICATION);
    }
    QJSEngine::setObjectOwnership(s_launcherInfo, QJSEngine::CppOwnership);
    return s_launcherInfo;
}

QString LauncherInfo::name() const
{
    return BuildConfig.LAUNCHER_DISPLAYNAME;
}
QString LauncherInfo::version() const
{
    return BuildConfig.printableVersionString();
}
QString LauncherInfo::platform() const
{
    return BuildConfig.BUILD_PLATFORM;
}
QString LauncherInfo::commit() const
{
    return BuildConfig.GIT_COMMIT;
}
QString LauncherInfo::buildDate() const
{
    return BuildConfig.BUILD_DATE;
}
QString LauncherInfo::channel() const
{
    return BuildConfig.VERSION_CHANNEL;
}
QString LauncherInfo::gitUrl() const
{
    return BuildConfig.LAUNCHER_GIT;
}
QString LauncherInfo::copyright() const
{
    return BuildConfig.LAUNCHER_COPYRIGHT;
}
QString LauncherInfo::qtVersion() const
{
    return QString::fromLatin1(qVersion());
}

QString LauncherInfo::buildInfo() const
{
    QStringList lines;
    lines << QString("%1 %2").arg(name(), version());
    if (!platform().isEmpty())
        lines << QString("Platform: %1").arg(platform());
    if (!commit().isEmpty())
        lines << QString("Commit: %1").arg(commit());
    if (!buildDate().isEmpty())
        lines << QString("Build date: %1").arg(buildDate());
    if (!channel().isEmpty())
        lines << QString("Channel: %1").arg(channel());
    lines << QString("Qt: %1").arg(qtVersion());
    lines << QString("OS: %1 (%2)").arg(QSysInfo::prettyProductName(), QSysInfo::currentCpuArchitecture());
    return lines.join('\n');
}

QVariantMap LauncherInfo::links() const
{
    return { { "help", BuildConfig.HELP_URL.arg("") },
             { "bugs", BuildConfig.BUG_TRACKER_URL },
             { "discord", BuildConfig.DISCORD_URL },
             { "matrix", BuildConfig.MATRIX_URL },
             { "reddit", BuildConfig.SUBREDDIT_URL },
             { "translations", BuildConfig.TRANSLATIONS_URL },
             { "git", BuildConfig.LAUNCHER_GIT } };
}

QString LauncherInfo::creditsHtml() const
{
    QFile dataFile(":/documents/credits.html");
    if (!dataFile.open(QIODevice::ReadOnly)) {
        return {};
    }
    QString content = QString::fromUtf8(dataFile.readAll());
    content = content.arg(tr("%1 Developers").arg(BuildConfig.LAUNCHER_DISPLAYNAME), tr("MultiMC Developers"), tr("With special thanks to"));
    return StringUtils::htmlListPatch(content);
}

QString LauncherInfo::licenseHtml() const
{
    QFile dataFile(":/documents/COPYING.md");
    if (!dataFile.open(QIODevice::ReadOnly)) {
        return {};
    }
    return StringUtils::htmlListPatch(markdownToHTML(dataFile.readAll()));
}

bool LauncherInfo::updaterEnabled() const
{
    return APPLICATION->updaterEnabled() && APPLICATION->updater() != nullptr;
}

void LauncherInfo::checkForUpdates()
{
    APPLICATION->triggerUpdateCheck();
    emit updateStateChanged();
}

void LauncherInfo::respondToUpdate(const QString& action)
{
    if (!m_respond) {
        return;
    }
    auto respond = std::move(m_respond);
    m_respond = nullptr;
    emit updateStateChanged();
    if (action == "install") {
        respond(UpdateAvailableDialog::Install);
    } else if (action == "skip") {
        respond(UpdateAvailableDialog::Skip);
    } else {
        respond(UpdateAvailableDialog::DontInstall);
    }
}

// ---------------------------------------------------------------- news

NewsFeed::NewsFeed(QObject* parent) : QObject(parent)
{
    if (!enabled()) {
        return;
    }
    m_checker = new NewsChecker(APPLICATION->network(), BuildConfig.NEWS_RSS_URL);
    connect(m_checker, &NewsChecker::newsLoaded, this, [this] {
        m_error.clear();
        emit changed();
    });
    connect(m_checker, &NewsChecker::newsLoadingFailed, this, [this](const QString& error) {
        m_error = error;
        emit changed();
    });
    QMetaObject::invokeMethod(this, &NewsFeed::reload, Qt::QueuedConnection);
}

NewsFeed::~NewsFeed()
{
    delete m_checker;
}

bool NewsFeed::enabled() const
{
    return !BuildConfig.NEWS_RSS_URL.isEmpty();
}

QString NewsFeed::moreUrl() const
{
    return BuildConfig.NEWS_OPEN_URL;
}

bool NewsFeed::loading() const
{
    return m_checker && m_checker->isLoadingNews();
}

QVariantList NewsFeed::entries() const
{
    QVariantList out;
    if (!m_checker) {
        return out;
    }
    for (const auto& entry : m_checker->getNewsEntries()) {
        out << QVariantMap{ { "title", entry->title }, { "html", StringUtils::htmlListPatch(entry->content) }, { "link", entry->link } };
    }
    return out;
}

void NewsFeed::reload()
{
    if (!m_checker) {
        return;
    }
    m_error.clear();
    m_checker->reloadNews();
    emit changed();
}
