import QtQuick
import PrismModern

// Compact segmented control. options: [{ value, text?, icon? }]
Rectangle {
    id: root
    property var options: []
    property var value: options.length ? options[0].value : undefined
    signal activated(var value)
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 6
    radius: Theme.radius
    color: Theme.surfaceAlt
    border.color: Theme.border

    Rectangle {
        id: knob
        property Item target: null
        y: 3; height: parent.height - 6
        x: target ? target.x + 3 : 3
        width: target ? target.width : 0
        radius: Theme.radiusSm + 1
        color: Theme.surfaceHover
        border.color: Theme.borderStrong
        Behavior on x { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        Behavior on width { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
    }
    Row {
        id: row
        x: 3; height: parent.height
        Repeater {
            model: root.options
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool current: root.value === modelData.value
                height: row.height
                width: Math.max(32, inner.implicitWidth + 20)
                onCurrentChanged: if (current) knob.target = seg
                Component.onCompleted: if (current) knob.target = seg
                Row {
                    id: inner
                    anchors.centerIn: parent; spacing: 6
                    Icon { visible: !!seg.modelData.icon; name: seg.modelData.icon || ""; size: 15; color: seg.current ? Theme.text : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Text { visible: !!seg.modelData.text; text: seg.modelData.text || ""; color: seg.current ? Theme.text : Theme.textMuted; font.pixelSize: Theme.fontSm + 1; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.value = seg.modelData.value; root.activated(seg.modelData.value) } }
            }
        }
    }
}
