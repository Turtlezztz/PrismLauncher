import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// "Update available" with release notes (classic UpdateAvailableDialog).
PDialog {
    id: dlg
    property string choice: "later"
    title: qsTr("A new version of %1 is available!").arg(LauncherInfo.name)
    subtitle: qsTr("Version %1 is now available — you have %2.").arg(LauncherInfo.updateVersion).arg(LauncherInfo.version)
    iconName: "download"
    maxWidth: 620
    onClosed: if (LauncherInfo.updateAvailable) LauncherInfo.respondToUpdate(choice)

    Text { text: qsTr("Release notes"); color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
        Flickable {
            id: fl
            anchors.fill: parent; anchors.margins: 14
            clip: true
            contentHeight: notes.implicitHeight
            ScrollBar.vertical: PScrollBar {}
            Text {
                id: notes
                width: fl.width
                text: LauncherInfo.updateNotesHtml
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: Theme.text; linkColor: Theme.accent; font.pixelSize: Theme.fontMd
                onLinkActivated: link => App.openUrl(link)
            }
        }
    }
    buttons: [
        PButton { text: qsTr("Skip this version"); variant: "ghost"; onClicked: { dlg.choice = "skip"; dlg.close() } },
        PButton { text: qsTr("Later"); onClicked: { dlg.choice = "later"; dlg.close() } },
        PButton { text: qsTr("Update now"); variant: "primary"; iconName: "download"; onClicked: { dlg.choice = "install"; dlg.close() } }
    ]
}
