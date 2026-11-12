import QtQuick
import QtQuick.Controls.Basic
import PrismModern

MenuItem {
    id: item
    property string iconName: ""
    property bool danger: false
    property string shortcutText: ""
    implicitHeight: visible ? 32 : 0
    hoverEnabled: true
    font.pixelSize: Theme.fontMd
    arrow: Icon { visible: item.subMenu; name: "chevron-right"; size: 14; color: Theme.textMuted; x: item.width - width - 8; y: (item.height - height) / 2 }
    indicator: Item {}
    contentItem: Row {
        spacing: 10
        leftPadding: 4
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: item.checkable ? (item.checked ? "check" : "") : item.iconName
            visible: true
            width: 16; size: 16
            color: item.danger ? Theme.danger : item.enabled ? Theme.textMuted : Theme.textDisabled
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: item.text
            font: item.font
            color: !item.enabled ? Theme.textDisabled : item.danger ? Theme.danger : Theme.text
            width: item.width - 60 - (item.shortcutText.length ? 60 : 0)
            elide: Text.ElideRight
        }
        Text {
            visible: item.shortcutText.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: item.shortcutText; font.pixelSize: Theme.fontSm; color: Theme.textSubtle
        }
    }
    background: Rectangle {
        radius: Theme.radiusSm
        color: item.highlighted && item.enabled ? (item.danger ? Theme.soft(Theme.danger) : Theme.surfaceHover) : "transparent"
    }
}
