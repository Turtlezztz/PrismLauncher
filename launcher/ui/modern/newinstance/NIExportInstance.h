#pragma once

#include <QModelIndex>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>

#include "FileIgnoreProxy.h"

#include "TaskBridge.h"
class QFileSystemModel;
class MinecraftInstance;

/// FileIgnoreProxy with QML roles (single column): fileName, checkState (0/1/2), isDir
class NIFileTreeModel : public FileIgnoreProxy {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by NIExportInstance")
   public:
    enum Roles { NameRole = Qt::UserRole + 700, CheckRole, IsDirRole, SizeRole };
    NIFileTreeModel(const QString& root, QObject* parent);
    int columnCount(const QModelIndex& parent = {}) const override;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;

    Q_INVOKABLE void toggle(const QModelIndex& index);
};

/**
 * Backend of ExportInstanceDialog.qml: classic ExportInstanceDialog (zip) and ExportPackDialog (Modrinth .mrpack / CurseForge zip).
 * Include/exclude choices are shared with the classic dialogs through the instance's .packignore file.
 */
class NIExportInstance : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString instanceId READ instanceId WRITE setInstanceId NOTIFY instanceChanged)
    Q_PROPERTY(QString instanceName READ instanceName NOTIFY instanceChanged)
    /// zip | modrinth | curseforge
    Q_PROPERTY(QString format READ format WRITE setFormat NOTIFY formatChanged)
    Q_PROPERTY(NIFileTreeModel* files READ files NOTIFY formatChanged)
    Q_PROPERTY(QModelIndex rootIndex READ rootIndex NOTIFY formatChanged)
    // pack options (persisted in the instance settings like the classic dialog)
    Q_PROPERTY(QString packName READ packName WRITE setPackName NOTIFY optionsChanged)
    Q_PROPERTY(QString packVersion READ packVersion WRITE setPackVersion NOTIFY optionsChanged)
    Q_PROPERTY(QString summary READ summary WRITE setSummary NOTIFY optionsChanged)
    Q_PROPERTY(QString author READ author WRITE setAuthor NOTIFY optionsChanged)
    Q_PROPERTY(bool optionalFiles READ optionalFiles WRITE setOptionalFiles NOTIFY optionsChanged)
    Q_PROPERTY(bool recommendedMemoryEnabled READ recommendedMemoryEnabled WRITE setRecommendedMemoryEnabled NOTIFY optionsChanged)
    Q_PROPERTY(int recommendedMemory READ recommendedMemory WRITE setRecommendedMemory NOTIFY optionsChanged)

   public:
    explicit NIExportInstance(QObject* parent = nullptr);
    ~NIExportInstance() override;

    QString instanceId() const { return m_id; }
    void setInstanceId(const QString& id);
    QString instanceName() const;
    QString format() const { return m_format; }
    void setFormat(const QString& f);
    NIFileTreeModel* files() const { return m_proxy; }
    QModelIndex rootIndex() const { return m_rootIndex; }

    QString packName() const { return m_packName; }
    void setPackName(const QString& v) { m_packName = v; emit optionsChanged(); }
    QString packVersion() const { return m_packVersion; }
    void setPackVersion(const QString& v) { m_packVersion = v; emit optionsChanged(); }
    QString summary() const { return m_summary; }
    void setSummary(const QString& v) { m_summary = v; emit optionsChanged(); }
    QString author() const { return m_author; }
    void setAuthor(const QString& v) { m_author = v; emit optionsChanged(); }
    bool optionalFiles() const { return m_optionalFiles; }
    void setOptionalFiles(bool v) { m_optionalFiles = v; emit optionsChanged(); }
    bool recommendedMemoryEnabled() const { return m_ramEnabled; }
    void setRecommendedMemoryEnabled(bool v) { m_ramEnabled = v; emit optionsChanged(); }
    int recommendedMemory() const { return m_ram; }
    void setRecommendedMemory(int v) { m_ram = v; emit optionsChanged(); }

    /// suggested output file name (without folder)
    Q_INVOKABLE QString suggestedFileName() const;
    Q_INVOKABLE QUrl suggestedFolder() const;
    /// save options + ignore list (also done by exportTo)
    Q_INVOKABLE void saveSettings();
    /// start the export to the given file; returns a started TaskBridge or null
    Q_INVOKABLE TaskBridge* exportTo(const QUrl& file);

   signals:
    void instanceChanged();
    void formatChanged();
    void optionsChanged();
    void error(const QString& message);

   private:
    void rebuildModel();
    QString ignoreFileName() const;
    MinecraftInstance* instance() const;

    QString m_id;
    QString m_format = "zip";
    QFileSystemModel* m_fsModel = nullptr;
    NIFileTreeModel* m_proxy = nullptr;
    QModelIndex m_rootIndex;

    QString m_packName, m_packVersion, m_summary, m_author;
    bool m_optionalFiles = true;
    bool m_ramEnabled = false;
    int m_ram = 4096;
};
