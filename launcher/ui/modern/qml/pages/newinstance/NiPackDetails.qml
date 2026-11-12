import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Details of the selected modpack: header, links, version picker and the description.
Rectangle {
    id: root
    property NIPackBrowser browser: null
    readonly property var info: browser ? browser.current : ({})
    readonly property bool hasSelection: browser !== null && browser.selectedRow >= 0

    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border
    clip: true

    EmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 320)
        visible: !root.hasSelection
        iconName: "package"
        title: qsTr("Pick a modpack")
        text: qsTr("Select one to see details and versions.")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacing
        visible: root.hasSelection
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            NiPackLogo { size: 64; source: root.info.logo || ""; name: root.info.name || "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: root.info.name || ""; color: Theme.text; font.pixelSize: Theme.fontXl; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text {
                    visible: (root.info.authorsHtml || "").length > 0
                    text: qsTr("by %1").arg(root.info.authorsHtml || "")
                    textFormat: Text.StyledText
                    color: Theme.textMuted; linkColor: Theme.accent; font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight; Layout.fillWidth: true
                    onLinkActivated: link => App.openUrl(link)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
                Text { visible: (root.info.mcVersion || "").length > 0; text: qsTr("Minecraft %1").arg(root.info.mcVersion || ""); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: !!root.info.archived || (root.info.warning || "").length > 0
            implicitHeight: warnText.implicitHeight + 16
            radius: Theme.radius; color: Theme.soft(Theme.warning)
            Text {
                id: warnText
                anchors.fill: parent; anchors.margins: 8
                text: root.info.warning || qsTr("This project has been archived. It will not receive any further updates unless the author decides to unarchive it.")
                color: Theme.text; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
            }
        }

        // links + donations
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: (root.info.links || []).length + (root.info.donate || []).length > 0
            Repeater {
                model: (root.info.links || []).concat(root.info.donate || [])
                delegate: NiChip {
                    required property var modelData
                    required property int index
                    text: modelData.label
                    iconName: index >= (root.info.links || []).length ? "heart" : "external-link"
                    onClicked: App.openUrl(modelData.url)
                    PToolTip { visible: parent.hovered; text: modelData.url }
                }
            }
        }

        // version
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Text { text: qsTr("Version"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            PComboBox {
                id: versionBox
                Layout.fillWidth: true
                enabled: root.browser && root.browser.versions.length > 0
                model: root.browser ? root.browser.versions : []
                textRole: "text"
                currentIndex: root.browser ? root.browser.versionIndex : -1
                displayText: root.browser && root.browser.versionsLoading && root.browser.versions.length === 0 ? qsTr("Loading versions…")
                           : root.browser && root.browser.versions.length === 0 ? qsTr("No version is available")
                           : currentIndex < 0 ? qsTr("Choose a version") : currentText
                onActivated: idx => root.browser.selectVersion(idx)
            }
            Spinner { visible: root.browser && root.browser.versionsLoading; size: 16 }
        }
        Text {
            Layout.fillWidth: true
            visible: root.browser && versionBox.currentIndex >= 0 && root.browser.versions.length > versionBox.currentIndex && (root.browser.versions[versionBox.currentIndex].mcVersions || "").length > 0
            text: visible ? qsTr("For Minecraft %1").arg(root.browser.versions[versionBox.currentIndex].mcVersions) : ""
            color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; elide: Text.ElideRight
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // description
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: desc.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            Text {
                id: desc
                width: flick.width - 12
                text: root.info.descriptionHtml || root.info.summary || ""
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: Theme.text
                linkColor: Theme.accent
                font.pixelSize: Theme.fontMd
                lineHeight: 1.15
                onLinkActivated: link => App.openUrl(link)
                HoverHandler { cursorShape: desc.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
            Spinner { anchors.horizontalCenter: parent.horizontalCenter; y: desc.implicitHeight + 12; visible: !!root.info.detailsLoading; size: 18 }
        }
    }
    // reset scroll for a new selection
    Connections { target: root.browser; function onSelectionChanged() { flick.contentY = 0 } }
}
