import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Full-window screenshot viewer with arrow-key navigation.
Popup {
    id: viewer
    property var model: null        // ResScreenshotModel
    property int currentIndex: -1
    readonly property var cur: (currentIndex, model && currentIndex >= 0 && currentIndex < model.count) ? model.get(currentIndex) : ({})
    signal renameRequested(int row)
    signal deleteRequested()
    signal uploadRequested()

    function show(i) { currentIndex = i; open() }
    function step(d) { if (model && model.count) currentIndex = (currentIndex + d + model.count) % model.count }

    parent: Overlay.overlay
    x: 0; y: 0
    width: parent ? parent.width : 800
    height: parent ? parent.height : 600
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.85) }
    background: Item {}
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }

    contentItem: Item {
        focus: true
        Keys.onLeftPressed: viewer.step(-1)
        Keys.onRightPressed: viewer.step(1)
        Keys.onDeletePressed: viewer.deleteRequested()

        Image {
            id: full
            anchors.fill: parent
            anchors.margins: 72
            anchors.topMargin: 64
            source: viewer.cur.url || ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(Math.min(3840, width * 2), Math.min(2160, height * 2))
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            TapHandler { onDoubleTapped: viewer.close() }
        }
        Spinner { anchors.centerIn: parent; visible: full.status === Image.Loading; size: 32; color: "white" }

        // top bar
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingSm
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: viewer.cur.fileName || ""; color: "white"; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; elide: Text.ElideMiddle; Layout.fillWidth: true }
                Text {
                    text: [viewer.cur.dimensions, viewer.cur.sizeText, viewer.cur.dateText, viewer.model ? (viewer.currentIndex + 1) + " / " + viewer.model.count : ""].filter(s => s && s.length).join("  ·  ")
                    color: Qt.rgba(1, 1, 1, 0.65); font.pixelSize: Theme.fontSm
                }
            }
            component Tool: AbstractButton {
                id: tb
                property string iconName
                property string tip
                implicitWidth: 36; implicitHeight: 36
                hoverEnabled: true
                background: Rectangle { radius: 18; color: tb.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08); Behavior on color { ColorAnimation { duration: Theme.durFast } } }
                contentItem: Item { Icon { anchors.centerIn: parent; name: tb.iconName; size: 17; color: "white" } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                PToolTip { visible: tb.hovered; text: tb.tip }
            }
            Tool { iconName: "upload"; tip: qsTr("Upload"); onClicked: viewer.uploadRequested() }
            Tool { iconName: "image"; tip: qsTr("Copy image"); onClicked: { viewer.model.copyImage(viewer.currentIndex); Toasts.success(qsTr("Image copied")) } }
            Tool { iconName: "pencil"; tip: qsTr("Rename"); onClicked: viewer.renameRequested(viewer.currentIndex) }
            Tool { iconName: "trash-2"; tip: qsTr("Delete"); onClicked: viewer.deleteRequested() }
            Tool { iconName: "x"; tip: qsTr("Close"); onClicked: viewer.close() }
        }

        // side arrows
        AbstractButton {
            id: prevBtn
            anchors.left: parent.left; anchors.leftMargin: Theme.spacingLg
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44
            visible: viewer.model && viewer.model.count > 1
            hoverEnabled: true
            onClicked: viewer.step(-1)
            background: Rectangle { radius: 22; color: prevBtn.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08) }
            contentItem: Item { Icon { anchors.centerIn: parent; name: "chevron-left"; size: 22; color: "white" } }
        }
        AbstractButton {
            id: nextBtn
            anchors.right: parent.right; anchors.rightMargin: Theme.spacingLg
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44
            visible: viewer.model && viewer.model.count > 1
            hoverEnabled: true
            onClicked: viewer.step(1)
            background: Rectangle { radius: 22; color: nextBtn.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08) }
            contentItem: Item { Icon { anchors.centerIn: parent; name: "chevron-right"; size: 22; color: "white" } }
        }
    }
    onOpened: contentItem.forceActiveFocus()
    Connections {
        target: viewer.model
        function onCountChanged() { if (viewer.opened && viewer.model.count === 0) viewer.close(); else if (viewer.currentIndex >= viewer.model.count) viewer.currentIndex = viewer.model.count - 1 }
    }
}
