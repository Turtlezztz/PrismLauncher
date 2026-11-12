import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Managed modpack info + updates (classic ManagedPackPage) for Modrinth / CurseForge packs.
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge

    ManagedPackBridge {
        id: pack
        instanceId: tab.instanceId
        Component.onCompleted: reload()
        onUpdateFinished: (ok, message, warnings) => {
            if (ok) Toasts.success(message); else Dialogs.message({ title: qsTr("Update failed"), text: message, kind: "error" })
            if (warnings.length) Dialogs.message({ title: qsTr("Warnings"), text: warnings.replace(/\n/g, "<br>"), kind: "warning" })
        }
    }

    function confirmUpdate(versionName, run) {
        Dialogs.confirm({
            title: versionName.length ? qsTr("Update to “%1”?").arg(versionName) : qsTr("Update the modpack?"),
            text: qsTr("Irreversible changes may be made to the instance's files. It is strongly recommended to make a backup copy of the instance first."),
            confirmText: qsTr("Update"), icon: "triangle-alert"
        }, function(ok) { if (ok) run() })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg

        // ---- pack card ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: info.implicitHeight + Theme.spacingLg * 2
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            RowLayout {
                id: info
                anchors.fill: parent; anchors.margins: Theme.spacingLg
                spacing: Theme.spacingLg
                Rectangle {
                    width: 48; height: 48; radius: 14
                    color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; name: "package"; size: 24; color: Theme.accent }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: pack.packName; color: Theme.text; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: tab.width * 0.5 }
                        Badge { text: pack.platformName; tone: "accent" }
                        Badge { visible: pack.local; text: qsTr("Local pack") }
                    }
                    Text {
                        visible: !pack.local
                        text: qsTr("Installed version: %1").arg(pack.packVersion || qsTr("unknown"))
                        color: Theme.textMuted; font.pixelSize: Theme.fontMd
                    }
                    Text {
                        visible: !pack.local
                        text: qsTr("Pack ID %1  ·  Version ID %2").arg(pack.packId).arg(pack.versionId)
                        color: Theme.textSubtle; font.pixelSize: Theme.fontSm
                    }
                }
                PButton { visible: pack.websiteUrl.length > 0; size: "sm"; variant: "ghost"; iconName: "external-link"; text: qsTr("Website"); onClicked: App.openUrl(pack.websiteUrl) }
            }
        }

        // ---- updating ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: pack.updating ? 44 : 0
            visible: Layout.preferredHeight > 0
            opacity: pack.updating ? 1 : 0
            clip: true
            radius: Theme.radius
            color: Theme.accentSoft
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                spacing: Theme.spacing
                Spinner { size: 16; visible: pack.updating }
                Text { Layout.fillWidth: true; text: pack.updateStatus.length ? pack.updateStatus : qsTr("Updating modpack…"); color: Theme.text; elide: Text.ElideRight }
                PProgressBar { Layout.preferredWidth: 200; indeterminate: pack.updateProgress < 0; value: Math.max(0, pack.updateProgress) }
            }
        }

        // ---- local pack: URL ----
        Rectangle {
            visible: pack.local
            Layout.fillWidth: true
            implicitHeight: localCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            ColumnLayout {
                id: localCol
                anchors.fill: parent; anchors.margins: Theme.spacingLg
                spacing: Theme.spacing
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontMd
                    text: qsTr("This is a local modpack. It can be updated from a file in %1 format or from a URL. Using a different format may break the instance. Make sure you trust the URL.").arg(pack.platformName)
                }
                RowLayout {
                    Layout.fillWidth: true
                    PTextField { id: urlField; Layout.fillWidth: true; placeholderText: "https://…"; text: pack.customUrl; onEditingFinished: pack.customUrl = text }
                    PButton {
                        text: qsTr("Update pack"); variant: "primary"; iconName: "download"
                        enabled: urlField.text.trim().length > 0 && !pack.updating
                        onClicked: { pack.customUrl = urlField.text; tab.confirmUpdate("", function() { pack.updateToSelected() }) }
                    }
                }
            }
        }

        // ---- versions + changelog ----
        RowLayout {
            visible: !pack.local
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Text { text: qsTr("Update to"); color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium }
            PComboBox {
                id: versionBox
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                enabled: !pack.loading && pack.versions.length > 0
                model: pack.versions.map(function(v) { return v.current ? qsTr("%1 (current)").arg(v.name) : v.name })
                displayText: pack.loading ? qsTr("Loading versions…") : pack.failed ? qsTr("No versions found") : currentText
                currentIndex: pack.selectedIndex
                onActivated: i => pack.selectedIndex = i
            }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Reload versions"); enabled: !pack.loading; onClicked: pack.reload() }
            Item { Layout.fillWidth: true }
            PButton {
                text: qsTr("Update"); variant: "primary"; iconName: "download"
                enabled: pack.selectedIndex >= 0 && !pack.updating && !pack.loading
                onClicked: tab.confirmUpdate(pack.selectedVersionName(), function() { pack.updateToSelected() })
            }
            PButton {
                id: moreUpd
                iconName: "ellipsis"; enabled: !pack.updating
                onClicked: updMenu.popup(moreUpd, moreUpd.width - updMenu.width, moreUpd.height + 4)
            }
        }

        Rectangle {
            visible: !pack.local
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            clip: true
            Flickable {
                id: logFlick
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                contentHeight: changelog.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: PScrollBar {}
                Text {
                    id: changelog
                    width: logFlick.width
                    text: pack.changelog
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: Theme.text
                    linkColor: Theme.accent
                    font.pixelSize: Theme.fontMd
                    onLinkActivated: link => App.openUrl(link)
                    HoverHandler { cursorShape: changelog.hoveredLink.length ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: pack.loading
                Spinner { size: 26; Layout.alignment: Qt.AlignHCenter }
                Text { text: qsTr("Fetching versions and changelogs…"); color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter }
            }
        }
        Item { visible: pack.local; Layout.fillHeight: true }
    }

    PMenu {
        id: updMenu
        implicitWidth: 230
        PMenuItem { text: qsTr("Update from file…"); iconName: "file-archive"; onTriggered: tab.confirmUpdate("", function() { pack.updateFromFile() }) }
        PMenuItem {
            text: qsTr("Update from URL…"); iconName: "link"
            onTriggered: Dialogs.prompt({ title: qsTr("Update from URL"), text: qsTr("Enter the download URL of the modpack file:"), placeholder: "https://…", confirmText: qsTr("Continue") },
                function(v) {
                    if (v === null || !v.trim().length) return
                    var err = pack.validateUrl(v)
                    if (err.length) { Toasts.error(err); return }
                    tab.confirmUpdate("", function() { pack.updateFromUrl(v) })
                })
        }
    }
}
