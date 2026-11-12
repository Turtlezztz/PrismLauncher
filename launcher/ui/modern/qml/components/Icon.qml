import QtQuick
import QtQuick.Window
import PrismModern

// Recolorable SVG line icon from qml/icons.  Icon { name: "play"; color: Theme.text; size: 16 }
Item {
    id: root
    property string name: ""
    property color color: Theme.text
    property int size: 16
    implicitWidth: size
    implicitHeight: size
    visible: name.length > 0
    Image {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize: Qt.size(root.size * Screen.devicePixelRatio, root.size * Screen.devicePixelRatio)
        source: root.name.length ? "image://icon/" + root.name + "?color=" + encodeURIComponent(root.color.toString()) : ""
        smooth: true
        cache: true
        fillMode: Image.PreserveAspectFit
    }
}
