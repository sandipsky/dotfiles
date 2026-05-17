pragma Singleton

import QtQuick

QtObject {
    readonly property color startmenuUserBg: "#1c1c1c"
    readonly property color startmenuBg: "#242424"
    readonly property color startmenuSearchInputBg: "#202020"
    readonly property color startmenuSearchBorder: "#323232"
    readonly property color startmenuSearchPlaceholder: "#828282"
    readonly property color startmenuBorder: "#36383c"

    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#a0a0a0"
    readonly property color hoverBg: "#2e2e2e"
    readonly property color highlightBg: "#3a3a3a"
    readonly property color dropdownBg: "#2b2b2b"
    readonly property color dropdownBorder: "#3a3a3a"

    readonly property color launcherBg: "#202020"
    readonly property color launcherBorder: "#383838"

    readonly property color calendarBg: "#1e1e1e"
    readonly property color calendarHeaderBg: "#181818"
    readonly property color calendarBorder: "#36383c"
    readonly property color calendarTodayBg: "#0078d4"
    readonly property color calendarTodayText: "#ffffff"
    readonly property color calendarDimText: "#6a6a6a"

    readonly property color barBg: "#1c1c1c"
    readonly property color barBorder: "#404040"
    readonly property color barActiveBg: "#3a3a3a"
    readonly property color barAccent: "#0078d4"

    readonly property real menuRadius: 10
    readonly property real launcherRadius: 12
    readonly property real calendarRadius: 10
    readonly property int  barHeight: 40
}
