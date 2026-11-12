import QtQuick
import QtQuick.Controls.Basic
import PrismModern

RadioButton {
    id: control
    hoverEnabled: true
    font.pixelSize: Theme.fontMd
    spacing: 8
    indicator: Rectangle {
        implicitWidth: 18; implicitHeight: 18
        x: control.leftPadding; y: (control.height - height) / 2
        radius: 9
        color: Theme.input
        border.width: control.checked ? 5 : 1.5
        border.color: control.checked ? Theme.accent : control.hovered ? Theme.textMuted : Theme.borderStrong
        Behavior on border.width { NumberAnimation { duration: Theme.durFast } }
    }
    contentItem: Text {
        text: control.text; font: control.font
        color: control.enabled ? Theme.text : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        wrapMode: Text.Wrap
    }
}
