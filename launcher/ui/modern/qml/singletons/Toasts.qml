pragma Singleton
import QtQuick

// Toast notifications.  Toasts.show("Saved", "success")
// kinds: info | success | warning | error.  Optional action: { text: "Undo", run: function() {...} }
QtObject {
    signal posted(string message, string kind, var action)
    function show(message, kind, action) { posted(message, kind || "info", action || null) }
    function error(message) { posted(message, "error", null) }
    function success(message) { posted(message, "success", null) }
}
