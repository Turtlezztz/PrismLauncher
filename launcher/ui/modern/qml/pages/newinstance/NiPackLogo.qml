import QtQuick
import PrismModern

// Modpack logo with a soft placeholder while it downloads; fades in when ready.
Rectangle {
    id: root
    property string source: ""
    property string name: ""
    property int size: 48
    width: size; height: size
    radius: Math.round(size * 0.24)
    color: Theme.surfaceAlt
    border.color: Theme.border
    clip: true
    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: root.name.length ? root.name.charAt(0).toUpperCase() : "?"
        color: Theme.textSubtle
        font.pixelSize: root.size * 0.42; font.weight: Font.Bold
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
    }
}
