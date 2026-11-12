import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Thin overlay scrollbar that widens on hover.
ScrollBar {
    id: bar
    minimumSize: 0.06
    padding: 2
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 8 : 5
        implicitHeight: implicitWidth
        radius: width / 2
        color: bar.pressed ? Theme.textMuted : Theme.textSubtle
        opacity: bar.policy === ScrollBar.AlwaysOn || (bar.active && bar.size < 1.0) ? (bar.hovered ? 0.8 : 0.5) : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        Behavior on implicitWidth { NumberAnimation { duration: Theme.durFast } }
    }
    background: Item {}
}
