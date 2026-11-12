import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Footer shared by NewInstancePage and DiscoverPage: icon, name (auto-named), group, location, template + Create.
Rectangle {
    id: bar
    property NIController controller: null
    property string initialGroup: controller ? controller.lastGroup : ""
    property bool nameEdited: false
    readonly property string effectiveName: nameField.text.trim().length ? nameField.text.trim() : (controller ? controller.suggestedName : "")

    implicitHeight: row.implicitHeight + 2 * Theme.spacingLg
    color: Theme.surface
    radius: Theme.radiusLg
    border.color: Theme.border

    // auto-naming: follow the selected version/pack until the user types a name
    Connections {
        target: bar.controller
        function onSuggestionChanged() {
            if (!bar.nameEdited) {
                nameField._internal = true
                nameField.text = bar.controller.suggestedName
                nameField._internal = false
            }
        }
    }

    function create() {
        if (!controller || !controller.hasTask) return
        var dirs = controller.instanceDirs
        var dir = dirs.length ? dirs[Math.max(0, dirCombo.currentIndex)].path : ""
        var group = groupCombo.editText.trim()
        var bridge = controller.create(nameField.text.trim(), group, dir, templateBox.checked)
        if (!bridge) return
        NiInteraction.track(bridge, { openInstance: true, successText: qsTr("Created “%1”").arg(bar.effectiveName) })
        nameEdited = false
    }

    Connections { target: bar.controller; function onError(message) { Toasts.error(message) } }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacing

        // icon (opens the icon picker in "pick" mode)
        AbstractButton {
            id: iconBtn
            Layout.preferredWidth: 48; Layout.preferredHeight: 48
            hoverEnabled: true
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: {
                var comp = Qt.createComponent(Qt.resolvedUrl("../../dialogs/IconPickerDialog.qml"))
                var dlg = comp.createObject(bar, { pickMode: true, selectedKey: bar.controller.iconKey })
                dlg.picked.connect(function(key) { bar.controller.iconKey = key })
                dlg.closed.connect(function() { dlg.destroy(500) })
                dlg.open()
            }
            background: Rectangle {
                radius: 12
                color: iconBtn.hovered ? Theme.surfaceHover : Theme.surfaceAlt
                border.color: iconBtn.hovered ? Theme.borderStrong : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
            contentItem: Item {
                Image {
                    anchors.centerIn: parent
                    width: 36; height: 36
                    source: bar.controller ? bar.controller.iconSource : ""
                    sourceSize: Qt.size(72, 72)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Rectangle {
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -3
                    width: 18; height: 18; radius: 9
                    color: Theme.elevated; border.color: Theme.borderStrong
                    opacity: iconBtn.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    Icon { anchors.centerIn: parent; name: "pencil"; size: 10; color: Theme.text }
                }
            }
            PToolTip { visible: iconBtn.hovered; text: qsTr("Change icon") }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 160
            spacing: 4
            Text { text: qsTr("Name"); color: Theme.textMuted; font.pixelSize: Theme.fontXs + 1; font.weight: Font.Medium }
            PTextField {
                id: nameField
                property bool _internal: false
                Layout.fillWidth: true
                placeholderText: bar.controller && bar.controller.suggestedName.length ? bar.controller.suggestedName : qsTr("Instance name")
                onTextChanged: if (!_internal) bar.nameEdited = text.length > 0
                onActiveFocusChanged: if (activeFocus && !bar.nameEdited) selectAll()
                onAccepted: bar.create()
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 180
            spacing: 4
            Text { text: qsTr("Group"); color: Theme.textMuted; font.pixelSize: Theme.fontXs + 1; font.weight: Font.Medium }
            PComboBox {
                id: groupCombo
                Layout.fillWidth: true
                editable: true
                model: [""].concat(App.groups)
                displayText: editText.length ? editText : qsTr("No group")
                Component.onCompleted: { editText = bar.initialGroup; currentIndex = model.indexOf(bar.initialGroup) }
                PToolTip { visible: groupCombo.hovered; text: qsTr("Pick a group or type a new name to create one") }
            }
        }
        ColumnLayout {
            visible: bar.controller && bar.controller.instanceDirs.length > 1
            Layout.preferredWidth: 200
            spacing: 4
            Text { text: qsTr("Location"); color: Theme.textMuted; font.pixelSize: Theme.fontXs + 1; font.weight: Font.Medium }
            PComboBox {
                id: dirCombo
                Layout.fillWidth: true
                model: bar.controller ? bar.controller.instanceDirs : []
                textRole: "label"; valueRole: "path"
                Component.onCompleted: {
                    if (!bar.controller) return
                    var dirs = bar.controller.instanceDirs
                    for (var i = 0; i < dirs.length; i++) if (dirs[i].path === bar.controller.lastDir) currentIndex = i
                }
            }
        }
        PCheckBox {
            id: templateBox
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
            text: qsTr("Use template")
            enabled: bar.controller && bar.controller.templateAvailable
            checked: enabled
            PToolTip { visible: templateBox.hovered; text: templateBox.enabled ? qsTr("Copy the files from the instance template folder into the new instance") : qsTr("Template directory does not exist.") }
        }
        PButton {
            Layout.alignment: Qt.AlignBottom
            size: "lg"
            variant: "primary"
            iconName: "plus"
            text: qsTr("Create")
            enabled: bar.controller !== null && bar.controller.hasTask && bar.effectiveName.length > 0
            onClicked: bar.create()
        }
    }
}
