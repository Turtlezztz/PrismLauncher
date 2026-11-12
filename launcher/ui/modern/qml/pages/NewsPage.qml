import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Classic NewsChecker / NewsDialog: article list on the left, the selected article on the right.
PageScaffold {
    id: page
    title: qsTr("News")
    subtitle: qsTr("The latest from the %1 team").arg(App.appName)
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) {}
    Component.onCompleted: Router.section = "News"

    NewsFeed { id: feed }
    property int selected: 0
    readonly property var article: feed.entries.length > selected ? feed.entries[selected] : null

    headerActions: [
        IconButton { iconName: "refresh-cw"; tip: qsTr("Reload"); enabled: !feed.loading; onClicked: feed.reload() },
        PButton { visible: feed.moreUrl.length > 0; text: qsTr("More news"); iconName: "external-link"; onClicked: App.openUrl(feed.moreUrl) }
    ]

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: Theme.spacingXl
        spacing: Theme.spacingLg
        visible: feed.entries.length > 0

        // ---- article list
        ListView {
            id: list
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: feed.entries
            ScrollBar.vertical: PScrollBar {}
            delegate: AbstractButton {
                id: it
                required property var modelData
                required property int index
                readonly property bool sel: page.selected === index
                width: ListView.view.width - 4
                height: Math.max(64, col.implicitHeight + 24)
                hoverEnabled: true
                onClicked: page.selected = index
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                background: Rectangle {
                    radius: Theme.radius
                    color: it.sel ? Theme.accentSoft : it.hovered ? Theme.surfaceHover : Theme.surface
                    border.color: it.sel ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
                contentItem: ColumnLayout {
                    id: col
                    spacing: 4
                    Text {
                        Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                        text: it.modelData.title; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: it.sel ? Font.DemiBold : Font.Medium
                    }
                    Text {
                        visible: it.index === 0
                        Layout.leftMargin: 14
                        text: qsTr("Latest"); color: Theme.accent; font.pixelSize: Theme.fontXs; font.weight: Font.Bold
                    }
                }
            }
        }

        // ---- article
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            Flickable {
                id: fl
                anchors.fill: parent
                anchors.margins: Theme.spacingXl
                clip: true
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: PScrollBar {}
                ColumnLayout {
                    id: body
                    width: fl.width - 12
                    spacing: Theme.spacingLg
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: page.article ? page.article.title : ""
                            wrapMode: Text.Wrap
                            color: Theme.text; font.pixelSize: Theme.fontXl; font.weight: Font.Bold
                        }
                        PButton { visible: !!page.article && page.article.link.length > 0; text: qsTr("Open"); size: "sm"; iconName: "external-link"; onClicked: App.openUrl(page.article.link) }
                    }
                    Text {
                        id: content
                        Layout.fillWidth: true
                        text: page.article ? page.article.html : ""
                        textFormat: Text.RichText
                        wrapMode: Text.Wrap
                        color: Theme.text; linkColor: Theme.accent
                        font.pixelSize: Theme.fontMd + 1
                        lineHeight: 1.15
                        onLinkActivated: link => App.openUrl(link)
                        HoverHandler { cursorShape: content.hoveredLink.length ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }
                }
                onContentHeightChanged: contentY = 0
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: feed.entries.length === 0
        Spinner { anchors.centerIn: parent; size: 28; visible: feed.loading }
        EmptyState {
            anchors.centerIn: parent
            visible: !feed.loading
            iconName: "newspaper"
            title: !feed.enabled ? qsTr("News is disabled in this build") : feed.error.length ? qsTr("Couldn't load the news") : qsTr("No news available")
            text: feed.error
            PButton { visible: feed.enabled; text: qsTr("Try again"); iconName: "refresh-cw"; onClicked: feed.reload() }
        }
    }
}
