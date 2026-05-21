import QtQuick
import Quickshell
import Quickshell.Wayland
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
    readonly property string displayName: {
        if (!appId) return "";
        // Subscribe to the applications model so the binding re-runs once
        // .desktop scanning finishes — otherwise the initial focused app
        // (set before entries load) shows the raw appId until focus
        // changes and triggers another evaluation.
        var _entryCount = DesktopEntries.applications.values.length;
        var entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.name) return entry.name;
        // Strip reverse-DNS prefix ("org.kde.Konsole" -> "Konsole") and
        // capitalize the first letter for a tidier display.
        var tail = appId.split(".").pop();
        return tail.charAt(0).toUpperCase() + tail.slice(1);
    }

    // Cap the width so very long titles don't crowd the bar. The Text
    // sizes itself from its content (avoiding a binding loop with the
    // parent's implicitWidth) and elides at the cap.
    readonly property int maxLabelWidth: 268

    visible: displayName.length > 0
    implicitWidth: visible ? label.width + 12 : 0
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

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 6
        width: Math.min(implicitWidth, root.maxLabelWidth)
        text: root.displayName
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 15
        elide: Text.ElideRight
    }
}
