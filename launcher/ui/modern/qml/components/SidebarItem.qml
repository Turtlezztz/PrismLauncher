import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

AbstractButton {
    id: item
    property string iconName: ""
    property string page: ""
    property bool collapsed: false
    readonly property bool current: page.length > 0 && Router.section === page
    Layout.fillWidth: true
    implicitHeight: 36
    hoverEnabled: true
    onClicked: if (page.length) Router.go(page)
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    background: Rectangle {
        radius: Theme.radius
        color: item.current ? Theme.accentSoft : item.down ? Theme.surfacePressed : item.hovered ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Rectangle {
            width: 3; radius: 2
            height: item.current ? 16 : 0
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            Behavior on height { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        }
    }
    contentItem: RowLayout {
        spacing: 12
        Item { width: item.collapsed ? (item.width - 18) / 2 - 12 : 0 }
        Icon { name: item.iconName; size: 18; color: item.current ? Theme.accent : item.hovered ? Theme.text : Theme.textMuted; Layout.leftMargin: item.collapsed ? 0 : 10 }
        Text {
            visible: !item.collapsed
            text: item.text
            color: item.current ? Theme.text : item.hovered ? Theme.text : Theme.textMuted
            font.pixelSize: Theme.fontMd
            font.weight: item.current ? Font.DemiBold : Font.Medium
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
    PToolTip { visible: item.collapsed && item.hovered; text: item.text }
}
