import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Standard page frame: header (back button, title, subtitle, actions) + content.
//   PageScaffold { title: "Settings"; headerActions: [ PButton {...} ]; <content items, use Layout.fill*> }
Item {
    id: page
    property string title: ""
    property string subtitle: ""
    property bool showBack: StackView.view ? StackView.index > 0 : false
    property alias headerActions: actions.data
    property alias headerExtra: extra.data
    property alias headerLeading: leading.data
    property int contentMargins: Theme.spacingXxl
    default property alias content: body.data

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: page.contentMargins
            Layout.rightMargin: page.contentMargins
            Layout.topMargin: Theme.spacingXl
            Layout.fillHeight: false   // nested layouts default to fillHeight; the header must never grow
            spacing: Theme.spacingLg

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                IconButton { visible: page.showBack; iconName: "arrow-left"; tip: qsTr("Back"); onClicked: Router.back() }
                Row { id: leading; spacing: Theme.spacing; Layout.alignment: Qt.AlignVCenter; visible: children.length > 0 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: page.title; color: Theme.text; font.pixelSize: Theme.fontXl + 2; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { visible: page.subtitle.length > 0; text: page.subtitle; color: Theme.textMuted; font.pixelSize: Theme.fontMd; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Row { id: actions; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }
            }
            ColumnLayout { id: extra; Layout.fillWidth: true; Layout.fillHeight: false; spacing: Theme.spacing; visible: implicitHeight > 0 }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: page.contentMargins
            Layout.rightMargin: page.contentMargins
            Layout.topMargin: Theme.spacingLg
            spacing: Theme.spacingLg
        }
    }
}
