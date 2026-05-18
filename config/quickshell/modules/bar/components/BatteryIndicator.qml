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
    property string timeRemaining: ""   // e.g. "1hr 24min remaining" or ""
    property int  brightness: -1        // -1 = no backlight detected
    property string profile: ""         // powerprofilesctl: power-saver | balanced | performance

    property var tooltip
    signal clicked()

    visible: present

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    // Segoe Fluent Icons glyphs, indexed 0..9 \u2192 battery levels 1..10 (deciles).
    // Discharging: Battery1..Battery10  (E851..E859, E83F)
    // Charging:    BatteryCharging1..10 (E85B..E862, EA93, E83E)
    // Power-saver: BatterySaver1..10    (E864..E86B, EA94, EA95)
    readonly property var __batGlyphs:    ["\uE851","\uE852","\uE853","\uE854","\uE855","\uE856","\uE857","\uE858","\uE859","\uE83F"]
    readonly property var __chargeGlyphs: ["\uE85B","\uE85C","\uE85D","\uE85E","\uE85F","\uE860","\uE861","\uE862","\uEA93","\uE83E"]
    readonly property var __saverGlyphs:  ["\uE864","\uE865","\uE866","\uE867","\uE868","\uE869","\uE86A","\uE86B","\uEA94","\uEA95"]

    function iconChar() {
        var idx = Math.max(0, Math.min(9, Math.ceil(percentage / 10) - 1));
        if (charging)                       return __chargeGlyphs[idx];
        if (profile === "power-saver")      return __saverGlyphs[idx];
        return __batGlyphs[idx];
    }

    function tooltipText() {
        var line1 = percentage + "%";
        if (timeRemaining.length > 0) line1 += ": " + timeRemaining;
        var lines = [line1];
        if (brightness >= 0) lines.push("Brightness: " + brightness + "%");
        return lines.join("\n");
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!tooltip) return;
            if (hovered) {
                var p = mapToItem(null, width / 2, 0);
                tooltip.show(root.tooltipText(), p.x);
            } else {
                tooltip.hide();
            }
        }
    }

    // Refresh tooltip live while the cursor lingers and any of the
    // displayed values change (level rolls over, brightness slider moves,
    // etc.).
    function refreshTooltip() {
        if (hover.hovered && tooltip) tooltip.text = root.tooltipText();
    }
    onPercentageChanged:    refreshTooltip()
    onChargingChanged:      refreshTooltip()
    onTimeRemainingChanged: refreshTooltip()
    onBrightnessChanged:    refreshTooltip()

    Text {
        anchors.centerIn: parent
        text: root.iconChar()
        color: Theme.textPrimary
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 26
        renderType: Text.NativeRendering
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
            timeQuery.running = true;
            brightnessQuery.running = true;
            profileQuery.running = true;
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
                // Treat any "plugged in" state as charging visually:
                //  - "Charging"     : actively pumping energy in
                //  - "Full"         : topped off but charger still connected
                //  - "Not charging" : plugged in, paused by a charge-threshold rule
                // Only "Discharging" (and the rare "Unknown") fall back to the
                // level icon.
                var status = text.trim();
                root.charging = (status === "Charging"
                              || status === "Full"
                              || status === "Not charging");
            }
        }
    }

    // upower exposes the time-remaining estimate already pre-formatted
    // (e.g. "2.4 hours" or "45 minutes"). Convert into a compact
    // "Xhr Ymin remaining" / "to full" string for the tooltip.
    Process {
        id: timeQuery
        command: ["sh", "-c",
            "upower -i $(upower -e 2>/dev/null | grep -m1 BAT) 2>/dev/null"
            + " | awk '/time to empty|time to full/ {sub(/^ +/, \"\"); print; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) { root.timeRemaining = ""; return; }
                // Example matches: "time to empty: 2.4 hours", "time to full: 45.0 minutes"
                var m = t.match(/time to (empty|full):\s*([0-9.]+)\s*(\w+)/);
                if (!m) { root.timeRemaining = ""; return; }
                var direction = m[1];   // "empty" or "full"
                var value = parseFloat(m[2]);
                var unit = m[3];
                var totalMin;
                if (unit.indexOf("hour") === 0)  totalMin = value * 60;
                else if (unit.indexOf("min") === 0) totalMin = value;
                else if (unit.indexOf("sec") === 0) totalMin = value / 60;
                else { root.timeRemaining = ""; return; }
                totalMin = Math.round(totalMin);
                var h = Math.floor(totalMin / 60);
                var mn = totalMin % 60;
                var pretty = (h > 0 ? h + "hr " : "") + (mn > 0 || h === 0 ? mn + "min" : "").trim();
                pretty = pretty.trim();
                root.timeRemaining = pretty + (direction === "full" ? " to full" : " remaining");
            }
        }
    }

    // Active power profile — used to swap the bar glyph to the BatterySaver
    // family when the user has toggled power-saver and isn't currently plugged in.
    Process {
        id: profileQuery
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p.length > 0) root.profile = p;
            }
        }
    }

    // Brightness pulled from sysfs — covers intel_backlight, amdgpu_bl0,
    // and friends via the glob. Output is rounded to a percentage.
    Process {
        id: brightnessQuery
        command: ["sh", "-c",
            "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1);"
            + "m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1);"
            + "[ -n \"$b\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ] && echo $((b * 100 / m))"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim();
                if (s.length === 0) { root.brightness = -1; return; }
                var n = parseInt(s);
                root.brightness = isNaN(n) ? -1 : n;
            }
        }
    }
}