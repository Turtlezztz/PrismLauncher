import QtQuick
import QtQuick.Layouts
import PrismModern

// One settings row: label + description on the left, control(s) on the right (or below when `stacked`).
// Registers itself in the settings search index of the enclosing SetPageBase.
Item {
    id: row
    property string label: ""
    property string description: ""
    property string keywords: ""
    property bool stacked: false
    property bool divider: true
    property bool modified: false          // shows a small dot when the row has unsaved changes
    default property alias control: slot.data

    width: parent ? parent.width : 400
    implicitHeight: stacked ? (texts.implicitHeight + slot.childrenRect.height + Theme.spacingSm + 26)
                            : Math.max(texts.implicitHeight, slot.childrenRect.height) + 26

    property Item _page: null
    Component.onCompleted: {
        var p = parent
        while (p && p.isSettingsPage !== true) p = p.parent
        if (p && p.store) {
            _page = p
            p.store.register({ page: p.pageKey, pageTitle: p.title, label: label, description: description, keywords: keywords, item: row })
        }
    }
    Component.onDestruction: if (_page && _page.store) _page.store.unregister(row)

    function flash() { flashAnim.restart() }

    Rectangle {
        id: hl
        anchors.fill: parent
        anchors.leftMargin: -10; anchors.rightMargin: -10
        radius: Theme.radius
        color: Theme.accentSoft
        opacity: 0
    }
    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: hl; property: "opacity"; to: 1; duration: Theme.dur }
        PauseAnimation { duration: 1100 }
        NumberAnimation { target: hl; property: "opacity"; to: 0; duration: Theme.durSlow }
    }

    Rectangle {
        visible: row.divider && row.Positioner.index > 0
        anchors.top: parent.top
        width: parent.width; height: 1
        color: Theme.border
    }

    ColumnLayout {
        id: texts
        spacing: 3
        anchors.left: parent.left
        anchors.right: row.stacked ? parent.right : slot.left
        anchors.rightMargin: row.stacked ? 0 : Theme.spacingXl
        anchors.top: row.stacked ? parent.top : undefined
        anchors.topMargin: 13
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        RowLayout {
            spacing: 6
            Layout.fillWidth: true
            visible: row.label.length > 0
            Text { text: row.label; color: row.enabled ? Theme.text : Theme.textDisabled; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Rectangle { visible: row.modified; width: 6; height: 6; radius: 3; color: Theme.accent; Layout.alignment: Qt.AlignVCenter }
        }
        Text {
            text: row.description; visible: text.length
            color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap
            textFormat: Text.StyledText; linkColor: Theme.accent
            onLinkActivated: link => App.openUrl(link)
            HoverHandler { cursorShape: parent.hoveredLink.length ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.left: row.stacked ? parent.left : undefined
        anchors.top: row.stacked ? texts.bottom : undefined
        anchors.topMargin: Theme.spacingSm + 2
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        width: row.stacked ? parent.width : childrenRect.width
        height: childrenRect.height
    }
}
