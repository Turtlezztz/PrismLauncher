import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Copy an instance (classic CopyInstanceDialog): name, group, icon, what to copy, and link/clone options.
PDialog {
    id: dlg
    property string instanceId
    property string iconKey: copier.originalIcon

    title: qsTr("Copy instance")
    subtitle: copier.originalName
    iconName: "copy"
    maxWidth: 600

    NICopyInstance { id: copier; instanceId: dlg.instanceId }

    readonly property bool linksInUse: copier.useSymLinks || copier.useHardLinks
    readonly property var contentOptions: [
        { key: "copySaves", text: qsTr("Worlds (saves)") },
        { key: "copyGameOptions", text: qsTr("Game options") },
        { key: "copyMods", text: qsTr("Mods") },
        { key: "copyResourcePacks", text: qsTr("Resource packs") },
        { key: "copyShaderPacks", text: qsTr("Shader packs") },
        { key: "copyServers", text: qsTr("Servers") },
        { key: "copyScreenshots", text: qsTr("Screenshots") },
        { key: "keepPlaytime", text: qsTr("Play time") }
    ]
    readonly property bool allChecked: contentOptions.every(o => copier[o.key])

    function pickIcon() {
        var comp = Qt.createComponent(Qt.resolvedUrl("IconPickerDialog.qml"))
        var picker = comp.createObject(dlg.parent, { pickMode: true, selectedKey: dlg.iconKey })
        picker.picked.connect(function(key) { dlg.iconKey = key })
        picker.closed.connect(function() { picker.destroy(500) })
        picker.open()
    }
    function accept() {
        var name = nameField.text.trim()
        if (!name.length) return
        var bridge = copier.copy(name, groupCombo.editText.trim(), dlg.iconKey)
        if (bridge) NiInteraction.track(bridge, { openInstance: true, successText: qsTr("Copied to “%1”").arg(name) })
        dlg.close()
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
            PTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Name")
                text: copier.originalName
                onAccepted: dlg.accept()
                Component.onCompleted: { forceActiveFocus(); selectAll() }
            }
            PComboBox {
                id: groupCombo
                Layout.fillWidth: true
                editable: true
                model: [""].concat(App.groups)
                displayText: editText.length ? editText : qsTr("No group")
                Component.onCompleted: { editText = copier.originalGroup; currentIndex = model.indexOf(copier.originalGroup) }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingSm
        Text { text: qsTr("Copy"); color: Theme.text; font.weight: Font.DemiBold; Layout.fillWidth: true }
        PCheckBox {
            text: qsTr("Select all")
            checkable: false
            checkState: dlg.allChecked ? Qt.Checked : Qt.Unchecked
            onClicked: { var v = !dlg.allChecked; dlg.contentOptions.forEach(o => copier[o.key] = v) }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.spacingLg
        rowSpacing: 2
        Repeater {
            model: dlg.contentOptions
            delegate: PCheckBox {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.text
                checkable: false
                checkState: copier[modelData.key] ? Qt.Checked : Qt.Unchecked
                onClicked: {
                    copier[modelData.key] = !copier[modelData.key]
                    if (modelData.key === "copySaves" && !copier.copySaves) copier.dontLinkSaves = false
                }
            }
        }
    }

    // ---- advanced: links / reflinks ----
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingSm
        radius: Theme.radius
        color: Theme.surfaceAlt
        border.color: Theme.border
        implicitHeight: adv.implicitHeight + 24
        ColumnLayout {
            id: adv
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 2
            Text { text: qsTr("Advanced copying"); color: Theme.text; font.weight: Font.DemiBold; font.pixelSize: Theme.fontMd }
            Text {
                Layout.fillWidth: true
                text: (copier.linkSupported ? qsTr("Links are supported on %1.") : qsTr("Links aren't supported on %1.")).arg(copier.filesystem)
                      + " " + (copier.cloneSupported ? qsTr("Reflinks (copy-on-write) are supported.") : qsTr("Reflinks (copy-on-write) aren't supported."))
                color: Theme.textMuted; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
            }
            PCheckBox {
                text: qsTr("Use symbolic links")
                enabled: copier.linkSupported && !copier.useHardLinks && !copier.useClone
                checkable: false
                checkState: copier.useSymLinks && enabled ? Qt.Checked : Qt.Unchecked
                onClicked: copier.useSymLinks = !copier.useSymLinks
                PToolTip { visible: parent.hovered; text: App.platform === "windows" ? qsTr("On Windows, symbolic links may require admin permission to create.") : qsTr("Use symbolic links instead of copying files.") }
            }
            PCheckBox {
                text: qsTr("Use hard links")
                enabled: copier.linkSupported && !copier.useSymLinks && !copier.useClone
                checkable: false
                checkState: copier.useHardLinks && enabled ? Qt.Checked : Qt.Unchecked
                onClicked: { copier.useHardLinks = !copier.useHardLinks; if (copier.useHardLinks) copier.linkRecursively = true }
                PToolTip { visible: parent.hovered; text: qsTr("Hard links share file contents; changes in one instance affect the other.") }
            }
            PCheckBox {
                Layout.leftMargin: 24
                text: qsTr("Link files recursively")
                enabled: copier.linkSupported && dlg.linksInUse && !copier.useHardLinks
                checkable: false
                checkState: copier.linkRecursively && dlg.linksInUse ? Qt.Checked : Qt.Unchecked
                onClicked: copier.linkRecursively = !copier.linkRecursively
            }
            PCheckBox {
                Layout.leftMargin: 24
                text: qsTr("Don't link saves (copy them instead)")
                enabled: copier.linkSupported && dlg.linksInUse
                checkable: false
                checkState: copier.dontLinkSaves && dlg.linksInUse ? Qt.Checked : Qt.Unchecked
                onClicked: copier.dontLinkSaves = !copier.dontLinkSaves
            }
            PCheckBox {
                text: qsTr("Clone instead of copying (reflink / copy-on-write)")
                enabled: copier.cloneSupported && !dlg.linksInUse
                checkable: false
                checkState: copier.useClone && enabled ? Qt.Checked : Qt.Unchecked
                onClicked: copier.useClone = !copier.useClone
            }
        }
    }

    buttons: [
        PButton { text: qsTr("Help"); variant: "ghost"; iconName: "book"; onClicked: App.openUrl("https://prismlauncher.org/wiki/help-pages/instance-copy") },
        Item { width: Theme.spacingLg; height: 1 },
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Copy"); variant: "primary"; iconName: "copy"; enabled: nameField.text.trim().length > 0; onClicked: dlg.accept() }
    ]
}
