import QtQuick
import Quickshell
import Quickshell.Io
import "../../../styles"

Rectangle {
    id: root
    width: 32
    height: 32
    radius: 6
    color: hover.hovered ? Theme.hoverBg : "transparent"

    // Hide entirely when no battery is detected (desktops, VMs without a
    // virtual battery, etc.) so we don't render a permanently-empty icon.
    property bool present: false
    property int  percentage: 0
    property bool charging: false

    visible: present

    function iconFile() {
        if (charging) return "bat-charge.svg";
        if (percentage <= 10) return "bat0.svg";
        if (percentage <= 30) return "bat1.svg";
        if (percentage <= 55) return "bat2.svg";
        if (percentage <= 80) return "bat3.svg";
        return "bat4.svg";
    }

    HoverHandler { id: hover }

    Image {
        anchors.centerIn: parent
        width: 24
        height: 24
        sourceSize.width: 32
        sourceSize.height: 32
        source: Qt.resolvedUrl("../../../icons/" + root.iconFile())
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // sysfs is the cheapest, most portable source — works the same on
    // Plasma and Hyprland and doesn't depend on upower/dbus. The glob
    // covers BAT0 / BAT1 / etc; `head -1` keeps things sane if a system
    // exposes more than one battery.
    Timer {
        running: true
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            capQuery.running = true;
            statusQuery.running = true;
        }
    }

    Process {
        id: capQuery
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim();
                if (s.length > 0) {
                    var n = parseInt(s);
                    if (!isNaN(n)) {
                        root.percentage = n;
                        root.present = true;
                    }
                } else {
                    root.present = false;
                }
            }
        }
    }

    Process {
        id: statusQuery
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // sysfs uses "Charging" while the charger is actively
                // pumping energy in; "Full", "Not charging", "Discharging",
                // "Unknown" all fall back to the level icon.
                root.charging = (text.trim() === "Charging");
            }
        }
    }
}
