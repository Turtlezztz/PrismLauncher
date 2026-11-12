import QtQuick
import PrismModern

// App-wide listeners for the settings area (instantiated once, by AccountSwitcher in the sidebar):
//  - Java messages raised by core code (JavaCommon: JVM argument checks while launching, …) → QML dialogs
//  - updates offered by the updater → toast + changelog dialog
Item {
    id: hooks
    visible: false

    Connections {
        target: SettingsBackend
        function onJavaMessage(kind, title, message) {
            Dialogs.message({ title: title, text: message, kind: kind === "success" ? "info" : kind })
        }
    }
    Connections {
        target: LauncherInfo
        function onUpdateOffered(version) {
            Toasts.show(qsTr("%1 %2 is available").arg(LauncherInfo.name).arg(version), "info", { text: qsTr("View"), run: function() { hooks.openUpdate() } })
        }
    }
    function openUpdate() {
        var comp = Qt.createComponent(Qt.resolvedUrl("SetUpdateDialog.qml"))
        if (comp.status !== Component.Ready) { console.warn(comp.errorString()); return }
        var dlg = comp.createObject(hooks)
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
    }
}
