import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../styles"

Row {
    id: root

    property int count: 6
    property int current: 1
    spacing: 4

    // Compositor detection. The Hyprland import above is harmless when not
    // running under Hyprland — the IPC simply stays disconnected.
    readonly property bool onHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

    // ---------------- Hyprland binding ----------------
    Connections {
        target: Hyprland
        enabled: root.onHyprland
        function onFocusedWorkspaceChanged() {
            if (Hyprland.focusedWorkspace)
                root.current = Hyprland.focusedWorkspace.id
        }
    }

    // ---------------- KWin polling ----------------
    // KWin has no Quickshell-native module, so we poll its DBus interface.
    // qdbus is shipped with Plasma; on Plasma 6 systems where only `qdbus6`
    // exists, symlink or alias it as `qdbus` (or edit `kdeQdbus` below).
    property string kdeQdbus: "qdbus"

    Timer {
        running: !root.onHyprland
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: kdeQuery.running = true
    }
    Process {
        id: kdeQuery
        command: [root.kdeQdbus, "org.kde.KWin", "/KWin", "currentDesktop"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(text.trim());
                if (!isNaN(n) && n > 0) root.current = n;
            }
        }
    }

    Component.onCompleted: {
        if (onHyprland && Hyprland.focusedWorkspace)
            root.current = Hyprland.focusedWorkspace.id;
    }

    // ---------------- Actions ----------------
    function switchTo(n) {
        if (onHyprland) {
            Hyprland.dispatch("workspace " + n);
        } else {
            Quickshell.execDetached(
                [kdeQdbus, "org.kde.KWin", "/KWin", "org.kde.KWin.setCurrentDesktop", String(n)]
            );
        }
    }
    function nextWs() {
        if (onHyprland) Hyprland.dispatch("workspace e+1");
        else Quickshell.execDetached([kdeQdbus, "org.kde.KWin", "/KWin", "nextDesktop"]);
    }
    function prevWs() {
        if (onHyprland) Hyprland.dispatch("workspace e-1");
        else Quickshell.execDetached([kdeQdbus, "org.kde.KWin", "/KWin", "previousDesktop"]);
    }

    // Scroll handler covers the whole row. Wheel down → next, up → prev.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y < 0) root.nextWs();
            else if (event.angleDelta.y > 0) root.prevWs();
        }
    }

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: cell
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: root.current === wsId

            width: 28
            height: 28
            radius: 6
            color: isActive
                ? Theme.barActiveBg
                : (hover.hovered ? Theme.hoverBg : "transparent")

            HoverHandler { id: hover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.switchTo(cell.wsId)
            }

            Text {
                anchors.centerIn: parent
                text: cell.wsId
                color: cell.isActive ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: 12
                font.weight: cell.isActive ? Font.DemiBold : Font.Normal
            }
        }
    }
}
