import QtQuick
import QtQuick.Controls.Basic
import PrismModern

CheckBox {
    id: control
    hoverEnabled: true
    font.pixelSize: Theme.fontMd
    spacing: 8
    indicator: Rectangle {
        implicitWidth: 18; implicitHeight: 18
        x: control.leftPadding; y: (control.height - height) / 2
        radius: 5
        color: control.checkState !== Qt.Unchecked ? Theme.accent : Theme.input
        border.width: control.checkState !== Qt.Unchecked ? 0 : 1.5
        border.color: control.hovered ? Theme.textMuted : Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Icon {
            anchors.centerIn: parent; size: 13; color: Theme.textOnAccent
            name: control.checkState === Qt.PartiallyChecked ? "minus" : "check"
            scale: control.checkState !== Qt.Unchecked ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
        }
    }
    contentItem: Text {
        text: control.text; font: control.font
        color: control.enabled ? Theme.text : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        wrapMode: Text.Wrap
    }
}
