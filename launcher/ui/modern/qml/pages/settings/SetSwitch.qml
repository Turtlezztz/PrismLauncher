import QtQuick
import PrismModern

// Switch bound to a boolean setting in the settings draft.  SetSwitch { key: "ShowConsole" }  (invert: store !value)
PSwitch {
    id: control
    property var store: null
    property string key: ""
    property bool invert: false
    checked: store ? (store.getBool(key) !== invert) : false
    onToggled: if (store) store.set(key, checked !== invert)
    Component.onCompleted: if (!store) { var p = parent; while (p && p.isSettingsPage !== true) p = p.parent; if (p) store = Qt.binding(function() { return p.store }) }
}
