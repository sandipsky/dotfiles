import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../styles"

// Active window indicator. Reads from the wlr-foreign-toplevel-management
// protocol so the same component works on Hyprland and KWin/Wayland; the
// compositor pushes activation changes, no polling required.
//
// Left-click toggles maximize on the focused window; right-click closes it.
Rectangle {
    id: root

    readonly property var active: ToplevelManager.activeToplevel
    readonly property string appId: active ? (active.appId || "") : ""
    readonly property string title: active ? (active.title || "") : ""

    // Prefer the desktop-entry display name (e.g. "Visual Studio Code"
    // instead of "code"); fall back to a tidied appId.
    readonly property var entry: {
        if (!appId) return null;
        // Subscribe to the applications model so the binding re-runs once
        // .desktop scanning finishes — otherwise the initial focused app
        // (set before entries load) shows the raw appId until focus
        // changes and triggers another evaluation.
        var _entryCount = DesktopEntries.applications.values.length;
        return DesktopEntries.heuristicLookup(appId);
    }
    readonly property string displayName: {
        if (!appId) return "";
        if (entry && entry.name) return entry.name;
        // Strip reverse-DNS prefix ("org.kde.Konsole" -> "Konsole") and
        // capitalize the first letter for a tidier display.
        var tail = appId.split(".").pop();
        return tail.charAt(0).toUpperCase() + tail.slice(1);
    }
    readonly property string iconName: (entry && entry.icon) ? entry.icon : appId

    // Cap the width so very long titles don't crowd the bar. The Text
    // sizes itself from its content (avoiding a binding loop with the
    // parent's implicitWidth) and elides at the cap.
    readonly property int maxLabelWidth: 268

    // Hyprland-only: both the focused window's maximize/fullscreen state and
    // the count of OTHER windows in its workspace are pulled from hyprctl,
    // because the wlr-foreign-toplevel `maximized` flag is not set when
    // Hyprland enters its (default) fullscreen mode. Used to show a small
    // dot indicating that a maximized app is covering other windows.
    property int otherWindowsInWorkspace: 0
    property bool activeFullscreen: false
    readonly property bool showOverlayDot:
        activeFullscreen && otherWindowsInWorkspace > 0

    visible: displayName.length > 0
    implicitWidth: visible ? label.x + label.width + (root.showOverlayDot ? 14 : 6) : 0
    implicitHeight: 28
    radius: 6
    color: hover.hovered ? Theme.hoverBg : "transparent"

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (root.active) root.active.maximized = !root.active.maximized;
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (root.active) root.active.close();
        }
    }

    Image {
        id: icon
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.leftMargin: 5
        width: source.toString().length > 0 ? 18 : 0
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        source: Quickshell.iconPath(root.iconName, "application-x-executable")
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: width > 0
    }

    Text {
        id: label
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: icon.right
        anchors.leftMargin: icon.visible ? 6 : 1
        width: Math.min(implicitWidth, root.maxLabelWidth)
        text: root.displayName
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 16
        elide: Text.ElideRight
    }

    Rectangle {
        id: stackDot
        anchors.left: label.right
        anchors.leftMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 9
        width: 6
        height: 6
        radius: 3
        color: Theme.barAccent
        visible: root.showOverlayDot
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { workspaceQuery.running = true; }
    }

    Connections {
        target: root.active
        ignoreUnknownSignals: true
        function onMaximizedChanged()  { workspaceQuery.running = true; }
        function onFullscreenChanged() { workspaceQuery.running = true; }
        function onTitleChanged()      { workspaceQuery.running = true; }
    }

    Timer {
        running: root.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: workspaceQuery.running = true
    }

    // Hyprland-only. Pulls the focused window's fullscreen state and the
    // total window count in its workspace in one shot, then prints them as
    // "<fullscreen> <window_count>". Non-Hyprland sessions produce "0 0"
    // so the dot stays hidden.
    Process {
        id: workspaceQuery
        command: ["sh", "-c",
            "fs=$(hyprctl activewindow 2>/dev/null"
            + " | awk '/^[[:space:]]*fullscreen:/{print $2; exit}');"
            + "wc=$(hyprctl activeworkspace 2>/dev/null"
            + " | awk '/^[[:space:]]*windows:/{print $2; exit}');"
            + "echo \"${fs:-0} ${wc:-0}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/);
                var fs = parseInt(parts[0]); if (isNaN(fs)) fs = 0;
                var wc = parseInt(parts[1]); if (isNaN(wc)) wc = 0;
                root.activeFullscreen = fs > 0;
                root.otherWindowsInWorkspace = Math.max(0, wc - 1);
            }
        }
    }

    Component.onCompleted: workspaceQuery.running = true
}
