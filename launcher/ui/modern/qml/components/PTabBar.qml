import QtQuick
import PrismModern

// Horizontal tabs with a sliding pill indicator.
//   PTabBar { model: [{ key: "mods", text: "Mods", icon: "puzzle" }, ...]; currentKey: "mods"; onActivated: key => ... }
Item {
    id: root
    property var model: []
    property string currentKey: model.length ? model[0].key : ""
    signal activated(string key)
    implicitHeight: 36
    implicitWidth: row.implicitWidth

    Rectangle {
        id: pill
        property Item target: null
        radius: Theme.radius - 2
        color: Theme.surface
        border.color: Theme.border
        height: parent.height
        x: target ? target.x : 0
        width: target ? target.width : 0
        visible: target !== null
        Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
    }
    Row {
        id: row
        height: parent.height
        spacing: 2
        Repeater {
            id: rep
            model: root.model
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: root.currentKey === modelData.key
                height: row.height
                width: content.implicitWidth + 24
                onCurrentChanged: if (current) pill.target = tab
                Component.onCompleted: if (current) pill.target = tab
                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { visible: !!tab.modelData.icon; name: tab.modelData.icon || ""; size: 15; color: tab.current ? Theme.text : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: tab.modelData.text
                        color: tab.current ? Theme.text : ma.containsMouse ? Theme.text : Theme.textMuted
                        font.pixelSize: Theme.fontMd; font.weight: tab.current ? Font.DemiBold : Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                    Badge { visible: !!tab.modelData.badge; text: tab.modelData.badge ? String(tab.modelData.badge) : ""; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentKey = tab.modelData.key; root.activated(tab.modelData.key) }
                }
            }
        }
    }
}
