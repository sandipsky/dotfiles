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
    visible: open

    onOpenChanged: {
        if (open) {
            searchBar.clear();
            searchBar.focusInput();
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

    ClippingRectangle {
        id: menu
        width: 420
        height: 680
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 46
        anchors.left: parent.left
        anchors.leftMargin: 8

        color: Theme.startmenuBg
        radius: Theme.menuRadius
        border.color: Theme.startmenuBorder
        border.width: 1

        function closeDropdowns() {
            userDropdown.visible = false;
            powerDropdown.visible = false;
            bottomBar.userActive = false;
            bottomBar.powerActive = false;
        }
        readonly property bool anyDropdownOpen: userDropdown.visible || powerDropdown.visible

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
            anchors.bottomMargin: 0
            spacing: 24

            SearchBar {
                id: searchBar
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                onAccepted: {
                    if (appList.entries.length > 0) {
                        appList.launchSelected();
                        root.close();
                    }
                }
                onEscapePressed: root.close()
                onUpPressed: appList.moveSelection(-1)
                onDownPressed: appList.moveSelection(1)
            }

            AppList {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                filter: searchBar.text
                onAppLaunched: root.close()
            }

            BottomBar {
                id: bottomBar
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                Layout.leftMargin: -16
                Layout.rightMargin: -16

                onToggleUserMenu: {
                    var openTo = !userDropdown.visible;
                    menu.closeDropdowns();
                    userDropdown.visible = openTo;
                    bottomBar.userActive = openTo;
                }
                onTogglePowerMenu: {
                    var openTo = !powerDropdown.visible;
                    menu.closeDropdowns();
                    powerDropdown.visible = openTo;
                    bottomBar.powerActive = openTo;
                }
            }
        }

        // Click-elsewhere-in-the-menu closes any open dropdown.
        MouseArea {
            anchors.fill: parent
            z: 500
            visible: menu.anyDropdownOpen
            onPressed: (m) => { menu.closeDropdowns(); m.accepted = true; }
        }

        Dropdown {
            id: userDropdown
            z: 1000
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            width: 220

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
                }
            ]
        }

        Dropdown {
            id: powerDropdown
            z: 1000
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            width: 200

            actions: [
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
