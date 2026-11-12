import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic CustomCommands + EnvironmentVariables widgets (tabs of the global Minecraft page).
SetPageBase {
    id: page
    title: qsTr("Commands & environment")
    subtitle: qsTr("Run commands around the game and pass environment variables to it.")

    SetSection {
        title: qsTr("Custom commands"); iconName: "terminal"
        SetRow { stacked: true; label: qsTr("Pre-load command"); description: qsTr("Runs before the instance's metadata is loaded.")
            keywords: "custom command preload"
            SetText { key: "PreLoadCommand"; width: parent.width; font.family: Theme.monoFamily } }
        SetRow { stacked: true; label: qsTr("Pre-launch command"); description: qsTr("Runs before the instance launches.")
            keywords: "custom command prelaunch"
            SetText { key: "PreLaunchCommand"; width: parent.width; font.family: Theme.monoFamily } }
        SetRow { stacked: true; label: qsTr("Wrapper command"); description: qsTr("Launch using an extra wrapper program (like 'optirun' on Linux).")
            keywords: "custom command wrapper"
            SetText { key: "WrapperCommand"; width: parent.width; font.family: Theme.monoFamily } }
        SetRow { stacked: true; label: qsTr("Post-exit command"); description: qsTr("Runs after the game exits.")
            keywords: "custom command postexit"
            SetText { key: "PostExitCommand"; width: parent.width; font.family: Theme.monoFamily } }
        Item {
            width: parent.width; height: help.implicitHeight + 32
            Rectangle {
                id: help
                y: 8; width: parent.width
                implicitHeight: helpText.implicitHeight + 24
                radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
                Text {
                    id: helpText
                    x: 14; y: 12; width: parent.width - 28
                    wrapMode: Text.Wrap; textFormat: Text.StyledText
                    color: Theme.textMuted; font.pixelSize: Theme.fontSm
                    text: qsTr("All commands run in the launcher's working folder with extra environment variables:") + "<br>" +
                          "<b>$INST_NAME</b> – " + qsTr("name of the instance") + "<br>" +
                          "<b>$INST_ID</b> – " + qsTr("ID of the instance (its folder name)") + "<br>" +
                          "<b>$INST_DIR</b> – " + qsTr("absolute path of the instance") + "<br>" +
                          "<b>$INST_MC_DIR</b> – " + qsTr("absolute path of Minecraft") + "<br>" +
                          "<b>$INST_JAVA</b> – " + qsTr("Java binary used for launch") + "<br>" +
                          "<b>$INST_JAVA_ARGS</b> – " + qsTr("command-line parameters used for launch (will not work correctly if arguments contain spaces)")
                }
            }
        }
    }

    SetSection {
        id: envSection
        title: qsTr("Environment variables"); iconName: "list"
        description: qsTr("Passed to the game and to the custom commands.")
        // rows are kept locally so editing a name doesn't reorder/re-create fields while typing
        property var entries: []
        function load() {
            var m = page.store ? page.store.getJson("Env", {}) : {}
            var l = []
            for (var k in m) l.push({ name: k, value: String(m[k]) })
            l.sort(function(a, b) { return a.name.localeCompare(b.name) })
            entries = l
        }
        function commit() {
            var m = {}
            for (var i = 0; i < entries.length; i++) if (entries[i].name.trim().length) m[entries[i].name.trim()] = entries[i].value
            page.store.setJson("Env", m)
        }
        Component.onCompleted: load()
        Connections { target: page.store; function onDiscarded() { envSection.load() } function onSaved() { envSection.load() } }
        headerActions: [
            PButton { text: qsTr("Clear"); size: "sm"; variant: "ghost"; enabled: envSection.entries.length > 0; onClicked: { envSection.entries = []; envSection.commit() } },
            PButton { text: qsTr("Add"); size: "sm"; iconName: "plus"; onClicked: { var l = envSection.entries.slice(); l.push({ name: "ENV_VAR", value: "value" }); envSection.entries = l; envSection.commit() } }
        ]
        Item {
            width: parent.width; height: 60
            visible: envSection.entries.length === 0
            Text { anchors.centerIn: parent; text: qsTr("No environment variables."); color: Theme.textMuted; font.pixelSize: Theme.fontMd }
        }
        Column {
            width: parent.width
            topPadding: 8; bottomPadding: 12
            spacing: 8
            Repeater {
                model: envSection.entries.length
                delegate: RowLayout {
                    id: envRow
                    required property int index
                    width: parent.width
                    spacing: 8
                    PTextField {
                        Layout.preferredWidth: 220
                        font.family: Theme.monoFamily
                        placeholderText: qsTr("Name")
                        text: envSection.entries[envRow.index] ? envSection.entries[envRow.index].name : ""
                        onTextEdited: { envSection.entries[envRow.index].name = text; envSection.commit() }
                    }
                    Text { text: "="; color: Theme.textSubtle }
                    PTextField {
                        Layout.fillWidth: true
                        font.family: Theme.monoFamily
                        placeholderText: qsTr("Value")
                        text: envSection.entries[envRow.index] ? envSection.entries[envRow.index].value : ""
                        onTextEdited: { envSection.entries[envRow.index].value = text; envSection.commit() }
                    }
                    IconButton {
                        iconName: "trash-2"; tip: qsTr("Remove")
                        onClicked: { var l = envSection.entries.slice(); l.splice(envRow.index, 1); envSection.entries = l; envSection.commit() }
                    }
                }
            }
        }
    }
}
