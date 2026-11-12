import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Choose the instance a dropped/opened resource (mod, resource pack, shader pack, world...) goes into.
// (classic ImportResourceDialog)
PDialog {
    id: dlg
    property string filePath: ""
    property string typeName: ""
    property string selectedId: ""
    signal chosen(string instanceId)

    title: qsTr("Add %1 to an instance").arg(typeName.toLowerCase())
    subtitle: filePath
    iconName: "download"
    maxWidth: 620
    property string result: ""
    onClosed: chosen(result)

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 340
        radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
        GridView {
            id: grid
            anchors.fill: parent; anchors.margins: 6
            clip: true
            model: App.instances
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 140)))
            cellHeight: 104
            ScrollBar.vertical: PScrollBar {}
            delegate: Item {
                id: cell
                required property string instanceId
                required property string name
                required property string iconSource
                required property string statusText
                readonly property bool current: instanceId === dlg.selectedId
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 3; radius: Theme.radius
                    color: cell.current ? Theme.accentSoft : ma.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: cell.current ? Theme.accent : "transparent"
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Image { anchors.horizontalCenter: parent.horizontalCenter; source: cell.iconSource; width: 40; height: 40; sourceSize: Qt.size(80, 80) }
                        Text { width: grid.cellWidth - 16; text: cell.name; color: Theme.text; font.pixelSize: Theme.fontSm; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                        Text { width: grid.cellWidth - 16; text: cell.statusText; color: Theme.textSubtle; font.pixelSize: Theme.fontXs; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                    }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: dlg.selectedId = cell.instanceId
                    onDoubleClicked: { dlg.result = cell.instanceId; dlg.close() }
                }
            }
        }
    }
    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Add"); variant: "primary"; enabled: dlg.selectedId.length > 0; onClicked: { dlg.result = dlg.selectedId; dlg.close() } }
    ]
}
