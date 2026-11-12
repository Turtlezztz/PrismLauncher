import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Log file browser (classic OtherLogsPage): pick a file, view, search, copy, upload, delete, clean up.
// mode "files" = an instance's logs, "launcher" = the launcher's own logs (first entry is the live log).
ColumnLayout {
    id: root
    property string mode: "files"
    property string instanceId: ""
    property string uploadName: qsTr("Log")
    readonly property bool launcherMode: mode === "launcher"
    readonly property var entries: launcherMode ? [""].concat(logModel.files) : logModel.files
    spacing: Theme.spacing

    LogViewModel { id: logModel; mode: root.mode; instanceId: root.instanceId }
    LogUploadDialog { id: uploader; log: logModel }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        PComboBox {
            id: picker
            Layout.preferredWidth: 340
            Layout.minimumWidth: 200
            model: root.entries.map(function(f) { return f.length ? f : qsTr("Current log (live)") })
            currentIndex: Math.max(0, root.entries.indexOf(logModel.currentFile))
            enabled: root.entries.length > 0
            displayText: root.entries.length ? currentText : qsTr("No log files")
            onActivated: (i) => logModel.currentFile = root.entries[i]
        }
        PButton {
            size: "sm"
            iconName: logModel.live ? "trash-2" : "refresh-cw"
            text: logModel.live ? qsTr("Clear") : qsTr("Reload")
            enabled: logModel.live ? logModel.count > 0 : logModel.currentFile.length > 0
            onClicked: logModel.live ? logModel.clear() : logModel.reload()
        }
        Item { Layout.fillWidth: true }
        IconButton { iconName: "folder-open"; tip: qsTr("Open logs folder"); onClicked: logModel.openLogsFolder() }
        PButton {
            size: "sm"; iconName: "trash-2"; text: qsTr("Delete"); variant: "ghost"
            enabled: !logModel.live && logModel.currentFile.length > 0
            onClicked: {
                var f = logModel.currentFile
                Dialogs.confirm({ title: qsTr("Delete “%1”?").arg(f),
                                  text: qsTr("This may be permanent and it will be gone from the logs folder."),
                                  confirmText: qsTr("Delete"), danger: true }, function(ok) {
                    if (!ok) return
                    var err = logModel.deleteCurrentFile()
                    if (err.length) Toasts.error(err); else Toasts.show(qsTr("Deleted %1").arg(f), "info")
                })
            }
        }
        PButton {
            size: "sm"; iconName: "sparkles"; text: qsTr("Clean up"); variant: "ghost"
            enabled: logModel.files.length > 0
            onClicked: {
                var files = logModel.files
                Dialogs.confirm({ title: qsTr("Delete all log files?"),
                                  text: files.length > 5 ? qsTr("All %1 log files will be deleted.").arg(files.length)
                                                         : qsTr("These files will be deleted:<br>%1").arg(files.join("<br>")),
                                  confirmText: qsTr("Delete all"), danger: true }, function(ok) {
                    if (!ok) return
                    var failed = logModel.cleanFiles()
                    if (failed.length) Dialogs.message({ title: qsTr("Couldn't delete some files"), text: failed.join("<br>"), kind: "error" })
                    else Toasts.success(qsTr("Log files deleted"))
                })
            }
        }
    }

    LogToolbar {
        Layout.fillWidth: true
        panel: panel
        log: logModel
        showFollow: logModel.live
        PButton {
            size: "sm"; iconName: "copy"; text: qsTr("Copy"); enabled: logModel.hasSource && logModel.count > 0
            onClicked: { logModel.copyAll(); Toasts.success(qsTr("Log copied to the clipboard")) }
        }
        PButton {
            size: "sm"; iconName: "upload"; text: qsTr("Upload"); busy: logModel.uploading
            enabled: logModel.hasSource && logModel.count > 0 && !logModel.uploading
            onClicked: uploader.ask(logModel.currentFile.length ? logModel.currentFile : root.uploadName)
        }
    }

    LogViewPanel {
        id: panel
        Layout.fillWidth: true
        Layout.fillHeight: true
        log: logModel
        emptyIcon: "file-text"
        emptyTitle: root.entries.length ? qsTr("Empty log") : qsTr("No log files")
        emptyText: root.entries.length ? "" : qsTr("Log files will show up here once the game has written some.")
    }
}
