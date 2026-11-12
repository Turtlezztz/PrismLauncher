import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Side panel with the details of the selected local resource (classic InfoFrame).
Item {
    id: panel
    property var info: ({})
    property bool shown: false
    property bool isMods: true
    property bool updatesAvailable: true
    property string singular: qsTr("mod")
    signal changeVersion()
    signal remove()
    signal toggleLock()
    signal toggleEnabled()
    signal checkUpdates()

    clip: true
    visible: Layout.preferredWidth > 1
    Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }

    Rectangle {
        id: card
        width: Math.min(340, Math.max(panel.width, 260))
        height: parent.height
        anchors.right: parent.right
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.border
        opacity: panel.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}

            ColumnLayout {
                id: col
                width: flick.width
                spacing: Theme.spacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    Rectangle {
                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                        radius: Theme.radius
                        color: Theme.surfaceAlt
                        border.color: Theme.border
                        Image {
                            id: bigIcon
                            anchors.fill: parent; anchors.margins: 4
                            source: panel.info.iconSource || ""
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            visible: status === Image.Ready && implicitWidth > 1
                        }
                        Icon { anchors.centerIn: parent; visible: !bigIcon.visible; name: panel.isMods ? "puzzle" : "package"; size: 24; color: Theme.textSubtle }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: panel.info.nameHtml || panel.info.name || ""
                            textFormat: Text.RichText
                            color: Theme.text
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: (panel.info.authors || []).length > 0
                            text: qsTr("by %1").arg((panel.info.authors || []).join(", "))
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            Badge { visible: !!panel.info.version; text: panel.info.version || "" }
                            Badge { visible: !!panel.info.provider; text: panel.info.provider || ""; tone: panel.info.provider === "Modrinth" ? "success" : "warning" }
                            Badge { visible: panel.info.enabled === false; text: qsTr("Disabled") }
                            Badge { visible: !!panel.info.updateLocked; text: qsTr("Locked"); iconName: "lock" }
                        }
                    }
                }

                // primary actions
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXs
                    PButton {
                        size: "sm"
                        text: panel.info.enabled ? qsTr("Disable") : qsTr("Enable")
                        iconName: panel.info.enabled ? "eye-off" : "toggle-left"
                        onClicked: panel.toggleEnabled()
                    }
                    PButton { size: "sm"; visible: panel.updatesAvailable && !!panel.info.hasMetadata; text: qsTr("Change version"); iconName: "history"; onClicked: panel.changeVersion() }
                    PButton { size: "sm"; visible: panel.updatesAvailable && !panel.info.updateLocked; text: qsTr("Check update"); iconName: "refresh-cw"; onClicked: panel.checkUpdates() }
                    PButton { size: "sm"; visible: !!panel.info.homepage; text: qsTr("Homepage"); iconName: "external-link"; onClicked: App.openUrl(panel.info.homepage) }
                    IconButton { size: Theme.controlHeightSm; visible: panel.updatesAvailable && !!panel.info.hasMetadata; iconName: panel.info.updateLocked ? "lock-open" : "lock"; tip: panel.info.updateLocked ? qsTr("Unlock updates") : qsTr("Lock updates"); onClicked: panel.toggleLock() }
                    IconButton { size: Theme.controlHeightSm; iconName: "trash-2"; tip: qsTr("Remove"); onClicked: panel.remove() }
                }

                // issues
                Rectangle {
                    Layout.fillWidth: true
                    visible: (panel.info.issues || []).length > 0
                    implicitHeight: issueCol.implicitHeight + 16
                    radius: Theme.radius
                    color: Theme.soft(Theme.warning)
                    ColumnLayout {
                        id: issueCol
                        anchors.fill: parent; anchors.margins: 8
                        spacing: 2
                        Repeater {
                            model: panel.info.issues || []
                            delegate: RowLayout {
                                required property string modelData
                                Layout.fillWidth: true
                                spacing: 6
                                Icon { name: "triangle-alert"; size: 13; color: Theme.warning; Layout.alignment: Qt.AlignTop }
                                Text { Layout.fillWidth: true; text: modelData; color: Theme.text; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: panel.info.descriptionHtml || ""
                    textFormat: Text.RichText
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontMd
                    wrapMode: Text.Wrap
                    linkColor: Theme.accent
                    onLinkActivated: link => App.openUrl(link)
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.spacing
                    rowSpacing: 6
                    component Key: Text { color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.alignment: Qt.AlignTop }
                    component Val: Text { color: Theme.text; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.StyledText; linkColor: Theme.accent; onLinkActivated: link => App.openUrl(link) }

                    Key { text: qsTr("File"); visible: fileVal.visible }
                    Val { id: fileVal; text: panel.info.fileName || ""; visible: text.length > 0 }
                    Key { text: qsTr("Mod ID"); visible: modIdVal.visible }
                    Val { id: modIdVal; text: panel.info.modId || ""; visible: panel.isMods && text.length > 0 }
                    Key { text: qsTr("Size"); visible: sizeVal.visible }
                    Val { id: sizeVal; text: panel.info.size || ""; visible: text.length > 0 }
                    Key { text: qsTr("Modified"); visible: dateVal.visible }
                    Val { id: dateVal; text: panel.info.date || ""; visible: text.length > 0 }
                    Key { text: qsTr("Loaders"); visible: loadersVal.visible }
                    Val { id: loadersVal; text: panel.info.loaders || ""; visible: text.length > 0 }
                    Key { text: qsTr("Minecraft"); visible: mcVal.visible }
                    Val { id: mcVal; text: panel.info.mcVersions || ""; visible: text.length > 0 }
                    Key { text: qsTr("Side"); visible: sideVal.visible }
                    Val { id: sideVal; text: panel.info.side || ""; visible: text.length > 0 }
                    Key { text: qsTr("Release"); visible: relVal.visible }
                    Val { id: relVal; text: panel.info.releaseType || ""; visible: text.length > 0 }
                    Key { text: qsTr("Pack format"); visible: pfVal.visible }
                    Val { id: pfVal; text: panel.info.packFormat || ""; visible: text.length > 0 }
                    Key { text: qsTr("License"); visible: licVal.visible }
                    Val { id: licVal; text: panel.info.licenseHtml || ""; visible: text.length > 0 }
                    Key { text: qsTr("Issues"); visible: issVal.visible }
                    Val { id: issVal; text: panel.info.issueTracker ? "<a href=\"" + panel.info.issueTracker + "\">" + panel.info.issueTracker + "</a>" : ""; visible: text.length > 0 }
                    Key { text: qsTr("Requires"); visible: reqVal.visible }
                    Val { id: reqVal; text: (panel.info.requires || []).join(", "); visible: text.length > 0 }
                    Key { text: qsTr("Required by"); visible: reqByVal.visible }
                    Val { id: reqByVal; text: (panel.info.requiredBy || []).join(", "); visible: text.length > 0 }
                    Key { text: qsTr("Updates"); visible: panel.updatesAvailable }
                    Val { visible: panel.updatesAvailable; text: panel.info.hasMetadata ? (panel.info.updateLocked ? qsTr("Locked") : qsTr("Tracked (%1)").arg(panel.info.provider || "")) : qsTr("No metadata") }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: panel.info.linkTip || ""
                    color: Theme.info
                    font.pixelSize: Theme.fontXs
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
