import QtQuick
import QtQuick.Layouts
import PrismModern

// Modern look (theme, accent, motion, library) + the classic AppearancePage options
// (icon/widget themes still used by classic dialogs, console font, background cat).
SetPageBase {
    id: page
    title: qsTr("Appearance")
    subtitle: qsTr("Theme, colors and motion. Changes here apply immediately.")
    property int catRev: 0

    // ---------------------------------------------------------------- modern theme
    SetSection {
        title: qsTr("Theme"); iconName: "palette"
        SetRow {
            label: qsTr("Color scheme")
            description: qsTr("Follow the system setting or always use a dark or light theme.")
            keywords: "dark light mode system theme"
            SegmentedControl {
                options: [ { value: "system", text: qsTr("System"), icon: "monitor" }, { value: "dark", text: qsTr("Dark"), icon: "moon" }, { value: "light", text: qsTr("Light"), icon: "sun" } ]
                value: App.theme || "system"
                onActivated: v => App.theme = v
            }
        }
        SetRow {
            id: accentRow
            stacked: true
            label: qsTr("Accent color")
            description: qsTr("Used for buttons, highlights and selection.")
            keywords: "accent colour color highlight"
            readonly property bool isPreset: Theme.accentPresets.indexOf(String(App.accent).toLowerCase()) >= 0
            RowLayout {
                width: parent.width
                spacing: 10
                Repeater {
                    model: Theme.accentPresets
                    delegate: Rectangle {
                        id: swatch
                        required property string modelData
                        readonly property bool current: String(App.accent).toLowerCase() === modelData
                        width: 30; height: 30; radius: 15
                        color: modelData
                        border.width: current ? 3 : 0
                        border.color: Theme.surface
                        scale: swatchMa.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 6; height: width; radius: width / 2
                            color: "transparent"; border.width: 2; border.color: swatch.modelData
                            visible: swatch.current
                        }
                        Icon { anchors.centerIn: parent; visible: swatch.current; name: "check"; size: 14; color: "#ffffff" }
                        MouseArea { id: swatchMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: App.accent = swatch.modelData }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle { width: 22; height: 22; radius: 6; color: hex.acceptableInput ? "#" + hex.text.replace("#", "") : Theme.surfaceAlt; border.color: Theme.border }
                PTextField {
                    id: hex
                    implicitWidth: 110
                    placeholderText: "#7c5cff"
                    text: App.accent
                    validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
                    onEditingFinished: if (acceptableInput) App.accent = "#" + text.replace("#", "").toLowerCase()
                    PToolTip { visible: parent.hovered; text: qsTr("Custom color (hex)") }
                }
            }
        }
        SetRow {
            label: qsTr("Reduce motion")
            description: qsTr("Turn off animations and transitions.")
            keywords: "animation accessibility"
            PSwitch { checked: App.reduceMotion; onToggled: App.reduceMotion = checked }
        }
    }

    // ---------------------------------------------------------------- layout
    SetSection {
        title: qsTr("Layout"); iconName: "grid-2x2"
        SetRow {
            label: qsTr("Library view")
            description: qsTr("Show instances as a grid of cards or as a compact list.")
            keywords: "grid list cards"
            SegmentedControl {
                id: viewSeg
                function current() { var v = String(App.setting("ModernLibraryView") || "grid"); return v }
                options: [ { value: "grid", text: qsTr("Grid"), icon: "grid-2x2" }, { value: "list", text: qsTr("List"), icon: "list" } ]
                value: current()
                onActivated: v => App.setSetting("ModernLibraryView", v)
            }
        }
        SetRow {
            label: qsTr("Compact sidebar")
            description: qsTr("Only show icons in the sidebar.")
            keywords: "collapse sidebar"
            PSwitch {
                id: compact
                checked: App.setting("ModernSidebarCollapsed") === true || App.setting("ModernSidebarCollapsed") === "true"
                onToggled: App.setSetting("ModernSidebarCollapsed", checked)
                Connections { target: App; function onSettingChanged(key, value) { if (key === "ModernSidebarCollapsed") compact.checked = value === true || value === "true" } }
            }
        }
        SetRow {
            label: qsTr("Use classic interface")
            description: qsTr("Switch back to the classic widget-based interface. The launcher restarts.")
            keywords: "classic old legacy widgets ui"
            PButton {
                text: qsTr("Switch…"); iconName: "rotate-ccw"
                onClicked: Dialogs.confirm({ title: qsTr("Switch to classic interface?"), text: qsTr("The launcher will restart with the classic interface. You can come back from Settings → Appearance in the classic interface by unchecking “Use classic interface”."), confirmText: qsTr("Restart") }, function(ok) {
                    if (ok) { if (page.store.dirty) page.store.save(); App.useClassicUi(true); App.restart() }
                })
            }
        }
    }

    // ---------------------------------------------------------------- classic themes
    SetSection {
        title: qsTr("Classic themes")
        description: qsTr("Used by dialogs that still come from the classic interface.")
        iconName: "layers"
        headerActions: [
            PButton { text: qsTr("Reload"); size: "sm"; variant: "ghost"; iconName: "refresh-cw"; onClicked: { SettingsBackend.reloadThemes(); themeCombos.reload() } }
        ]
        Item {
            id: themeCombos
            width: 0; height: 0
            property var icons: SettingsBackend.iconThemes()
            property var widgets: SettingsBackend.widgetThemes()
            property var cats: SettingsBackend.catPacks()
            function reload() { icons = SettingsBackend.iconThemes(); widgets = SettingsBackend.widgetThemes(); cats = SettingsBackend.catPacks() }
            function indexIn(list, v) { for (var i = 0; i < list.length; i++) if (list[i].value === v) return i; return -1 }
        }
        SetRow {
            label: qsTr("Icons"); keywords: "icon theme"
            RowLayout {
                spacing: 6
                PComboBox {
                    implicitWidth: 220
                    model: themeCombos.icons; textRole: "text"; valueRole: "value"
                    currentIndex: themeCombos.indexIn(themeCombos.icons, App.setting("IconTheme"))
                    onActivated: { App.setSetting("IconTheme", currentValue); SettingsBackend.applyClassicTheme() }
                }
                IconButton { iconName: "folder-open"; tip: qsTr("Open icon themes folder"); onClicked: App.openFolder("iconThemes") }
            }
        }
        SetRow {
            label: qsTr("Widgets"); keywords: "widget style theme"
            RowLayout {
                spacing: 6
                PComboBox {
                    implicitWidth: 220
                    model: themeCombos.widgets; textRole: "text"; valueRole: "value"
                    currentIndex: themeCombos.indexIn(themeCombos.widgets, App.setting("ApplicationTheme"))
                    onActivated: { App.setSetting("ApplicationTheme", currentValue); SettingsBackend.applyClassicTheme() }
                }
                IconButton { iconName: "folder-open"; tip: qsTr("Open widget themes folder"); onClicked: App.openFolder("widgetThemes") }
            }
        }
    }

    // ---------------------------------------------------------------- console
    SetSection {
        title: qsTr("Console"); iconName: "terminal"
        SetRow {
            label: qsTr("Console font"); keywords: "font monospace log"
            RowLayout {
                spacing: 8
                PComboBox {
                    id: fontCombo
                    implicitWidth: 220
                    model: SettingsBackend.fontFamilies()
                    currentIndex: page.store ? model.indexOf(page.store.getString("ConsoleFont")) : -1
                    onActivated: page.store.set("ConsoleFont", currentText)
                }
                SetSpin { key: "ConsoleFontSize"; from: 5; to: 16; implicitWidth: 90 }
            }
        }
        Item { width: parent.width; height: preview.height + 16
            Rectangle {
                id: preview
                y: 4
                width: parent.width
                height: previewCol.implicitHeight + 20
                radius: Theme.radius
                color: Theme.dark ? "#0b0c10" : "#fbfbfd"
                border.color: Theme.border
                Column {
                    id: previewCol
                    x: 12; y: 10
                    width: parent.width - 24
                    Repeater {
                        model: SettingsBackend.consolePreview()
                        delegate: Rectangle {
                            required property var modelData
                            width: previewCol.width
                            height: line.implicitHeight + 2
                            color: modelData.bg.length ? modelData.bg : "transparent"
                            Text {
                                id: line
                                text: modelData.text
                                color: modelData.fg.length ? modelData.fg : Theme.text
                                font.family: page.store ? page.store.getString("ConsoleFont") : Theme.monoFamily
                                font.pixelSize: Math.round((page.store ? page.store.getInt("ConsoleFontSize") : 11) * 1.25)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- cat
    SetSection {
        title: qsTr("Background cat"); iconName: "image"
        description: qsTr("Shown in the classic main window background.")
        SetRow {
            label: qsTr("Enable the cat"); keywords: "cat background kitteh"
            PSwitch {
                checked: page.store ? page.store.getBool("EnableCat") : false
                onToggled: { page.store.set("EnableCat", checked); if (!checked) page.store.set("TheCat", false) }
            }
        }
        SetRow {
            label: qsTr("Cat pack"); keywords: "cat pack"
            enabled: page.store ? page.store.getBool("EnableCat") : false
            RowLayout {
                spacing: 6
                PComboBox {
                    implicitWidth: 220
                    model: themeCombos.cats; textRole: "text"; valueRole: "value"
                    currentIndex: themeCombos.indexIn(themeCombos.cats, App.setting("BackgroundCat"))
                    onActivated: { SettingsBackend.setCatPack(currentValue); page.catRev++ }
                }
                IconButton { iconName: "folder-open"; tip: qsTr("Open cat packs folder"); onClicked: App.openFolder("catPacks") }
            }
        }
        SetRow {
            label: qsTr("Opacity"); keywords: "cat opacity transparency"
            enabled: page.store ? page.store.getBool("EnableCat") : false
            RowLayout {
                spacing: 10
                PSlider {
                    id: catOpacity
                    implicitWidth: 200
                    from: 0; to: 100; stepSize: 1
                    value: page.store ? page.store.getInt("CatOpacity") : 100
                    onMoved: page.store.set("CatOpacity", Math.round(value))
                }
                Text { text: Math.round(catOpacity.value) + "%"; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 36 }
            }
        }
        SetRow {
            label: qsTr("Fit"); keywords: "cat fit fill stretch"
            enabled: page.store ? page.store.getBool("EnableCat") : false
            SetCombo { key: "CatFit"; implicitWidth: 160; options: [ { value: "fit", text: qsTr("Fit") }, { value: "fill", text: qsTr("Fill") }, { value: "strech", text: qsTr("Stretch") } ] }
        }
        Item {
            width: parent.width; height: 150
            visible: page.store ? page.store.getBool("EnableCat") : false
            Rectangle {
                anchors.fill: parent; anchors.bottomMargin: 14
                radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border; clip: true
                Image {
                    anchors.fill: parent; anchors.margins: 8
                    source: { page.catRev; return SettingsBackend.catImageUrl() }
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    opacity: catOpacity.value / 100
                    sourceSize.height: 280
                }
            }
        }
    }
}
