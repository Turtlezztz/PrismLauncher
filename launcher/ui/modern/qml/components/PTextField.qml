import QtQuick
import QtQuick.Controls.Basic
import PrismModern

TextField {
    id: control
    property string iconName: ""
    property bool error: false
    implicitHeight: Theme.controlHeight
    leftPadding: iconName.length ? 34 : 12
    rightPadding: 12
    font.pixelSize: Theme.fontMd
    color: Theme.text
    placeholderTextColor: Theme.textSubtle
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.text
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    background: Rectangle {
        radius: Theme.radius
        color: Theme.input
        border.width: control.activeFocus ? 2 : 1
        border.color: control.error ? Theme.danger : control.activeFocus ? Theme.accent : control.hovered ? Theme.borderStrong : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
        Icon {
            visible: control.iconName.length > 0
            name: control.iconName; size: 15; color: Theme.textSubtle
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
        }
    }
}
