import QtQuick
import PrismModern

// Lightweight spinner: a single rotating arc, animation only runs while visible.
Item {
    id: root
    property int size: 20
    property color color: Theme.accent
    property int lineWidth: Math.max(2, Math.round(size / 9))
    implicitWidth: size
    implicitHeight: size
    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            ctx.lineWidth = root.lineWidth; ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.18)
            ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - root.lineWidth, 0, 2 * Math.PI); ctx.stroke()
            ctx.strokeStyle = root.color
            ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - root.lineWidth, 0, Math.PI * 0.6); ctx.stroke()
        }
        Connections { target: root; function onColorChanged() { canvas.requestPaint() } }
        RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: root.visible }
    }
}
