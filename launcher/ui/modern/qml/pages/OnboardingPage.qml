import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// First-run setup (classic SetupWizard). Steps come from Shell.setupSteps:
// language, java, autojava, paste, theme, login.
Item {
    id: page
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) {}

    // keep the steps fixed while the flow runs; fall back to a short tour when opened manually
    property var steps: Shell.setupSteps.length ? Shell.setupSteps.slice() : ["theme", "login"]
    property int current: 0
    readonly property string step: steps[current] || ""
    readonly property bool last: current === steps.length - 1

    readonly property var meta: ({
        language: { title: qsTr("Language"), icon: "languages", heading: qsTr("Welcome to %1").arg(App.appName), text: qsTr("Let's get a few things set up. This only takes a minute.") },
        java: { title: qsTr("Java"), icon: "coffee", heading: qsTr("Set up Java"), text: qsTr("Minecraft needs Java to run. The launcher can manage it for you.") },
        autojava: { title: qsTr("Java downloads"), icon: "download", heading: qsTr("Automatic Java downloads"), text: qsTr("The launcher can automatically download the correct Java version for each version of Minecraft. You can change this later in the Java settings.") },
        paste: { title: qsTr("Log uploads"), icon: "upload", heading: qsTr("Paste service changed"), text: qsTr("The default paste service has changed to mclo.gs. Choose what to do with your settings.") },
        theme: { title: qsTr("Appearance"), icon: "palette", heading: qsTr("Make it yours"), text: qsTr("Pick a theme and an accent color. You can change these any time in Settings → Appearance.") },
        login: { title: qsTr("Account"), icon: "user", heading: qsTr("Add your Microsoft account"), text: qsTr("To play Minecraft you need at least one Microsoft account that owns the game.") }
    })

    Component.onCompleted: {
        Router.section = "Onboarding"
        // debug (screenshots): PRISM_MODERN_SETTINGS_PAGE=<step> shows the full flow at that step
        var all = ["language", "java", "autojava", "paste", "theme", "login"]
        if (all.indexOf(SettingsBackend.debugPage) >= 0) { steps = all; current = all.indexOf(SettingsBackend.debugPage) }
    }

    function finish() {
        Shell.finishSetup()
        Router.go("Library")
    }
    function next() {
        if (!validate()) return
        if (last) finish(); else current++
    }
    function back() { if (current > 0) current-- }

    // apply the step's choices; return false to stay on the step
    function validate() {
        switch (step) {
        case "language":
            App.setSetting("Language", "en_US")
            App.setSetting("UseSystemLocale", sysLocale.checked)
            SettingsBackend.setUseSystemLocale(sysLocale.checked)
            return true
        case "java":
            App.setSetting("AutomaticJavaSwitch", autoDetect.checked)
            App.setSetting("AutomaticJavaDownload", autoDetect.checked && autoDownload.checked)
            App.setSetting("UserAskedAboutAutomaticJavaDownload", true)
            var path = javaPath.text.trim()
            var ok = path.length > 0 && SettingsBackend.executableResolves(path)
            var save = function() {
                if (ok) App.setSetting("JavaPath", path)
                var mn = Math.min(minMem.value, maxMem.value), mx = Math.max(minMem.value, maxMem.value)
                App.setSetting("MinMemAlloc", mn); App.setSetting("MaxMemAlloc", mx)
            }
            if (!ok && !(SettingsBackend.javaDownloaderEnabled && autoDetect.checked && autoDownload.checked)) {
                Dialogs.confirm({ title: qsTr("No Java version selected"), confirmText: qsTr("Continue anyway"),
                                  text: qsTr("You either didn't select a Java version or selected one that does not work. %1 will not be able to start Minecraft.<br><br>Do you wish to proceed without a functional version of Java? You can change the Java version in the settings later.").arg(App.appName) },
                                function(yes) { if (yes) { save(); if (page.last) page.finish(); else page.current++ } })
                return false
            }
            save()
            return true
        case "autojava":
            if (autoEnable.checked) { App.setSetting("AutomaticJavaSwitch", true); App.setSetting("AutomaticJavaDownload", true) }
            App.setSetting("UserAskedAboutAutomaticJavaDownload", true)
            return true
        case "paste":
            var prev = String(App.setting("PastebinURL") || "")
            App.resetSetting("PastebinURL")
            if (pasteKeep.checked) {
                var np = SettingsBackend.pasteTypes.filter(function(t) { return t.value === 0 })[0]
                App.setSetting("PastebinType", 0)
                if (np && prev !== np.defaultBase) App.setSetting("PastebinCustomAPIBase", prev)
            }
            return true
        default:
            return true
        }
    }

    function openLogin() {
        var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/AccMsaLoginDialog.qml"))
        var dlg = comp.createObject(page, { makeDefault: true })
        dlg.signedIn.connect(function() { page.next() })
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
    }
    function pickJava() {
        var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/SetJavaPickerDialog.qml"))
        var dlg = comp.createObject(page, { major: 0 })
        dlg.picked.connect(function(j) { javaPath.text = j.path })
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
    }

    Rectangle { anchors.fill: parent; color: Theme.bg }

    RowLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.spacingXxl, 980)
        height: Math.min(parent.height - 2 * Theme.spacingXl, 620)
        spacing: Theme.spacingXl

        // ------------------------------------------------------------ stepper
        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.maximumWidth: 220
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 4
            Image { source: "qrc:/qt/qml/PrismModern/qml/assets/logo.svg"; sourceSize: Qt.size(96, 96); Layout.preferredWidth: 44; Layout.preferredHeight: 44; Layout.bottomMargin: 8 }
            Text { text: qsTr("Setup"); color: Theme.text; font.pixelSize: Theme.fontXl; font.weight: Font.Bold; Layout.bottomMargin: Theme.spacing }
            Repeater {
                model: page.steps
                delegate: RowLayout {
                    id: st
                    required property string modelData
                    required property int index
                    readonly property bool done: index < page.current
                    readonly property bool active: index === page.current
                    spacing: 12
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: st.done ? Theme.accent : st.active ? Theme.accentSoft : "transparent"
                        border.width: st.done ? 0 : 1.5
                        border.color: st.active ? Theme.accent : Theme.borderStrong
                        Behavior on color { ColorAnimation { duration: Theme.dur } }
                        Icon { anchors.centerIn: parent; visible: st.done; name: "check"; size: 14; color: Theme.textOnAccent }
                        Text { anchors.centerIn: parent; visible: !st.done; text: st.index + 1; color: st.active ? Theme.accent : Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Bold }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: page.meta[st.modelData] ? page.meta[st.modelData].title : st.modelData
                        color: st.active ? Theme.text : st.done ? Theme.textMuted : Theme.textSubtle
                        font.pixelSize: Theme.fontMd; font.weight: st.active ? Font.DemiBold : Font.Medium
                    }
                }
            }
            Item { Layout.fillHeight: true }
            Text { text: qsTr("Step %1 of %2").arg(page.current + 1).arg(page.steps.length); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
            PProgressBar { Layout.fillWidth: true; value: (page.current + 1) / Math.max(1, page.steps.length) }
        }

        // ------------------------------------------------------------ step card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusXl
            color: Theme.surface
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXxl
                spacing: Theme.spacingLg

                Rectangle {
                    width: 48; height: 48; radius: 14; color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; name: page.meta[page.step] ? page.meta[page.step].icon : "sparkles"; size: 24; color: Theme.accent }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: page.meta[page.step] ? page.meta[page.step].heading : ""; color: Theme.text; font.pixelSize: Theme.fontXxl - 4; font.weight: Font.Bold; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    Text { text: page.meta[page.step] ? page.meta[page.step].text : ""; color: Theme.textMuted; font.pixelSize: Theme.fontLg - 1; Layout.fillWidth: true; wrapMode: Text.Wrap }
                }

                // step bodies (all kept alive so going back keeps choices)
                StackLayout {
                    id: bodies
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: ["language", "java", "autojava", "paste", "theme", "login"].indexOf(page.step)
                    opacity: 1

                    // language
                    ColumnLayout {
                        spacing: Theme.spacing
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 56; radius: Theme.radius
                            color: Theme.accentSoft; border.color: Theme.accent
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 14
                                Icon { name: "check"; size: 16; color: Theme.accent }
                                Text { text: qsTr("English"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                Text { text: qsTr("The new interface is available in English only"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                            }
                        }
                        PCheckBox { id: sysLocale; text: qsTr("Use system regional standards for dates and numbers") }
                        Item { Layout.fillHeight: true }
                    }

                    // java
                    ColumnLayout {
                        spacing: Theme.spacing
                        PSwitch {
                            id: autoDetect
                            visible: SettingsBackend.javaDownloaderEnabled
                            Layout.fillWidth: true
                            text: qsTr("Automatically pick a compatible Java for each instance")
                            checked: true
                        }
                        PSwitch {
                            id: autoDownload
                            visible: SettingsBackend.javaDownloaderEnabled
                            enabled: autoDetect.checked
                            Layout.fillWidth: true
                            text: qsTr("Download Mojang's recommended Java when needed")
                            checked: true
                        }
                        Text { text: qsTr("Java executable"); color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; Layout.topMargin: 6 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            PTextField {
                                id: javaPath
                                Layout.fillWidth: true
                                placeholderText: autoDetect.checked ? qsTr("Optional — picked automatically") : qsTr("Path to java executable")
                                Component.onCompleted: text = App.setting("JavaPath") || ""
                                error: text.length > 0 && !SettingsBackend.executableResolves(text)
                            }
                            PButton { text: qsTr("Detect"); iconName: "search"; onClicked: page.pickJava() }
                            PButton { text: qsTr("Browse"); onClicked: { var p = SettingsBackend.browseFile(qsTr("Find Java executable"), javaPath.text, ""); if (p.length) javaPath.text = SettingsBackend.normalizePath(p) } }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            columns: 3; columnSpacing: 12; rowSpacing: 6
                            Text { text: qsTr("Minimum memory"); color: Theme.text; font.pixelSize: Theme.fontMd }
                            PSlider { id: minSl; Layout.fillWidth: true; from: 256; to: Math.max(2048, SettingsBackend.systemRamMiB); stepSize: 128; value: minMem.value; onMoved: minMem.value = value }
                            PSpinBox { id: minMem; from: 8; to: 1048576; stepSize: 128; suffix: "MiB"; implicitWidth: 140; value: parseInt(App.setting("MinMemAlloc")) || 512 }
                            Text { text: qsTr("Maximum memory"); color: Theme.text; font.pixelSize: Theme.fontMd }
                            PSlider { id: maxSl; Layout.fillWidth: true; from: 256; to: Math.max(2048, SettingsBackend.systemRamMiB); stepSize: 128; value: maxMem.value; onMoved: maxMem.value = value }
                            PSpinBox { id: maxMem; from: 8; to: 1048576; stepSize: 128; suffix: "MiB"; implicitWidth: 140; value: parseInt(App.setting("MaxMemAlloc")) || 4096 }
                        }
                        Text {
                            text: qsTr("Your system has %1 MiB of memory.").arg(SettingsBackend.systemRamMiB)
                            color: maxMem.value >= SettingsBackend.systemRamMiB ? Theme.danger : Theme.textSubtle; font.pixelSize: Theme.fontSm
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // autojava
                    ColumnLayout {
                        spacing: Theme.spacing
                        Repeater {
                            model: [ { on: true, title: qsTr("Enable auto-download"), text: qsTr("Recommended. The right Java is downloaded and selected automatically.") },
                                     { on: false, title: qsTr("Disable auto-download"), text: qsTr("Keep my current Java settings.") } ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: autoEnable.checked === modelData.on
                                Layout.fillWidth: true; implicitHeight: 72; radius: Theme.radiusLg
                                color: sel ? Theme.accentSoft : ma.containsMouse ? Theme.surfaceHover : Theme.surfaceAlt
                                border.color: sel ? Theme.accent : Theme.border; border.width: sel ? 2 : 1
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 2
                                    Text { text: modelData.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold }
                                    Text { text: modelData.text; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                                }
                                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: autoEnable.checked = modelData.on }
                            }
                        }
                        PCheckBox { id: autoEnable; visible: false; checked: true }
                        Item { Layout.fillHeight: true }
                    }

                    // paste
                    ColumnLayout {
                        spacing: Theme.spacing
                        PRadioButton { id: pasteNew; text: qsTr("Use the new default service (mclo.gs)"); checked: true }
                        PRadioButton { id: pasteKeep; text: qsTr("Keep my previous settings") }
                        Item { Layout.fillHeight: true }
                    }

                    // theme
                    ColumnLayout {
                        spacing: Theme.spacingLg
                        RowLayout {
                            spacing: Theme.spacing
                            Repeater {
                                model: [ { value: "system", text: qsTr("System"), icon: "monitor" }, { value: "dark", text: qsTr("Dark"), icon: "moon" }, { value: "light", text: qsTr("Light"), icon: "sun" } ]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: (App.theme || "system") === modelData.value
                                    width: 150; height: 108; radius: Theme.radiusLg
                                    color: sel ? Theme.accentSoft : tma.containsMouse ? Theme.surfaceHover : Theme.surfaceAlt
                                    border.color: sel ? Theme.accent : Theme.border; border.width: sel ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                    // mini preview
                                    Rectangle {
                                        x: 12; y: 12; width: parent.width - 24; height: 52; radius: 8
                                        color: modelData.value === "light" ? "#f5f5f8" : modelData.value === "dark" ? "#0e0f13" : "transparent"
                                        border.color: Theme.border
                                        gradient: modelData.value === "system" ? sysGrad : null
                                        Gradient { id: sysGrad; orientation: Gradient.Horizontal; GradientStop { position: 0.5; color: "#f5f5f8" } GradientStop { position: 0.501; color: "#0e0f13" } }
                                        Rectangle { x: 8; y: 8; width: 30; height: 6; radius: 3; color: Theme.accent }
                                        Rectangle { x: 8; y: 20; width: 50; height: 4; radius: 2; color: modelData.value === "dark" ? "#3a3b45" : "#c8c9d2" }
                                    }
                                    RowLayout {
                                        x: 12; y: 74; spacing: 6
                                        Icon { name: modelData.icon; size: 15; color: sel ? Theme.accent : Theme.textMuted }
                                        Text { text: modelData.text; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium }
                                    }
                                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.theme = modelData.value }
                                }
                            }
                        }
                        RowLayout {
                            spacing: 10
                            Repeater {
                                model: Theme.accentPresets
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool cur: String(App.accent).toLowerCase() === modelData
                                    width: 28; height: 28; radius: 14; color: modelData
                                    Icon { anchors.centerIn: parent; visible: parent.cur; name: "check"; size: 14; color: "#ffffff" }
                                    scale: am.containsMouse ? 1.12 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.durFast } }
                                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.accent = modelData }
                                }
                            }
                        }
                        Text { text: qsTr("Classic dialogs use the classic icon and widget themes; they are set up automatically and can be changed in Settings → Appearance."); color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        Item { Layout.fillHeight: true }
                    }

                    // login
                    ColumnLayout {
                        spacing: Theme.spacing
                        Rectangle {
                            visible: Accounts.anyValid
                            Layout.fillWidth: true; implicitHeight: 52; radius: Theme.radius
                            color: Theme.soft(Theme.success)
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 14
                                Icon { name: "circle-check"; size: 16; color: Theme.success }
                                Text { text: qsTr("Signed in as %1").arg(Accounts.defaultName); color: Theme.text; font.pixelSize: Theme.fontMd; Layout.fillWidth: true }
                            }
                        }
                        PButton {
                            visible: Accounts.msaSupported
                            size: "lg"; variant: Accounts.anyValid ? "secondary" : "primary"; iconName: "log-in"
                            text: Accounts.anyValid ? qsTr("Add another Microsoft account") : qsTr("Sign in with Microsoft")
                            onClicked: page.openLogin()
                        }
                        Text { visible: !Accounts.msaSupported; text: qsTr("Microsoft sign-in is not available in this build."); color: Theme.textMuted }
                        Item { Layout.fillHeight: true }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    PButton { visible: page.current > 0; text: qsTr("Back"); iconName: "arrow-left"; variant: "ghost"; onClicked: page.back() }
                    Item { Layout.fillWidth: true }
                    PButton { visible: page.step === "login" && !Accounts.anyValid; text: qsTr("Skip for now"); variant: "ghost"; onClicked: page.next() }
                    PButton {
                        variant: "primary"; size: "lg"
                        text: page.last ? qsTr("Get started") : qsTr("Continue")
                        trailingIconName: page.last ? "" : "chevron-right"
                        iconName: page.last ? "sparkles" : ""
                        onClicked: page.next()
                    }
                }
            }
        }
    }
}
