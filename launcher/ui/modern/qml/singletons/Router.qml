pragma Singleton
import QtQuick

// Navigation state. Pages live in qml/pages/<Name>.qml.
//   Router.go("Settings", { page: "java" })      -> replace the whole stack with a top-level section
//   Router.push("Instance", { instanceId: id })   -> push a detail page
//   Router.back()
QtObject {
    id: router

    property string section: "Library"     // highlighted sidebar item
    property int depth: 1

    signal goRequested(string page, var props)
    signal pushRequested(string page, var props)
    signal backRequested()

    function pageUrl(name) { return Qt.resolvedUrl("../pages/" + name + "Page.qml") }

    function go(page, props) { section = page; goRequested(page, props || {}) }
    function push(page, props) { pushRequested(page, props || {}) }
    function back() { backRequested() }
}
