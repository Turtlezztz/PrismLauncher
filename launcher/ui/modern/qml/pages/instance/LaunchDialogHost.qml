import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// QML side of the launch flow dialogs (LaunchUi / ModernLaunchHandler): account choice, offline name, demo,
// profile setup, re-login, progress, kill confirmation, profiler. Created by C++ inside the main window.
Item {
    id: host
    anchors.fill: parent
    z: 1000
    property var queue: []
    property int current: -1
    property string kind: ""
    property var req: ({})

    function show(id, k, d) {
        current = id; kind = k; req = d
        var dlg = dialogFor(k)
        if (!dlg) { LaunchUi.respond(id, {}); next(); return }
        dlg.prepare()
        dlg.open()
    }
    function dialogFor(k) {
        switch (k) {
        case "noAccounts": case "playDemo": case "reauth": case "confirmKill": return confirmDlg
        case "chooseAccount": return accountDlg
        case "offlineName": return nameDlg
        case "profileSetup": return profileDlg
        case "progress": return progressDlg
        case "profiler": return profilerDlg
        }
        return null
    }
    function answer(result) {
        var id = current
        current = -1
        LaunchUi.respond(id, result)
        Qt.callLater(next)
    }
    function next() {
        if (current >= 0 || queue.length === 0) return
        var q = queue.shift()
        show(q.id, q.kind, q.data)
    }

    Connections {
        target: LaunchUi
        function onRequested(id, kind, data) {
            host.queue.push({ id: id, kind: kind, data: data })
            host.next()
        }
        // the C++ side completed the request itself (task finished, profile created)
        function onRequestFinished(id) {
            if (id !== host.current) return
            host.current = -1
            if (host.kind === "progress") progressDlg.close()
            else if (host.kind === "profileSetup") profileDlg.close()
            Qt.callLater(host.next)
        }
        function onProgressChanged(id, status, cur, total) {
            if (id !== host.current) return
            progressDlg.status = status
            progressDlg.progress = total > 0 ? cur / total : -1
        }
        function onErrorRaised(title, message) { Dialogs.message({ title: title, text: message.replace(/\n/g, "<br>"), kind: "error" }) }
        function onLaunchFailedFor(instanceId, name, reason) {
            Toasts.show(qsTr("“%1” failed to launch: %2").arg(name).arg(reason), "error",
                        { text: qsTr("Show log"), run: function() { Router.push("Instance", { instanceId: instanceId, initialTab: "console" }) } })
        }
        function onProfileNameChecked(id, name, status, message) {
            if (id !== host.current || name !== profileField.text) return
            profileDlg.status = status
            profileDlg.message = message
        }
        function onProfileCreateFailed(id, message) {
            if (id !== host.current) return
            profileDlg.working = false
            profileDlg.status = "error"
            profileDlg.message = message
        }
    }

    // ---- generic yes/no ----
    PDialog {
        id: confirmDlg
        property bool accepted: false
        property string body: ""
        property string okText: ""
        property bool danger: false
        maxWidth: 460
        closePolicy: Popup.CloseOnEscape
        function prepare() {
            accepted = false
            switch (host.kind) {
            case "noAccounts":
                title = qsTr("No accounts"); iconName = "user"; danger = false
                body = qsTr("To play Minecraft you need at least one Microsoft account which owns Minecraft. Would you like to add an account now?")
                okText = qsTr("Add account"); break
            case "playDemo":
                title = qsTr("Play demo?"); iconName = "gamepad-2"; danger = false
                body = (host.req.text || "").replace(/\n/g, "<br>") + "<br><br>" + qsTr("Do you want to play the demo?")
                okText = qsTr("Play demo"); break
            case "reauth":
                title = qsTr("Account refresh failed"); iconName = "key-round"; danger = false
                body = qsTr("%1. Do you want to sign in to this account again?").arg(host.req.reason || "")
                okText = qsTr("Sign in again"); break
            case "confirmKill":
                title = qsTr("Kill Minecraft?"); iconName = "skull"; danger = true
                body = qsTr("This can corrupt the instance and should only be used if Minecraft is frozen.")
                okText = qsTr("Kill"); break
            }
        }
        onClosed: host.answer({ accepted: accepted })
        Text { Layout.fillWidth: true; text: confirmDlg.body; wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontMd; textFormat: Text.StyledText }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: confirmDlg.close() },
            PButton { text: confirmDlg.okText; variant: confirmDlg.danger ? "danger" : "primary"; onClicked: { confirmDlg.accepted = true; confirmDlg.close() } }
        ]
    }

    // ---- account choice ----
    PDialog {
        id: accountDlg
        property bool accepted: false
        property string selectedId: ""
        title: qsTr("Choose an account")
        iconName: "users"
        maxWidth: 440
        closePolicy: Popup.CloseOnEscape
        function prepare() {
            accepted = false
            subtitle = host.req.message || ""
            var a = host.req.accounts || []
            selectedId = a.length ? a[0].id : ""
            defaultBox.checked = false
        }
        onClosed: host.answer({ accepted: accepted, accountId: selectedId, useAsDefault: defaultBox.checked })
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 280)
            clip: true
            spacing: 4
            model: host.kind === "chooseAccount" ? (host.req.accounts || []) : []
            delegate: Rectangle {
                id: acc
                required property var modelData
                readonly property bool sel: accountDlg.selectedId === modelData.id
                width: ListView.view.width
                height: 48
                radius: Theme.radius
                color: sel ? Theme.accentSoft : accHover.hovered ? Theme.surfaceHover : "transparent"
                border.color: sel ? Theme.accent : "transparent"
                HoverHandler { id: accHover }
                TapHandler { onTapped: accountDlg.selectedId = acc.modelData.id; onDoubleTapped: { accountDlg.accepted = true; accountDlg.close() } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: Theme.spacing
                    Image { visible: acc.modelData.face.length > 0; source: acc.modelData.face; Layout.preferredWidth: 28; Layout.preferredHeight: 28; smooth: false }
                    Icon { visible: !acc.modelData.face.length; name: "user"; size: 20; color: Theme.textMuted }
                    Text { Layout.fillWidth: true; text: acc.modelData.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; elide: Text.ElideRight }
                    Badge { text: acc.modelData.type }
                }
            }
        }
        PCheckBox { id: defaultBox; text: qsTr("Use as default account"); Layout.fillWidth: true }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: accountDlg.close() },
            PButton { text: qsTr("Play"); variant: "primary"; iconName: "play"; enabled: accountDlg.selectedId.length > 0; onClicked: { accountDlg.accepted = true; accountDlg.close() } }
        ]
    }

    // ---- offline / demo name ----
    PDialog {
        id: nameDlg
        property bool accepted: false
        iconName: "user"
        maxWidth: 440
        closePolicy: Popup.CloseOnEscape
        readonly property bool valid: allowAny.checked ? nameField.text.length > 0 : /^[A-Za-z0-9_]{3,16}$/.test(nameField.text)
        function prepare() {
            accepted = false
            title = host.req.title || qsTr("Player name")
            subtitle = ""
            allowAny.checked = false
            nameField.text = host.req.name || ""
        }
        onOpened: { nameField.forceActiveFocus(); nameField.selectAll() }
        onClosed: host.answer({ accepted: accepted, name: nameField.text })
        Text { Layout.fillWidth: true; text: (host.req.text || "").replace(/\n/g, "<br>"); wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontMd; textFormat: Text.StyledText; visible: text.length > 0 }
        PTextField {
            id: nameField
            Layout.fillWidth: true
            iconName: "user"
            placeholderText: qsTr("Player name")
            error: text.length > 0 && !nameDlg.valid
            onAccepted: if (nameDlg.valid) { nameDlg.accepted = true; nameDlg.close() }
        }
        Text {
            Layout.fillWidth: true
            visible: nameField.text.length > 0 && !nameDlg.valid
            text: qsTr("Names must be 3 to 16 characters long and only use letters, digits and underscores.")
            color: Theme.danger; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
        }
        PCheckBox { id: allowAny; Layout.fillWidth: true; text: qsTr("Allow invalid usernames (may cause issues)") }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: nameDlg.close() },
            PButton { text: qsTr("Play"); variant: "primary"; iconName: "play"; enabled: nameDlg.valid; onClicked: { nameDlg.accepted = true; nameDlg.close() } }
        ]
    }

    // ---- Minecraft profile setup ----
    PDialog {
        id: profileDlg
        property string status: ""      // "" | pending | available | taken | invalid | error
        property string message: ""
        property bool working: false
        title: qsTr("Choose your Minecraft name")
        iconName: "user"
        maxWidth: 460
        closePolicy: Popup.NoAutoClose
        showClose: false
        function prepare() {
            status = ""; message = ""; working = false
            subtitle = qsTr("The account %1 doesn't have a Minecraft profile yet. Pick a name for it.").arg(host.req.account || "")
            profileField.text = ""
        }
        onOpened: profileField.forceActiveFocus()
        Timer { id: checkTimer; interval: 700; onTriggered: LaunchUi.checkProfileName(host.current, profileField.text) }
        PTextField {
            id: profileField
            Layout.fillWidth: true
            placeholderText: qsTr("Name")
            enabled: !profileDlg.working
            error: profileDlg.status === "taken" || profileDlg.status === "invalid" || profileDlg.status === "error"
            onTextEdited: { profileDlg.status = "pending"; profileDlg.message = ""; checkTimer.restart() }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: profileDlg.status.length > 0
            spacing: 6
            Spinner { size: 14; visible: profileDlg.status === "pending" || profileDlg.working }
            Icon { visible: profileDlg.status === "available" && !profileDlg.working; name: "circle-check"; size: 14; color: Theme.success }
            Icon { visible: ["taken", "invalid", "error"].indexOf(profileDlg.status) >= 0; name: "circle-alert"; size: 14; color: Theme.danger }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSm
                color: profileDlg.status === "available" ? Theme.success : profileDlg.status === "pending" ? Theme.textMuted : Theme.danger
                text: profileDlg.working ? qsTr("Creating profile…") : profileDlg.status === "available" ? qsTr("This name is available.")
                    : profileDlg.status === "pending" ? qsTr("Checking…") : profileDlg.message
            }
        }
        buttons: [
            PButton { text: qsTr("Cancel"); enabled: !profileDlg.working; onClicked: { profileDlg.close(); host.answer({ accepted: false }) } },
            PButton {
                text: qsTr("Create profile"); variant: "primary"; busy: profileDlg.working
                enabled: profileDlg.status === "available" && !profileDlg.working
                onClicked: { profileDlg.working = true; LaunchUi.createProfile(host.current, profileField.text) }
            }
        ]
    }

    // ---- blocking progress (account refresh) ----
    PDialog {
        id: progressDlg
        property string status: ""
        property real progress: -1
        property bool skippable: false
        title: qsTr("Please wait")
        iconName: "refresh-cw"
        maxWidth: 420
        showClose: false
        closePolicy: Popup.NoAutoClose
        function prepare() { status = host.req.status || ""; progress = -1; skippable = !!host.req.skippable }
        Text { Layout.fillWidth: true; text: progressDlg.status.length ? progressDlg.status : qsTr("Refreshing account…"); color: Theme.textMuted; wrapMode: Text.Wrap }
        PProgressBar { Layout.fillWidth: true; indeterminate: progressDlg.progress < 0; value: Math.max(0, progressDlg.progress) }
        buttons: [
            PButton { visible: progressDlg.skippable; text: qsTr("Skip"); onClicked: { progressDlg.close(); host.answer({ skip: true }) } }
        ]
    }

    // ---- profiler ----
    PDialog {
        id: profilerDlg
        property bool done: false
        title: qsTr("Waiting for profiler")
        iconName: "clock"
        maxWidth: 480
        closePolicy: Popup.NoAutoClose
        showClose: false
        function prepare() { disableBox.checked = false }
        Text { Layout.fillWidth: true; text: (host.req.text || "").replace(/\n/g, "<br>"); wrapMode: Text.Wrap; color: Theme.textMuted; textFormat: Text.StyledText }
        PCheckBox { id: disableBox; Layout.fillWidth: true; text: qsTr("Disable profiler on next launch") }
        buttons: [
            PButton { text: qsTr("Launch"); variant: "primary"; iconName: "play"; onClicked: { profilerDlg.close(); host.answer({ disable: disableBox.checked }) } }
        ]
    }
}
