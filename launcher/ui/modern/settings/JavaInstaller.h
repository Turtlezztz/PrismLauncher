#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariant>

#include "java/JavaMetadata.h"
#include "meta/Version.h"
#include "tasks/Task.h"

/**
 * Backend of the "Install Java" dialog (classic Java::InstallDialog):
 * pick a vendor (Mojang / Adoptium / Azul / IBM), a major version and a concrete build, then download it
 * into the launcher's managed Java folder.
 *
 *   JavaInstaller { id: inst; instanceId: "" }   // instanceId optional: recommends the majors that instance needs
 */
class JavaInstaller : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList providers READ providers CONSTANT)
    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY providerChanged)
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceIdChanged)
    Q_PROPERTY(bool recommendedOnly READ recommendedOnly WRITE setRecommendedOnly NOTIFY majorsChanged)
    Q_PROPERTY(QStringList recommendedMajors READ recommendedMajors NOTIFY majorsChanged)

    Q_PROPERTY(QVariantList majors READ majors NOTIFY majorsChanged)
    Q_PROPERTY(bool loadingMajors READ loadingMajors NOTIFY majorsChanged)
    Q_PROPERTY(QString majorsError READ majorsError NOTIFY majorsChanged)
    Q_PROPERTY(QString major READ major WRITE setMajor NOTIFY majorChanged)

    Q_PROPERTY(QVariantList builds READ builds NOTIFY buildsChanged)
    Q_PROPERTY(bool loadingBuilds READ loadingBuilds NOTIFY buildsChanged)
    Q_PROPERTY(QString buildsError READ buildsError NOTIFY buildsChanged)
    Q_PROPERTY(int selectedBuild READ selectedBuild WRITE setSelectedBuild NOTIFY selectedBuildChanged)

    Q_PROPERTY(bool installing READ installing NOTIFY installStateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY installStateChanged)
    Q_PROPERTY(QString status READ status NOTIFY installStateChanged)

   public:
    explicit JavaInstaller(QObject* parent = nullptr);
    ~JavaInstaller() override;

    QVariantList providers() const;
    QString provider() const { return m_provider; }
    void setProvider(const QString& uid);
    QString instanceId() const { return m_instanceId; }
    void setInstanceId(const QString& id);
    bool recommendedOnly() const { return m_recommendedOnly; }
    void setRecommendedOnly(bool on);
    QStringList recommendedMajors() const { return m_recommended; }

    QVariantList majors() const;
    bool loadingMajors() const { return m_loadingMajors; }
    QString majorsError() const { return m_majorsError; }
    QString major() const { return m_major; }
    void setMajor(const QString& major);

    QVariantList builds() const;
    bool loadingBuilds() const { return m_loadingBuilds; }
    QString buildsError() const { return m_buildsError; }
    int selectedBuild() const { return m_selectedBuild; }
    void setSelectedBuild(int index);

    bool installing() const { return m_task != nullptr; }
    double progress() const { return m_progress; }
    QString status() const { return m_status; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void install();
    Q_INVOKABLE void cancel();

   signals:
    void providerChanged();
    void instanceIdChanged();
    void majorsChanged();
    void majorChanged();
    void buildsChanged();
    void selectedBuildChanged();
    void installStateChanged();
    /// ok=false with an empty message means the user cancelled
    void installFinished(bool ok, const QString& message);

   private:
    void loadMajors(bool force);
    void loadBuilds(bool force);
    void computeRecommended();
    static QString majorName(const QString& version);

    QString m_provider = "net.minecraft.java";
    QString m_instanceId;
    bool m_recommendedOnly = true;
    QStringList m_recommended;

    QList<Meta::Version::Ptr> m_majorList;
    bool m_loadingMajors = false;
    QString m_majorsError;
    QString m_major;
    Task::Ptr m_majorsTask;

    QList<Java::MetadataPtr> m_builds;
    bool m_loadingBuilds = false;
    QString m_buildsError;
    int m_selectedBuild = -1;
    Task::Ptr m_buildsTask;

    Task::Ptr m_task;
    double m_progress = 0;
    QString m_status;
    QString m_finalPath;
};
