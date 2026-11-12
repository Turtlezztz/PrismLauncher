import QtQuick
import PrismModern

// Spin box bound to an integer setting in the settings draft.
PSpinBox {
    id: control
    property var store: null
    property string key: ""
    from: 0; to: 100000
    value: store ? store.getInt(key) : 0
    onValueModified: if (store) store.set(key, value)
    Component.onCompleted: if (!store) { var p = parent; while (p && p.isSettingsPage !== true) p = p.parent; if (p) store = Qt.binding(function() { return p.store }) }
}
