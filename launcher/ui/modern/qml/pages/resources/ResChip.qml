import QtQuick
import PrismModern

// Toggleable filter chip.
Rectangle {
    id: chip
    property string text: ""
    property bool checked: false
    signal clicked()
    height: 26
    width: label.implicitWidth + 20
    radius: 13
    color: checked ? Theme.accentSoft : ma.containsMouse ? Theme.surfaceHover : "transparent"
    border.color: checked ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.checked ? Theme.accent : Theme.textMuted
        font.pixelSize: Theme.fontSm
        font.weight: Font.Medium
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
}
