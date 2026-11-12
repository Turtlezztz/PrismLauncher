import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic LauncherPage: updates, UI behaviour, folders, mods, console and network.
SetPageBase {
    id: page
    title: qsTr("Launcher")
    subtitle: qsTr("Folders, behaviour, downloads and updates.")

    // ---------------------------------------------------------------- updates
    SetSection {
        title: qsTr("Updates"); iconName: "download"
        SetRow {
            visible: SettingsBackend.updaterAvailable
            label: qsTr("Check for updates automatically")
            PSwitch {
                checked: SettingsBackend.updaterAutoCheck()
                onToggled: SettingsBackend.setUpdaterAutoCheck(checked)
            }
        }
        SetRow {
            visible: SettingsBackend.updaterAvailable
            label: qsTr("How often?")
            description: qsTr("Set to 0 to only check on launch.")
            PSpinBox {
                from: 0; to: 168; suffix: qsTr("hours")
                value: SettingsBackend.updaterIntervalHours()
                onValueModified: SettingsBackend.setUpdaterIntervalHours(value)
            }
        }
        SetRow {
            label: SettingsBackend.updaterAvailable ? qsTr("Check now") : qsTr("Automatic updates")
            description: SettingsBackend.updaterAvailable ? qsTr("You are running %1.").arg(LauncherInfo.version)
                         : qsTr("Updates for this build are managed outside the launcher (package manager or a build without the updater). You are running %1.").arg(LauncherInfo.version)
            PButton {
                visible: SettingsBackend.updaterAvailable
                text: qsTr("Check for updates"); iconName: "refresh-cw"
                onClicked: LauncherInfo.checkForUpdates()
            }
        }
    }

    // ---------------------------------------------------------------- user interface
    SetSection {
        title: qsTr("User interface"); iconName: "sliders-horizontal"
        SetRow {
            label: qsTr("Instance sorting")
            description: qsTr("How instances are ordered in the library.")
            keywords: "sort order name last launched playtime"
            SegmentedControl {
                id: sortSeg
                function current() { return page.store ? page.store.getString("InstSortMode") || "Name" : "Name" }
                options: [ { value: "Name", text: qsTr("Name") }, { value: "LastLaunch", text: qsTr("Last launched") }, { value: "Playtime", text: qsTr("Time played") } ]
                value: current()
                onActivated: v => { page.store.set("InstSortMode", v); value = Qt.binding(current) }
            }
        }
        SetRow {
            label: qsTr("Instance renaming")
            description: qsTr("What to do with the instance folder when an instance is renamed.")
            keywords: "rename folder directory"
            SetCombo {
                key: "InstRenamingMode"
                options: [ { value: "AskEverytime", text: qsTr("Ask what to do") }, { value: "PhysicalDir", text: qsTr("Always rename the folder") }, { value: "MetadataOnly", text: qsTr("Never rename the folder") } ]
            }
        }
        SetRow {
            label: qsTr("Open instance details on double-click")
            description: qsTr("Double-clicking an instance opens it instead of launching it.")
            SetSwitch { key: "EditInstanceOnDoubleClick" }
        }
        SetRow {
            label: qsTr("Replace toolbar with menubar")
            description: qsTr("Classic interface only. The menubar is more friendly for keyboard-driven interaction.")
            SetSwitch { key: "MenuBarInsteadOfToolBar" }
        }
    }

    // ---------------------------------------------------------------- folders
    SetSection {
        title: qsTr("Folders"); iconName: "folder"
        description: qsTr("Relative paths are resolved from the launcher's data folder.")
        SetRow {
            stacked: true; label: qsTr("Instances"); keywords: "instance folder directory"
            SetPathField { key: "InstanceDir"; dialogTitle: qsTr("Instance Folder"); validate: p => SettingsBackend.instanceDirWarning(p) }
        }
        SetRow {
            id: extraDirs
            stacked: true
            label: qsTr("Additional instance folders")
            description: qsTr("Instances in these folders are shown in the library too.")
            keywords: "extra instance folders directories"
            readonly property var dirs: page.store ? page.store.getList("AdditionalInstanceDirs") : []
            ColumnLayout {
                width: parent.width
                spacing: 6
                Repeater {
                    model: extraDirs.dirs
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.radius
                        color: Theme.surfaceAlt
                        border.color: Theme.border
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4
                            Icon { name: "folder"; size: 15; color: Theme.textMuted }
                            Text { text: modelData; color: Theme.text; font.pixelSize: Theme.fontMd; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            IconButton { iconName: "external-link"; tip: qsTr("Open"); size: 28; onClicked: App.openPath(modelData) }
                            IconButton {
                                iconName: "trash-2"; tip: qsTr("Remove"); size: 28
                                onClicked: { var l = extraDirs.dirs.slice(); l.splice(index, 1); page.store.set("AdditionalInstanceDirs", l) }
                            }
                        }
                    }
                }
                PButton {
                    text: qsTr("Add folder"); iconName: "plus"; size: "sm"
                    onClicked: {
                        var raw = SettingsBackend.browseDirectory(qsTr("Additional Instance Folder"), "")
                        if (!raw.length || !SettingsBackend.directoryExists(raw)) return
                        var dir = SettingsBackend.normalizePath(raw)
                        if (dir === SettingsBackend.normalizePath(page.store.getString("InstanceDir"))) {
                            Dialogs.message({ title: qsTr("Duplicate directory"), text: qsTr("This is already your primary instance directory."), kind: "warning" }); return
                        }
                        if (extraDirs.dirs.indexOf(dir) >= 0) {
                            Dialogs.message({ title: qsTr("Duplicate directory"), text: qsTr("This directory has already been added."), kind: "warning" }); return
                        }
                        var add = function() { var l = extraDirs.dirs.slice(); l.push(dir); page.store.set("AdditionalInstanceDirs", l) }
                        var w = SettingsBackend.instanceDirWarning(raw)
                        if (w.length) Dialogs.confirm({ title: qsTr("Use this folder?"), text: w, confirmText: qsTr("Use anyway") }, function(ok) { if (ok) add() })
                        else add()
                    }
                }
            }
        }
        SetRow { stacked: true; label: qsTr("Mods (quick access)"); keywords: "central mods folder"
            SetPathField { key: "CentralModsDir"; dialogTitle: qsTr("Mods Folder") } }
        SetRow { stacked: true; label: qsTr("Instance icons"); keywords: "icons folder"
            SetPathField { key: "IconsDir"; dialogTitle: qsTr("Icons Folder") } }
        SetRow { stacked: true; label: qsTr("Auto-downloaded Java")
            description: qsTr("Folder where the launcher stores automatically downloaded Java versions. Do NOT set this to your system Java installation.")
            keywords: "java folder"
            SetPathField { key: "JavaDir"; dialogTitle: qsTr("Java Folder") } }
        SetRow { stacked: true; label: qsTr("Skins"); keywords: "skins folder"
            SetPathField { key: "SkinsDir"; dialogTitle: qsTr("Skins Folder") } }
        SetRow { stacked: true; label: qsTr("Downloads")
            description: qsTr("Where the launcher looks for manually downloaded files, e.g. blocked CurseForge mods.")
            keywords: "downloads folder"
            SetPathField { key: "DownloadsDir"; dialogTitle: qsTr("Downloads Folder") } }
        SetRow { stacked: true; label: qsTr("Instance template")
            description: qsTr("Folder that may get copied to new instances on creation (can be toggled per instance). Useful for options.txt.")
            keywords: "template folder"
            SetPathField { key: "TemplateDir"; dialogTitle: qsTr("Instance Template Folder") } }
    }

    // ---------------------------------------------------------------- mods
    SetSection {
        title: qsTr("Mods and modpacks"); iconName: "puzzle"
        SetRow {
            label: qsTr("Check subfolders for blocked mods")
            description: qsTr("Also search sub folders of the downloads folder when looking for resources (e.g. blocked mods on CurseForge).")
            SetSwitch { key: "DownloadsDirWatchRecursive" }
        }
        SetRow {
            label: qsTr("Move blocked mods instead of copying them")
            SetSwitch { key: "MoveModsFromDownloadsDir" }
        }
        SetRow {
            id: metaRow
            label: qsTr("Keep track of mod metadata")
            description: page.store && page.store.getBool("ModMetadataDisabled")
                         ? "<font color='" + Theme.warning + "'>" + qsTr("Warning: disabling mod metadata may also disable some QoL features, such as mod updating!") + "</font>"
                         : qsTr("Store version information provided by mod providers (like Modrinth or CurseForge) for mods.")
            SetSwitch { key: "ModMetadataDisabled"; invert: true }
        }
        SetRow {
            label: qsTr("Install dependencies automatically")
            description: qsTr("Automatically detect, install, and update mod dependencies.")
            SetSwitch { key: "ModDependenciesDisabled"; invert: true }
        }
        SetRow {
            label: qsTr("Detect and show mod incompatibilities (experimental)")
            description: qsTr("Currently this just shows mods which are not marked as compatible with the current Minecraft version.")
            SetSwitch { key: "ShowModIncompat" }
        }
        SetRow {
            label: qsTr("Suggest updating an existing instance during modpack installation")
            description: qsTr("When creating a new modpack instance, suggest updating an existing instance instead.")
            SetSwitch { key: "SkipModpackUpdatePrompt"; invert: true }
        }
        SetRow {
            label: qsTr("Mod update channel")
            description: qsTr("The preferred release channel when checking for mod updates.")
            keywords: "release beta alpha"
            PComboBox {
                id: channel
                implicitWidth: 240
                model: [ qsTr("All (Release, Beta, Alpha)"), qsTr("Release only"), qsTr("Release and Beta") ]
                readonly property var values: [ "[]", "[\"release\"]", "[\"release\", \"beta\"]" ]
                currentIndex: {
                    if (!page.store) return 0
                    var l = page.store.getJson("ModUpdateReleaseTypes", []).map(function(s) { return String(s).toLowerCase() })
                    if (l.length === 1 && l.indexOf("release") >= 0) return 1
                    if (l.length === 2 && l.indexOf("release") >= 0 && l.indexOf("beta") >= 0) return 2
                    return 0
                }
                onActivated: page.store.set("ModUpdateReleaseTypes", values[currentIndex])
            }
        }
    }

    // ---------------------------------------------------------------- instance creation
    SetSection {
        title: qsTr("Instance creation"); iconName: "plus"
        SetRow {
            label: qsTr("Download game files during instance creation")
            description: qsTr("Disable this to skip the initial download and fetch files when the instance is launched instead.")
            SetSwitch { key: "DownloadGameFilesDuringInstanceCreation" }
        }
    }

    // ---------------------------------------------------------------- console
    SetSection {
        title: qsTr("Console"); iconName: "terminal"
        SetRow {
            label: qsTr("Log history limit")
            description: qsTr("Maximum number of lines kept in the game log.")
            keywords: "lines console log"
            SetSpin { key: "ConsoleMaxLines"; from: 10000; to: 1000000; stepSize: 10000; suffix: qsTr("lines"); implicitWidth: 180 }
        }
        SetRow {
            label: qsTr("Stop logging when log overflows")
            SetSwitch { key: "ConsoleOverflowStop" }
        }
    }

    // ---------------------------------------------------------------- tasks & network
    SetSection {
        title: qsTr("Tasks and network"); iconName: "network"
        SetRow { label: qsTr("Concurrent task limit"); keywords: "parallel"
            SetSpin { key: "NumberOfConcurrentTasks"; from: 1; to: 99 } }
        SetRow { label: qsTr("Concurrent download limit"); keywords: "parallel downloads"
            SetSpin { key: "NumberOfConcurrentDownloads"; from: 1; to: 99 } }
        SetRow { label: qsTr("Network retry limit")
            SetSpin { key: "NetworkRetryLimit"; from: 0; to: 99 } }
        SetRow { label: qsTr("HTTP timeout"); description: qsTr("Seconds to wait until requests are terminated."); keywords: "timeout seconds"
            SetSpin { key: "RequestTimeout"; from: 0; to: 99; suffix: "s" } }
    }
}
