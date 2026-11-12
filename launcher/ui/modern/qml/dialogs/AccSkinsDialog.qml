import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Skins & capes for an account (classic SkinManageDialog). 2D front/back preview.
PDialog {
    id: dlg
    property string accountId: ""
    readonly property var account: Accounts.get(accountId)

    title: qsTr("Skins")
    subtitle: account.name ? qsTr("Change the skin and cape of %1").arg(account.name) : ""
    iconName: "shirt"
    maxWidth: 940
    closePolicy: mgr.busy ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    SkinManager {
        id: mgr
        accountId: dlg.accountId
        onNotify: (kind, message) => kind === "error" ? Dialogs.message({ title: qsTr("Skins"), text: message, kind: "error" }) : Toasts.success(message)
        onApplied: dlg.close()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 470
        spacing: Theme.spacingLg

        // ------------------------------------------------------------ preview
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            radius: Theme.radiusLg
            color: Theme.surfaceAlt
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // soft floor shadow
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        width: parent.width * 0.7; height: 14; radius: 7
                        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.08)
                    }
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -6
                        spacing: 22
                        Repeater {
                            model: [ { src: mgr.selectedFront, label: qsTr("Front") }, { src: mgr.selectedBack, label: qsTr("Back") } ]
                            delegate: Column {
                                required property var modelData
                                spacing: 6
                                Image {
                                    width: 84; height: 168
                                    source: modelData.src
                                    smooth: false
                                    fillMode: Image.PreserveAspectFit
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: Theme.textSubtle; font.pixelSize: Theme.fontXs }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: mgr.selected.length === 0
                        text: qsTr("Select a skin")
                        color: Theme.textMuted; font.pixelSize: Theme.fontMd
                    }
                }

                Text { text: qsTr("Model"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
                SegmentedControl {
                    Layout.fillWidth: true
                    enabled: mgr.selected.length > 0
                    options: [ { value: false, text: qsTr("Classic (Steve)") }, { value: true, text: qsTr("Slim (Alex)") } ]
                    value: mgr.selectedSlim
                    onActivated: v => mgr.setSlim(v)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Cape"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; Layout.fillWidth: true }
                    PCheckBox { text: qsTr("Show as elytra"); checked: mgr.showElytra; onToggled: mgr.showElytra = checked; font.pixelSize: Theme.fontSm }
                }
                PComboBox {
                    id: capeCombo
                    Layout.fillWidth: true
                    enabled: mgr.selected.length > 0
                    model: mgr.capes
                    textRole: "alias"; valueRole: "id"
                    currentIndex: { var c = mgr.capes; for (var i = 0; i < c.length; i++) if (c[i].id === mgr.selectedCape) return i; return 0 }
                    onActivated: mgr.setCape(currentValue)
                }
                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 48; Layout.preferredWidth: 60
                    visible: source.toString().length > 0
                    source: capeCombo.currentIndex >= 0 && mgr.capes[capeCombo.currentIndex] ? mgr.capes[capeCombo.currentIndex].preview : ""
                    smooth: false; fillMode: Image.PreserveAspectFit
                }
            }
        }

        // ------------------------------------------------------------ skin library
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PTextField {
                    id: source
                    Layout.fillWidth: true
                    iconName: "link"
                    placeholderText: qsTr("Skin URL or Minecraft username")
                    onAccepted: importBtn.clicked()
                }
                PButton {
                    id: importBtn
                    text: qsTr("Import")
                    enabled: source.text.trim().length > 0 && !mgr.busy
                    onClicked: {
                        var t = source.text.trim()
                        if (/^https?:\/\//i.test(t)) mgr.installFromUrl(t); else mgr.importFromUsername(t)
                        source.text = ""
                    }
                    PToolTip { visible: parent.hovered; text: qsTr("A URL downloads that skin; a username copies that player's current skin.") }
                }
                PButton {
                    text: qsTr("From file"); iconName: "upload"
                    enabled: !mgr.busy
                    onClicked: { var e = mgr.browseAndInstall(); if (e.length && e !== "cancelled") Dialogs.message({ title: qsTr("Selected file is not a valid skin"), text: e, kind: "error" }) }
                }
                IconButton { iconName: "folder-open"; tip: qsTr("Open skins folder"); onClicked: mgr.openFolder() }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLg
                color: Theme.surfaceAlt
                border.color: Theme.border
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 8
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 124)))
                    cellHeight: 150
                    model: mgr.skins
                    ScrollBar.vertical: PScrollBar {}
                    delegate: Item {
                        id: tile
                        required property var modelData
                        readonly property bool sel: mgr.selected === modelData.name
                        width: grid.cellWidth; height: grid.cellHeight
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4
                            radius: Theme.radius
                            color: tile.sel ? Theme.accentSoft : tileMa.containsMouse ? Theme.surfaceHover : Theme.surface
                            border.color: tile.sel ? Theme.accent : Theme.border
                            border.width: tile.sel ? 2 : 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 26
                                width: 44; height: 88
                                source: tile.modelData.front
                                smooth: false; fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.margins: 8
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.name; elide: Text.ElideMiddle
                                color: Theme.text; font.pixelSize: Theme.fontSm
                            }
                            Badge {
                                visible: tile.modelData.inUse
                                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 5
                                text: qsTr("Current"); tone: "success"
                            }
                        }
                        MouseArea {
                            id: tileMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: ev => { mgr.selected = tile.modelData.name; if (ev.button === Qt.RightButton) { skinMenu.skin = tile.modelData.name; skinMenu.popup() } }
                            onDoubleClicked: { mgr.selected = tile.modelData.name; mgr.apply() }
                        }
                    }
                }
                EmptyState {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    iconName: "shirt"
                    title: qsTr("No skins yet")
                    text: qsTr("Add a skin from a file, a URL or another player's username.")
                }
            }
            RowLayout {
                visible: mgr.busy
                spacing: 8
                Spinner { size: 14 }
                Text { text: mgr.busyText; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
            }
        }
    }

    PMenu {
        id: skinMenu
        property string skin
        PMenuItem { text: qsTr("Rename"); iconName: "pencil"; onTriggered: {
            var s = skinMenu.skin
            Dialogs.prompt({ title: qsTr("Rename skin"), value: s, confirmText: qsTr("Rename") }, function(v) { if (v && v.length && v !== s) mgr.rename(s, v) })
        } }
        PMenuItem { text: qsTr("Delete"); iconName: "trash-2"; danger: true; onTriggered: {
            var s = skinMenu.skin
            Dialogs.confirm({ title: qsTr("Delete “%1”?").arg(s), text: qsTr("The skin file is moved to the trash when possible."), confirmText: qsTr("Delete"), danger: true },
                function(ok) { if (ok) { var e = mgr.remove(s); if (e.length) Dialogs.message({ title: qsTr("Delete error"), text: e, kind: "warning" }) } })
        } }
    }

    buttons: [
        PButton {
            text: qsTr("Reset to default skin"); variant: "ghost"; enabled: !mgr.busy
            onClicked: Dialogs.confirm({ title: qsTr("Reset skin?"), text: qsTr("Your account will use the default skin."), confirmText: qsTr("Reset"), danger: true }, function(ok) { if (ok) mgr.resetSkin() })
        },
        PButton { text: qsTr("Cancel"); enabled: !mgr.busy; onClicked: dlg.close() },
        PButton { text: qsTr("Apply skin"); variant: "primary"; iconName: "check"; busy: mgr.busy; enabled: mgr.selected.length > 0 && !mgr.busy; onClicked: mgr.apply() }
    ]
}
