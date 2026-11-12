import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Square icon-only button with optional tooltip.
AbstractButton {
    id: control
    property string iconName: ""
    property color iconColor: active ? Theme.accent : Theme.textMuted
    property string tip: ""
    property bool active: false
    property int size: 32
    property int iconSize: 16
    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    HoverHandler { cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.iconSize
            color: !control.enabled ? Theme.textDisabled : control.hovered ? Theme.text : control.iconColor
        }
    }
    background: Rectangle {
        radius: Theme.radiusSm + 2
        color: control.down ? Theme.surfacePressed : (control.hovered || control.active) ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.accent
    }
    PToolTip { visible: control.tip.length > 0 && control.hovered; text: control.tip }
}
