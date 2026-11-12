import QtQuick
import QtQuick.Controls.Basic
import PrismModern

Switch {
    id: control
    hoverEnabled: true
    font.pixelSize: Theme.fontMd
    spacing: 10
    indicator: Rectangle {
        implicitWidth: 38; implicitHeight: 22
        x: control.text.length ? control.width - width - control.rightPadding : control.leftPadding
        y: (control.height - height) / 2
        radius: height / 2
        color: control.checked ? (control.enabled ? Theme.accent : Theme.textDisabled) : Theme.surfacePressed
        border.width: control.checked ? 0 : 1
        border.color: Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.dur } }
        Rectangle {
            width: 16; height: 16; radius: 8
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        }
    }
    contentItem: Text {
        text: control.text; font: control.font
        color: control.enabled ? Theme.text : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        rightPadding: control.indicator.width + control.spacing
        elide: Text.ElideRight
    }
}
