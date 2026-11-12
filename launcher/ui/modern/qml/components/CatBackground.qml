import QtQuick
import PrismModern

// The classic Prism background cat, drawn in the bottom-right corner behind the library.
// Honors the same settings as the classic UI: EnableCat/TheCat, BackgroundCat (cat packs, seasonal), CatOpacity, CatFit.
Item {
    id: root
    readonly property bool shown: App.catVisible && cat.status === Image.Ready
    clip: true

    AnimatedImage {
        id: cat
        source: App.catVisible ? App.catSource : ""
        asynchronous: true
        cache: true
        smooth: true
        // animated cat packs (gif/webp) only animate while actually on screen
        playing: root.shown && root.visible && Qt.application.state === Qt.ApplicationActive

        readonly property real nw: Math.max(1, sourceSize.width)
        readonly property real nh: Math.max(1, sourceSize.height)
        readonly property real fitScale: Math.min(root.width / nw, root.height / nh)
        // fit: natural size, shrunk to the view if needed; fill: scaled to the view keeping aspect; stretch: whole view
        width: App.catFit === "stretch" ? root.width : nw * (App.catFit === "fill" ? fitScale : Math.min(1, fitScale))
        height: App.catFit === "stretch" ? root.height : nh * (App.catFit === "fill" ? fitScale : Math.min(1, fitScale))
        fillMode: Image.Stretch
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        opacity: root.shown ? App.catOpacity : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing } }
    }
}
