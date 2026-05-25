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
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible
    property bool profileExpanded: false

    // Distance the panel must travel to be fully tucked behind the bar.
    readonly property real _hiddenOffset: panel.height + panel.anchors.bottomMargin

    function close() { open = false; }
    function refresh() {
        profileQuery.running = true;
        brightnessQuery.running = true;
        batteryQuery.running = true;
    }
    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            refresh();
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            profileExpanded = false;
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    // ----- backing state -----
    property string profile: ""
    readonly property var profileList: ["power-saver", "balanced", "performance"]
    function profileLabel(p) {
        if (p === "power-saver") return "Power Saver";
        if (p === "balanced")    return "Balanced";
        if (p === "performance") return "Performance";
        return p || "Balanced";
    }
    function setProfile(p) {
        if (p === profile) return;
        Quickshell.execDetached(["powerprofilesctl", "set", p]);
        profile = p;
        setRefreshRate(p === "power-saver" ? 60 : 144);
    }

    // Power-saver drops eDP-1 to 60 Hz to extend battery; any other profile
    // restores 144 Hz. Hyprland-only; harmless no-op elsewhere.
    function setRefreshRate(hz) {
        Quickshell.execDetached([
            "hyprctl", "keyword", "monitor",
            "eDP-1,1920x1080@" + hz + ",auto,1"
        ]);
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

    // Clipping container: its bottom edge sits at the top of the bar so
    // anything past that line is cut off, producing the "tuck behind the
    // bar" slide. The bar (a separate layer-shell surface) keeps painting
    // normally over the clipped pixels.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.bottomMargin: Theme.barHeight
        clip: true

        Item {
            id: slideContent
            anchors.fill: parent
            transform: Translate { id: slideTransform; y: 0 }
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

    Rectangle {
        id: panel
        parent: slideContent
        width: 320
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 6

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

            Item {
                id: profileTile
                Layout.fillWidth: true
                implicitHeight: 44

                Rectangle {
                    id: profileTileBg
                    anchors.fill: parent
                    radius: height / 2
                    color: root.profileExpanded ? Theme.barAccent : Theme.dropdownBg

                    HoverHandler { id: profileTileHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.profileExpanded = !root.profileExpanded
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: profileTileHover.hovered ? "#ffffff" : "transparent"
                        opacity: 0.06
                    }

                    Image {
                        id: profileIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        sourceSize.width: 36
                        sourceSize.height: 36
                        source: Qt.resolvedUrl("../../icons/profile.svg")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.left: profileIcon.right
                        anchors.leftMargin: 12
                        anchors.right: profileChevron.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.profileLabel(root.profile)
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.styleName: Theme.fontStyle
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        id: profileChevron
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""   // Segoe Fluent Icons: ChevronDown
                        color: Theme.textPrimary
                        font.family: "Segoe Fluent Icons"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        rotation: root.profileExpanded ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // Power-profile dropdown — slides open below the tile.
            Item {
                id: profileDropdown
                Layout.fillWidth: true
                Layout.preferredHeight: root.profileExpanded ? profileOptions.implicitHeight + 4 : 0
                clip: true
                visible: Layout.preferredHeight > 0

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Column {
                    id: profileOptions
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    spacing: 0

                    Repeater {
                        model: root.profileList

                        delegate: Rectangle {
                            width: profileOptions.width
                            height: 34
                            radius: 6
                            color: optHover.hovered
                                ? Theme.hoverBg
                                : (modelData === root.profile ? Theme.dropdownBg : "transparent")

                            HoverHandler { id: optHover }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    root.setProfile(modelData);
                                    root.profileExpanded = false;
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.right: optCheck.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.profileLabel(modelData)
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.styleName: Theme.fontStyle
                                font.pixelSize: 14
                                font.weight: modelData === root.profile ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                id: optCheck
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""   // Segoe Fluent Icons: CheckMark
                                color: Theme.barAccent
                                font.family: "Segoe Fluent Icons"
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                                visible: modelData === root.profile
                            }
                        }
                    }
                }
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
