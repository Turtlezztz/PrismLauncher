import QtQuick
import QtQuick.Layouts
import PrismModern

// A titled card grouping SetRows.  SetSection { title: "Folders"; iconName: "folder"; SetRow {...} SetRow {...} }
Rectangle {
    id: sec
    property string title: ""
    property string description: ""
    property string iconName: ""
    property alias headerActions: actions.data
    default property alias content: col.data

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 8 + (title.length ? 20 : 8)
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: sec.title.length ? 18 : 4
        spacing: 6

        RowLayout {
            visible: sec.title.length > 0
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                visible: sec.iconName.length > 0
                width: 30; height: 30; radius: 9
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: sec.iconName; size: 16; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: sec.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { visible: sec.description.length > 0; text: sec.description; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
            Row { id: actions; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }
        }
        Column {
            id: col
            Layout.fillWidth: true
        }
    }
}
