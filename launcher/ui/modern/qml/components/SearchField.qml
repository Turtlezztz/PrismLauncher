import QtQuick
import PrismModern

// Search input with icon, clear button and Ctrl/Cmd+F focus.
PTextField {
    id: root
    iconName: "search"
    placeholderText: qsTr("Search…")
    rightPadding: text.length ? 34 : 12
    IconButton {
        visible: root.text.length > 0
        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
        size: 26; iconSize: 14; iconName: "x"
        onClicked: root.clear()
    }
    Keys.onEscapePressed: { if (text.length) clear(); else focus = false }
}
