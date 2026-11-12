import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Blocked mods (CurseForge/FTB/ATL files that can't be downloaded by third-party launchers).
// The user downloads them in the browser; watched folders are scanned and files are matched by hash.
PDialog {
    id: dlg
    property var req: ({})
    readonly property NIBlockedModsModel mods: req.model || null
    property bool result: false
    signal answered(bool proceed)

    title: req.title || qsTr("Blocked mods found")
    iconName: "triangle-alert"
    maxWidth: 680
    closePolicy: Popup.CloseOnEscape
    onOpened: { result = false; if (mods) mods.start() }
    onClosed: answered(result)

    Connections {
        target: dlg.mods
        function onChanged() { if (dlg.mods.allMatched && dlg.visible) { dlg.result = true; dlg.close() } }
    }

    Text {
        Layout.fillWidth: true
        text: (dlg.req.text || "") + "<br><br>" + qsTr("Your downloads folder and the global mods folder are checked automatically. You can also drop the downloaded files here or add another folder to watch.")
        color: Theme.textMuted; wrapMode: Text.Wrap; font.pixelSize: Theme.fontMd; textFormat: Text.StyledText
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        Text {
            Layout.fillWidth: true
            text: dlg.mods ? qsTr("%1 of %2 found").arg(dlg.mods.matchedCount).arg(dlg.mods.total) : ""
            color: Theme.text; font.weight: Font.DemiBold
        }
        PButton { size: "sm"; iconName: "external-link"; text: qsTr("Open missing"); onClicked: dlg.mods.openMissing() }
        PButton { size: "sm"; iconName: "folder-open"; text: qsTr("Add folder"); onClicked: folderDialog.open() }
    }
    PProgressBar { Layout.fillWidth: true; value: dlg.mods && dlg.mods.total ? dlg.mods.matchedCount / dlg.mods.total : 0 }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.contentHeight + 12, 300)
        radius: Theme.radius; color: Theme.surfaceAlt
        border.color: drop.containsDrag ? Theme.accent : Theme.border
        border.width: drop.containsDrag ? 2 : 1
        ListView {
            id: list
            anchors.fill: parent; anchors.margins: 6
            clip: true
            model: dlg.mods
            spacing: 2
            delegate: Rectangle {
                id: row
                required property int index
                required property string name
                required property string websiteUrl
                required property bool matched
                required property string localPath
                width: list.width; height: 44; radius: Theme.radiusSm
                color: rowHover.hovered ? Theme.surfaceHover : "transparent"
                HoverHandler { id: rowHover }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                    spacing: 10
                    Icon { name: row.matched ? "circle-check" : "circle-alert"; color: row.matched ? Theme.success : Theme.warning; size: 16 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: row.name; color: Theme.text; font.pixelSize: Theme.fontMd; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        Text { text: row.matched ? qsTr("Found at %1").arg(row.localPath) : qsTr("Not found yet"); color: row.matched ? Theme.success : Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    }
                    IconButton { iconName: "external-link"; tip: qsTr("Open download page"); onClicked: dlg.mods.openUrl(row.index) }
                }
            }
            ScrollBar.vertical: PScrollBar {}
        }
        DropArea {
            id: drop
            anchors.fill: parent
            onDropped: (ev) => { if (ev.hasUrls) dlg.mods.addFiles(ev.urls) }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: dlg.mods && dlg.mods.watchedFolders.length > 0
        text: dlg.mods ? qsTr("Watching: %1").arg(dlg.mods.watchedFolders.join(", ")) : ""
        color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Select the folder where you downloaded the mods")
        onAccepted: dlg.mods.addFolder(selectedFolder)
    }

    buttons: [
        PButton { text: qsTr("Cancel install"); onClicked: { dlg.result = false; dlg.close() } },
        PButton {
            text: dlg.mods && dlg.mods.allMatched ? qsTr("Continue") : qsTr("Skip missing")
            variant: "primary"
            onClicked: { dlg.result = true; dlg.close() }
        }
    ]
}
