import QtQuick
import QtQuick.Layouts
import PrismModern

PDialog {
    id: dlg
    property string instanceId
    readonly property var info: App.instances.get(instanceId)
    title: qsTr("Change group")
    subtitle: info.name || ""
    iconName: "layers"
    maxWidth: 420

    PComboBox {
        id: combo
        Layout.fillWidth: true
        editable: true
        model: [""].concat(App.groups)
        displayText: editText.length ? editText : qsTr("No group")
        Component.onCompleted: { editText = dlg.info.group || ""; currentIndex = model.indexOf(dlg.info.group || "") }
    }
    Text { text: qsTr("Type a new name to create a group. Leave empty to remove the instance from its group."); color: Theme.textSubtle; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap; Layout.fillWidth: true }
    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Save"); variant: "primary"; onClicked: { App.setInstanceGroup(dlg.instanceId, combo.editText); dlg.close() } }
    ]
}
