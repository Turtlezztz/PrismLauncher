import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Component list of the instance (classic VersionPage): versions, loaders, jar mods, agents, custom components.
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge
    property string selectedUid: ""

    ComponentListModel {
        id: components
        instanceId: tab.instanceId
        onError: (title, message) => Dialogs.message({ title: title, text: message, kind: "error" })
        onInfo: (message) => Toasts.show(message, "success")
    }
    InstVersionSelectDialog { id: versionDialog }
    InstInstallLoaderDialog { id: loaderDialog }

    function changeVersion(c) {
        if (!c || !c.versionChangeable) return
        var opts = {
            uid: c.uid,
            title: qsTr("Change %1 version").arg(c.name),
            current: c.version.replace(/ \((Custom|auto-update)\)$/, ""),
            extraRecommended: components.recommendedVersionFor(c.uid),
        }
        if (c.uid !== "net.minecraft") opts.parentVersion = bridge.minecraftVersion
        if (c.uid === "net.fabricmc.intermediary" || c.uid === "org.quiltmc.hashed")
            opts.emptyText = qsTr("No intermediary mappings versions are currently available.")
        versionDialog.pick(opts, function(v) {
            components.changeVersion(c.uid, v.descriptor)
            Toasts.show(qsTr("%1 set to %2").arg(c.name).arg(v.versionName), "success")
        })
    }
    function remove(c) {
        var doRemove = function() {
            var err = components.remove(c.uid)
            if (err.length) Toasts.error(err)
            else Toasts.show(qsTr("Removed %1").arg(c.name), "info")
        }
        Dialogs.confirm({ title: qsTr("Remove “%1”?").arg(c.name),
                          text: c.custom ? qsTr("This is permanent and will completely remove the custom component.")
                                         : qsTr("The component will be removed from this instance."),
                          confirmText: qsTr("Remove"), danger: true }, function(ok) { if (ok) doRemove() })
    }
    function revert(c) {
        Dialogs.confirm({ title: qsTr("Revert “%1”?").arg(c.name),
                          text: qsTr("This is permanent and will completely revert your customizations."),
                          confirmText: qsTr("Revert"), danger: true }, function(ok) { if (ok) components.revert(c.uid) })
    }
    function addEmpty() { emptyDialog.open() }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        // ---- toolbar ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            SearchField {
                Layout.preferredWidth: 240
                placeholderText: qsTr("Filter components")
                onTextChanged: components.filterText = text
            }
            Item { Layout.fillWidth: true }
            PButton {
                size: "sm"; variant: "subtle"; iconName: "hammer"; text: qsTr("Install loader")
                onClicked: loaderDialog.openFor(components, tab.bridge.minecraftVersion, "")
            }
            PButton {
                id: addBtn
                size: "sm"; iconName: "plus"; text: qsTr("Add"); trailingIconName: "chevron-down"
                onClicked: addMenu.popup(addBtn, 0, addBtn.height + 4)
            }
            PButton {
                size: "sm"; iconName: "download"; text: qsTr("Download all")
                enabled: !components.busy
                onClicked: components.downloadAll()
                PToolTip { visible: parent.hovered; text: qsTr("Download the files needed to launch the instance now.") }
            }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Reload all components"); enabled: !components.busy; onClicked: components.reload() }
            IconButton { id: moreBtn; iconName: "ellipsis"; tip: qsTr("More"); onClicked: moreMenu.popup(moreBtn, 0, moreBtn.height + 4) }
        }

        // ---- busy ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: components.busy ? 40 : 0
            opacity: components.busy ? 1 : 0
            visible: Layout.preferredHeight > 0
            clip: true
            radius: Theme.radius
            color: Theme.accentSoft
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                spacing: Theme.spacing
                Spinner { size: 16; visible: components.busy }
                Text { Layout.fillWidth: true; text: components.busyStatus.length ? components.busyStatus : qsTr("Updating components…"); color: Theme.text; elide: Text.ElideRight; font.pixelSize: Theme.fontMd }
                PProgressBar { Layout.preferredWidth: 180; indeterminate: components.busyProgress < 0; value: Math.max(0, components.busyProgress) }
            }
        }

        // ---- list ----
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
                anchors.margins: 6
                model: components
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: PScrollBar {}
                displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }
                move: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property string uid
                    required property string name
                    required property string version
                    required property bool componentEnabled
                    required property bool canBeDisabled
                    required property string severity
                    required property var problems
                    required property bool removable
                    required property bool moveable
                    required property bool versionChangeable
                    required property bool customizable
                    required property bool revertible
                    required property bool custom
                    required property bool loader
                    required property bool dependencyOnly
                    required property string releaseDate
                    readonly property bool selected: tab.selectedUid === uid
                    readonly property var info: ({ uid: uid, name: name, version: version, versionChangeable: versionChangeable, custom: custom })

                    width: list.width
                    height: rowCol.implicitHeight + 20
                    radius: Theme.radius
                    color: selected ? Theme.accentSoft : rowHover.hovered ? Theme.surfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    HoverHandler { id: rowHover }
                    TapHandler {
                        onTapped: tab.selectedUid = row.uid
                        onDoubleTapped: tab.changeVersion(row.info)
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: { tab.selectedUid = row.uid; compMenu.target = row; compMenu.popup() }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: Theme.spacing

                        PCheckBox {
                            Layout.preferredWidth: 26
                            Layout.fillWidth: false
                            checked: row.componentEnabled
                            enabled: row.canBeDisabled
                            opacity: row.canBeDisabled ? 1 : 0.35
                            onToggled: components.setEnabled(row.uid, checked)
                            PToolTip { visible: parent.hovered && row.canBeDisabled; text: row.componentEnabled ? qsTr("Disable component") : qsTr("Enable component") }
                        }
                        Rectangle {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10
                            color: row.severity === "error" ? Theme.soft(Theme.danger) : row.severity === "warning" ? Theme.soft(Theme.warning)
                                 : row.loader ? Theme.accentSoft : Theme.surfaceAlt
                            Icon {
                                anchors.centerIn: parent; size: 17
                                name: row.severity === "error" ? "circle-alert" : row.severity === "warning" ? "triangle-alert"
                                    : row.uid === "net.minecraft" ? "box" : row.loader ? "hammer" : row.uid.indexOf("lwjgl") >= 0 ? "cpu"
                                    : row.custom ? "wrench" : "package"
                                color: row.severity === "error" ? Theme.danger : row.severity === "warning" ? Theme.warning
                                     : row.loader ? Theme.accent : Theme.textMuted
                            }
                        }
                        ColumnLayout {
                            id: rowCol
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: row.name
                                    color: row.componentEnabled ? Theme.text : Theme.textSubtle
                                    font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                                    font.strikeout: !row.componentEnabled
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: list.width * 0.4
                                }
                                Badge { visible: row.custom; text: qsTr("Custom"); tone: "info" }
                                Badge { visible: row.dependencyOnly; text: qsTr("Dependency") }
                                Badge { visible: !row.componentEnabled; text: qsTr("Disabled"); tone: "warning" }
                                Item { Layout.fillWidth: true }
                            }
                            Text { text: row.uid; color: Theme.textSubtle; font.pixelSize: Theme.fontXs; font.family: Theme.monoFamily }
                            Repeater {
                                model: row.problems
                                delegate: Row {
                                    required property var modelData
                                    spacing: 6
                                    Icon { name: modelData.severity === "error" ? "circle-alert" : "triangle-alert"; size: 12; color: modelData.severity === "error" ? Theme.danger : Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: modelData.text
                                        width: Math.min(implicitWidth, list.width - 260)
                                        wrapMode: Text.Wrap
                                        color: modelData.severity === "error" ? Theme.danger : Theme.warning
                                        font.pixelSize: Theme.fontSm
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            spacing: 1
                            Layout.preferredWidth: 150
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                            Text { Layout.alignment: Qt.AlignRight; text: row.version; color: Theme.text; font.pixelSize: Theme.fontMd; font.family: Theme.monoFamily }
                            Text { Layout.alignment: Qt.AlignRight; visible: row.releaseDate.length > 0; text: row.releaseDate; color: Theme.textSubtle; font.pixelSize: Theme.fontXs }
                        }
                        Row {
                            spacing: 2
                            Layout.preferredWidth: 66
                            opacity: rowHover.hovered || row.selected ? 1 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            IconButton { iconName: "arrow-up-down"; tip: qsTr("Change version"); enabled: row.versionChangeable; onClicked: tab.changeVersion(row.info) }
                            IconButton {
                                id: rowMore
                                iconName: "ellipsis-vertical"; tip: qsTr("More")
                                onClicked: { tab.selectedUid = row.uid; compMenu.target = row; compMenu.popup(rowMore, rowMore.width - compMenu.width, rowMore.height) }
                            }
                        }
                    }
                }
            }
            EmptyState {
                anchors.centerIn: parent
                visible: list.count === 0
                iconName: "layers"
                title: qsTr("No components")
                text: components.filterText.length ? qsTr("Nothing matches the filter.") : qsTr("This instance has no components yet.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: components.autoUpdateMinecraft
            Icon { name: "refresh-cw"; size: 13; color: Theme.textSubtle }
            Text { text: qsTr("Minecraft is updated automatically to the latest version (see Settings › Minecraft version)."); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
        }
    }

    // ---- menus ----
    PMenu {
        id: compMenu
        property var target: null
        readonly property var t: target || ({})
        PMenuItem { text: qsTr("Change version…"); iconName: "arrow-up-down"; enabled: !!compMenu.t.versionChangeable; onTriggered: tab.changeVersion(compMenu.t.info) }
        PMenuItem {
            text: compMenu.t.componentEnabled ? qsTr("Disable") : qsTr("Enable"); iconName: "toggle-left"; enabled: !!compMenu.t.canBeDisabled
            onTriggered: components.setEnabled(compMenu.t.uid, !compMenu.t.componentEnabled)
        }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Move up"); iconName: "arrow-up"; enabled: !!compMenu.t.moveable; onTriggered: components.moveUp(compMenu.t.uid) }
        PMenuItem { text: qsTr("Move down"); iconName: "arrow-down"; enabled: !!compMenu.t.moveable; onTriggered: components.moveDown(compMenu.t.uid) }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Customize"); iconName: "wrench"; enabled: !!compMenu.t.customizable; onTriggered: components.customize(compMenu.t.uid) }
        PMenuItem { text: qsTr("Edit JSON"); iconName: "file-text"; enabled: !!compMenu.t.custom; onTriggered: components.edit(compMenu.t.uid) }
        PMenuItem { text: qsTr("Revert"); iconName: "rotate-ccw"; enabled: !!compMenu.t.revertible; onTriggered: tab.revert(compMenu.t.info) }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Remove"); iconName: "trash-2"; danger: true; enabled: !!compMenu.t.removable; onTriggered: tab.remove(compMenu.t.info) }
    }
    PMenu {
        id: addMenu
        implicitWidth: 250
        PMenuItem { text: qsTr("Add to Minecraft.jar…"); iconName: "archive"; onTriggered: components.addJarMods() }
        PMenuItem { text: qsTr("Replace Minecraft.jar…"); iconName: "file-archive"; onTriggered: components.replaceMinecraftJar() }
        PMenuItem { text: qsTr("Add Java agents…"); iconName: "coffee"; onTriggered: components.addAgents() }
        PMenuItem { text: qsTr("Import components…"); iconName: "file-text"; onTriggered: components.importComponents() }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Add empty component…"); iconName: "plus"; onTriggered: tab.addEmpty() }
    }
    PMenu {
        id: moreMenu
        implicitWidth: 230
        PMenuItem { text: qsTr("Open .minecraft folder"); iconName: "folder-open"; onTriggered: tab.bridge.openFolder("game") }
        PMenuItem { text: qsTr("Open libraries folder"); iconName: "folder-open"; onTriggered: tab.bridge.openFolder("libraries") }
    }

    // ---- add empty component ----
    PDialog {
        id: emptyDialog
        title: qsTr("Add empty component")
        subtitle: qsTr("Creates a custom component you can then edit as JSON.")
        iconName: "plus"
        maxWidth: 460
        onAboutToShow: { nameField.text = ""; uidField.text = "" }
        onOpened: nameField.forceActiveFocus()
        readonly property string uid: uidField.text.trim().length ? uidField.text.trim() : components.suggestUid(nameField.text)
        readonly property string problem: components.validateEmpty(uid, nameField.text)
        FormRow {
            label: qsTr("Name"); stacked: true
            PTextField { id: nameField; width: parent.width; placeholderText: qsTr("My component") }
        }
        FormRow {
            label: qsTr("Uid"); stacked: true
            PTextField { id: uidField; width: parent.width; placeholderText: components.suggestUid(nameField.text) || "org.multimc.custom.example" }
        }
        Text {
            Layout.fillWidth: true
            visible: (nameField.text.length > 0 || uidField.text.length > 0) && emptyDialog.problem.length > 0
            text: emptyDialog.problem; color: Theme.danger; font.pixelSize: Theme.fontSm
        }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: emptyDialog.close() },
            PButton {
                text: qsTr("Add"); variant: "primary"; enabled: emptyDialog.problem.length === 0
                onClicked: { components.addEmpty(emptyDialog.uid, nameField.text); emptyDialog.close() }
            }
        ]
    }
}
