import QtQuick
import PrismModern

// Small colored mark for a source / modpack platform (no brand artwork is bundled, so a tinted monogram/icon is used).
Rectangle {
    id: root
    property string platform: ""
    property int size: 28
    readonly property var info: ({
        vanilla: { c: Theme.accent, icon: "box" },
        import: { c: "#64748b", icon: "file-archive" },
        modrinth: { c: "#1bd96a", t: "M" },
        curseforge: { c: "#f16436", t: "C" },
        ftb: { c: "#e5383b", t: "F" },
        legacyftb: { c: "#b5838d", t: "F" },
        ftbapp: { c: "#9d4edd", icon: "folder-open" },
        atlauncher: { c: "#3b82f6", t: "A" },
        technic: { c: "#f59e0b", t: "T" }
    })[platform] || { c: Theme.textMuted, icon: "package" }
    readonly property color tint: info.c
    width: size; height: size
    radius: size * 0.3
    color: Theme.soft(tint)
    Text {
        anchors.centerIn: parent
        visible: !!root.info.t
        text: root.info.t || ""
        color: root.tint
        font.pixelSize: root.size * 0.5; font.weight: Font.Black
    }
    Icon { anchors.centerIn: parent; visible: !root.info.t; name: root.info.icon || ""; size: root.size * 0.55; color: root.tint }
}
