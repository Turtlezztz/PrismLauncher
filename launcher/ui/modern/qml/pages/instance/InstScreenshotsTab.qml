import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Instance → Screenshots (classic ScreenshotsPage): thumbnail grid, viewer, imgur upload, copy, rename, delete.
Item {
    id: tab
    property string instanceId
    readonly property alias model: shots

    ResScreenshotModel { id: shots; instanceId: tab.instanceId }

    function deleteSelected() {
        if (shots.selectedCount === 0) return
        Dialogs.confirm({
            title: shots.selectedCount > 1 ? qsTr("Delete %1 screenshots?").arg(shots.selectedCount) : qsTr("Delete screenshot?"),
            text: qsTr("Screenshots are moved to the trash when possible, otherwise they are gone forever."),
            confirmText: qsTr("Delete"), danger: true
        }, function(ok) { if (ok) shots.deleteSelected() })
    }
    function renameAt(row) {
        var cur = shots.get(row)
        Dialogs.prompt({ title: qsTr("Rename screenshot"), value: cur.baseName, confirmText: qsTr("Rename") }, function(v) {
            if (v === null) return
            var err = shots.rename(row, v)
            if (err.length) Toasts.error(err)
        })
    }
    function upload() {
        if (shots.selectedCount === 0) return
        Dialogs.confirm({
            title: qsTr("Upload to %1?").arg(shots.uploadHost),
            text: shots.selectedCount > 1 ? qsTr("You are about to upload %1 screenshots to %2. Double-check them for personal information.").arg(shots.selectedCount).arg(shots.uploadHost)
                                          : qsTr("You are about to upload the selected screenshot to %1. Double-check it for personal information.").arg(shots.uploadHost),
            confirmText: qsTr("Upload")
        }, function(ok) {
            if (!ok) return
            progress.track(shots.uploadSelected(), { closeOnSuccess: true }, function(success) {
                if (!success) return
                var link = shots.lastUploadLink()
                if (link.length) Dialogs.message({ title: qsTr("Upload finished"), text: qsTr("The <a href=\"%1\">link to the upload</a> has been copied to your clipboard.").arg(link) })
                else Toasts.error(qsTr("Upload failed: unknown error"))
            })
        })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Text { text: qsTr("%n screenshot(s)", "", shots.count) + (shots.selectedCount ? qsTr(" · %1 selected").arg(shots.selectedCount) : ""); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
            Item { Layout.fillWidth: true }
            PButton { size: "sm"; variant: "ghost"; visible: shots.selectedCount > 0; text: qsTr("Upload"); iconName: "upload"; enabled: !shots.uploading; onClicked: tab.upload() }
            PButton { size: "sm"; variant: "ghost"; visible: shots.selectedCount === 1; text: qsTr("Copy image"); iconName: "image"; onClicked: { shots.copyImage(grid.currentIndex); Toasts.success(qsTr("Image copied")) } }
            PButton { size: "sm"; variant: "ghost"; visible: shots.selectedCount > 0; text: qsTr("Copy file(s)"); iconName: "copy"; onClicked: { shots.copySelectedFiles(); Toasts.success(qsTr("Copied to clipboard")) } }
            PButton { size: "sm"; variant: "ghost"; visible: shots.selectedCount === 1; text: qsTr("Rename"); iconName: "pencil"; onClicked: tab.renameAt(grid.currentIndex) }
            PButton { size: "sm"; variant: "ghost"; visible: shots.selectedCount > 0; text: qsTr("Delete"); iconName: "trash-2"; onClicked: tab.deleteSelected() }
            PButton { text: qsTr("Open folder"); iconName: "folder-open"; onClicked: shots.openFolder() }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            clip: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: 8
                model: shots
                clip: true
                focus: true
                readonly property int columns: Math.max(1, Math.floor(width / 240))
                cellWidth: Math.floor(width / columns)
                cellHeight: Math.round(cellWidth * 9 / 16) + 34
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 300
                reuseItems: true
                currentIndex: -1
                ScrollBar.vertical: PScrollBar {}
                Keys.onPressed: (ev) => {
                    if (ev.key === Qt.Key_Delete) { tab.deleteSelected(); ev.accepted = true }
                    else if (ev.key === Qt.Key_A && (ev.modifiers & Qt.ControlModifier)) { shots.selectAll(); ev.accepted = true }
                    else if ((ev.key === Qt.Key_Return || ev.key === Qt.Key_Space) && grid.currentIndex >= 0) { viewer.show(grid.currentIndex); ev.accepted = true }
                    else if (ev.key === Qt.Key_Escape) { shots.clearSelection(); ev.accepted = true }
                }

                delegate: Item {
                    id: cell
                    required property int index
                    required property string thumb
                    required property string baseName
                    required property string dateText
                    required property bool selected
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radius
                        color: cell.selected ? Theme.accentSoft : hov.hovered ? Theme.surfaceHover : "transparent"
                        border.width: cell.selected ? 2 : 0
                        border.color: Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        HoverHandler { id: hov }
                        TapHandler {
                            acceptedModifiers: Qt.KeyboardModifierMask
                            onTapped: (ev) => {
                                grid.forceActiveFocus(); grid.currentIndex = cell.index
                                shots.select(cell.index, (ev.modifiers & Qt.ShiftModifier) ? "range" : (ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) ? "toggle" : "single")
                            }
                            onDoubleTapped: viewer.show(cell.index)
                        }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { grid.currentIndex = cell.index; if (!cell.selected) shots.select(cell.index); shotMenu.popup() } }
                        Rectangle {
                            id: frame
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 6
                            height: parent.height - 34
                            radius: Theme.radiusSm
                            color: Theme.surfaceAlt
                            clip: true
                            Image {
                                id: img
                                anchors.fill: parent
                                source: cell.thumb
                                sourceSize: Qt.size(480, 270)
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                opacity: status === Image.Ready ? 1 : 0
                                scale: hov.hovered ? 1.03 : 1
                                Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                                Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
                            }
                            Icon { anchors.centerIn: parent; visible: img.status !== Image.Ready; name: img.status === Image.Error ? "circle-alert" : "image"; size: 22; color: Theme.textSubtle }
                        }
                        RowLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 8
                            anchors.bottomMargin: 6
                            Text { text: cell.baseName; color: Theme.text; font.pixelSize: Theme.fontSm; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            Text { text: cell.dateText; color: Theme.textSubtle; font.pixelSize: Theme.fontXs; visible: grid.cellWidth > 200 }
                        }
                    }
                }
            }
            EmptyState {
                anchors.centerIn: parent
                visible: shots.count === 0
                iconName: "camera"
                title: qsTr("No screenshots yet")
                text: qsTr("Press F2 in game to take one. You can also drop images here.")
                PButton { text: qsTr("Open folder"); iconName: "folder-open"; onClicked: shots.openFolder() }
            }
        }
    }

    PMenu {
        id: shotMenu
        PMenuItem { text: qsTr("View"); iconName: "maximize"; enabled: shots.selectedCount === 1; onTriggered: viewer.show(grid.currentIndex) }
        PMenuItem { text: qsTr("Upload to %1").arg(shots.uploadHost); iconName: "upload"; enabled: !shots.uploading; onTriggered: tab.upload() }
        PMenuItem { text: qsTr("Copy image"); iconName: "image"; enabled: shots.selectedCount === 1; onTriggered: shots.copyImage(grid.currentIndex) }
        PMenuItem { text: qsTr("Copy file(s)"); iconName: "copy"; onTriggered: shots.copySelectedFiles() }
        PMenuItem { text: qsTr("Rename…"); iconName: "pencil"; enabled: shots.selectedCount === 1; onTriggered: tab.renameAt(grid.currentIndex) }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Delete"); iconName: "trash-2"; danger: true; shortcutText: "Del"; onTriggered: tab.deleteSelected() }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: (ev) => { if (ev.hasUrls) { shots.addFiles(ev.urls); ev.accept(Qt.CopyAction) } }
        Rectangle {
            anchors.fill: parent; radius: Theme.radiusLg
            color: Theme.accentSoft; border.color: Theme.accent; border.width: 2
            opacity: drop.containsDrag ? 1 : 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            EmptyState { anchors.centerIn: parent; iconName: "image-plus"; title: qsTr("Drop images to add them") }
        }
    }

    ResTaskDialog { id: progress }
    ResScreenshotViewer {
        id: viewer
        model: shots
        onCurrentIndexChanged: if (opened && currentIndex >= 0) { grid.currentIndex = currentIndex; shots.select(currentIndex) }
        onRenameRequested: (row) => tab.renameAt(row)
        onDeleteRequested: tab.deleteSelected()
        onUploadRequested: tab.upload()
    }
}
