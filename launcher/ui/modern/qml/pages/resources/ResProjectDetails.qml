import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Project details pane of the resource browser: header, links, version picker, description.
Rectangle {
    id: pane
    property var model: null           // ResSearchModel
    property bool changeVersionMode: false
    property string singular: qsTr("mod")
    signal installNow()

    readonly property var cur: model ? model.current : ({})
    readonly property bool hasProject: cur.name !== undefined
    readonly property var versions: model ? model.currentVersions : []
    readonly property bool curSelected: model ? (model.selectedCount, cur, model.isCurrentVersionSelected()) : false

    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border
    clip: true

    EmptyState {
        anchors.centerIn: parent
        visible: !pane.hasProject
        iconName: pane.model && pane.model.searching ? "search" : "package"
        title: pane.model && pane.model.searching ? qsTr("Loading…") : qsTr("Select a project")
        text: pane.model && pane.model.searching ? "" : qsTr("Pick a result to see its description and versions.")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacing
        visible: pane.hasProject

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Rectangle {
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                radius: Theme.radius
                color: Theme.surfaceAlt
                clip: true
                Image {
                    id: logo
                    anchors.fill: parent
                    source: pane.cur.logo || ""
                    sourceSize: Qt.size(128, 128)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
                Icon { anchors.centerIn: parent; visible: logo.status !== Image.Ready; name: "package"; size: 24; color: Theme.textSubtle }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: pane.cur.name || ""
                        color: Theme.text
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: implicitWidth > width
                        Layout.maximumWidth: implicitWidth
                    }
                    Badge { visible: !!pane.cur.installed; text: qsTr("Installed"); tone: "success" }
                    Item { Layout.fillWidth: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: (pane.cur.authors || []).length > 0
                    textFormat: Text.StyledText
                    text: qsTr("by %1").arg((pane.cur.authors || []).map(a => a.url ? "<a href=\"" + a.url + "\">" + a.name + "</a>" : a.name).join(", "))
                    color: Theme.textMuted
                    linkColor: Theme.accent
                    font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight
                    onLinkActivated: link => App.openUrl(link)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: pane.cur.links || []
                        delegate: PButton {
                            required property var modelData
                            size: "sm"; variant: "ghost"
                            iconName: modelData.icon
                            text: modelData.name
                            onClicked: App.openUrl(modelData.url)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: !!pane.cur.archived
            implicitHeight: archivedText.implicitHeight + 16
            radius: Theme.radius
            color: Theme.soft(Theme.warning)
            Text {
                id: archivedText
                anchors.fill: parent; anchors.margins: 8
                text: qsTr("This project has been archived. It will not receive any further updates unless the author decides to unarchive it.")
                color: Theme.text; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
            }
        }

        // version picker
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: verRow.implicitHeight + 20
            radius: Theme.radius
            color: Theme.surfaceAlt
            border.color: Theme.border
            RowLayout {
                id: verRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: Theme.spacingSm
                Text { text: qsTr("Version"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                Spinner { visible: pane.model && pane.model.currentLoading; size: 16 }
                PComboBox {
                    id: versionBox
                    Layout.fillWidth: true
                    visible: pane.versions.length > 0
                    textRole: "text"; valueRole: "value"
                    model: pane.versions.map(v => ({
                        value: v.index,
                        text: v.name + (v.type.length ? "  [" + v.type + "]" : "") + (v.installed ? qsTr("  [installed]") : "") + (v.selected ? qsTr("  [selected]") : "")
                    }))
                    currentIndex: {
                        for (var i = 0; i < pane.versions.length; ++i) if (pane.versions[i].index === pane.model.currentVersionIndex) return i
                        return -1
                    }
                    onActivated: pane.model.currentVersionIndex = currentValue
                }
                Text {
                    Layout.fillWidth: true
                    visible: pane.versions.length === 0 && !(pane.model && pane.model.currentLoading) && !!pane.cur.versionsLoaded
                    text: qsTr("No compatible versions. The author may have blocked downloads from third-party launchers, or none match your filters.")
                    color: Theme.warning; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
                }
                PButton {
                    visible: pane.versions.length > 0
                    variant: !pane.changeVersionMode && pane.curSelected ? "subtle" : "primary"
                    iconName: pane.changeVersionMode ? "download" : pane.curSelected ? "check" : "plus"
                    text: pane.changeVersionMode ? qsTr("Install this version") : pane.curSelected ? qsTr("Selected") : qsTr("Select %1").arg(pane.singular)
                    onClicked: {
                        if (pane.changeVersionMode) {
                            if (!pane.model.isCurrentVersionSelected()) pane.model.toggleCurrentVersion()
                            pane.installNow()
                        } else pane.model.toggleCurrentVersion()
                    }
                }
                PButton {
                    visible: pane.versions.length === 0 && !!pane.cur.website
                    text: qsTr("Open website"); iconName: "external-link"; size: "sm"
                    onClicked: App.openUrl(pane.cur.website)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            readonly property var v: pane.versions.find(x => x.index === (pane.model ? pane.model.currentVersionIndex : -1))
            visible: !!v
            text: v ? [v.fileName, v.mcVersions.length ? "Minecraft " + v.mcVersions : "", v.loaders, v.date].filter(s => s && s.length).join("  ·  ") : ""
            color: Theme.textSubtle
            font.pixelSize: Theme.fontXs
            elide: Text.ElideRight
        }

        // description
        Flickable {
            id: descFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: desc.implicitHeight + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            Text {
                id: desc
                width: descFlick.width - 12
                text: (pane.cur.descriptionHtml || "").replace(/%IMGW%/g, Math.max(100, Math.round(width)))
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: Theme.text
                linkColor: Theme.accent
                font.pixelSize: Theme.fontMd
                onLinkActivated: link => { if (pane.model.isSafeUrl(link)) App.openUrl(link) }
                HoverHandler { cursorShape: desc.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
            Connections { target: pane; function onCurChanged() { descFlick.contentY = 0 } }
        }
    }
}
