import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Scrollable settings sub-page. Children are stacked in a centered column.
Flickable {
    id: page
    readonly property bool isSettingsPage: true
    property var store: null
    property string pageKey: ""
    property string title: ""
    property string subtitle: ""
    property alias headerActions: hdrActions.data
    default property alias content: col.data

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: col.implicitHeight + Theme.spacingXl + 110
    ScrollBar.vertical: PScrollBar {}

    ColumnLayout {
        id: col
        width: Math.min(page.width - 2 * Theme.spacingXxl, 860)
        x: Math.round((page.width - width) / 2)
        y: Theme.spacingXl
        spacing: Theme.spacingLg

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: Theme.spacing
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: page.title; color: Theme.text; font.pixelSize: Theme.fontXl; font.weight: Font.Bold; Layout.fillWidth: true }
                Text { visible: page.subtitle.length > 0; text: page.subtitle; color: Theme.textMuted; font.pixelSize: Theme.fontMd; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
            Row { id: hdrActions; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }
        }
    }

    NumberAnimation { id: scrollAnim; target: page; property: "contentY"; duration: Theme.durSlow; easing.type: Theme.easing }

    // scroll so `item` is visible, then flash it
    function reveal(item) {
        if (!item) return
        var pt = item.mapToItem(page.contentItem, 0, 0)
        var target = Math.max(0, Math.min(pt.y - 90, page.contentHeight - page.height))
        scrollAnim.stop()
        scrollAnim.to = target
        scrollAnim.start()
        if (item.flash) item.flash()
    }
}
