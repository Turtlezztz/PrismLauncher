import QtQuick
import PrismModern

// Combo box bound to a setting in the settings draft.  options: [{ value, text }]
PComboBox {
    id: control
    property var store: null
    property string key: ""
    property var options: []
    model: options
    textRole: "text"
    valueRole: "value"
    implicitWidth: 240
    currentIndex: {
        if (!store) return -1
        var v = store.get(key)
        for (var i = 0; i < options.length; i++) if (String(options[i].value) === String(v)) return i
        return 0
    }
    onActivated: if (store) store.set(key, options[currentIndex].value)
    Component.onCompleted: if (!store) { var p = parent; while (p && p.isSettingsPage !== true) p = p.parent; if (p) store = Qt.binding(function() { return p.store }) }
}
