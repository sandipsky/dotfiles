import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../styles"
import "components"

PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool open: false
    visible: open

    function close() { open = false; }
    function refresh() {
        profileQuery.running = true;
        brightnessQuery.running = true;
        batteryQuery.running = true;
    }
    onOpenChanged: if (open) refresh()

    // ----- backing state -----
    property string profile: ""
    readonly property var profileList: ["power-saver", "balanced", "performance"]
    function profileLabel(p) {
        if (p === "power-saver") return "Power Saver";
        if (p === "balanced")    return "Balanced";
        if (p === "performance") return "Performance";
        return p || "Balanced";
    }
    function cycleProfile() {
        var idx = profileList.indexOf(profile);
        if (idx < 0) idx = 1;
        var next = profileList[(idx + 1) % profileList.length];
        Quickshell.execDetached(["powerprofilesctl", "set", next]);
        profile = next;
    }

    property int brightness: 50

    property int batteryPct: 0
    property bool batteryPresent: false
    property bool batteryCharging: false
    property string timeRemaining: ""

    // Segoe Fluent Icons glyphs (deciles), kept in sync with the bar's
    // BatteryIndicator so the footer flips to BatterySaver while
    // power-saver is active and the laptop isn't plugged in.
    readonly property var __batGlyphs:    ["\uE851","\uE852","\uE853","\uE854","\uE855","\uE856","\uE857","\uE858","\uE859","\uE83F"]
    readonly property var __chargeGlyphs: ["\uE85B","\uE85C","\uE85D","\uE85E","\uE85F","\uE860","\uE861","\uE862","\uEA93","\uE83E"]
    readonly property var __saverGlyphs:  ["\uE864","\uE865","\uE866","\uE867","\uE868","\uE869","\uE86A","\uE86B","\uEA94","\uEA95"]
    function batteryGlyph() {
        var idx = Math.max(0, Math.min(9, Math.ceil(batteryPct / 10) - 1));
        if (batteryCharging)            return __chargeGlyphs[idx];
        if (profile === "power-saver")  return __saverGlyphs[idx];
        return __batGlyphs[idx];
    }

    // ----- outside-click dismiss -----
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Rectangle {
        id: panel
        width: 320
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 46

        height: column.implicitHeight + 28

        color: Theme.calendarBg
        radius: Theme.calendarRadius
        border.color: Theme.calendarBorder
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            spacing: 10

            Tile {
                Layout.fillWidth: true
                iconSource: Qt.resolvedUrl("../../icons/profile.svg")
                label: root.profileLabel(root.profile)
                active: false
                onClicked: root.cycleProfile()
            }

            SettingSlider {
                Layout.fillWidth: true
                Layout.topMargin: 2
                iconSource: Qt.resolvedUrl("../../icons/brightness.svg")
                minValue: 1
                maxValue: 100
                value: root.brightness
                onValueDragged: (v) => {
                    root.brightness = Math.round(v);
                    Quickshell.execDetached([
                        "brightnessctl", "-q",
                        "set", Math.round(v) + "%"
                    ]);
                }
            }

            // Hairline divider above the footer
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                height: 1
                color: Theme.calendarBorder
                visible: root.batteryPresent
            }

            // Battery footer — icon + "<pct>%: <time remaining>"
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "transparent"
                visible: root.batteryPresent

                Text {
                    id: footerBat
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryGlyph()
                    color: Theme.textPrimary
                    font.family: "Segoe Fluent Icons"
                    font.pixelSize: 28
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.left: footerBat.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batteryPct + "%"
                          + (root.timeRemaining.length > 0
                              ? ": " + root.timeRemaining
                              : "")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ----- polling -----
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

    Process {
        id: brightnessQuery
        command: ["sh", "-c",
            "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1);"
            + "m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1);"
            + "[ -n \"$b\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ] && echo $((b * 100 / m))"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(text.trim());
                if (!isNaN(n)) root.brightness = n;
            }
        }
    }

    // Pulls capacity + charging state + a pre-formatted time-remaining string in one shell hop.
    Process {
        id: batteryQuery
        command: ["sh", "-c",
            "cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1);"
            + "[ -z \"$cap\" ] && exit 0;"
            + "echo \"pct=$cap\";"
            + "st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1);"
            + "[ -n \"$st\" ] && echo \"status=$st\";"
            + "t=$(upower -i $(upower -e 2>/dev/null | grep -m1 BAT) 2>/dev/null"
            + "    | awk '/time to empty|time to full/ {sub(/^ +/, \"\"); print; exit}');"
            + "[ -n \"$t\" ] && echo \"time=$t\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var pct = -1, time = "", status = "";
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (line.indexOf("pct=") === 0) {
                        var n = parseInt(line.substring(4));
                        if (!isNaN(n)) pct = n;
                    } else if (line.indexOf("status=") === 0) {
                        status = line.substring(7);
                    } else if (line.indexOf("time=") === 0) {
                        time = line.substring(5);
                    }
                }
                // Match the bar indicator: anything but Discharging/Unknown counts as charging.
                root.batteryCharging = (status === "Charging"
                                     || status === "Full"
                                     || status === "Not charging");
                if (pct >= 0) {
                    root.batteryPct = pct;
                    root.batteryPresent = true;
                } else {
                    root.batteryPresent = false;
                }
                // Format the time-remaining string for the footer.
                if (time.length > 0) {
                    var m = time.match(/time to (empty|full):\s*([0-9.]+)\s*(\w+)/);
                    if (m) {
                        var direction = m[1];
                        var value = parseFloat(m[2]);
                        var unit = m[3];
                        var totalMin = 0;
                        if (unit.indexOf("hour") === 0)      totalMin = value * 60;
                        else if (unit.indexOf("min") === 0)  totalMin = value;
                        else if (unit.indexOf("sec") === 0)  totalMin = value / 60;
                        totalMin = Math.round(totalMin);
                        var h = Math.floor(totalMin / 60);
                        var mn = totalMin % 60;
                        var pretty = (h > 0 ? h + "hr " : "") + (mn > 0 || h === 0 ? mn + "min" : "");
                        pretty = pretty.trim();
                        root.timeRemaining = pretty + (direction === "full" ? " to full" : " remaining");
                    } else {
                        root.timeRemaining = "";
                    }
                } else {
                    root.timeRemaining = "";
                }
            }
        }
    }
}
