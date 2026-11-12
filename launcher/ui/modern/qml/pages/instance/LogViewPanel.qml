import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Fast monospace log view over a LogViewModel (ListView, one delegate per line).
//   LogViewPanel { log: someLogViewModel; searchText: search.text }
// Colors lines by MessageLevel, supports find next/previous, autoscroll and copy.
Rectangle {
    id: root
    property LogViewModel log
    property string searchText: ""
    property bool autoScroll: true
    property int currentMatch: -1
    property string emptyTitle: qsTr("No log yet")
    property string emptyText: ""
    property string emptyIcon: "terminal"
    readonly property alias view: list
    readonly property int matches: log && searchText.length ? _matchCount : 0
    property int _matchCount: 0

    radius: Theme.radiusLg
    color: Theme.dark ? "#0b0c10" : "#fbfbfd"
    border.color: Theme.border
    clip: true

    function levelColor(level) {
        switch (level) {
        case 2: return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.85)   // stderr
        case 3: return Theme.accent                                                    // launcher
        case 4: case 5: return Theme.textSubtle                                        // trace / debug
        case 8: return Theme.warning
        case 9: case 10: return Theme.danger
        default: return Theme.text
        }
    }
    function findNext(backwards) {
        if (!log || !searchText.length) return
        var from = currentMatch >= 0 ? currentMatch : (backwards ? list.count : -1)
        var r = log.find(searchText, from, backwards)
        if (r >= 0) {
            currentMatch = r
            root.autoScroll = false
            list.positionViewAtIndex(r, ListView.Center)
        } else {
            Toasts.show(qsTr("No matches for “%1”").arg(searchText), "info")
        }
    }
    function scrollToEnd() { list.positionViewAtEnd() }

    onSearchTextChanged: { currentMatch = -1; recount.restart() }
    Timer { id: recount; interval: 200; onTriggered: root._matchCount = root.log ? root.log.matchCount(root.searchText) : 0 }

    Connections {
        target: root.log
        function onRestarted() { root.currentMatch = -1; Qt.callLater(root.scrollToEnd) }
        function onCountChanged() {
            if (root.autoScroll) Qt.callLater(root.scrollToEnd)
            if (root.searchText.length) recount.restart()
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 1
        topMargin: 8; bottomMargin: 8
        clip: true
        model: root.log
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 600
        pixelAligned: true
        ScrollBar.vertical: PScrollBar { id: vbar }
        ScrollBar.horizontal: PScrollBar { visible: !root.log || !root.log.wrap }
        contentWidth: root.log && !root.log.wrap ? Math.max(width, maxLineWidth + 40) : width
        flickableDirection: root.log && !root.log.wrap ? Flickable.HorizontalAndVerticalFlick : Flickable.VerticalFlick
        property real maxLineWidth: 0

        // user scrolled up -> stop following; back at the end -> follow again
        onMovementEnded: root.autoScroll = atYEnd
        onFlickEnded: root.autoScroll = atYEnd
        Component.onCompleted: positionViewAtEnd()

        delegate: Rectangle {
            id: row
            required property int index
            required property string line
            required property int level
            readonly property bool match: root.searchText.length > 0 && line.toLowerCase().indexOf(root.searchText.toLowerCase()) >= 0
            width: Math.max(list.width, txt.implicitWidth + 28)
            height: txt.height + 2
            color: index === root.currentMatch ? Theme.soft(Theme.accent)
                 : match ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, Theme.dark ? 0.10 : 0.14)
                 : level === 10 ? Theme.soft(Theme.danger) : "transparent"
            Rectangle { visible: row.index === root.currentMatch; width: 3; height: parent.height; color: Theme.accent }
            Text {
                id: txt
                x: 14
                width: root.log && root.log.wrap ? list.width - 28 : implicitWidth
                text: row.line
                textFormat: Text.PlainText
                wrapMode: root.log && root.log.wrap ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                color: root.log && root.log.colorLines ? root.levelColor(row.level) : Theme.text
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSm
                font.bold: row.level === 10
                Component.onCompleted: if (implicitWidth > list.maxLineWidth) list.maxLineWidth = implicitWidth
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: { lineMenu.row = row.index; lineMenu.popup() }
            }
        }
    }

    PMenu {
        id: lineMenu
        property int row: -1
        PMenuItem { text: qsTr("Copy line"); iconName: "copy"; onTriggered: root.log.copyLine(lineMenu.row) }
        PMenuItem { text: qsTr("Copy all"); iconName: "copy"; onTriggered: { root.log.copyAll(); Toasts.success(qsTr("Log copied to the clipboard")) } }
    }

    // jump-to-end pill when not following
    Rectangle {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Theme.spacing
        height: 30; width: jumpRow.implicitWidth + 22; radius: 15
        color: Theme.elevated; border.color: Theme.borderStrong
        opacity: !root.autoScroll && list.count > 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        Row {
            id: jumpRow; anchors.centerIn: parent; spacing: 6
            Icon { name: "arrow-down-to-line"; size: 14; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTr("Jump to end"); color: Theme.text; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.autoScroll = true; root.scrollToEnd() } }
    }

    EmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 420)
        visible: !root.log || list.count === 0
        iconName: root.log && root.log.message.length ? "file-text" : root.emptyIcon
        title: root.log && root.log.message.length ? "" : root.emptyTitle
        text: root.log && root.log.message.length ? root.log.message : root.emptyText
    }
}
