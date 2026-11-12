import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Create a desktop / applications / custom shortcut that launches the instance (classic CreateShortcutDialog),
// optionally with a specific account or straight into a world / server.
PDialog {
    id: dlg
    property string instanceId
    property string iconKey: sc.iconKey
    property string launchTarget: ""   // "" | world | server

    title: qsTr("Create shortcut")
    subtitle: sc.instanceName
    iconName: "link"
    maxWidth: 560

    NIShortcut { id: sc; instanceId: dlg.instanceId }

    readonly property string worldName: worldCombo.currentIndex >= 0 && sc.worlds.length ? sc.worlds[worldCombo.currentIndex].value : ""
    readonly property string defaultName: launchTarget === "world" && worldName.length ? qsTr("%1 - %2").arg(sc.instanceName).arg(worldName)
                                        : launchTarget === "server" && serverField.text.length ? qsTr("%1 - Server %2").arg(sc.instanceName).arg(serverField.text)
                                        : sc.instanceName
    readonly property bool valid: launchTarget === "" || (launchTarget === "world" && worldName.length > 0) || (launchTarget === "server" && serverField.text.trim().length > 0)
    readonly property string target: targetCombo.currentValue || "desktop"

    function pickIcon() {
        var comp = Qt.createComponent(Qt.resolvedUrl("IconPickerDialog.qml"))
        var picker = comp.createObject(dlg.parent, { pickMode: true, selectedKey: dlg.iconKey })
        picker.picked.connect(function(key) { dlg.iconKey = key })
        picker.closed.connect(function() { picker.destroy(500) })
        picker.open()
    }
    function create(otherFile) {
        var err = sc.create(nameField.text, dlg.target, dlg.launchTarget, dlg.worldName, serverField.text.trim(),
                            accountBox.checked ? accountCombo.currentValue : "", dlg.iconKey, otherFile || "")
        if (err.length) { Toasts.error(err); return }
        var what = launchTarget === "world" ? qsTr("world") : launchTarget === "server" ? qsTr("server") : qsTr("instance")
        Toasts.success(dlg.target === "desktop" ? qsTr("Created a shortcut to this %1 on your desktop").arg(what)
                     : dlg.target === "applications" ? qsTr("Created a shortcut to this %1 in your applications folder").arg(what)
                     : qsTr("Created a shortcut to this %1").arg(what))
        dlg.close()
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Create shortcut")
        fileMode: FileDialog.SaveFile
        nameFilters: sc.otherExtension.length ? [qsTr("Desktop entries (*%1)").arg(sc.otherExtension)] : []
        onAccepted: dlg.create(selectedFile)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing
        AbstractButton {
            id: iconBtn
            Layout.preferredWidth: 56; Layout.preferredHeight: 56
            hoverEnabled: true
            onClicked: dlg.pickIcon()
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            background: Rectangle { radius: 14; color: iconBtn.hovered ? Theme.surfaceHover : Theme.surfaceAlt; border.color: Theme.border }
            contentItem: Item { Image { anchors.centerIn: parent; width: 40; height: 40; source: "image://instanceicon/" + dlg.iconKey; sourceSize: Qt.size(80, 80) } }
            PToolTip { visible: iconBtn.hovered; text: qsTr("Change icon") }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            PTextField { id: nameField; Layout.fillWidth: true; placeholderText: dlg.defaultName }
            PComboBox {
                id: targetCombo
                Layout.fillWidth: true
                model: sc.targets
                textRole: "text"; valueRole: "value"
                displayText: qsTr("Save to: %1").arg(currentText)
            }
        }
    }

    FormRow {
        label: qsTr("Launch target")
        description: sc.quickJoinSupported ? qsTr("Open the game straight into a world or join a server") : qsTr("Join a server right after launch")
        SegmentedControl {
            options: sc.quickJoinSupported && sc.worlds.length
                     ? [ { value: "", text: qsTr("Instance") }, { value: "world", text: qsTr("World") }, { value: "server", text: qsTr("Server") } ]
                     : [ { value: "", text: qsTr("Instance") }, { value: "server", text: qsTr("Server") } ]
            value: dlg.launchTarget
            onActivated: v => dlg.launchTarget = v
        }
    }
    PComboBox {
        id: worldCombo
        Layout.fillWidth: true
        visible: dlg.launchTarget === "world"
        model: sc.worlds
        textRole: "text"; valueRole: "value"
    }
    PTextField {
        id: serverField
        Layout.fillWidth: true
        visible: dlg.launchTarget === "server"
        placeholderText: qsTr("Server address, e.g. play.example.com:25565")
        iconName: "server"
    }

    FormRow {
        label: qsTr("Use a specific account")
        description: sc.accounts.length ? qsTr("Otherwise the default account is used") : qsTr("No accounts added yet")
        PSwitch { id: accountBox; enabled: sc.accounts.length > 0 }
    }
    PComboBox {
        id: accountCombo
        Layout.fillWidth: true
        visible: accountBox.checked
        model: sc.accounts
        textRole: "text"; valueRole: "value"
        Component.onCompleted: currentIndex = sc.defaultAccount
    }

    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton {
            text: dlg.target === "other" ? qsTr("Choose location…") : qsTr("Create")
            variant: "primary"; iconName: "link"
            enabled: dlg.valid
            onClicked: {
                if (dlg.target === "other") {
                    saveDialog.selectedFile = sc.suggestedOtherFile(nameField.text.length ? nameField.text : dlg.defaultName)
                    saveDialog.open()
                } else dlg.create("")
            }
        }
    ]
}
