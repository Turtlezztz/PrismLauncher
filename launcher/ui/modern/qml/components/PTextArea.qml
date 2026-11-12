import QtQuick
import QtQuick.Controls.Basic
import PrismModern

ScrollView {
    id: root
    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property alias readOnly: area.readOnly
    property alias textArea: area
    property bool monospace: false
    implicitHeight: 120
    ScrollBar.vertical: PScrollBar {}
    TextArea {
        id: area
        font.pixelSize: Theme.fontMd
        font.family: root.monospace ? Theme.monoFamily : Theme.fontFamily
        color: Theme.text
        placeholderTextColor: Theme.textSubtle
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.text
        wrapMode: TextArea.Wrap
        selectByMouse: true
        padding: 12
        background: Rectangle {
            radius: Theme.radius
            color: Theme.input
            border.width: area.activeFocus ? 2 : 1
            border.color: area.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
        }
    }
}
