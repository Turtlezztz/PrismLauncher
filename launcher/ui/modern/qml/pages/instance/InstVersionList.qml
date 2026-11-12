import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Selectable version list over an InstVersionListModel (search, type chips, loading/error/empty states).
//   InstVersionList { versions: someModel; onPicked: ... }   selected: { descriptor, versionName, ... } or null
ColumnLayout {
    id: root
    property InstVersionListModel versions
    property var selected: null
    property bool showTypeFilter: true
    property bool javaMode: false
    property string emptyText: qsTr("No versions available.")
    signal picked()          // double-click / Enter
    spacing: Theme.spacing

    readonly property var typeNames: ({ release: qsTr("Releases"), snapshot: qsTr("Snapshots"), old_beta: qsTr("Betas"),
                                        old_alpha: qsTr("Alphas"), experiment: qsTr("Experiments"), old_snapshot: qsTr("Old snapshots") })

    function select(row) {
        if (!versions || row < 0 || row >= list.count) { selected = null; list.currentIndex = -1; return }
        list.currentIndex = row
        selected = versions.get(row)
        list.positionViewAtIndex(row, ListView.Contain)
    }
    function preselect() { select(versions ? versions.preferredRow() : -1); list.positionViewAtIndex(list.currentIndex, ListView.Center) }

    Connections {
        target: root.versions
        function onLoaded() { Qt.callLater(root.preselect) }
        function onFilterChanged() { Qt.callLater(function() {
            var r = root.selected ? root.versions.rowOf(root.selected.descriptor) : -1
            root.select(r >= 0 ? r : (root.versions.count ? 0 : -1))
        }) }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        SearchField {
            id: search
            Layout.fillWidth: true
            placeholderText: root.javaMode ? qsTr("Search Java installations") : qsTr("Search versions")
            onTextChanged: root.versions.search = text
            Keys.onDownPressed: root.select(Math.min(list.count - 1, list.currentIndex + 1))
            Keys.onUpPressed: root.select(Math.max(0, list.currentIndex - 1))
            onAccepted: if (root.selected) root.picked()
            Component.onCompleted: forceActiveFocus()
        }
        IconButton { iconName: "refresh-cw"; tip: qsTr("Reload the version list"); enabled: !root.versions.loading; onClicked: root.versions.load(true) }
    }

    // type chips (only when the list has several types, e.g. Minecraft)
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: root.showTypeFilter && root.versions.availableTypes.length > 1
        Repeater {
            model: root.versions.availableTypes
            delegate: Rectangle {
                id: chip
                required property string modelData
                readonly property bool on: root.versions.types.length === 0 || root.versions.types.indexOf(modelData) >= 0
                height: 26; width: chipRow.implicitWidth + 20; radius: 13
                color: on ? Theme.accentSoft : chipMa.containsMouse ? Theme.surfaceHover : "transparent"
                border.color: on ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Row {
                    id: chipRow; anchors.centerIn: parent; spacing: 4
                    Icon { visible: chip.on; name: "check"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.typeNames[chip.modelData] || chip.modelData; color: chip.on ? Theme.accent : Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var all = root.versions.availableTypes
                        var cur = root.versions.types.length ? root.versions.types.slice() : all.slice()
                        var i = cur.indexOf(chip.modelData)
                        if (i >= 0) cur.splice(i, 1); else cur.push(chip.modelData)
                        if (cur.length === 0) cur = [chip.modelData]
                        root.versions.types = cur.length === all.length ? [] : cur
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 200
        radius: Theme.radius
        color: Theme.input
        border.color: Theme.border
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            model: root.versions
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            highlightMoveDuration: 0
            delegate: Rectangle {
                id: row
                required property int index
                required property string versionName
                required property string descriptor
                required property var type
                required property bool recommended
                required property bool current
                required property var time
                required property var path
                required property var arch
                readonly property bool isSelected: list.currentIndex === index
                width: list.width
                height: root.javaMode ? 46 : 34
                radius: Theme.radiusSm
                color: isSelected ? Theme.accentSoft : rowHover.hovered ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                HoverHandler { id: rowHover }
                TapHandler { onTapped: root.select(row.index); onDoubleTapped: { root.select(row.index); root.picked() } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: Theme.spacingSm
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: row.versionName
                            color: row.isSelected ? Theme.accent : Theme.text
                            font.pixelSize: Theme.fontMd; font.weight: row.isSelected || row.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: root.javaMode
                            Layout.fillWidth: true
                            text: (row.path || "")
                            color: Theme.textSubtle; font.pixelSize: Theme.fontXs; elide: Text.ElideMiddle
                        }
                    }
                    Badge { visible: row.current; text: qsTr("Current"); tone: "accent" }
                    Badge { visible: row.recommended; text: qsTr("Recommended"); tone: "success"; iconName: "star" }
                    Badge { visible: !!row.type && row.type !== "release" && !root.javaMode; text: root.typeNames[row.type] ? root.typeNames[row.type].replace(/s$/, "") : String(row.type); tone: row.type === "snapshot" ? "warning" : "neutral" }
                    Text { visible: root.javaMode && !!row.arch; text: row.arch || ""; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                    Text {
                        visible: !root.javaMode && !!row.time && String(row.time).length > 0
                        text: row.time ? String(row.time) : ""
                        color: Theme.textSubtle; font.pixelSize: Theme.fontSm
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: root.versions.loading
            spacing: Theme.spacing
            Spinner { size: 28; Layout.alignment: Qt.AlignHCenter }
            Text { text: qsTr("Loading versions…"); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
        }
        EmptyState {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 380)
            visible: !root.versions.loading && list.count === 0
            iconName: root.versions.errorString.length ? "circle-alert" : "search"
            title: root.versions.errorString.length ? qsTr("Couldn't load versions") : qsTr("Nothing here")
            text: root.versions.errorString.length ? root.versions.errorString : (search.text.length ? qsTr("No version matches “%1”.").arg(search.text) : root.emptyText)
        }
    }
}
