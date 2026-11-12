import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// UI for ResUpdateFlow (classic ResourceUpdateDialog + ChooseProviderDialog + ScrollMessageBox).
//   updater.begin(folderModel, includeDeps, releaseTypes)
Item {
    id: root
    property var folderModel: null
    readonly property alias flow: flow

    function begin(fm, includeDeps, releaseTypes) {
        folderModel = fm
        flow.start(fm, includeDeps, releaseTypes || [])
    }

    ResUpdateFlow {
        id: flow
        onNotice: (msg, kind) => Toasts.show(msg, kind)
        onStageChanged: root.handleStage()
    }

    function handleStage() {
        if (flow.stage !== "running") progress.close()
        switch (flow.stage) {
        case "askProvider":
            providerDlg.open(); break
        case "running":
            if (flow.task) progress.track(flow.task, { closeOnSuccess: true })
            break
        case "metadataFailed":
            choice.ask({
                title: qsTr("Metadata generation failed"),
                text: qsTr("Could not generate metadata for the following %1. Do you want to continue without them?").arg(flow.resourceLabel),
                details: flow.failures.map(f => "<b>" + f.name + "</b> (" + f.fileName + "): " + f.reason),
                icon: "triangle-alert",
                choices: [ { text: qsTr("Cancel"), value: false }, { text: qsTr("Continue"), value: true, variant: "primary" } ]
            }, function(v) { if (v) flow.proceed(false); else flow.cancel() })
            break
        case "checkFailed":
            choice.ask({
                title: qsTr("Failed to check for updates"),
                text: qsTr("Could not check or get the following %1 for updates. Do you want to continue without them?").arg(flow.resourceLabel),
                details: flow.failures.map(f => "<b>" + f.name + "</b>" + (f.reason.length ? ": " + f.reason : "")
                                               + (f.url.length ? " — <a href=\"" + f.url + "\">" + qsTr("get it manually") + "</a>" : "")),
                icon: "triangle-alert",
                checkText: qsTr("Disable unavailable %1").arg(flow.resourceLabel),
                choices: [ { text: qsTr("Cancel"), value: false }, { text: qsTr("Continue"), value: true, variant: "primary" } ]
            }, function(v, checked) { if (v) flow.proceed(checked); else flow.cancel() })
            break
        case "review":
            progress.close()
            reviewDlg.openWith(flow.updates)
            break
        case "done":
            progress.close()
            if (flow.message.length) Toasts.show(flow.message, "success")
            break
        case "error":
            progress.close()
            Dialogs.message({ title: qsTr("Update failed"), text: flow.message, kind: "error" })
            break
        }
    }

    ResTaskDialog { id: progress }
    ResChoiceDialog { id: choice }

    PDialog {
        id: providerDlg
        title: qsTr("Missing metadata")
        subtitle: qsTr("Some %1 don't have update metadata yet. Choose a platform to look them up on.").arg(flow.resourceLabel)
        iconName: "circle-alert"
        maxWidth: 520
        property bool _handled: false
        onOpened: _handled = false
        onClosed: if (!_handled) flow.cancel()
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(missingList.contentHeight + 16, 180)
            radius: Theme.radius
            color: Theme.surfaceAlt
            border.color: Theme.border
            ListView {
                id: missingList
                anchors.fill: parent; anchors.margins: 8
                clip: true
                model: flow.missingMetadata
                ScrollBar.vertical: PScrollBar {}
                delegate: Text { required property string modelData; width: ListView.view.width; text: "• " + modelData; color: Theme.text; font.pixelSize: Theme.fontSm + 1; elide: Text.ElideRight; topPadding: 2; bottomPadding: 2 }
            }
        }
        SegmentedControl {
            id: provChoice
            options: [ { value: "modrinth", text: "Modrinth" }, { value: "curseforge", text: "CurseForge" } ]
            value: "modrinth"
        }
        PCheckBox { id: tryOthers; text: qsTr("Try the other platform if not found"); checked: true }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: providerDlg.close() },
            PButton { text: qsTr("Skip these"); onClicked: { providerDlg._handled = true; providerDlg.close(); flow.chooseProvider("skip", false) } },
            PButton { text: qsTr("Look up"); variant: "primary"; onClicked: { providerDlg._handled = true; providerDlg.close(); flow.chooseProvider(provChoice.value, tryOthers.checked) } }
        ]
    }

    PDialog {
        id: reviewDlg
        title: qsTr("Updates available")
        subtitle: qsTr("Only checked items will be updated.")
        iconName: "refresh-cw"
        maxWidth: 680
        property var items: []
        property var excluded: ({})
        property bool _handled: false
        function openWith(list) {
            items = list
            var ex = {}
            for (var i = 0; i < list.length; ++i) if (!list[i].enabled) ex[list[i].key] = true
            excluded = ex
            _handled = false
            open()
        }
        function includedCount() { var n = 0; for (var i = 0; i < items.length; ++i) if (!excluded[items[i].key]) n++; return n }
        onClosed: if (!_handled) flow.cancel()

        ListView {
            id: updList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 440)
            clip: true
            spacing: 4
            model: reviewDlg.items
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            delegate: Rectangle {
                id: u
                required property var modelData
                property bool expanded: false
                readonly property bool included: !reviewDlg.excluded[modelData.key]
                width: updList.width
                height: uCol.implicitHeight + 16
                radius: Theme.radius
                color: Theme.surfaceAlt
                opacity: included ? 1 : 0.6
                ColumnLayout {
                    id: uCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        PCheckBox {
                            checked: u.included
                            onToggled: { var ex = Object.assign({}, reviewDlg.excluded); if (checked) delete ex[u.modelData.key]; else ex[u.modelData.key] = true; reviewDlg.excluded = ex }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                spacing: 6
                                Text { text: u.modelData.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 300 }
                                Badge { text: u.modelData.provider; tone: u.modelData.provider === "Modrinth" ? "success" : "warning" }
                                Badge { visible: u.modelData.dependency; text: qsTr("Dependency"); tone: "info" }
                                Badge { visible: u.modelData.versionType.length > 0 && u.modelData.versionType !== "Release"; text: u.modelData.versionType; tone: "warning" }
                            }
                            Text {
                                text: u.modelData.oldVersion + "  →  " + u.modelData.newVersion
                                color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                visible: u.modelData.requiredBy.length > 0
                                text: qsTr("Required by: %1").arg(u.modelData.requiredBy.join(", "))
                                color: Theme.textSubtle; font.pixelSize: Theme.fontXs; wrapMode: Text.Wrap; Layout.fillWidth: true
                            }
                        }
                        PButton {
                            size: "sm"; variant: "ghost"
                            visible: u.modelData.changelogHtml.length > 0
                            text: qsTr("Changelog")
                            trailingIconName: u.expanded ? "chevron-up" : "chevron-down"
                            onClicked: u.expanded = !u.expanded
                        }
                    }
                    Text {
                        visible: u.expanded
                        Layout.fillWidth: true
                        Layout.leftMargin: 34
                        text: u.expanded ? u.modelData.changelogHtml : ""
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap
                        color: Theme.textMuted
                        linkColor: Theme.accent
                        font.pixelSize: Theme.fontSm
                        onLinkActivated: link => App.openUrl(link)
                    }
                }
            }
        }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: reviewDlg.close() },
            PButton {
                text: qsTr("Update %1").arg(reviewDlg.includedCount())
                variant: "primary"; iconName: "download"
                enabled: reviewDlg.includedCount() > 0
                onClicked: {
                    reviewDlg._handled = true
                    reviewDlg.close()
                    var h = flow.install(Object.keys(reviewDlg.excluded))
                    if (h) progress.track(h, { closeOnSuccess: true })
                }
            }
        ]
    }
}
