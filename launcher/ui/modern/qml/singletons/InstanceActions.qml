pragma Singleton
import QtQuick
import PrismModern

// Shared instance actions with confirmations / toasts.
QtObject {
    signal dialogRequested(string kind, string instanceId)   // handled by InstanceDialogs (in Main)

    function confirmDelete(id) {
        var info = App.instances.get(id)
        var shortcuts = App.instanceShortcuts(id)
        Dialogs.confirm({
            title: qsTr("Delete “%1”?").arg(info.name),
            text: qsTr("This will delete the instance%1. Deleted instances are moved to the trash when possible.")
                    .arg(shortcuts.length ? (shortcuts.length === 1 ? qsTr(" and its shortcut") : qsTr(" and its %1 shortcuts").arg(shortcuts.length)) : ""),
            confirmText: qsTr("Delete"), danger: true
        }, function(ok) {
            if (!ok) return
            var err = App.deleteInstance(id)
            if (err.length) { Toasts.error(err); return }
            if (App.canUndoDelete)
                Toasts.show(qsTr("Deleted “%1”").arg(info.name), "info", { text: qsTr("Undo"), run: function() { App.undoDelete() } })
            else
                Toasts.show(qsTr("Deleted “%1”").arg(info.name), "info")
        })
    }
    function open(kind, id) { dialogRequested(kind, id) }
}
