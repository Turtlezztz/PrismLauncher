import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Install a managed Java runtime (classic Java::InstallDialog): vendor → major version → build → download.
//   SetInstallJavaDialog { instanceId: "" ; onInstalled: ... }
PDialog {
    id: dlg
    property string instanceId: ""
    signal installed()

    title: qsTr("Install Java")
    subtitle: qsTr("Downloads a Java runtime into the launcher's Java folder.")
    iconName: "download"
    maxWidth: 860
    closePolicy: installer.installing ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    showClose: !installer.installing

    JavaInstaller {
        id: installer
        instanceId: dlg.instanceId
        onInstallFinished: (ok, message) => {
            if (ok) { Toasts.success(message); dlg.installed(); dlg.close() }
            else if (message.length) Dialogs.message({ title: qsTr("Error"), text: message, kind: "error" })
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing
        PTabBar {
            model: installer.providers.map(function(p) { return { key: p.uid, text: p.name } })
            currentKey: installer.provider
            onActivated: key => installer.provider = key
            enabled: !installer.installing
        }
        Item { Layout.fillWidth: true }
        PCheckBox {
            text: qsTr("Recommended only")
            checked: installer.recommendedOnly
            onToggled: installer.recommendedOnly = checked
            enabled: !installer.installing
        }
        IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh"); enabled: !installer.installing; onClicked: installer.reload() }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 340
        spacing: Theme.spacing
        enabled: !installer.installing

        // ---- majors
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border; clip: true
            ListView {
                anchors.fill: parent; anchors.margins: 4
                model: installer.majors
                spacing: 2
                ScrollBar.vertical: PScrollBar {}
                delegate: AbstractButton {
                    id: mj
                    required property var modelData
                    readonly property bool sel: installer.major === modelData.id
                    width: ListView.view.width; height: 38
                    hoverEnabled: true
                    onClicked: installer.major = modelData.id
                    background: Rectangle { radius: Theme.radiusSm + 2; color: mj.sel ? Theme.accentSoft : mj.hovered ? Theme.surfaceHover : "transparent" }
                    contentItem: RowLayout {
                        spacing: 8
                        Text { Layout.leftMargin: 10; text: mj.modelData.name; color: mj.sel ? Theme.accent : Theme.text; font.pixelSize: Theme.fontMd; font.weight: mj.sel ? Font.DemiBold : Font.Medium; Layout.fillWidth: true }
                        Badge { visible: mj.modelData.recommended; text: qsTr("Recommended"); tone: "success"; Layout.rightMargin: 8 }
                    }
                }
            }
            Spinner { anchors.centerIn: parent; visible: installer.loadingMajors }
            Text {
                anchors.fill: parent; anchors.margins: 16
                visible: !installer.loadingMajors && installer.majors.length === 0
                text: installer.majorsError.length ? installer.majorsError : qsTr("No Java versions are currently available in the meta.")
                wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontSm
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
        }

        // ---- builds
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border; clip: true
            ListView {
                id: builds
                anchors.fill: parent; anchors.margins: 4
                model: installer.builds
                spacing: 2
                ScrollBar.vertical: PScrollBar {}
                delegate: AbstractButton {
                    id: bd
                    required property var modelData
                    readonly property bool sel: installer.selectedBuild === modelData.index
                    width: ListView.view.width; height: 50
                    hoverEnabled: true
                    onClicked: installer.selectedBuild = modelData.index
                    onDoubleClicked: { installer.selectedBuild = modelData.index; installer.install() }
                    background: Rectangle {
                        radius: Theme.radiusSm + 2
                        color: bd.sel ? Theme.accentSoft : bd.hovered ? Theme.surfaceHover : "transparent"
                        border.color: bd.sel ? Theme.accent : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        ColumnLayout {
                            Layout.leftMargin: 10
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: bd.modelData.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: [bd.modelData.version, bd.modelData.vendor, bd.modelData.released].filter(function(s) { return s && s.length }).join(" · "); color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Badge { visible: bd.modelData.packageType.length > 0; text: bd.modelData.packageType.toUpperCase(); Layout.rightMargin: 10 }
                    }
                }
            }
            Spinner { anchors.centerIn: parent; visible: installer.loadingBuilds }
            Text {
                anchors.fill: parent; anchors.margins: 16
                visible: !installer.loadingBuilds && installer.builds.length === 0 && installer.major.length > 0
                text: installer.buildsError.length ? installer.buildsError : qsTr("No Java versions are currently available for your OS.")
                wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontSm
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: installer.installing
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { text: installer.status; color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: Math.round(installer.progress * 100) + "%"; color: Theme.textMuted; font.pixelSize: Theme.fontSm; visible: installer.progress > 0 }
        }
        PProgressBar { Layout.fillWidth: true; value: installer.progress; indeterminate: installer.progress <= 0 }
    }

    buttons: [
        PButton { text: installer.installing ? qsTr("Stop") : qsTr("Cancel"); onClicked: installer.installing ? installer.cancel() : dlg.close() },
        PButton {
            text: qsTr("Download"); variant: "primary"; iconName: "download"
            busy: installer.installing
            enabled: installer.selectedBuild >= 0 && !installer.installing
            onClicked: installer.install()
        }
    ]
}
