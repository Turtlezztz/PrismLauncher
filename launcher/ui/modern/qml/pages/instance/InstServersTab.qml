import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Instance → Servers (classic ServersPage): servers.dat with live status.
Item {
    id: tab
    property string instanceId
    readonly property alias model: sm

    ResServerModel { id: sm; instanceId: tab.instanceId }

    function removeSelected() {
        if (sm.locked || sm.selectedCount === 0) return
        var cur = sm.get(sm.currentRow)
        Dialogs.confirm({
            title: sm.selectedCount === 1 ? qsTr("Remove “%1”?").arg(cur.name || "") : qsTr("Remove %1 servers?").arg(sm.selectedCount),
            text: qsTr("The server will be gone from your list forever."),
            confirmText: qsTr("Remove"), danger: true
        }, function(ok) { if (ok) sm.removeSelected() })
    }
    function editServer(row) { editor.openFor(row, row >= 0 ? sm.get(row) : null) }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Rectangle {
                visible: sm.locked
                implicitHeight: 28; implicitWidth: lockRow.implicitWidth + 20; radius: 14
                color: Theme.soft(Theme.warning)
                Row { id: lockRow; anchors.centerIn: parent; spacing: 6
                    Icon { name: "lock"; size: 13; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Read-only while the game is running"); color: Theme.warning; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Item { Layout.fillWidth: true }
            PButton { text: qsTr("Add server"); iconName: "plus"; variant: "primary"; enabled: !sm.locked; onClicked: tab.editServer(-1) }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh status"); onClicked: sm.refresh() }
        }

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
                model: sm
                clip: true
                focus: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: PScrollBar {}
                move: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }
                moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }
                Keys.onPressed: (ev) => {
                    if (ev.key === Qt.Key_Delete) { tab.removeSelected(); ev.accepted = true }
                    else if (ev.key === Qt.Key_Up && (ev.modifiers & Qt.AltModifier)) { sm.moveUp(sm.currentRow); ev.accepted = true }
                    else if (ev.key === Qt.Key_Down && (ev.modifiers & Qt.AltModifier)) { sm.moveDown(sm.currentRow); ev.accepted = true }
                }

                delegate: Rectangle {
                    id: srow
                    required property int index
                    required property string name
                    required property string address
                    required property string iconSource
                    required property string status
                    required property string motdHtml
                    required property int players
                    required property int maxPlayers
                    required property string version
                    required property int ping
                    required property string error
                    required property bool selected
                    width: list.width
                    height: 72
                    radius: Theme.radius
                    color: selected ? Theme.accentSoft : hov.hovered ? Theme.surfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    HoverHandler { id: hov }
                    TapHandler {
                        acceptedModifiers: Qt.KeyboardModifierMask
                        onTapped: (ev) => { list.forceActiveFocus(); sm.select(srow.index, (ev.modifiers & Qt.ShiftModifier) ? "range" : (ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) ? "toggle" : "single") }
                        onDoubleTapped: sm.join(srow.index)
                    }
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: { if (!srow.selected) sm.select(srow.index); serverMenu.popup() } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 48; Layout.preferredHeight: 48
                            radius: Theme.radiusSm + 2
                            color: Theme.surfaceAlt
                            clip: true
                            Image { id: sicon; anchors.fill: parent; source: srow.iconSource; sourceSize: Qt.size(64, 64); smooth: false; visible: status === Image.Ready && implicitWidth > 1 }
                            Icon { anchors.centerIn: parent; visible: !sicon.visible; name: "server"; size: 20; color: Theme.textSubtle }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Text { text: srow.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: list.width * 0.35 }
                                Text { text: srow.address; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.maximumWidth: list.width * 0.25 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srow.status === "online" ? srow.motdHtml : srow.status === "pinging" ? qsTr("Pinging…") : (srow.error.length ? qsTr("Can't connect: %1").arg(srow.error) : qsTr("Can't connect"))
                                textFormat: srow.status === "online" ? Text.RichText : Text.PlainText
                                color: srow.status === "offline" ? Theme.danger : Theme.textMuted
                                font.pixelSize: Theme.fontSm
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.preferredWidth: 190
                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 6
                                Spinner { visible: srow.status === "pinging"; size: 12 }
                                Rectangle { visible: srow.status !== "pinging"; width: 8; height: 8; radius: 4; color: srow.status === "online" ? Theme.success : Theme.danger }
                                Text {
                                    text: srow.status === "online" ? (srow.players >= 0 ? (srow.maxPlayers >= 0 ? srow.players + " / " + srow.maxPlayers : srow.players) : "?") : srow.status === "pinging" ? "…" : qsTr("Offline")
                                    color: Theme.text; font.pixelSize: Theme.fontSm; font.weight: Font.Medium
                                }
                                Icon { visible: srow.status === "online"; name: "users"; size: 12; color: Theme.textSubtle }
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                visible: srow.status === "online"
                                text: [srow.version, srow.ping >= 0 ? srow.ping + " ms" : ""].filter(s => s.length).join("  ·  ")
                                color: Theme.textSubtle; font.pixelSize: Theme.fontXs; elide: Text.ElideRight
                                Layout.maximumWidth: 190
                            }
                        }
                        PButton {
                            size: "sm"; variant: "primary"; iconName: "play"; text: qsTr("Join")
                            opacity: hov.hovered || srow.selected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            onClicked: sm.join(srow.index)
                        }
                        IconButton { iconName: "ellipsis"; onClicked: { if (!srow.selected) sm.select(srow.index); serverMenu.popup() } }
                    }
                }
            }
            EmptyState {
                anchors.centerIn: parent
                visible: sm.count === 0
                iconName: "server"
                title: qsTr("No servers yet")
                text: qsTr("Add a multiplayer server to join it straight from the launcher.")
                PButton { text: qsTr("Add server"); iconName: "plus"; enabled: !sm.locked; onClicked: tab.editServer(-1) }
            }
        }
        Text { text: qsTr("%n server(s)", "", sm.count); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
    }

    PMenu {
        id: serverMenu
        readonly property bool single: sm.selectedCount === 1
        PMenuItem { text: qsTr("Join"); iconName: "play"; enabled: serverMenu.single; onTriggered: sm.join(sm.currentRow) }
        PMenuItem { text: qsTr("Edit…"); iconName: "pencil"; enabled: serverMenu.single && !sm.locked; onTriggered: tab.editServer(sm.currentRow) }
        PMenuItem { text: qsTr("Move up"); iconName: "arrow-up"; shortcutText: "Alt+↑"; enabled: serverMenu.single && !sm.locked && sm.currentRow > 0; onTriggered: sm.moveUp(sm.currentRow) }
        PMenuItem { text: qsTr("Move down"); iconName: "arrow-down"; shortcutText: "Alt+↓"; enabled: serverMenu.single && !sm.locked && sm.currentRow < sm.count - 1; onTriggered: sm.moveDown(sm.currentRow) }
        PMenuItem { text: qsTr("Copy address"); iconName: "copy"; enabled: serverMenu.single; onTriggered: { ResUtil.copyText(sm.get(sm.currentRow).address); Toasts.success(qsTr("Address copied")) } }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Remove"); iconName: "trash-2"; danger: true; enabled: !sm.locked; onTriggered: tab.removeSelected() }
    }

    PDialog {
        id: editor
        property int row: -1
        title: row >= 0 ? qsTr("Edit server") : qsTr("Add server")
        iconName: "server"
        maxWidth: 460
        function openFor(r, data) {
            row = r
            nameField.text = data ? data.name : qsTr("Minecraft Server")
            addrField.text = data ? data.address : ""
            texBox.currentIndex = data ? data.acceptTextures : 0
            open()
            addrField.forceActiveFocus()
        }
        function save() {
            if (!addrField.text.trim().length) { addrField.error = true; return }
            if (row >= 0) sm.setServer(row, nameField.text, addrField.text.trim(), texBox.currentIndex)
            else sm.addServer(nameField.text, addrField.text.trim(), texBox.currentIndex)
            close()
        }
        FormRow { label: qsTr("Name"); stacked: true; PTextField { id: nameField; width: parent.width; onAccepted: editor.save() } }
        FormRow { label: qsTr("Address"); description: qsTr("Host name or IP, optionally with :port"); stacked: true
            PTextField { id: addrField; width: parent.width; placeholderText: "play.example.com"; onTextChanged: error = false; onAccepted: editor.save() } }
        FormRow { label: qsTr("Server resource packs"); stacked: true
            PComboBox { id: texBox; width: parent.width; model: [qsTr("Prompt"), qsTr("Enabled"), qsTr("Disabled")] } }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: editor.close() },
            PButton { text: editor.row >= 0 ? qsTr("Save") : qsTr("Add"); variant: "primary"; onClicked: editor.save() }
        ]
    }
}
