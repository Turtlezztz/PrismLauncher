import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Grid tile for an instance. Emits open/launch/contextMenu.
Item {
    id: card
    required property string instanceId
    required property string name
    required property string iconSource
    required property string statusText
    required property string lastPlayedText
    required property string group
    required property bool running
    required property bool crashed
    required property bool broken
    property bool selected: false

    signal open()
    signal launch()
    signal stop()
    signal contextMenu(real x, real y)
    signal clicked()

    readonly property bool hovered: hh.hovered

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: 6
        radius: Theme.radiusLg
        // slightly see-through while the background cat is shown, so it peeks through like in the classic view
        readonly property color _base: card.hovered ? Theme.surfaceHover : Theme.surface
        color: App.catVisible ? Qt.rgba(_base.r, _base.g, _base.b, 0.82) : _base
        border.width: card.selected ? 2 : 1
        border.color: card.selected ? Theme.accent : card.hovered ? Theme.borderStrong : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
        transform: Translate { y: card.hovered && !Theme.reduceMotion ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    width: 52; height: 52; radius: 12
                    color: Theme.surfaceAlt
                    border.color: Theme.border
                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40
                        source: card.iconSource
                        sourceSize: Qt.size(80, 80)
                        smooth: false
                        fillMode: Image.PreserveAspectFit
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { text: card.name; color: Theme.text; font.pixelSize: Theme.fontMd + 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: card.statusText; color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Badge { visible: card.running; text: qsTr("Running"); tone: "success" }
                Badge { visible: card.crashed && !card.running; text: qsTr("Crashed"); tone: "danger" }
                Badge { visible: card.broken; text: qsTr("Broken"); tone: "warning" }
                Text {
                    visible: !card.running
                    text: card.lastPlayedText; color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Item { Layout.fillWidth: card.running }
                // play/stop button fades in on hover
                Rectangle {
                    id: play
                    width: 34; height: 34; radius: 17
                    color: card.running ? (playMa.containsMouse ? Qt.lighter(Theme.danger, 1.1) : Theme.danger)
                                        : (playMa.containsMouse ? Theme.accentHover : Theme.accent)
                    opacity: card.hovered || card.running ? 1 : 0
                    scale: card.hovered || card.running ? (playMa.pressed ? 0.92 : 1) : 0.7
                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }
                    Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: card.running ? 0 : 1; name: card.running ? "square" : "play"; size: 15; color: "#ffffff" }
                    MouseArea {
                        id: playMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: card.running ? card.stop() : card.launch()
                    }
                    PToolTip { visible: playMa.containsMouse; text: card.running ? qsTr("Stop") : qsTr("Play") }
                }
            }
        }
    }

    HoverHandler { id: hh }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: card.clicked()
        onDoubleTapped: card.open()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (ev) => card.contextMenu(ev.position.x, ev.position.y)
    }
}
