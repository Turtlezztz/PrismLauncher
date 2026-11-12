import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Icon picker (classic IconPickerDialog).
//  - instance mode: set `instanceId`; choosing an icon calls App.setInstanceIcon
//  - pick mode: set `pickMode: true` (+ optional `selectedKey`) and listen to picked(key)
PDialog {
    id: dlg
    property string instanceId
    property bool pickMode: false
    property string selectedKey: instanceId.length ? (App.instances.get(instanceId).iconKey || "default") : "default"
    signal picked(string key)

    title: qsTr("Choose an icon")
    subtitle: instanceId.length ? (App.instances.get(instanceId).name || "") : ""
    iconName: "image"
    maxWidth: 720

    function choose(key) {
        if (!key.length) return
        if (instanceId.length && !pickMode) App.setInstanceIcon(instanceId, key)
        picked(key)
        close()
    }

    NIIconModel { id: icons }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        SearchField { id: search; Layout.fillWidth: true; placeholderText: qsTr("Search icons"); onTextChanged: icons.search = text }
        SegmentedControl {
            options: [ { value: "all", text: qsTr("All") }, { value: "modern", text: qsTr("Modern") }, { value: "legacy", text: qsTr("Legacy") },
                       { value: "modpacks", text: qsTr("Modpacks") }, { value: "custom", text: qsTr("Custom") } ]
            value: icons.category
            onActivated: v => icons.category = v
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 380
        radius: Theme.radius
        color: Theme.surfaceAlt
        border.color: drop.containsDrag ? Theme.accent : Theme.border
        border.width: drop.containsDrag ? 2 : 1

        GridView {
            id: grid
            anchors.fill: parent; anchors.margins: 6
            clip: true
            model: icons
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 92)))
            cellHeight: 92
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            cacheBuffer: 400
            delegate: Item {
                id: cell
                required property string key
                required property string name
                required property string source
                readonly property bool current: key === dlg.selectedKey
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 3
                    radius: Theme.radius
                    color: cell.current ? Theme.accentSoft : cellMa.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: cell.current ? Theme.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 44; height: 44
                            source: cell.source
                            sourceSize: Qt.size(88, 88)
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            scale: cellMa.containsMouse ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
                        }
                        Text {
                            width: grid.cellWidth - 14
                            text: cell.name
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            color: cell.current ? Theme.accent : Theme.textMuted
                            font.pixelSize: Theme.fontXs + 1
                        }
                    }
                }
                MouseArea {
                    id: cellMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: dlg.selectedKey = cell.key
                    onDoubleClicked: dlg.choose(cell.key)
                }
            }
            Component.onCompleted: Qt.callLater(function() { var i = icons.indexOf(dlg.selectedKey); if (i >= 0) grid.positionViewAtIndex(i, GridView.Center) })
        }
        EmptyState {
            anchors.centerIn: parent
            visible: icons.count === 0
            iconName: "image"
            title: qsTr("No icons")
            text: search.text.length ? qsTr("Nothing matches “%1”.").arg(search.text) : qsTr("Add your own icons with “Add icon” or by dropping image files here.")
        }
        DropArea {
            id: drop
            anchors.fill: parent
            onDropped: ev => { if (ev.hasUrls) { var k = icons.addIcons(ev.urls); if (k.length) dlg.selectedKey = k } }
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select icons")
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Icons %1").arg(icons.iconFilter), qsTr("All files (*)")]
        onAccepted: { var k = icons.addIcons(selectedFiles); if (k.length) dlg.selectedKey = k }
    }

    buttons: [
        PButton { text: qsTr("Add icon"); iconName: "plus"; onClicked: fileDialog.open() },
        PButton {
            text: qsTr("Remove"); iconName: "trash-2"
            enabled: icons.canRemove(dlg.selectedKey) && icons.count >= 0
            onClicked: {
                var key = dlg.selectedKey
                Dialogs.confirm({ title: qsTr("Remove icon “%1”?").arg(key), text: qsTr("The icon file is moved to the trash when possible."), confirmText: qsTr("Remove"), danger: true },
                                function(ok) { if (ok && icons.removeIcon(key)) dlg.selectedKey = "default" })
            }
        },
        PButton { text: qsTr("Open folder"); iconName: "folder-open"; onClicked: icons.openFolder(dlg.selectedKey) },
        Item { width: Theme.spacingLg; height: 1 },
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Select"); variant: "primary"; onClicked: dlg.choose(dlg.selectedKey) }
    ]
}
