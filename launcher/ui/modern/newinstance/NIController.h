#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>
#include <memory>

class InstanceTask;
class TaskBridge;

/**
 * State shared by all "new instance" sources (the QML twin of classic NewInstanceDialog):
 * every source (vanilla, import, modpack browsers) hands the controller a ready-to-run InstanceTask plus a suggested
 * name / version / icon, and the page's footer calls create() with the user's name, group, folder and icon.
 */
class NIController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString suggestedName READ suggestedName NOTIFY suggestionChanged)
    Q_PROPERTY(QString suggestedVersion READ suggestedVersion NOTIFY suggestionChanged)
    Q_PROPERTY(bool hasTask READ hasTask NOTIFY suggestionChanged)
    /// icon chosen by the user (IconPicker) — "default" unless changed
    Q_PROPERTY(QString iconKey READ iconKey WRITE setIconKey NOTIFY iconChanged)
    /// image source previewing the icon that will be used (picked key or a modpack logo)
    Q_PROPERTY(QString iconSource READ iconSource NOTIFY iconChanged)
    Q_PROPERTY(QVariantList instanceDirs READ instanceDirs NOTIFY instanceDirsChanged)
    Q_PROPERTY(QString lastDir READ lastDir CONSTANT)
    Q_PROPERTY(QString lastGroup READ lastGroup CONSTANT)
    Q_PROPERTY(bool templateAvailable READ templateAvailable CONSTANT)

   public:
    explicit NIController(QObject* parent = nullptr);
    ~NIController() override;

    QString suggestedName() const { return m_suggestedName; }
    QString suggestedVersion() const { return m_suggestedVersion; }
    bool hasTask() const { return m_task != nullptr; }
    QString iconKey() const { return m_iconKey; }
    void setIconKey(const QString& key);
    QString iconSource() const;
    QVariantList instanceDirs() const { return m_dirs; }
    QString lastDir() const;
    QString lastGroup() const;
    bool templateAvailable() const;

    /// takes ownership of task (may be null to clear)
    void setSuggestedPack(const QString& name = {}, const QString& version = {}, InstanceTask* task = nullptr);
    void setSuggestedIconFromFile(const QString& path, const QString& name);
    void clearSuggestedIcon();

    Q_INVOKABLE void clear() { setSuggestedPack(); }
    Q_INVOKABLE void refreshInstanceDirs();
    /// Runs the pending task through InstanceList::wrapInstanceTask. Returns a started TaskBridge whose resultId becomes
    /// the new instance id, or null (and emits error) when nothing can be created.
    Q_INVOKABLE TaskBridge* create(const QString& name, const QString& group, const QString& dir, bool copyTemplate);

   signals:
    void suggestionChanged();
    void iconChanged();
    void instanceDirsChanged();
    void error(const QString& message);

   private:
    std::unique_ptr<InstanceTask> m_task;
    QString m_suggestedName;
    QString m_suggestedVersion;
    QString m_iconKey = "default";
    bool m_importIcon = false;
    QString m_importIconPath;
    QString m_importIconName;
    QVariantList m_dirs;
};
