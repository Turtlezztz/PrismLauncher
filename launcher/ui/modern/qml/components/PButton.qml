import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Button.  variant: primary | secondary | ghost | danger | subtle.  size: "md" | "sm" | "lg"
Button {
    id: control
    property string variant: "secondary"
    property string size: "md"
    property string iconName: ""
    property string trailingIconName: ""
    property bool busy: false

    readonly property color _bg: {
        if (!enabled) return variant === "ghost" ? "transparent" : Theme.surfaceAlt
        switch (variant) {
        case "primary": return down ? Theme.accentPressed : hovered ? Theme.accentHover : Theme.accent
        case "danger": return down ? Qt.darker(Theme.danger, 1.15) : hovered ? Qt.lighter(Theme.danger, 1.08) : Theme.danger
        case "ghost": return down ? Theme.surfacePressed : hovered ? Theme.surfaceHover : "transparent"
        case "subtle": return down ? Theme.surfacePressed : hovered ? Theme.surfaceHover : Theme.accentSoft
        default: return down ? Theme.surfacePressed : hovered ? Theme.surfaceHover : Theme.surfaceAlt
        }
    }
    readonly property color _fg: !enabled ? Theme.textDisabled
                                 : (variant === "primary" || variant === "danger") ? Theme.textOnAccent
                                 : variant === "subtle" ? Theme.accent : Theme.text

    implicitHeight: size === "sm" ? Theme.controlHeightSm : size === "lg" ? 44 : Theme.controlHeight
    implicitWidth: Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: text.length ? (size === "sm" ? 10 : 14) : 0
    rightPadding: leftPadding
    font.pixelSize: size === "sm" ? Theme.fontSm : size === "lg" ? Theme.fontLg : Theme.fontMd
    font.weight: Font.DemiBold
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    HoverHandler { cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Spinner { visible: control.busy; size: 14; color: control._fg; anchors.verticalCenter: parent.verticalCenter }
            Icon {
                visible: !control.busy && control.iconName.length > 0
                name: control.iconName; color: control._fg
                size: control.size === "sm" ? 14 : 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: control.text.length > 0
                text: control.text
                font: control.font
                color: control._fg
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
            Icon {
                visible: control.trailingIconName.length > 0
                name: control.trailingIconName; color: control._fg; size: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: control._bg
        border.width: control.variant === "secondary" ? 1 : 0
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        // focus ring
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: control.visualFocus ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }
    scale: down ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
}
