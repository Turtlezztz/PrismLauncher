import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Pick one of the Java installations detected on this system (classic VersionSelectDialog over the Java list).
//   SetJavaPickerDialog { major: 17; onPicked: java => ... }   java: { path, version, major, arch, is64 }
PDialog {
    id: dlg
    property int major: 0
    property string selectedPath: ""
    signal picked(var java)

    title: major > 0 ? qsTr("Select a Java %1 installation").arg(major) : qsTr("Select a Java version")
    subtitle: qsTr("Java installations detected on this computer.")
    iconName: "coffee"
    maxWidth: 680

    readonly property var items: SettingsBackend.javaInstalls.filter(function(j) { return dlg.major <= 0 || j.major === dlg.major })
    Component.onCompleted: SettingsBackend.refreshJavaInstalls(false)

    function choose(j) { picked(j); close() }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 320
        radius: Theme.radius
        color: Theme.surfaceAlt
        border.color: Theme.border
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            model: SettingsBackend.javaListLoading ? [] : dlg.items
            spacing: 2
            ScrollBar.vertical: PScrollBar {}
            delegate: AbstractButton {
                id: item
                required property var modelData
                readonly property bool sel: dlg.selectedPath === modelData.path
                width: ListView.view.width
                height: 52
                hoverEnabled: true
                onClicked: dlg.selectedPath = modelData.path
                onDoubleClicked: dlg.choose(modelData)
                background: Rectangle {
                    radius: Theme.radiusSm + 2
                    color: item.sel ? Theme.accentSoft : item.hovered ? Theme.surfaceHover : "transparent"
                    border.color: item.sel ? Theme.accent : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12
                    Rectangle {
                        Layout.leftMargin: 8
                        width: 34; height: 34; radius: 9
                        color: Theme.soft(Theme.warning)
                        Text { anchors.centerIn: parent; text: item.modelData.major; color: Theme.warning; font.pixelSize: Theme.fontMd; font.weight: Font.Bold }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            spacing: 6
                            Text { text: qsTr("Java %1").arg(item.modelData.version); color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold }
                            Badge { text: item.modelData.arch; visible: text.length > 0 }
                        }
                        Text { text: item.modelData.path; color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    }
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: SettingsBackend.javaListLoading
            Spinner { anchors.horizontalCenter: parent.horizontalCenter; size: 26 }
            Text { text: qsTr("Looking for Java installations…"); color: Theme.textMuted; font.pixelSize: Theme.fontMd }
        }
        EmptyState {
            anchors.centerIn: parent
            visible: !SettingsBackend.javaListLoading && dlg.items.length === 0
            iconName: "coffee"
            title: qsTr("No Java found")
            text: dlg.major > 0 ? qsTr("No Java %1 installations were detected on this system.").arg(dlg.major) : qsTr("No Java installations were detected on this system.")
        }
    }

    buttons: [
        PButton { text: qsTr("Refresh"); iconName: "refresh-cw"; variant: "ghost"; enabled: !SettingsBackend.javaListLoading; onClicked: SettingsBackend.refreshJavaInstalls(true) },
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton {
            text: qsTr("Select"); variant: "primary"
            enabled: dlg.selectedPath.length > 0
            onClicked: { for (var i = 0; i < dlg.items.length; i++) if (dlg.items[i].path === dlg.selectedPath) { dlg.choose(dlg.items[i]); return } }
        }
    ]
}
