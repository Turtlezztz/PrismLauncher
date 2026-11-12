import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Instance → Worlds (classic WorldListPage).
Item {
    id: tab
    property string instanceId
    readonly property alias model: wm
    readonly property var cur: (wm.selectedCount, wm.count, wm.currentRow >= 0 && wm.selectedCount === 1) ? wm.get(wm.currentRow) : ({})

    ResWorldModel { id: wm; instanceId: tab.instanceId }

    function safe(title, fn) {
        if (!wm.instanceRunning) { fn(); return }
        Dialogs.confirm({ title: title, text: qsTr("Changing a world while Minecraft is running is potentially unsafe. Do you want to proceed?"),
                          confirmText: qsTr("Proceed"), danger: true }, function(ok) { if (ok) fn() })
    }
    function removeSelected() {
        if (wm.selectedCount === 0) return
        var single = wm.selectedCount === 1 && cur.name !== undefined
        Dialogs.confirm({
            title: single ? qsTr("Delete “%1”?").arg(cur.name) : qsTr("Delete %1 worlds?").arg(wm.selectedCount),
            text: qsTr("Deleted worlds are moved to the trash when possible, otherwise they are gone forever."),
            confirmText: qsTr("Delete"), danger: true
        }, function(ok) { if (ok) progress.track(wm.deleteSelected(), { successText: qsTr("Deleted") }) })
    }
    function copyWorld() {
        var row = wm.currentRow, name = cur.name
        safe(qsTr("Copy world"), function() {
            Dialogs.prompt({ title: qsTr("Copy world"), text: qsTr("Enter a name for the copy."), value: name, confirmText: qsTr("Copy") }, function(v) {
                if (v && v.length) progress.track(wm.copyWorld(row, v), { successText: qsTr("World copied") })
            })
        })
    }
    function renameWorld() {
        var row = wm.currentRow, name = cur.name
        safe(qsTr("Rename world"), function() {
            Dialogs.prompt({ title: qsTr("Rename world"), text: qsTr("Enter a new world name."), value: name, confirmText: qsTr("Rename") }, function(v) {
                if (v && v.length && !wm.renameWorld(row, v)) Toasts.error(qsTr("Could not rename the world."))
            })
        })
    }
    function openDataPacks() {
        var row = wm.currentRow, name = cur.name
        safe(qsTr("Manage data packs"), function() { dataPacks.openFor(wm.datapacksFolder(row), name) })
    }
    function runTool(tool) {
        var row = wm.currentRow
        safe(tool, function() { var err = wm.launchTool(row, tool); if (err.length) Toasts.error(err) })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            SearchField {
                Layout.fillWidth: true; Layout.maximumWidth: 340; Layout.minimumWidth: 140
                placeholderText: qsTr("Search worlds")
                onTextChanged: wm.filterText = text
            }
            PComboBox {
                Layout.preferredWidth: 170
                textRole: "text"; valueRole: "value"
                model: [ { value: "lastPlayed", text: qsTr("Sort: Last played") }, { value: "name", text: qsTr("Sort: Name") },
                         { value: "size", text: qsTr("Sort: Size") }, { value: "gameMode", text: qsTr("Sort: Game mode") } ]
                onActivated: wm.sortKey = currentValue
            }
            Item { Layout.fillWidth: true }
            PButton { text: qsTr("Add world"); iconName: "plus"; variant: "primary"; onClicked: zipDialog.open() }
            IconButton { iconName: "folder-open"; tip: qsTr("Open saves folder"); onClicked: wm.openFolder(-1) }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh"); onClicked: wm.refresh() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 4
                    model: wm
                    clip: true
                    focus: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: PScrollBar {}
                    Keys.onPressed: (ev) => {
                        if (ev.key === Qt.Key_Delete) { tab.removeSelected(); ev.accepted = true }
                        else if (ev.key === Qt.Key_A && (ev.modifiers & Qt.ControlModifier)) { wm.selectAll(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Escape) { wm.clearSelection(); ev.accepted = true }
                    }
                    delegate: Rectangle {
                        id: wrow
                        required property int index
                        required property string name
                        required property string folderName
                        required property string gameMode
                        required property string lastPlayedText
                        required property string sizeText
                        required property string iconSource
                        required property bool linked
                        required property bool selected
                        width: list.width
                        height: 64
                        radius: Theme.radius
                        color: selected ? Theme.accentSoft : hov.hovered ? Theme.surfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        HoverHandler { id: hov }
                        TapHandler {
                            acceptedModifiers: Qt.KeyboardModifierMask
                            onTapped: (ev) => { list.forceActiveFocus(); wm.select(wrow.index, (ev.modifiers & Qt.ShiftModifier) ? "range" : (ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) ? "toggle" : "single") }
                            onDoubleTapped: if (wm.supportsJoin) wm.join(wrow.index)
                        }
                        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { if (!wrow.selected) wm.select(wrow.index); worldMenu.popup() } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                radius: Theme.radiusSm + 2
                                color: Theme.surfaceAlt
                                clip: true
                                Image { id: wicon; anchors.fill: parent; source: wrow.iconSource; sourceSize: Qt.size(64, 64); asynchronous: true; smooth: false; visible: status === Image.Ready }
                                Icon { anchors.centerIn: parent; visible: !wicon.visible; name: "mountain"; size: 20; color: Theme.textSubtle }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    spacing: 6
                                    Text { text: wrow.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: list.width * 0.4 }
                                    Icon { visible: wrow.linked; name: "link"; size: 12; color: Theme.info }
                                }
                                Text { text: wrow.folderName; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Badge { text: wrow.gameMode; tone: wrow.gameMode === "Creative" ? "info" : wrow.gameMode === "Hardcore" ? "danger" : "neutral" }
                            Text { text: wrow.lastPlayedText; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                            Text { text: wrow.sizeText; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                            PButton {
                                visible: wm.supportsJoin
                                size: "sm"; variant: "primary"; iconName: "play"; text: qsTr("Play")
                                opacity: hov.hovered || wrow.selected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                                onClicked: wm.join(wrow.index)
                            }
                            IconButton { iconName: "ellipsis"; onClicked: { if (!wrow.selected) wm.select(wrow.index); worldMenu.popup() } }
                        }
                    }
                }
                EmptyState {
                    anchors.centerIn: parent
                    visible: wm.count === 0
                    iconName: wm.totalCount > 0 ? "search" : "mountain"
                    title: wm.totalCount > 0 ? qsTr("No matches") : qsTr("No worlds yet")
                    text: wm.totalCount > 0 ? "" : qsTr("Play the game to create a world, or add one from a zip file.")
                    PButton { visible: wm.totalCount === 0; text: qsTr("Add world"); iconName: "plus"; onClicked: zipDialog.open() }
                }
            }

            // details
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: tab.cur.name !== undefined && tab.width > 640 ? 300 : 0
                visible: Layout.preferredWidth > 0
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                clip: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingLg
                    spacing: Theme.spacing
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 96; Layout.preferredHeight: 96
                        radius: Theme.radius
                        color: Theme.surfaceAlt
                        clip: true
                        Image { id: big; anchors.fill: parent; source: tab.cur.iconSource || ""; sourceSize: Qt.size(128, 128); smooth: false; asynchronous: true; visible: status === Image.Ready }
                        Icon { anchors.centerIn: parent; visible: !big.visible; name: "mountain"; size: 36; color: Theme.textSubtle }
                    }
                    Text { Layout.fillWidth: true; text: tab.cur.name || ""; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                    PButton { visible: wm.supportsJoin; Layout.fillWidth: true; variant: "primary"; iconName: "play"; text: qsTr("Join world"); onClicked: wm.join(wm.currentRow) }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: Theme.spacing; rowSpacing: 6
                        Text { text: qsTr("Folder"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
                        Text { text: tab.cur.folderName || ""; color: Theme.text; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; elide: Text.ElideMiddle }
                        Text { text: qsTr("Game mode"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
                        Text { text: tab.cur.gameMode || ""; color: Theme.text; font.pixelSize: Theme.fontSm }
                        Text { text: qsTr("Last played"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
                        Text { text: tab.cur.lastPlayedFull || ""; color: Theme.text; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        Text { text: qsTr("Size"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
                        Text { text: tab.cur.sizeText || ""; color: Theme.text; font.pixelSize: Theme.fontSm }
                        Text { text: qsTr("Seed"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: tab.cur.seed || ""; color: Theme.text; font.pixelSize: Theme.fontSm; font.family: Theme.monoFamily; Layout.fillWidth: true; elide: Text.ElideRight }
                            IconButton { size: 24; iconSize: 13; iconName: "copy"; tip: qsTr("Copy seed"); onClicked: { wm.copySeed(wm.currentRow); Toasts.success(qsTr("Seed copied")) } }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs
                        PButton { size: "sm"; text: qsTr("Data packs"); iconName: "database"; onClicked: tab.openDataPacks() }
                        PButton { size: "sm"; text: qsTr("Rename"); iconName: "pencil"; onClicked: tab.renameWorld() }
                        PButton { size: "sm"; text: qsTr("Copy"); iconName: "copy"; onClicked: tab.copyWorld() }
                        PButton { size: "sm"; text: qsTr("Folder"); iconName: "folder-open"; onClicked: wm.openFolder(wm.currentRow) }
                        PButton { size: "sm"; variant: "ghost"; text: qsTr("Delete"); iconName: "trash-2"; onClicked: tab.removeSelected() }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        Text {
            text: wm.selectedCount > 1 ? qsTr("%1 selected").arg(wm.selectedCount) : qsTr("%n world(s)", "", wm.totalCount)
            color: Theme.textSubtle; font.pixelSize: Theme.fontSm
        }
    }

    PMenu {
        id: worldMenu
        readonly property bool single: wm.selectedCount === 1
        PMenuItem { visible: wm.supportsJoin; text: qsTr("Join world"); iconName: "play"; enabled: worldMenu.single; onTriggered: wm.join(wm.currentRow) }
        PMenuItem { text: qsTr("Data packs…"); iconName: "database"; enabled: worldMenu.single; onTriggered: tab.openDataPacks() }
        PMenuItem { text: qsTr("Copy seed"); iconName: "key-round"; enabled: worldMenu.single; onTriggered: { wm.copySeed(wm.currentRow); Toasts.success(qsTr("Seed copied")) } }
        PMenuItem { text: qsTr("Rename…"); iconName: "pencil"; enabled: worldMenu.single; onTriggered: tab.renameWorld() }
        PMenuItem { text: qsTr("Copy…"); iconName: "copy"; enabled: worldMenu.single; onTriggered: tab.copyWorld() }
        PMenuItem { text: qsTr("Reset icon"); iconName: "rotate-ccw"; enabled: (wm.selectedCount, wm.anySelectedHasIcon()); onTriggered: wm.resetSelectedIcons() }
        PMenuItem { text: qsTr("Show in folder"); iconName: "folder-open"; enabled: worldMenu.single; onTriggered: wm.openFolder(wm.currentRow) }
        PMenu {
            id: toolsMenu
            title: qsTr("World tools")
            enabled: worldMenu.single
            Instantiator {
                model: wm.worldTools
                delegate: PMenuItem { required property string modelData; text: modelData; onTriggered: tab.runTool(modelData) }
                onObjectAdded: (i, o) => toolsMenu.insertItem(i, o)
                onObjectRemoved: (i, o) => toolsMenu.removeItem(o)
            }
            PMenuItem { visible: wm.worldTools.length === 0; text: qsTr("No tools added"); enabled: false }
            PMenuItem { visible: wm.worldTools.length === 0; text: qsTr("Open settings"); iconName: "settings"; onTriggered: Router.go("Settings", { initialPage: "external-tools" }) }
        }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Delete"); iconName: "trash-2"; danger: true; shortcutText: "Del"; onTriggered: tab.removeSelected() }
    }

    FileDialog {
        id: zipDialog
        title: qsTr("Select a Minecraft world zip")
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Minecraft world zip file (*.zip)")]
        onAccepted: progress.track(wm.addWorlds(selectedFiles), { successText: qsTr("World added") })
    }
    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: (ev) => { if (ev.hasUrls) { progress.track(wm.addWorlds(ev.urls), { successText: qsTr("World added") }); ev.accept(Qt.CopyAction) } }
        Rectangle {
            anchors.fill: parent; radius: Theme.radiusLg
            color: Theme.accentSoft; border.color: Theme.accent; border.width: 2
            opacity: drop.containsDrag ? 1 : 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            EmptyState { anchors.centerIn: parent; iconName: "download"; title: qsTr("Drop world zips to add them") }
        }
    }
    ResTaskDialog { id: progress }
    ResWorldDataPacksDialog { id: dataPacks; instanceId: tab.instanceId }
}
