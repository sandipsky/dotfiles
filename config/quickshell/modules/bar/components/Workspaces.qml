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
        // Clamp to [1..count] so the scroll wheel doesn't wrap at the end.
        if (root.current >= root.count) return;
        root.switchTo(root.current + 1);
    }
    function prevWs() {
        if (root.current <= 1) return;
        root.switchTo(root.current - 1);
    }

    // Scroll handler covers the whole row. Wheel down → next, up → prev.
    // Tracks an optimistic `pending` workspace so rapid touchpad events
    // don't blow past the clamp before `current` catches up.
    WheelHandler {
        id: wheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property int pending: -1

        onWheel: (event) => {
            event.accepted = true;
            if (event.angleDelta.y === 0) return;
            var base = wheel.pending > 0 ? wheel.pending : root.current;
            var target = base + (event.angleDelta.y < 0 ? 1 : -1);
            if (target < 1 || target > root.count) return;
            wheel.pending = target;
            root.switchTo(target);
        }
    }
    onCurrentChanged: if (wheel.pending === root.current) wheel.pending = -1

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
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 16
                font.weight: cell.isActive ? Font.Bold : Font.Normal
            }
        }
    }
}
