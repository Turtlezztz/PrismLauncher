import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Confirms and runs a log upload to the configured paste service.
//   LogUploadDialog { id: up; log: myLog }   ...   up.ask(qsTr("Minecraft Log"))
PDialog {
    id: dlg
    property LogViewModel log
    property string name: ""
    property var info: ({})
    title: qsTr("Upload log?")
    iconName: "upload"
    maxWidth: 480

    function ask(n) {
        if (!log || !log.hasSource) return
        name = n
        info = log.uploadInfo()
        trim.checked = true
        open()
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font.pixelSize: Theme.fontMd
        text: qsTr("You are about to upload “%1” to %2. Double-check it for personal information first.").arg(dlg.name).arg(dlg.info.host || "")
    }
    Rectangle {
        Layout.fillWidth: true
        visible: !!dlg.info.tooLong
        implicitHeight: tooLongCol.implicitHeight + 24
        radius: Theme.radius
        color: Theme.soft(Theme.warning)
        ColumnLayout {
            id: tooLongCol
            anchors.fill: parent; anchors.margins: 12
            spacing: 6
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.text; font.pixelSize: Theme.fontSm
                text: qsTr("The log has %1 lines, more than mclo.gs accepts (%2). Without trimming, only the first %2 lines are kept and crashes at the end may be lost.")
                        .arg(dlg.info.lines || 0).arg(dlg.info.maxLines || 0)
            }
            PCheckBox {
                id: trim
                Layout.fillWidth: true
                text: qsTr("Trim the middle (keep the first %1 and last %2 lines)").arg(dlg.info.keepFirst || 0).arg(dlg.info.keepLast || 0)
            }
        }
    }
    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton {
            text: qsTr("Upload"); variant: "primary"; iconName: "upload"
            onClicked: { dlg.log.upload(dlg.name, !!dlg.info.tooLong && trim.checked); dlg.close(); Toasts.show(qsTr("Uploading log…"), "info") }
        }
    ]

    Connections {
        target: dlg.log
        function onUploadFinished(url) {
            Dialogs.message({ title: qsTr("Upload finished"),
                              text: qsTr("The <a href=\"%1\">link to the uploaded log</a> has been copied to your clipboard.").arg(url) })
        }
        function onUploadFailed(reason) { Dialogs.message({ title: qsTr("Failed to upload log"), text: reason, kind: "error" }) }
    }
}
