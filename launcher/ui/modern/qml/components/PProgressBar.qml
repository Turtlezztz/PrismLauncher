import QtQuick
import QtQuick.Controls.Basic
import PrismModern

ProgressBar {
    id: control
    implicitHeight: 6
    background: Rectangle { radius: height / 2; color: Theme.surfacePressed; implicitWidth: 120; implicitHeight: control.implicitHeight }
    contentItem: Item {
        clip: true
        Rectangle {
            visible: !control.indeterminate
            width: control.visualPosition * parent.width; height: parent.height
            radius: height / 2; color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        }
        Rectangle {
            id: sweep
            visible: control.indeterminate
            width: parent.width * 0.35; height: parent.height; radius: height / 2; color: Theme.accent
            XAnimator on x { from: -sweep.width; to: control.width; duration: 1100; loops: Animation.Infinite; running: control.indeterminate && control.visible }
        }
    }
}
