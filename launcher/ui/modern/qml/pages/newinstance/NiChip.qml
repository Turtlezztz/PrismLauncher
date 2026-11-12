import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Toggle pill used for filters (version types, loaders, categories). Bind `checked`; handle onClicked.
AbstractButton {
    id: chip
    property string iconName: ""
    checkable: false
    hoverEnabled: true
    implicitHeight: 28
    implicitWidth: row.implicitWidth + 22
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    background: Rectangle {
        radius: height / 2
        color: chip.checked ? Theme.accentSoft : chip.hovered ? Theme.surfaceHover : "transparent"
        border.color: chip.checked ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5
            Icon { visible: chip.checked || chip.iconName.length > 0; name: chip.checked ? "check" : chip.iconName; size: 12; color: chip.checked ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text { text: chip.text; color: chip.checked ? Theme.accent : Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
