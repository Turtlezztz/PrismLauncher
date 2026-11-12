import QtQuick
import QtQuick.Controls.Basic
import PrismModern

Slider {
    id: control
    hoverEnabled: true
    implicitHeight: 24
    background: Rectangle {
        x: control.leftPadding; y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth; height: 4; radius: 2
        color: Theme.surfacePressed
        Rectangle { width: control.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 16; height: 16; radius: 8
        color: "#ffffff"
        border.width: 3; border.color: Theme.accent
        scale: control.pressed ? 1.15 : control.hovered ? 1.05 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }
    }
}
