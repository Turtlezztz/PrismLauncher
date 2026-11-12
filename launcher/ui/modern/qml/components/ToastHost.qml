import QtQuick
import QtQuick.Layouts
import PrismModern

// Stack of auto-dismissing toasts (bottom-right).
Column {
    id: host
    spacing: Theme.spacingSm
    width: 360
    z: 1000

    ListModel { id: toasts }
    property int _seq: 0
    property var _actions: ({})

    Connections {
        target: Toasts
        function onPosted(message, kind, action) {
            var id = ++host._seq
            if (action) host._actions[id] = action
            toasts.append({ uid: id, message: message, kind: kind, actionText: action ? action.text : "" })
            if (toasts.count > 4) toasts.remove(0)
        }
    }

    move: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }

    Repeater {
        model: toasts
        delegate: Rectangle {
            id: toast
            required property int index
            required property int uid
            required property string message
            required property string kind
            required property string actionText
            readonly property color tone: kind === "success" ? Theme.success : kind === "error" ? Theme.danger : kind === "warning" ? Theme.warning : Theme.accent
            width: host.width
            height: row.implicitHeight + 24
            radius: Theme.radiusLg
            color: Theme.elevated
            border.color: Theme.borderStrong
            opacity: 0
            transform: Translate { id: tr; x: 40 }
            Component.onCompleted: appear.start()
            ParallelAnimation {
                id: appear
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: Theme.dur; easing.type: Theme.easing }
                NumberAnimation { target: tr; property: "x"; to: 0; duration: Theme.durSlow; easing.type: Theme.easingEmph }
            }
            function dismiss() { vanish.start() }
            SequentialAnimation {
                id: vanish
                ParallelAnimation {
                    NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Theme.dur }
                    NumberAnimation { target: tr; property: "x"; to: 40; duration: Theme.dur }
                }
                ScriptAction { script: { delete host._actions[toast.uid]; for (var i = 0; i < toasts.count; i++) if (toasts.get(i).uid === toast.uid) { toasts.remove(i); break } } }
            }
            Timer { running: !hover.hovered; interval: toast.kind === "error" ? 9000 : 4500; onTriggered: toast.dismiss() }
            HoverHandler { id: hover }

            RowLayout {
                id: row
                anchors.fill: parent; anchors.margins: 12
                spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    width: 26; height: 26; radius: 8; color: Theme.soft(toast.tone)
                    Icon { anchors.centerIn: parent; size: 15; color: toast.tone
                        name: toast.kind === "success" ? "circle-check" : toast.kind === "error" ? "circle-alert" : toast.kind === "warning" ? "triangle-alert" : "info" }
                }
                Text { text: toast.message; color: Theme.text; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: Theme.fontMd; Layout.alignment: Qt.AlignVCenter }
                PButton {
                    visible: toast.actionText.length > 0
                    text: toast.actionText; size: "sm"; variant: "subtle"
                    onClicked: { var a = host._actions[toast.uid]; if (a && a.run) a.run(); toast.dismiss() }
                }
                IconButton { iconName: "x"; size: 24; iconSize: 13; onClicked: toast.dismiss(); Layout.alignment: Qt.AlignTop }
            }
        }
    }
}
