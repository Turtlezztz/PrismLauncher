import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Classic AboutDialog: version & build info, credits, license; plus update status.
PageScaffold {
    id: page
    title: qsTr("About")
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) { tabs.currentKey = key }
    Component.onCompleted: Router.section = "About"

    headerExtra: [
        PTabBar {
            id: tabs
            model: [ { key: "about", text: qsTr("About"), icon: "info" }, { key: "credits", text: qsTr("Credits"), icon: "heart" }, { key: "license", text: qsTr("License"), icon: "file-text" } ]
            currentKey: page.initialTab.length ? page.initialTab : "about"
        }
    ]

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: ["about", "credits", "license"].indexOf(tabs.currentKey)

        // ------------------------------------------------------------ about
        Flickable {
            clip: true
            contentHeight: aboutCol.implicitHeight + Theme.spacingXl
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            ColumnLayout {
                id: aboutCol
                width: Math.min(parent.width, 760)
                spacing: Theme.spacingLg

                Card {
                    Layout.fillWidth: true
                    implicitHeight: hero.implicitHeight + 2 * padding
                    RowLayout {
                        id: hero
                        width: parent.width
                        spacing: Theme.spacingXl
                        Image { source: "qrc:/qt/qml/PrismModern/qml/assets/logo.svg"; sourceSize: Qt.size(160, 160); Layout.preferredWidth: 80; Layout.preferredHeight: 80 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: LauncherInfo.name; color: Theme.text; font.pixelSize: Theme.fontXxl; font.weight: Font.Bold }
                            Text { text: LauncherInfo.version; color: Theme.textMuted; font.pixelSize: Theme.fontLg; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                text: qsTr("A custom launcher that makes managing Minecraft easier by allowing you to have multiple instances of Minecraft at once.")
                                color: Theme.textMuted; font.pixelSize: Theme.fontMd
                            }
                        }
                    }
                }

                // update status
                Card {
                    Layout.fillWidth: true
                    implicitHeight: upd.implicitHeight + 2 * padding
                    RowLayout {
                        id: upd
                        width: parent.width
                        spacing: Theme.spacing
                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: LauncherInfo.updateAvailable ? Theme.soft(Theme.success) : Theme.accentSoft
                            Icon { anchors.centerIn: parent; name: LauncherInfo.updateAvailable ? "download" : "badge-check"; size: 18; color: LauncherInfo.updateAvailable ? Theme.success : Theme.accent }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: LauncherInfo.updateAvailable ? qsTr("Version %1 is available").arg(LauncherInfo.updateVersion) : qsTr("Updates")
                                color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                text: LauncherInfo.updaterEnabled ? qsTr("Check whether a newer version of the launcher is available.")
                                      : qsTr("Updates for this build are managed outside the launcher (package manager, or a build without the updater).")
                                color: Theme.textMuted; font.pixelSize: Theme.fontSm
                            }
                        }
                        PButton {
                            visible: LauncherInfo.updateAvailable
                            text: qsTr("View update"); variant: "primary"
                            onClicked: {
                                var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/SetUpdateDialog.qml"))
                                var dlg = comp.createObject(page); dlg.closed.connect(function() { dlg.destroy(500) }); dlg.open()
                            }
                        }
                        PButton {
                            visible: LauncherInfo.updaterEnabled && !LauncherInfo.updateAvailable
                            text: qsTr("Check for updates"); iconName: "refresh-cw"
                            onClicked: LauncherInfo.checkForUpdates()
                        }
                        PButton {
                            visible: !LauncherInfo.updaterEnabled
                            text: qsTr("Releases"); iconName: "external-link"; variant: "ghost"
                            onClicked: App.openUrl(LauncherInfo.gitUrl + "/releases")
                        }
                    }
                }

                // build info
                Card {
                    Layout.fillWidth: true
                    implicitHeight: info.implicitHeight + 2 * padding
                    ColumnLayout {
                        id: info
                        width: parent.width
                        spacing: Theme.spacing
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Build information"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true }
                            PButton { text: qsTr("Copy"); iconName: "copy"; size: "sm"; onClicked: { App.copyToClipboard(LauncherInfo.buildInfo); Toasts.success(qsTr("Build information copied")) } }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2; columnSpacing: Theme.spacingXl; rowSpacing: 8
                            Repeater {
                                model: [
                                    { k: qsTr("Version"), v: LauncherInfo.version },
                                    { k: qsTr("Platform"), v: LauncherInfo.platform },
                                    { k: qsTr("Channel"), v: LauncherInfo.channel },
                                    { k: qsTr("Commit"), v: LauncherInfo.commit },
                                    { k: qsTr("Build date"), v: LauncherInfo.buildDate },
                                    { k: qsTr("Qt"), v: LauncherInfo.qtVersion }
                                ].filter(function(e) { return e.v && e.v.length })
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    Text { text: modelData.k; color: Theme.textMuted; font.pixelSize: Theme.fontMd; Layout.preferredWidth: 120 }
                                    Text { text: modelData.v; color: Theme.text; font.pixelSize: Theme.fontMd; font.family: modelData.k === qsTr("Commit") ? Theme.monoFamily : Theme.fontFamily; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }

                // links
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    PButton { text: qsTr("Source code"); iconName: "github"; onClicked: App.openUrl(LauncherInfo.gitUrl) }
                    PButton { text: qsTr("Help / Wiki"); iconName: "book"; onClicked: App.openUrl(LauncherInfo.links.help) }
                    PButton { visible: LauncherInfo.links.bugs.length > 0; text: qsTr("Report a bug"); iconName: "bug"; onClicked: App.openUrl(LauncherInfo.links.bugs) }
                    PButton { visible: LauncherInfo.links.discord.length > 0; text: "Discord"; iconName: "discord"; onClicked: App.openUrl(LauncherInfo.links.discord) }
                    PButton { visible: LauncherInfo.links.matrix.length > 0; text: "Matrix"; onClicked: App.openUrl(LauncherInfo.links.matrix) }
                    PButton { visible: LauncherInfo.links.reddit.length > 0; text: "Reddit"; onClicked: App.openUrl(LauncherInfo.links.reddit) }
                }
                Text { text: LauncherInfo.copyright; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
        }

        // ------------------------------------------------------------ credits / license
        Repeater {
            model: [ LauncherInfo.creditsHtml(), LauncherInfo.licenseHtml() ]
            delegate: Rectangle {
                required property string modelData
                radius: Theme.radiusLg; color: Theme.surface; border.color: Theme.border
                Flickable {
                    id: docFl
                    anchors.fill: parent; anchors.margins: Theme.spacingXl
                    clip: true
                    contentHeight: doc.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: PScrollBar {}
                    Text {
                        id: doc
                        width: docFl.width - 12
                        text: modelData
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap
                        color: Theme.text; linkColor: Theme.accent
                        font.pixelSize: Theme.fontMd
                        onLinkActivated: link => App.openUrl(link)
                        HoverHandler { cursorShape: doc.hoveredLink.length ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }
                }
            }
        }
    }
}
