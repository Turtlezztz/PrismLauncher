import QtQuick
import QtQuick.Layouts
import PrismModern

// A settings row: label + description on the left, control(s) on the right.
// For wide controls set `stacked: true` to put the control below the label.
Item {
    id: root
    property string label: ""
    property string description: ""
    property bool stacked: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: stacked ? (texts.implicitHeight + slot.childrenRect.height + Theme.spacingSm + 20)
                            : Math.max(texts.implicitHeight, slot.childrenRect.height) + 20
    implicitWidth: 400

    ColumnLayout {
        id: texts
        spacing: 2
        anchors.left: parent.left
        anchors.right: root.stacked ? parent.right : slot.left
        anchors.rightMargin: root.stacked ? 0 : Theme.spacingLg
        anchors.top: root.stacked ? parent.top : undefined
        anchors.topMargin: 10
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        Text { text: root.label; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; Layout.fillWidth: true; wrapMode: Text.Wrap; visible: text.length }
        Text { text: root.description; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap; visible: text.length }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.left: root.stacked ? parent.left : undefined
        anchors.top: root.stacked ? texts.bottom : undefined
        anchors.topMargin: Theme.spacingSm
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        width: root.stacked ? parent.width : childrenRect.width
        height: childrenRect.height
    }
}
