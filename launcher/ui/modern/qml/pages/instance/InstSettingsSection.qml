import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// A card in the instance settings tab. With `gateKey` set it gets an "Override global settings" switch
// (classic checkable group box); its content is only editable while overriding.
Rectangle {
    id: section
    property InstSettingsBridge settings
    property string title: ""
    property string description: ""
    property string iconName: ""
    property string gateKey: ""
    property var keys: []
    /// for sections without a gate: a custom switch (e.g. "Use a specific account")
    property string switchKey: ""
    property string switchText: qsTr("Override global settings")
    default property alias content: body.data
    readonly property bool hasSwitch: gateKey.length > 0 || switchKey.length > 0
    readonly property bool on: !hasSwitch || (settings && (settings.revision, !!settings.get(gateKey.length ? gateKey : switchKey)))
    signal toggled(bool on)

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Theme.spacingLg * 2
    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Rectangle {
                visible: section.iconName.length > 0
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9
                color: section.on ? Theme.accentSoft : Theme.surfaceAlt
                Behavior on color { ColorAnimation { duration: Theme.dur } }
                Icon { anchors.centerIn: parent; name: section.iconName; size: 16; color: section.on ? Theme.accent : Theme.textMuted }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: section.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { visible: section.description.length > 0; text: section.description; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }
            Text {
                visible: section.hasSwitch
                text: section.switchText
                color: section.on ? Theme.text : Theme.textMuted
                font.pixelSize: Theme.fontSm
            }
            PSwitch {
                visible: section.hasSwitch
                checked: section.on
                onToggled: {
                    if (section.gateKey.length) section.settings.setOverride(section.gateKey, section.keys, checked)
                    else if (section.switchKey.length) section.settings.set(section.switchKey, checked)
                    section.toggled(checked)
                }
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 0
            enabled: section.on
            opacity: section.on ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
            visible: children.length > 0
        }
    }
}
