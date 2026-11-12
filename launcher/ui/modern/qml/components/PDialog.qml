import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Modal dialog with title, content and footer buttons.  Content goes in the default slot.
//   PDialog { title: "Rename"; PTextField {...}; footer buttons via `buttons: [...]` or standard ones }
Popup {
    id: dlg
    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property alias buttons: buttonRow.data
    property bool showClose: true
    default property alias content: body.data
    property int maxWidth: 520

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(maxWidth, (parent ? parent.width : 800) - 48)
    height: Math.min(implicitHeight, (parent ? parent.height : 600) - 48)
    padding: 0

    Overlay.modal: Rectangle {
        color: Theme.overlay
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durSlow; easing.type: Theme.easingEmph }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
            NumberAnimation { property: "scale"; from: 1; to: 0.97; duration: Theme.durFast }
        }
    }

    background: Rectangle {
        color: Theme.elevated
        radius: Theme.radiusXl
        border.color: Theme.borderStrong
    }

    contentItem: ColumnLayout {
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingXl
            Layout.bottomMargin: Theme.spacing
            spacing: Theme.spacing
            visible: dlg.title.length > 0
            Rectangle {
                visible: dlg.iconName.length > 0
                width: 36; height: 36; radius: 10; color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: dlg.iconName; color: Theme.accent; size: 18 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: dlg.title; color: Theme.text; font.pixelSize: Theme.fontLg + 2; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { visible: dlg.subtitle.length > 0; text: dlg.subtitle; color: Theme.textMuted; font.pixelSize: Theme.fontMd; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
            IconButton { visible: dlg.showClose; iconName: "x"; onClicked: dlg.close(); Layout.alignment: Qt.AlignTop }
        }
        // children of the dialog land here; use Layout.fillWidth: true on them
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.spacingXl
            Layout.rightMargin: Theme.spacingXl
            Layout.topMargin: dlg.title.length ? 0 : Theme.spacingXl
            spacing: Theme.spacing
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingXl
            Layout.topMargin: Theme.spacingLg
            visible: buttonRow.children.length > 0
            Item { Layout.fillWidth: true }
            Row { id: buttonRow; spacing: Theme.spacingSm; layoutDirection: Qt.LeftToRight }
        }
    }
}
