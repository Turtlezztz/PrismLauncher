import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Modal progress for a C++ TaskBridge (status, details, progress, sub-steps, warnings, abort/skip).
//   TaskProgressDialog { task: someBridge; title: qsTr("Installing"); onSucceeded: ... }
// Closes itself on success (unless there are warnings or keepOpen is set); on failure it shows the reason.
PDialog {
    id: dlg
    property TaskBridge task: null
    property bool keepOpen: false
    property string successText: ""
    signal succeeded()
    signal failed(string reason)
    signal aborted()

    readonly property bool running: task ? !task.finished : false
    readonly property bool failedState: task ? task.finished && !task.succeeded && !task.aborted : false
    readonly property bool warnState: task ? task.finished && task.succeeded && task.warnings.length > 0 : false

    title: task ? task.title : ""
    iconName: failedState ? "circle-alert" : (task && task.finished && task.succeeded) ? "circle-check" : "download"
    maxWidth: 500
    showClose: !running
    closePolicy: running ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    property bool _handled: false
    function _finish() {
        if (_handled || !task || !task.finished) return
        _handled = true
        if (task.succeeded) {
            succeeded()
            if (!keepOpen && task.warnings.length === 0) close()
        } else if (task.aborted) {
            aborted()
            close()
        } else {
            failed(task.failReason)
        }
    }
    onOpened: _finish()
    Connections {
        target: dlg.task
        function onTaskFinished() { dlg._finish() }
    }

    // ---- running ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        visible: !dlg.failedState && !dlg.warnState

        Text {
            Layout.fillWidth: true
            text: dlg.task && dlg.task.status.length ? dlg.task.status : qsTr("Working…")
            color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
        }
        PProgressBar {
            Layout.fillWidth: true
            indeterminate: !dlg.task || dlg.task.fraction < 0
            value: dlg.task && dlg.task.fraction >= 0 ? dlg.task.fraction : 0
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: dlg.task ? dlg.task.details : ""
            color: Theme.textMuted; font.pixelSize: Theme.fontSm
            elide: Text.ElideMiddle
        }
        // sub-steps (parallel downloads etc.)
        Repeater {
            model: dlg.task ? dlg.task.steps : []
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3
                Text {
                    Layout.fillWidth: true
                    text: modelData.status + (modelData.details.length ? " · " + modelData.details : "")
                    color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; elide: Text.ElideMiddle
                }
                PProgressBar {
                    Layout.fillWidth: true; implicitHeight: 3
                    indeterminate: modelData.fraction < 0
                    value: modelData.fraction >= 0 ? modelData.fraction : 0
                }
            }
        }
    }

    // ---- failed ----
    Rectangle {
        Layout.fillWidth: true
        visible: dlg.failedState
        radius: Theme.radius
        color: Theme.soft(Theme.danger)
        implicitHeight: failText.implicitHeight + 24
        Text {
            id: failText
            anchors.fill: parent; anchors.margins: 12
            text: dlg.task ? (dlg.task.failReason.length ? dlg.task.failReason : qsTr("The task failed.")) : ""
            color: Theme.text; wrapMode: Text.Wrap; font.pixelSize: Theme.fontMd
            textFormat: Text.StyledText
        }
    }

    // ---- warnings ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: dlg.warnState
        spacing: Theme.spacingSm
        Text { text: qsTr("Finished with warnings:"); color: Theme.text; font.weight: Font.Medium }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(warnList.contentHeight + 16, 200)
            radius: Theme.radius; color: Theme.soft(Theme.warning)
            ListView {
                id: warnList
                anchors.fill: parent; anchors.margins: 8
                clip: true
                model: dlg.task ? dlg.task.warnings : []
                delegate: Text { required property string modelData; width: warnList.width; text: "• " + modelData; color: Theme.text; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSm }
                ScrollBar.vertical: PScrollBar {}
            }
        }
    }

    buttons: [
        PButton {
            visible: dlg.running && dlg.task && dlg.task.canAbort
            text: dlg.task ? dlg.task.abortText : qsTr("Cancel")
            onClicked: dlg.task.abort()
        },
        PButton {
            visible: !dlg.running
            text: qsTr("Close"); variant: dlg.failedState ? "secondary" : "primary"
            onClicked: dlg.close()
        }
    ]
}
