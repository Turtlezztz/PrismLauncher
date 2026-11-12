#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <vector>

#include "Version.h"
#include "modplatform/CheckUpdateTask.h"
#include "modplatform/ModIndex.h"

class ResFolderModel;
class ResTaskHandle;
class Resource;
class ResourceFolderModel;
class MinecraftInstance;
class ConcurrentTask;
class ModrinthCheckUpdate;
class FlameCheckUpdate;

/**
 * Asynchronous port of the classic ResourceUpdateDialog flow:
 *   (ask provider for resources without metadata) -> generate metadata -> check updates
 *   -> (report failures) -> resolve dependencies -> review -> install.
 * QML drives it by watching `stage` and showing the current `task` (ResTaskDialog).
 */
class ResUpdateFlow : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString stage READ stage NOTIFY stageChanged)
    Q_PROPERTY(ResTaskHandle* task READ task NOTIFY stageChanged)
    Q_PROPERTY(QStringList missingMetadata READ missingMetadata NOTIFY stageChanged)
    Q_PROPERTY(QVariantList failures READ failures NOTIFY stageChanged)
    Q_PROPERTY(QVariantList updates READ updates NOTIFY stageChanged)
    Q_PROPERTY(QString message READ message NOTIFY stageChanged)
    Q_PROPERTY(QString resourceLabel READ resourceLabel NOTIFY stageChanged)

   public:
    explicit ResUpdateFlow(QObject* parent = nullptr);
    ~ResUpdateFlow() override;

    /// stages: idle | askProvider | running | metadataFailed | checkFailed | review | done | error
    QString stage() const { return m_stage; }
    ResTaskHandle* task() const { return m_task; }
    QStringList missingMetadata() const { return m_missingNames; }
    QVariantList failures() const { return m_failureList; }
    QVariantList updates() const;
    QString message() const { return m_message; }
    QString resourceLabel() const { return m_label; }

    /// releaseTypes: [] = use the global setting, otherwise e.g. ["release","beta"]
    Q_INVOKABLE void start(ResFolderModel* folder, bool includeDeps, const QStringList& releaseTypes = {});
    /// For resources without metadata: provider "modrinth" | "curseforge" | "skip"
    Q_INVOKABLE void chooseProvider(const QString& provider, bool tryOthers);
    /// After failures were reported: continue (optionally disabling the unavailable mods) or cancel
    Q_INVOKABLE void proceed(bool disableUnavailable = false);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE ResTaskHandle* install(const QStringList& excludedKeys);

   signals:
    void stageChanged();
    void notice(const QString& message, const QString& kind);
    void installed();

   private:
    void setStage(const QString& s);
    void runTask(Task::Ptr task, const QString& title, std::function<void(bool ok)> next);
    void onMetadataEnsured(Resource* r);
    void onMetadataFailed(Resource* r, bool tryOthers, ModPlatform::ResourceProvider first);
    void generateMetadata(ModPlatform::ResourceProvider provider, bool tryOthers);
    void checkUpdates();
    void afterCheck();
    void resolveDependencies();
    void finishReview();

    QString m_stage = "idle";
    QString m_message;
    QString m_label;
    QPointer<ResTaskHandle> m_task;
    QPointer<ResourceFolderModel> m_model;
    QPointer<MinecraftInstance> m_instance;
    bool m_includeDeps = false;
    std::vector<ModPlatform::IndexedVersionType> m_releaseTypes;
    QList<ModPlatform::ModLoaderType> m_loadersList;
    std::vector<Version> m_mcVersions;

    QList<Resource*> m_candidates;
    QList<Resource*> m_noMetadata;
    QStringList m_missingNames;
    QList<Resource*> m_modrinthToUpdate;
    QList<Resource*> m_flameToUpdate;
    QList<Resource*> m_metadataTmp;
    shared_qobject_ptr<ConcurrentTask> m_secondTry;
    QList<std::pair<Resource*, QString>> m_failedMetadata;
    QList<std::tuple<Resource*, QString, QUrl>> m_failedCheck;
    QVariantList m_failureList;
    shared_qobject_ptr<ModrinthCheckUpdate> m_modrinthCheck;
    shared_qobject_ptr<FlameCheckUpdate> m_flameCheck;
    QList<std::shared_ptr<GetModDependenciesTask::PackDependency>> m_depsSeed;

    struct Item {
        CheckUpdateTask::Update update;
        QStringList requiredBy;
        bool dependency = false;
    };
    QList<Item> m_items;
};
