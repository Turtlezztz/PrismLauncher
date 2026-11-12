import QtQuick
import PrismModern

// Text field bound to a string setting in the settings draft.
PTextField {
    id: control
    property var store: null
    property string key: ""
    implicitWidth: 320
    text: store ? store.getString(key) : ""
    onTextEdited: if (store) store.set(key, text)
    Component.onCompleted: if (!store) { var p = parent; while (p && p.isSettingsPage !== true) p = p.parent; if (p) store = Qt.binding(function() { return p.store }) }
}
