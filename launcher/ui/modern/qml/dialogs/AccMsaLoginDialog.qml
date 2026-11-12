import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Add a Microsoft account (classic MSALoginDialog): device code + QR, or sign in through the browser.
//   AccMsaLoginDialog { makeDefault: true; onSignedIn: name => ... }
PDialog {
    id: dlg
    property bool makeDefault: false
    signal signedIn(string name)

    title: qsTr("Add Microsoft account")
    subtitle: qsTr("Sign in with the Microsoft account that owns Minecraft.")
    iconName: "log-in"
    maxWidth: 620
    closePolicy: Popup.CloseOnEscape

    onOpened: login.start()
    onClosed: login.cancel()

    MsaLogin {
        id: login
        makeDefault: dlg.makeDefault
        onSucceeded: name => { Toasts.success(qsTr("Signed in as %1").arg(name)); dlg.signedIn(name); dlg.close() }
    }

    readonly property bool failed: !login.running && login.deviceState === "failed" && login.browserState === "failed"

    // ---------------------------------------------------------------- device code
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: codeRow.implicitHeight + 32
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        border.color: Theme.border

        RowLayout {
            id: codeRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 20

            // QR code
            Rectangle {
                Layout.alignment: Qt.AlignTop
                width: 150; height: 150; radius: Theme.radius
                color: login.deviceState === "code" ? "#ffffff" : Theme.surface
                border.color: Theme.border
                Image {
                    anchors.fill: parent; anchors.margins: 4
                    visible: login.deviceState === "code"
                    source: login.qrSource
                    smooth: false
                    fillMode: Image.PreserveAspectFit
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                }
                Spinner { anchors.centerIn: parent; visible: login.deviceState === "waiting" && login.running }
                Icon { anchors.centerIn: parent; visible: login.deviceState === "failed"; name: "circle-alert"; size: 28; color: Theme.danger }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 8
                Text { text: qsTr("Use a code"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    color: Theme.textMuted; font.pixelSize: Theme.fontSm
                    textFormat: Text.StyledText; linkColor: Theme.accent
                    text: login.deviceState === "code"
                          ? qsTr("Scan the QR code or open <a href=\"%1\">%2</a> and enter the code below if needed.").arg(login.verifyUrl).arg(login.displayUrl)
                          : login.deviceState === "failed" ? qsTr("This sign-in method failed:") : qsTr("Preparing a sign-in code…")
                    onLinkActivated: link => App.openUrl(link)
                }
                RowLayout {
                    visible: login.deviceState === "code"
                    spacing: 8
                    Rectangle {
                        implicitWidth: codeText.implicitWidth + 28; implicitHeight: 44
                        radius: Theme.radius; color: Theme.surface; border.color: Theme.borderStrong
                        Text {
                            id: codeText
                            anchors.centerIn: parent
                            text: login.code
                            color: Theme.text; font.family: Theme.monoFamily; font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 2
                        }
                    }
                    IconButton { iconName: "copy"; tip: qsTr("Copy code"); onClicked: { App.copyToClipboard(login.code); Toasts.show(qsTr("Code copied")) } }
                    PButton { text: qsTr("Open page"); iconName: "external-link"; size: "sm"; onClicked: login.openVerifyUrl() }
                }
                Text {
                    visible: login.deviceState !== "code" && login.deviceStatus.length > 0
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    color: login.deviceState === "failed" ? Theme.danger : Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    text: login.deviceStatus
                }
                RowLayout {
                    visible: login.deviceState === "code" && login.running
                    spacing: 8
                    Spinner { size: 14 }
                    Text { text: qsTr("Waiting for you to sign in…"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                }
            }
        }
    }

    // ---------------------------------------------------------------- browser
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
        Text { text: qsTr("or"); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        PButton {
            Layout.fillWidth: true
            size: "lg"
            variant: "primary"
            iconName: "globe"
            text: qsTr("Sign in with Microsoft in the browser")
            enabled: login.browserState === "ready"
            busy: login.browserState === "waiting" && login.running
            onClicked: if (!login.openBrowser()) Toasts.show(qsTr("The sign-in page is not ready yet"))
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            visible: login.browserState === "failed" || (login.browserState === "ready" && login.browserStatus.length > 0)
            color: login.browserState === "failed" ? Theme.danger : Theme.textMuted
            font.pixelSize: Theme.fontSm
            text: login.browserStatus
        }
    }

    buttons: [
        PButton { visible: dlg.failed; text: qsTr("Try again"); iconName: "refresh-cw"; onClicked: login.start() },
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() }
    ]
}
