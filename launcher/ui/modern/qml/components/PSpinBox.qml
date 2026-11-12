import QtQuick
import QtQuick.Controls.Basic
import PrismModern

SpinBox {
    id: control
    editable: true
    implicitHeight: Theme.controlHeight
    implicitWidth: 140
    font.pixelSize: Theme.fontMd
    property string suffix: ""
    textFromValue: function(value, locale) { return Number(value).toLocaleString(locale, 'f', 0).replace(/[,.\s]/g, "") + (suffix.length ? " " + suffix : "") }
    valueFromText: function(text, locale) { return parseInt(text.replace(/[^0-9-]/g, "")) || 0 }
    contentItem: TextInput {
        text: control.displayText
        font: control.font
        color: Theme.text
        selectionColor: Theme.accentSoft
        horizontalAlignment: Qt.AlignLeft
        verticalAlignment: Qt.AlignVCenter
        leftPadding: 12
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        selectByMouse: true
    }
    up.indicator: Rectangle {
        x: control.width - width - 1; y: 1
        width: 26; height: control.height / 2 - 1
        color: control.up.pressed ? Theme.surfacePressed : control.up.hovered ? Theme.surfaceHover : "transparent"
        radius: Theme.radiusSm
        Icon { anchors.centerIn: parent; name: "chevron-down"; rotation: 180; size: 12; color: Theme.textMuted }
    }
    down.indicator: Rectangle {
        x: control.width - width - 1; y: control.height / 2
        width: 26; height: control.height / 2 - 1
        color: control.down.pressed ? Theme.surfacePressed : control.down.hovered ? Theme.surfaceHover : "transparent"
        radius: Theme.radiusSm
        Icon { anchors.centerIn: parent; name: "chevron-down"; size: 12; color: Theme.textMuted }
    }
    background: Rectangle {
        radius: Theme.radius
        color: Theme.input
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
    }
}
