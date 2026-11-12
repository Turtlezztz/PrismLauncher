import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

PageScaffold {
    id: page
    title: qsTr("Library")
    subtitle: App.instances.count === 1 ? qsTr("1 instance") : qsTr("%1 instances").arg(App.instances.count)
    Component.onCompleted: Router.section = "Library"
    property string view: App.setting("ModernLibraryView") || "grid"

    headerActions: [
        SearchField {
            id: search
            width: 260
            placeholderText: qsTr("Search instances")
            onTextChanged: App.instances.filterText = text
            Component.onCompleted: text = App.instances.filterText
        },
        PComboBox {
            width: 150
            model: [ { value: "name", text: qsTr("Sort: Name") }, { value: "lastPlayed", text: qsTr("Sort: Last played") } ]
            textRole: "text"; valueRole: "value"
            Component.onCompleted: currentIndex = App.instances.sortMode === "lastPlayed" ? 1 : 0
            onActivated: App.instances.sortMode = currentValue
        },
        SegmentedControl {
            options: [ { value: "grid", icon: "grid-2x2" }, { value: "list", icon: "list" } ]
            value: page.view
            onActivated: v => { page.view = v; App.setSetting("ModernLibraryView", v) }
        }
    ]
    Shortcut { sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }

    headerExtra: [
        // group filter chips
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: App.groups.length > 0
            Repeater {
                model: [""].concat(App.groups)
                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool current: App.instances.groupFilter === modelData
                    height: 28
                    width: chipText.implicitWidth + 24
                    radius: 14
                    color: current ? Theme.accentSoft : chipMa.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: current ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Text { id: chipText; anchors.centerIn: parent; text: chip.modelData.length ? chip.modelData : qsTr("All"); color: chip.current ? Theme.accent : Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
                    MouseArea {
                        id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (ev) => {
                            if (ev.button === Qt.RightButton && chip.modelData.length) { groupMenu.group = chip.modelData; groupMenu.popup() }
                            else App.instances.groupFilter = chip.modelData
                        }
                    }
                }
            }
        }
    ]

    PMenu {
        id: groupMenu
        property string group
        PMenuItem { text: qsTr("Rename group"); iconName: "pencil"; onTriggered: {
            var g = groupMenu.group
            Dialogs.prompt({ title: qsTr("Rename group"), value: g, confirmText: qsTr("Rename") }, function(v) {
                if (v && v.length) { App.renameGroup(g, v); if (App.instances.groupFilter === g) App.instances.groupFilter = v }
            })
        } }
        PMenuItem { text: qsTr("Delete group"); iconName: "trash-2"; danger: true; onTriggered: {
            var g = groupMenu.group
            Dialogs.confirm({ title: qsTr("Delete group “%1”?").arg(g), text: qsTr("Instances in this group will not be deleted; they will become ungrouped."), confirmText: qsTr("Delete group"), danger: true },
                function(ok) { if (ok) { App.deleteGroup(g); App.instances.groupFilter = "" } })
        } }
    }

    InstanceContextMenu { id: ctxMenu }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        EmptyState {
            anchors.centerIn: parent
            visible: App.instances.count === 0
            iconName: App.instances.filterText.length ? "search" : "box"
            title: App.instances.filterText.length ? qsTr("No matches") : qsTr("No instances yet")
            text: App.instances.filterText.length ? qsTr("No instance matches “%1”.").arg(App.instances.filterText)
                                                  : qsTr("Create your first instance or import a modpack to get started.")
            PButton { visible: !App.instances.filterText.length; text: qsTr("New instance"); iconName: "plus"; variant: "primary"; onClicked: Router.go("NewInstance") }
            PButton { visible: !App.instances.filterText.length; text: qsTr("Browse modpacks"); iconName: "compass"; onClicked: Router.go("Discover") }
        }

        GridView {
            id: grid
            anchors.fill: parent
            anchors.leftMargin: -6; anchors.rightMargin: -6
            visible: page.view === "grid" && count > 0
            clip: true
            model: App.instances
            readonly property int columns: Math.max(1, Math.floor(width / 260))
            cellWidth: Math.floor(width / columns)
            cellHeight: 132
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            bottomMargin: Theme.spacingXl
            cacheBuffer: 400
            reuseItems: true

            add: Transition { ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.dur; easing.type: Theme.easing } } }
            displaced: Transition { NumberAnimation { properties: "x,y"; duration: Theme.dur; easing.type: Theme.easing } }

            delegate: InstanceCard {
                id: cardDelegate
                width: grid.cellWidth
                height: grid.cellHeight
                onClicked: Router.push("Instance", { instanceId: cardDelegate.instanceId })
                onLaunch: App.launch(cardDelegate.instanceId)
                onStop: App.kill(cardDelegate.instanceId)
                onContextMenu: (x, y) => { ctxMenu.instanceId = cardDelegate.instanceId; ctxMenu.popup() }
            }
        }

        ListView {
            id: list
            anchors.fill: parent
            visible: page.view === "list" && count > 0
            clip: true
            model: App.instances
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            bottomMargin: Theme.spacingXl
            reuseItems: true
            displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }

            delegate: Rectangle {
                id: rowItem
                required property string instanceId
                required property string name
                required property string iconSource
                required property string statusText
                required property string lastPlayedText
                required property string playTimeText
                required property string group
                required property bool running
                width: list.width
                height: 56
                radius: Theme.radius
                color: rowHover.hovered ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                HoverHandler { id: rowHover }
                TapHandler { onTapped: Router.push("Instance", { instanceId: rowItem.instanceId }); onDoubleTapped: App.launch(rowItem.instanceId) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: { ctxMenu.instanceId = rowItem.instanceId; ctxMenu.popup() } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 14
                    Image { source: rowItem.iconSource; sourceSize: Qt.size(64, 64); Layout.preferredWidth: 32; Layout.preferredHeight: 32; smooth: false }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: rowItem.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: rowItem.statusText; color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Badge { visible: rowItem.group.length > 0; text: rowItem.group }
                    Text { text: rowItem.playTimeText; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                    Text { text: rowItem.lastPlayedText; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                    PButton {
                        size: "sm"
                        variant: rowItem.running ? "danger" : "primary"
                        iconName: rowItem.running ? "square" : "play"
                        text: rowItem.running ? qsTr("Stop") : qsTr("Play")
                        opacity: rowHover.hovered || rowItem.running ? 1 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        onClicked: rowItem.running ? App.kill(rowItem.instanceId) : App.launch(rowItem.instanceId)
                    }
                    IconButton { iconName: "ellipsis"; onClicked: { ctxMenu.instanceId = rowItem.instanceId; ctxMenu.popup() } }
                }
            }
        }
    }
}
