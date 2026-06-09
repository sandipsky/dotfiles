import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../styles"
import "components"

PanelWindow {
    id: root

    // Full-screen layer-shell window. The actual menu lives inside as a
    // child Rectangle; the surrounding transparent area swallows
    // outside-clicks so they close the menu (Hyprland-friendly).
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool open: true
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Distance the menu must travel to be fully tucked behind the bar.
    // Menu's bottom sits `slideClip.bottomMargin` above the bar's top, so
    // moving it down by (menu.height + that gap) puts its top at the bar's
    // top edge — where the slideClip will clip the rest away.
    readonly property real _hiddenOffset: menu.height + menu.anchors.bottomMargin

    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            bottomBar.clearSearch();
            bottomBar.focusSearch();
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    function close() {
        menu.closeDropdowns();
        open = false;
    }

    // Esc closes from anywhere in the window
    Keys.onEscapePressed: root.close()

    // ---------------- Outside-click dismiss ----------------
    MouseArea {
        id: outsideArea
        anchors.fill: parent
        onPressed: root.close()
    }

    // Clipping container: its bottom edge sits at the top of the bar so
    // anything past that line is cut off. Sliding the menu down through
    // this edge produces the "tuck behind the bar" effect, while the bar
    // (a separate layer-shell surface) continues to paint normally.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.bottomMargin: Theme.barHeight
        clip: true

    ClippingRectangle {
        id: menu
        width: 420
        height: 680
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 8

        color: Theme.startmenuBg
        radius: Theme.menuRadius
        border.color: Theme.startmenuBorder
        border.width: 1

        transform: Translate {
            id: slideTransform
            y: 0
        }

        NumberAnimation {
            id: slideInAnim
            target: slideTransform
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: slideTransform
            property: "y"
            to: root._hiddenOffset
            duration: 220
            easing.type: Easing.InCubic
            onFinished: root._renderVisible = false
        }

        Component.onCompleted: {
            if (root.open) {
                slideTransform.y = root._hiddenOffset;
                slideInAnim.restart();
            }
        }

        function closeDropdowns() {
            powerDropdown.open = false;
            bottomBar.powerActive = false;
        }
        readonly property bool anyDropdownOpen: powerDropdown.open

        // Swallows any click inside the menu that wasn't handled by a
        // child handler so the outer outsideArea never sees it.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 12
            spacing: 24

            AppList {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                filter: bottomBar.searchText
                // While the power dropdown is open, ignore clicks so a tap on
                // a dropdown item doesn't also launch the app beneath it.
                enabled: !powerDropdown.open
                onAppLaunched: root.close()
            }

            BottomBar {
                id: bottomBar
                Layout.fillWidth: true

                onSearchAccepted: {
                    if (appList.entries.length > 0) {
                        appList.launchSelected();
                        root.close();
                    }
                }
                onSearchEscape: root.close()
                onSearchUp: appList.moveSelection(-1)
                onSearchDown: appList.moveSelection(1)

                onTogglePowerMenu: {
                    var openTo = !powerDropdown.open;
                    powerDropdown.open = openTo;
                    bottomBar.powerActive = openTo;
                }
            }
        }

        // Any click outside the open dropdown (app list, search, the power
        // button) closes it. We grab the press but only close on release
        // (onClicked): keeping the grab for the whole gesture stops the
        // release from falling through to the power button — which would
        // otherwise re-toggle the dropdown back open.
        MouseArea {
            anchors.fill: parent
            z: 500
            visible: menu.anyDropdownOpen
            onPressed: (m) => { m.accepted = true; }
            onClicked: menu.closeDropdowns()
        }

        Dropdown {
            id: powerDropdown
            z: 1000
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64
            width: 200

            actions: [
                {
                    label: "Lock",
                    icon: Qt.resolvedUrl("../../icons/lock.svg"),
                    onTrigger: () => Quickshell.execDetached(["loginctl", "lock-session"])
                },
                {
                    label: "Sign out",
                    icon: Qt.resolvedUrl("../../icons/logout.svg"),
                    onTrigger: () => Quickshell.execDetached(["loginctl", "terminate-user", Quickshell.env("USER") || ""])
                },
                { separator: true },
                {
                    label: "Sleep",
                    icon: Qt.resolvedUrl("../../icons/sleep.svg"),
                    onTrigger: () => Quickshell.execDetached(["systemctl", "suspend"])
                },
                {
                    label: "Shut down",
                    icon: Qt.resolvedUrl("../../icons/power.svg"),
                    onTrigger: () => Quickshell.execDetached(["systemctl", "poweroff"])
                },
                {
                    label: "Restart",
                    icon: Qt.resolvedUrl("../../icons/restart.svg"),
                    onTrigger: () => Quickshell.execDetached(["systemctl", "reboot"])
                }
            ]
        }
    }
    }
}
