import QtQuick
import QtQuick.Layouts
import PrismModern

ColumnLayout {
    id: root
    property string iconName: "package"
    property string title: ""
    property string text: ""
    default property alias actions: actionRow.data
    spacing: Theme.spacing
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        width: 64; height: 64; radius: 20
        color: Theme.accentSoft
        Icon { anchors.centerIn: parent; name: root.iconName; size: 28; color: Theme.accent }
    }
    Text { Layout.alignment: Qt.AlignHCenter; text: root.title; color: Theme.text; font.pixelSize: Theme.fontLg + 1; font.weight: Font.DemiBold; visible: text.length }
    Text {
        Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 380
        text: root.text; color: Theme.textMuted; font.pixelSize: Theme.fontMd
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; visible: text.length
    }
    Row { id: actionRow; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: Theme.spacingSm; spacing: Theme.spacingSm }
}
