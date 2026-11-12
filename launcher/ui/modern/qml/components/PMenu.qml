import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Context / dropdown menu. Use PMenuItem children (and MenuSeparator via PMenuSeparator).
Menu {
    id: menu
    padding: 5
    implicitWidth: 220
    delegate: PMenuItem {}
    background: Rectangle {
        implicitWidth: 220
        color: Theme.elevated
        radius: Theme.radius
        border.color: Theme.borderStrong
    }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Theme.dur; easing.type: Theme.easing }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
}
