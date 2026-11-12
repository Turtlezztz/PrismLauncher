import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Instance page header: icon, name (click to rename), version, play time, launch state + Play/Stop.
ColumnLayout {
    id: header
    property InstanceBridge bridge
    property bool showBack: false
    signal openTabRequested(string key)
    spacing: Theme.spacing

    function rename() {
        nameEdit.text = bridge.name
        nameEdit.visible = true
        nameEdit.forceActiveFocus()
        nameEdit.selectAll()
    }
    function commitRename() {
        if (!nameEdit.visible) return
        nameEdit.visible = false
        var v = nameEdit.text.trim()
        if (v.length && v !== bridge.name) {
            if (!App.renameInstance(bridge.instanceId, v)) Toasts.error(qsTr("Could not rename the instance"))
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingLg

        IconButton { visible: header.showBack; iconName: "arrow-left"; tip: qsTr("Back"); onClicked: Router.back(); Layout.alignment: Qt.AlignTop }

        // icon
        Rectangle {
            id: iconBox
            Layout.preferredWidth: 72; Layout.preferredHeight: 72
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: iconHover.hovered ? Theme.borderStrong : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
            Image {
                anchors.centerIn: parent
                width: 52; height: 52
                source: header.bridge ? header.bridge.iconSource : ""
                sourceSize: Qt.size(104, 104)
                smooth: false
                fillMode: Image.PreserveAspectFit
                scale: iconHover.hovered ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
            }
            Rectangle {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -4
                width: 22; height: 22; radius: 11
                color: Theme.elevated; border.color: Theme.borderStrong
                opacity: iconHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                Icon { anchors.centerIn: parent; name: "pencil"; size: 11; color: Theme.text }
            }
            HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: InstanceActions.open("icon", header.bridge.instanceId) }
            PToolTip { visible: iconHover.hovered; text: qsTr("Change icon") }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Item {
                    Layout.fillWidth: nameEdit.visible
                    Layout.preferredWidth: nameEdit.visible ? 0 : nameRow.implicitWidth
                    Layout.maximumWidth: nameEdit.visible ? 99999 : header.width * 0.55
                    implicitHeight: 36
                    Row {
                        id: nameRow
                        visible: !nameEdit.visible
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.Layout.maximumWidth)
                        spacing: 8
                        Text {
                            id: nameText
                            text: header.bridge ? header.bridge.name : ""
                            color: Theme.text
                            font.pixelSize: Theme.fontXxl - 2
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, header.width * 0.55 - 30)
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "pencil"; size: 14; color: Theme.textSubtle
                            opacity: nameHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        }
                        HoverHandler { id: nameHover; cursorShape: Qt.IBeamCursor }
                        TapHandler { onTapped: header.rename() }
                    }
                    PTextField {
                        id: nameEdit
                        visible: false
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.DemiBold
                        onAccepted: header.commitRename()
                        onActiveFocusChanged: if (!activeFocus) header.commitRename()
                        Keys.onEscapePressed: visible = false
                    }
                }
                Badge {
                    visible: !!header.bridge && (header.bridge.running || header.bridge.launching)
                    tone: header.bridge && header.bridge.running ? "success" : "accent"
                    text: header.bridge && header.bridge.running ? qsTr("Running") : qsTr("Launching")
                    iconName: header.bridge && header.bridge.running ? "play" : ""
                }
                Badge { visible: !!header.bridge && header.bridge.crashed && !header.bridge.running; tone: "danger"; text: qsTr("Crashed"); iconName: "circle-alert" }
                Badge { visible: !!header.bridge && header.bridge.broken; tone: "warning"; text: qsTr("Needs attention"); iconName: "triangle-alert" }
                Badge {
                    visible: !!header.bridge && header.bridge.group.length > 0
                    text: header.bridge ? header.bridge.group : ""
                    iconName: "layers"
                }
                Item { Layout.fillWidth: !nameEdit.visible }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.spacingLg
                MetaItem { iconName: "box"; text: header.bridge ? header.bridge.versionText : "" }
                MetaItem { iconName: "clock"; text: header.bridge ? header.bridge.playTimeText : "" }
                MetaItem { iconName: "history"; text: header.bridge ? header.bridge.lastPlayedText : "" }
            }
        }

        // ---- actions ----
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingSm

            IconButton { iconName: "folder-open"; tip: qsTr("Open instance folder"); anchors.verticalCenter: parent.verticalCenter; onClicked: header.bridge.openFolder("") }
            IconButton {
                id: moreBtn
                iconName: "ellipsis"; tip: qsTr("More actions"); anchors.verticalCenter: parent.verticalCenter
                onClicked: moreMenu.popup(moreBtn, 0, moreBtn.height + 4)
            }

            // running: restart + kill
            PButton {
                visible: !!header.bridge && header.bridge.running
                size: "lg"; variant: "secondary"; iconName: "rotate-ccw"; text: qsTr("Restart")
                enabled: header.bridge && !header.bridge.restartQueued
                onClicked: header.bridge.restart()
            }
            PButton {
                visible: !!header.bridge && header.bridge.running
                size: "lg"; variant: "danger"; iconName: "square"; text: qsTr("Kill")
                onClicked: header.bridge.kill()
            }
            // idle / launching: split play button
            Row {
                visible: !header.bridge || !header.bridge.running
                spacing: 1
                PButton {
                    id: playBtn
                    size: "lg"; variant: "primary"
                    iconName: "play"
                    busy: !!header.bridge && header.bridge.launching
                    text: header.bridge && header.bridge.launching ? qsTr("Launching…") : qsTr("Play")
                    enabled: !!header.bridge && header.bridge.canLaunch && !header.bridge.launching
                    rightPadding: 18
                    background: Rectangle {
                        radius: Theme.radius
                        color: playBtn._bg
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        // square the right edge so it joins the dropdown half
                        Rectangle { anchors.right: parent.right; width: Theme.radius; height: parent.height; color: parent.color }
                    }
                    onClicked: header.bridge.launch("normal")
                }
                PButton {
                    id: playMenuBtn
                    size: "lg"; variant: "primary"
                    iconName: "chevron-down"
                    implicitWidth: 34
                    enabled: playBtn.enabled
                    background: Rectangle {
                        radius: Theme.radius
                        color: playMenuBtn._bg
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Rectangle { anchors.left: parent.left; width: Theme.radius; height: parent.height; color: parent.color }
                    }
                    onClicked: playMenu.popup(playMenuBtn, playMenuBtn.width - playMenu.width, playMenuBtn.height + 4)
                }
            }
        }
    }

    // launch progress
    Rectangle {
        id: progressBox
        Layout.fillWidth: true
        readonly property bool shown: !!header.bridge && (header.bridge.launching || header.bridge.launchStatus.length > 0) && !header.bridge.running
        Layout.preferredHeight: shown ? 44 : 0
        opacity: shown ? 1 : 0
        visible: Layout.preferredHeight > 0
        clip: true
        radius: Theme.radius
        color: Theme.accentSoft
        Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
            spacing: Theme.spacing
            Spinner { size: 16; visible: progressBox.shown }
            Text {
                Layout.fillWidth: true
                text: header.bridge && header.bridge.launchStatus.length ? header.bridge.launchStatus : qsTr("Preparing to launch…")
                color: Theme.text; font.pixelSize: Theme.fontMd; elide: Text.ElideRight
            }
            PProgressBar {
                Layout.preferredWidth: 180
                indeterminate: !header.bridge || header.bridge.launchProgress < 0
                value: header.bridge && header.bridge.launchProgress >= 0 ? header.bridge.launchProgress : 0
            }
            PButton { size: "sm"; variant: "ghost"; text: qsTr("Show log"); onClicked: header.openTabRequested("console") }
        }
    }

    component MetaItem: Row {
        property string iconName
        property string text
        spacing: 6
        visible: text.length > 0
        Icon { name: parent.iconName; size: 14; color: Theme.textSubtle; anchors.verticalCenter: parent.verticalCenter }
        Text { text: parent.text; color: Theme.textMuted; font.pixelSize: Theme.fontMd; anchors.verticalCenter: parent.verticalCenter }
    }

    // ---- play dropdown ----
    PMenu {
        id: playMenu
        implicitWidth: 240
        PMenuItem { text: qsTr("Play"); iconName: "play"; onTriggered: header.bridge.launch("normal") }
        PMenuItem { text: qsTr("Play offline"); iconName: "wifi"; onTriggered: header.bridge.launch("offline") }
        PMenuItem { text: qsTr("Play demo"); iconName: "gamepad-2"; enabled: !!header.bridge && header.bridge.supportsDemo; onTriggered: header.bridge.launch("demo") }
        PMenu {
            id: accountsMenu
            title: qsTr("Play as")
            enabled: !!header.bridge && header.bridge.accounts.length > 0
            Instantiator {
                model: header.bridge ? header.bridge.accounts : []
                delegate: PMenuItem {
                    required property var modelData
                    text: modelData.name + (modelData.isDefault ? qsTr("  (default)") : "")
                    iconName: "user"
                    onTriggered: header.bridge.launch("normal", modelData.id)
                }
                onObjectAdded: (i, o) => accountsMenu.insertItem(i, o)
                onObjectRemoved: (i, o) => accountsMenu.removeItem(o)
            }
        }
        PMenuSeparator {}
        PMenuItem {
            text: qsTr("Join server…"); iconName: "server"
            onTriggered: Dialogs.prompt({ title: qsTr("Join server"), text: qsTr("Launch and connect directly to a server."),
                                          placeholder: "play.example.com:25565", confirmText: qsTr("Play") },
                                        function(v) { if (v && v.trim().length) header.bridge.launchJoinServer(v) })
        }
        PMenu {
            id: worldsMenu
            title: qsTr("Join world")
            enabled: !!header.bridge && header.bridge.supportsQuickPlayWorld && worldsInst.count > 0
            Instantiator {
                id: worldsInst
                model: playMenu.visible && header.bridge && header.bridge.supportsQuickPlayWorld ? header.bridge.worlds() : []
                delegate: PMenuItem {
                    required property string modelData
                    text: modelData; iconName: "map"
                    onTriggered: header.bridge.launchJoinWorld(modelData)
                }
                onObjectAdded: (i, o) => worldsMenu.insertItem(i, o)
                onObjectRemoved: (i, o) => worldsMenu.removeItem(o)
            }
        }
        PMenuSeparator {}
        PMenu {
            id: profilerMenu
            title: qsTr("Profiler")
            PMenuItem {
                text: qsTr("No profiler"); checkable: true
                checked: !header.bridge || header.bridge.profiler.length === 0
                onTriggered: header.bridge.setProfiler("")
            }
            Instantiator {
                model: header.bridge ? header.bridge.profilers : []
                delegate: PMenuItem {
                    required property var modelData
                    text: modelData.name; checkable: true
                    enabled: modelData.available
                    checked: header.bridge.profiler === modelData.key
                    onTriggered: header.bridge.setProfiler(modelData.key)
                }
                onObjectAdded: (i, o) => profilerMenu.insertItem(i + 1, o)
                onObjectRemoved: (i, o) => profilerMenu.removeItem(o)
            }
        }
    }

    // ---- overflow menu ----
    PMenu {
        id: moreMenu
        implicitWidth: 240
        PMenuItem { text: qsTr("Rename"); iconName: "pencil"; onTriggered: header.rename() }
        PMenuItem { text: qsTr("Change icon"); iconName: "image"; onTriggered: InstanceActions.open("icon", header.bridge.instanceId) }
        PMenuItem { text: qsTr("Change group"); iconName: "layers"; onTriggered: InstanceActions.open("group", header.bridge.instanceId) }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Open .minecraft folder"); iconName: "folder"; onTriggered: header.bridge.openFolder("game") }
        PMenuItem { text: qsTr("Open libraries folder"); iconName: "folder"; onTriggered: header.bridge.openFolder("libraries") }
        PMenuItem { text: qsTr("Open logs folder"); iconName: "folder"; onTriggered: header.bridge.openFolder("logs") }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Copy instance"); iconName: "copy"; onTriggered: InstanceActions.open("copy", header.bridge.instanceId) }
        PMenuItem { text: qsTr("Export"); iconName: "upload"; onTriggered: InstanceActions.open("export", header.bridge.instanceId) }
        PMenuItem { text: qsTr("Create shortcut"); iconName: "link"; onTriggered: InstanceActions.open("shortcut", header.bridge.instanceId) }
        PMenuSeparator {}
        PMenuItem {
            text: qsTr("Delete"); iconName: "trash-2"; danger: true
            enabled: !!header.bridge && !header.bridge.running
            onTriggered: InstanceActions.confirmDelete(header.bridge.instanceId)
        }
    }
}
