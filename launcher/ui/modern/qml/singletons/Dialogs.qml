pragma Singleton
import QtQuick

// Global, promise-like dialogs rendered by DialogHost in Main.qml.
//   Dialogs.confirm({ title, text, confirmText, danger: true }, function(ok) { ... })
//   Dialogs.prompt({ title, text, value, placeholder, confirmText }, function(value) { ... })   // value === null when cancelled
//   Dialogs.message({ title, text, kind })   // kind: info | warning | error
QtObject {
    signal confirmRequested(var opts, var callback)
    signal promptRequested(var opts, var callback)
    signal messageRequested(var opts)
    function confirm(opts, cb) { confirmRequested(opts, cb || function() {}) }
    function prompt(opts, cb) { promptRequested(opts, cb || function() {}) }
    function message(opts) { messageRequested(opts) }
}
