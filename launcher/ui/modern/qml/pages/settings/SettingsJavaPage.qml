import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Classic JavaPage (+ JavaSettingsWidget): installation, auto-detection, pinned installs, memory, JVM arguments,
// and the managed Java installations list with "Install Java".
SetPageBase {
    id: page
    title: qsTr("Java")
    subtitle: qsTr("Which Java runs Minecraft and how much memory it gets.")

    readonly property int ram: SettingsBackend.systemRamMiB
    readonly property int minMem: store ? store.getInt("MinMemAlloc") : 512
    readonly property int maxMem: store ? store.getInt("MaxMemAlloc") : 1024

    Component.onCompleted: { SettingsBackend.refreshManagedJavas() }

    Connections {
        target: SettingsBackend
        function onJavaTestFinished(kind, title, message) {
            Dialogs.message({ title: title, text: message, kind: kind === "success" ? "info" : kind === "warning" ? "warning" : "error" })
        }
    }

    function openInstaller() {
        var comp = Qt.createComponent(Qt.resolvedUrl("../../dialogs/SetInstallJavaDialog.qml"))
        if (comp.status !== Component.Ready) { console.warn(comp.errorString()); return }
        var dlg = comp.createObject(page)
        dlg.installed.connect(function() { SettingsBackend.refreshManagedJavas() })
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
    }

    function pickJava(major, cb) {
        if (!SettingsBackend.javaCheckerAvailable) {
            Dialogs.message({ title: qsTr("Java test failure"), text: qsTr("Java checker library could not be found. Please check your installation."), kind: "error" })
            return
        }
        var comp = Qt.createComponent(Qt.resolvedUrl("../../dialogs/SetJavaPickerDialog.qml"))
        var dlg = comp.createObject(page, { major: major })
        dlg.picked.connect(function(java) { cb(java) })
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
    }

    // ---------------------------------------------------------------- installation
    SetSection {
        title: qsTr("Java installation"); iconName: "coffee"
        SetRow {
            stacked: true
            label: qsTr("Java executable")
            description: qsTr("Used for instances that don't override it. Leave empty to let the launcher pick one.")
            keywords: "java path executable binary jre jdk"
            ColumnLayout {
                width: parent.width
                spacing: 8
                SetText { key: "JavaPath"; Layout.fillWidth: true; placeholderText: qsTr("Path to java executable") }
                RowLayout {
                    spacing: 8
                    PButton {
                        text: qsTr("Detect"); iconName: "search"
                        onClicked: page.pickJava(0, function(java) {
                            page.store.set("JavaPath", java.path)
                            if (!java.is64 && page.maxMem > 2048)
                                Dialogs.message({ title: qsTr("Confirm Selection"), kind: "warning",
                                                  text: qsTr("You selected a 32-bit version of Java. This installation does not support more than 2048 MiB of RAM. Please make sure that the maximum memory value is lower.") })
                        })
                    }
                    PButton {
                        text: qsTr("Browse"); iconName: "folder-open"
                        onClicked: {
                            var p = SettingsBackend.browseFile(qsTr("Find Java executable"), page.store.getString("JavaPath"), "")
                            if (p.length && SettingsBackend.isExecutableFile(p)) page.store.set("JavaPath", SettingsBackend.normalizePath(p))
                        }
                    }
                    PButton {
                        text: qsTr("Test settings"); iconName: "flask"
                        busy: SettingsBackend.javaTesting
                        enabled: !SettingsBackend.javaTesting
                        onClicked: SettingsBackend.testJava(page.store.getString("JavaPath"), page.store.getString("JvmArgs").replace(/\n/g, " "),
                                                            page.minMem, page.maxMem, page.store.getInt("PermGen"))
                    }
                    Item { Layout.fillWidth: true }
                    PButton {
                        visible: SettingsBackend.javaDownloaderEnabled
                        variant: "subtle"; text: qsTr("Install Java…"); iconName: "download"
                        onClicked: page.openInstaller()
                    }
                }
            }
        }
        SetRow {
            visible: SettingsBackend.javaDownloaderEnabled
            label: qsTr("Auto-detect Java version")
            description: qsTr("Pick a compatible Java for each instance automatically.")
            keywords: "automatic switch"
            PSwitch {
                checked: page.store ? page.store.getBool("AutomaticJavaSwitch") : false
                onToggled: { page.store.set("AutomaticJavaSwitch", checked); if (!checked) page.store.set("AutomaticJavaDownload", false) }
            }
        }
        SetRow {
            visible: SettingsBackend.javaDownloaderEnabled
            enabled: page.store ? page.store.getBool("AutomaticJavaSwitch") : false
            label: qsTr("Auto-download Mojang Java")
            description: qsTr("Automatically downloads and selects the Java build recommended by Mojang.")
            keywords: "automatic download"
            SetSwitch { key: "AutomaticJavaDownload" }
        }
        SetRow {
            label: qsTr("Skip Java compatibility checks")
            description: qsTr("The launcher will not check if an instance is compatible with the selected Java version.")
            SetSwitch { key: "IgnoreJavaCompatibility" }
        }
        SetRow {
            label: qsTr("Skip Java setup prompt on startup")
            description: qsTr("Don't ask to choose a Java version if none is found on startup.")
            keywords: "wizard"
            SetSwitch { key: "IgnoreJavaWizard" }
        }
    }

    // ---------------------------------------------------------------- pinned
    SetSection {
        title: qsTr("Pinned Java installations"); iconName: "pin"
        description: qsTr("When Java is picked automatically, a pinned installation of the required version is used before anything else is detected or downloaded.")
        enabled: page.store ? page.store.getBool("AutomaticJavaSwitch") : false
        opacity: enabled ? 1 : 0.6
        Repeater {
            model: SettingsBackend.pinnableMajors
            delegate: SetRow {
                id: pinRow
                required property int modelData
                readonly property var pins: page.store ? page.store.getJson("PinnedJavaPaths", {}) : ({})
                readonly property string value: pins[String(modelData)] || ""
                function setPath(p) {
                    var m = Object.assign({}, page.store.getJson("PinnedJavaPaths", {}))
                    if (p.trim().length) m[String(modelData)] = p.trim(); else delete m[String(modelData)]
                    page.store.setJson("PinnedJavaPaths", m)
                }
                label: qsTr("Java %1").arg(modelData)
                keywords: "pin pinned java " + modelData
                RowLayout {
                    spacing: 8
                    PTextField {
                        implicitWidth: 320
                        text: pinRow.value
                        placeholderText: qsTr("Automatically detected")
                        error: text.length > 0 && !SettingsBackend.executableResolves(text)
                        onTextEdited: pinRow.setPath(text)
                    }
                    PButton { text: qsTr("Browse"); size: "sm"
                        onClicked: { var p = SettingsBackend.browseFile(qsTr("Find Java %1 executable").arg(pinRow.modelData), pinRow.value, ""); if (p.length && SettingsBackend.isExecutableFile(p)) pinRow.setPath(SettingsBackend.normalizePath(p)) } }
                    PButton { text: qsTr("Detect"); size: "sm"; onClicked: page.pickJava(pinRow.modelData, function(java) { pinRow.setPath(java.path) }) }
                }
            }
        }
    }

    // ---------------------------------------------------------------- memory
    SetSection {
        title: qsTr("Memory"); iconName: "hard-drive"
        description: qsTr("Your system has %1 of memory.").arg(page.ram >= 1024 ? (page.ram / 1024).toFixed(1) + " GiB" : page.ram + " MiB")
        Repeater {
            model: [
                { key: "MinMemAlloc", label: qsTr("Minimum memory (-Xms)"), desc: qsTr("The amount of memory Minecraft is started with."), kw: "xms ram minimum" },
                { key: "MaxMemAlloc", label: qsTr("Maximum memory (-Xmx)"), desc: qsTr("The maximum amount of memory Minecraft is allowed to use."), kw: "xmx ram maximum" }
            ]
            delegate: SetRow {
                id: memRow
                required property var modelData
                stacked: true
                label: modelData.label
                description: modelData.desc
                keywords: modelData.kw
                RowLayout {
                    width: parent.width
                    spacing: 14
                    PSlider {
                        id: slider
                        Layout.fillWidth: true
                        from: 256; to: Math.max(2048, Math.ceil(page.ram / 512) * 512)
                        stepSize: 128
                        snapMode: Slider.SnapAlways
                        value: page.store ? page.store.getInt(memRow.modelData.key) : 0
                        onMoved: page.store.set(memRow.modelData.key, Math.round(value))
                    }
                    SetSpin { key: memRow.modelData.key; from: 8; to: 1048576; stepSize: 128; suffix: "MiB"; implicitWidth: 150 }
                }
            }
        }
        Item {
            width: parent.width
            height: notice.visible ? notice.implicitHeight + 14 : 0
            readonly property int mx: page.maxMem
            Rectangle {
                id: notice
                visible: text.text.length > 0
                width: parent.width
                implicitHeight: text.implicitHeight + 18
                radius: Theme.radius
                color: Theme.soft(page.maxMem >= page.ram ? Theme.danger : Theme.warning)
                Text {
                    id: text
                    anchors.fill: parent; anchors.margins: 9; anchors.leftMargin: 12
                    wrapMode: Text.Wrap
                    color: page.maxMem >= page.ram ? Theme.danger : Theme.warning
                    font.pixelSize: Theme.fontSm; font.weight: Font.Medium
                    text: page.maxMem >= page.ram ? qsTr("Your maximum memory allocation exceeds your system memory capacity.")
                          : page.maxMem * 10 > page.ram * 9 ? qsTr("Your maximum memory allocation is close to your system memory capacity.")
                          : page.maxMem < page.minMem ? qsTr("Your maximum memory allocation is below the minimum memory allocation.") : ""
                }
            }
        }
        SetRow {
            label: qsTr("PermGen size (-XX:PermSize)")
            description: qsTr("The amount of memory available to store loaded Java classes (Java 7 and older).")
            keywords: "permgen"
            SetSpin { key: "PermGen"; from: 4; to: 1048576; stepSize: 8; suffix: "MiB"; implicitWidth: 150 }
        }
        SetRow {
            label: qsTr("Warn when there is not enough free memory")
            keywords: "low memory warning"
            SetSwitch { key: "LowMemWarning" }
        }
    }

    // ---------------------------------------------------------------- arguments
    SetSection {
        title: qsTr("JVM arguments"); iconName: "terminal"
        SetRow {
            stacked: true
            label: qsTr("Extra arguments passed to Java")
            description: qsTr("Memory options belong in the memory settings above.")
            keywords: "jvm args arguments flags"
            PTextArea {
                id: jvm
                width: parent.width
                implicitHeight: 96
                monospace: true
                placeholderText: "-XX:+UseG1GC"
                text: page.store ? page.store.getString("JvmArgs") : ""
                Connections { target: jvm.textArea; function onTextChanged() { if (jvm.textArea.activeFocus) page.store.set("JvmArgs", jvm.text) } }
            }
        }
        Text {
            readonly property string warn: page.store ? SettingsBackend.jvmArgsWarning(page.store.getString("JvmArgs")) : ""
            visible: warn.length > 0
            width: parent.width; bottomPadding: 12
            wrapMode: Text.Wrap; color: Theme.warning; font.pixelSize: Theme.fontSm
            text: warn
        }
    }

    // ---------------------------------------------------------------- managed installs
    SetSection {
        visible: SettingsBackend.javaDownloaderEnabled
        title: qsTr("Installations"); iconName: "package"
        description: qsTr("Java versions downloaded and managed by the launcher.")
        headerActions: [
            IconButton { iconName: "folder-open"; tip: qsTr("Open Java folder"); onClicked: App.openFolder("java") },
            IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh"); onClicked: SettingsBackend.refreshManagedJavas() },
            PButton { text: qsTr("Install Java…"); iconName: "download"; size: "sm"; variant: "primary"; onClicked: page.openInstaller() }
        ]
        Item {
            width: parent.width; height: 70
            visible: SettingsBackend.managedJavaLoading
            Spinner { anchors.centerIn: parent }
        }
        Item {
            width: parent.width; height: 64
            visible: !SettingsBackend.managedJavaLoading && SettingsBackend.managedJavas.length === 0
            Text { anchors.centerIn: parent; text: qsTr("No managed Java versions are installed."); color: Theme.textMuted; font.pixelSize: Theme.fontMd }
        }
        Repeater {
            model: SettingsBackend.managedJavaLoading ? [] : SettingsBackend.managedJavas
            delegate: SetRow {
                id: jr
                required property var modelData
                label: qsTr("Java %1").arg(modelData.version)
                description: SettingsBackend.managedJavaFolderName(modelData.path) + " · " + modelData.arch
                keywords: "managed java installation"
                RowLayout {
                    spacing: 4
                    Badge { visible: page.store && page.store.getString("JavaPath") === jr.modelData.path; text: qsTr("Default"); tone: "accent" }
                    PButton { text: qsTr("Use as default"); size: "sm"; variant: "ghost"; onClicked: page.store.set("JavaPath", jr.modelData.path) }
                    IconButton {
                        iconName: "trash-2"; tip: qsTr("Remove")
                        onClicked: Dialogs.confirm({ title: qsTr("Remove Java?"), danger: true, confirmText: qsTr("Remove"),
                                                     text: qsTr("You are about to remove the Java installation named “%1”.").arg(SettingsBackend.managedJavaFolderName(jr.modelData.path)) },
                            function(ok) { if (ok) { var e = SettingsBackend.removeManagedJava(jr.modelData.path); if (e.length) Toasts.error(e); else Toasts.success(qsTr("Java removed")) } })
                    }
                }
            }
        }
    }

}
