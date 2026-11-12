pragma Singleton
import QtQuick
import PrismModern

// Design tokens for the modern UI. Everything visual should come from here.
QtObject {
    id: theme

    // ---- mode ----
    readonly property string mode: App.theme   // system | dark | light
    readonly property bool dark: mode === "dark" || (mode === "system" && Qt.styleHints.colorScheme !== Qt.ColorScheme.Light)

    // ---- palette ----
    readonly property color accent: App.accent && App.accent.length ? App.accent : "#7c5cff"
    readonly property color accentHover: Qt.lighter(accent, dark ? 1.12 : 1.06)
    readonly property color accentPressed: Qt.darker(accent, 1.12)
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.16 : 0.12)
    readonly property color textOnAccent: "#ffffff"

    readonly property color bg:            dark ? "#0e0f13" : "#f5f5f8"
    readonly property color sidebar:       dark ? "#121318" : "#ececf1"
    readonly property color surface:       dark ? "#17181e" : "#ffffff"
    readonly property color surfaceAlt:    dark ? "#1c1d25" : "#f8f8fb"
    readonly property color surfaceHover:  dark ? "#22232c" : "#f0f0f5"
    readonly property color surfacePressed: dark ? "#2a2b35" : "#e6e6ee"
    readonly property color elevated:      dark ? "#1f2028" : "#ffffff"
    readonly property color input:         dark ? "#121318" : "#ffffff"
    readonly property color border:        dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color borderStrong:  dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.15)
    readonly property color overlay:       dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0.08, 0.08, 0.12, 0.32)

    readonly property color text:          dark ? "#ececf1" : "#16171d"
    readonly property color textMuted:     dark ? "#a0a1b0" : "#5c5d6c"
    readonly property color textSubtle:    dark ? "#6c6d7c" : "#9091a0"
    readonly property color textDisabled:  dark ? "#4c4d58" : "#b8b9c4"

    readonly property color success: "#34c77b"
    readonly property color warning: "#f5a524"
    readonly property color danger:  "#ef4f5f"
    readonly property color info:    "#3b9eff"
    function soft(c) { return Qt.rgba(c.r, c.g, c.b, dark ? 0.16 : 0.12) }

    // ---- shape & spacing ----
    readonly property int radiusSm: 6
    readonly property int radius: 10
    readonly property int radiusLg: 14
    readonly property int radiusXl: 20
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacing: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int spacingXxl: 32
    readonly property int controlHeight: 36
    readonly property int controlHeightSm: 28

    // ---- type ----
    readonly property string fontFamily: Qt.application.font.family
    readonly property string monoFamily: Qt.platform.os === "osx" ? "Menlo" : (Qt.platform.os === "windows" ? "Consolas" : "monospace")
    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 13
    readonly property int fontLg: 15
    readonly property int fontXl: 20
    readonly property int fontXxl: 28

    // ---- motion ---- (all animations must use these so "reduce motion" works)
    readonly property bool reduceMotion: App.reduceMotion
    readonly property int durFast: reduceMotion ? 0 : 120
    readonly property int dur: reduceMotion ? 0 : 200
    readonly property int durSlow: reduceMotion ? 0 : 320
    readonly property int easing: Easing.OutCubic
    readonly property int easingEmph: Easing.OutQuint

    readonly property var accentPresets: ["#7c5cff", "#3b82f6", "#06b6d4", "#10b981", "#84cc16", "#f59e0b", "#f97316", "#ef4444", "#ec4899", "#a855f7"]
}
