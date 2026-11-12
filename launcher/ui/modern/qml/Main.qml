import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import PrismModern

ApplicationWindow {
    id: window
    width: 1240
    height: 780
    minimumWidth: 900
    minimumHeight: 580
    visible: false
    title: App.appName
    color: Theme.bg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontMd

    palette.window: Theme.bg
    palette.windowText: Theme.text
    palette.base: Theme.input
    palette.text: Theme.text
    palette.button: Theme.surfaceAlt
    palette.buttonText: Theme.text
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.textOnAccent
    palette.placeholderText: Theme.textSubtle
    palette.toolTipBase: Theme.elevated
    palette.toolTipText: Theme.text

    Component.onCompleted: {
        var g = Shell.savedGeometry().split(",")
        if (g.length === 5) {
            var w = parseInt(g[2]), h = parseInt(g[3])
            if (w >= minimumWidth && h >= minimumHeight) { width = w; height = h }
            x = parseInt(g[0]); y = parseInt(g[1])
            if (g[4] === "1") visibility = Window.Maximized
        }
    }
    // first-run onboarding + debug hooks
    Timer {
        interval: 50; running: true
        onTriggered: {
            if (Shell.debugStartPage.length) Router.go(Shell.debugStartPage)
            else if (Shell.setupSteps.length > 0) Router.go("Onboarding")
            if (Shell.debugScreenshotPath.length) shotTimer.start()
        }
    }
    Timer {
        id: shotTimer; interval: 1500
        onTriggered: { Shell.grabWindowTo(Shell.debugScreenshotPath); Shell.debugQuit() }
    }

    onClosing: function(close) {
        Shell.saveGeometry([x, y, width, height, visibility === Window.Maximized ? 1 : 0].join(","))
        Shell.mainWindowClosed()
    }

    // ---- navigation glue ----
    Connections {
        target: Router
        function onGoRequested(page, props) {
            stack.replace(null, Router.pageUrl(page), props)
            Router.depth = stack.depth
        }
        function onPushRequested(page, props) {
            stack.push(Router.pageUrl(page), props)
            Router.depth = stack.depth
        }
        function onBackRequested() {
            if (stack.depth > 1) stack.pop()
            Router.depth = stack.depth
        }
    }
    Connections {
        target: Shell
        function onInstanceRequested(instanceId, page) {
            Router.section = "Library"
            if (stack.currentItem && stack.currentItem.instanceId === instanceId) {
                if (page && stack.currentItem.openTab) stack.currentItem.openTab(page)
                return
            }
            stack.replace(null, Router.pageUrl("Library"))
            Router.push("Instance", { instanceId: instanceId, initialTab: page || "" })
        }
        function onSettingsRequested(page) { Router.go("Settings", { initialPage: page || "" }) }
        function onLauncherLogRequested() { Router.go("LauncherLog") }
        function onImportRequested(urls) { Router.go("NewInstance", { importUrls: urls }) }
    }
    Connections {
        target: App
        function onToast(message, kind) { Toasts.show(message, kind) }
    }

    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; enabled: stack.depth > 1; onActivated: Router.back() }
    Shortcut { sequence: "Ctrl+N"; onActivated: Router.go("NewInstance") }
    
    Shortcut { sequence: "Ctrl+,"; onActivated: Router.go("Settings") }

    // ---- layout ----
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            initialItem: Router.pageUrl("Library")

            readonly property int slide: Theme.reduceMotion ? 0 : 24
            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
                    NumberAnimation { property: "x"; from: stack.slide; to: 0; duration: Theme.durSlow; easing.type: Theme.easingEmph }
                }
            }
            pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
                    NumberAnimation { property: "x"; from: -stack.slide; to: 0; duration: Theme.durSlow; easing.type: Theme.easingEmph }
                }
            }
            popExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
            replaceEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
                    NumberAnimation { property: "y"; from: stack.slide / 2; to: 0; duration: Theme.durSlow; easing.type: Theme.easingEmph }
                }
            }
            replaceExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
        }
    }

    DialogHost { anchors.fill: parent }
    InstanceDialogHost { anchors.fill: parent }
    NiInteractionHost { anchors.fill: parent }   // import/install questions + background task progress
    ToastHost {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingXl
    }
}
