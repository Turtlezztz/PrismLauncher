import QtQuick
import PrismModern

// Opens per-instance dialogs from qml/dialogs on InstanceActions.open(kind, id).
// Convention: dialogs/<Name>Dialog.qml has a root PDialog with `property string instanceId`.
Item {
    id: host
    readonly property var kinds: ({
        icon: "IconPicker", group: "ChangeGroup", copy: "CopyInstance", export: "ExportInstance", shortcut: "CreateShortcut"
    })
    Connections {
        target: InstanceActions
        function onDialogRequested(kind, instanceId) {
            var name = host.kinds[kind] || kind
            var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/" + name + "Dialog.qml"))
            if (comp.status !== Component.Ready) { console.warn(comp.errorString()); Toasts.error(qsTr("Could not open dialog")); return }
            var dlg = comp.createObject(host, { instanceId: instanceId })
            dlg.closed.connect(function() { dlg.destroy(500) })
            dlg.open()
        }
    }
}
