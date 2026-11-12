import QtQuick
import PrismModern

// Surface container. Set `interactive: true` for hover feedback; handle clicks with a TapHandler/MouseArea inside.
Rectangle {
    id: card
    property bool interactive: false
    property bool hovered: hover.hovered
    property bool selected: false
    property int padding: Theme.spacingLg
    default property alias content: inner.data

    radius: Theme.radiusLg
    color: interactive && hovered ? Theme.surfaceHover : Theme.surface
    border.width: 1
    border.color: selected ? Theme.accent : (interactive && hovered ? Theme.borderStrong : Theme.border)
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2

    HoverHandler { id: hover; enabled: card.interactive; cursorShape: card.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
    Item { id: inner; anchors.fill: parent; anchors.margins: card.padding }
}
