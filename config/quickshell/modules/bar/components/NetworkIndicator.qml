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

    // "ethernet" | "wifi" | "none"
    property string conn: "none"
    // 0..100, only meaningful when conn === "wifi"
    property int wifiSignal: 0

    // Extra info for the hover tooltip — populated by detailsQuery.
    property string device: ""    // e.g. "wlan0" or "eth0"
    property string ssid: ""      // only when conn === "wifi"
    property string ip: ""        // first IPv4 of the active device
    property string speed: ""     // pre-formatted "130 Mbit/s" / "1000 Mbit/s"

    property var tooltip
    signal clicked()

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    function iconFile() {
        if (conn === "ethernet") return "ethernet.svg";
        if (conn === "wifi") {
            if (wifiSignal >= 75) return "wifi4.svg";
            if (wifiSignal >= 50) return "wifi3.svg";
            if (wifiSignal >= 25) return "wifi2.svg";
            return "wifi1.svg";
        }
        return "nointernet.svg";
    }

    function tooltipText() {
        if (conn === "none") return "No Internet";
        var lines = [];
        if (conn === "wifi") {
            if (ssid.length > 0 && device.length > 0)      lines.push(ssid + " @ " + device);
            else if (ssid.length > 0)                       lines.push(ssid);
            else if (device.length > 0)                     lines.push(device);
        } else {
            if (device.length > 0) lines.push(device);
        }
        if (ip.length > 0)    lines.push(ip);
        if (speed.length > 0) lines.push(speed);
        return lines.length > 0 ? lines.join("\n") : "Connected";
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

    function refreshTooltip() {
        if (hover.hovered && tooltip) tooltip.text = root.tooltipText();
    }
    onConnChanged:       refreshTooltip()
    onWifiSignalChanged: refreshTooltip()
    onDeviceChanged:     refreshTooltip()
    onSsidChanged:       refreshTooltip()
    onIpChanged:         refreshTooltip()
    onSpeedChanged:      refreshTooltip()

    Image {
        anchors.centerIn: parent
        width: 22
        height: 22
        sourceSize.width: 44
        sourceSize.height: 44
        source: Qt.resolvedUrl("../../../icons/" + root.iconFile())
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // NetworkManager is the de-facto network daemon on both Plasma and
    // common Hyprland setups, so `nmcli` is the most portable signal.
    // Ethernet wins over WiFi when both are connected — that matches the
    // typical "wired is the active route" heuristic.
    Timer {
        running: true
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: deviceQuery.running = true
    }

    Process {
        id: deviceQuery
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var hasEthernet = false;
                var hasWifi = false;
                for (var i = 0; i < lines.length; ++i) {
                    var parts = lines[i].split(":");
                    if (parts.length < 2) continue;
                    if (parts[1] !== "connected") continue;
                    if (parts[0] === "ethernet") hasEthernet = true;
                    else if (parts[0] === "wifi") hasWifi = true;
                }
                if (hasEthernet) {
                    root.conn = "ethernet";
                } else if (hasWifi) {
                    root.conn = "wifi";
                    wifiSignalQuery.running = true;
                } else {
                    root.conn = "none";
                    root.device = "";
                    root.ssid = "";
                    root.ip = "";
                    root.speed = "";
                }
                if (root.conn !== "none") detailsQuery.running = true;
            }
        }
    }

    Process {
        id: wifiSignalQuery
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null"
            + " | awk -F: '$1==\"*\"{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(text.trim());
                if (!isNaN(n)) root.wifiSignal = n;
            }
        }
    }

    // Pulls device, IP, SSID (WiFi only), and link speed in one shell hop.
    // Output format (one key per line, "key=value"):
    //   device=wlan0
    //   ssid=MyNet      (omitted for ethernet)
    //   ip=192.168.1.42
    //   speed=130 Mbit/s
    Process {
        id: detailsQuery
        command: ["sh", "-c",
            "type=$(nmcli -t -f TYPE,STATE,DEVICE device status 2>/dev/null"
            + " | awk -F: '$2==\"connected\" && ($1==\"ethernet\" || $1==\"wifi\") {print $1\":\"$3; exit}');"
            + "[ -z \"$type\" ] && exit 0;"
            + "kind=${type%:*}; dev=${type#*:};"
            + "echo \"device=$dev\";"
            + "if [ \"$kind\" = \"wifi\" ]; then"
            + "  ssid=$(nmcli -t -f IN-USE,SSID device wifi 2>/dev/null"
            + "         | awk -F: '$1==\"*\"{print $2; exit}');"
            + "  echo \"ssid=$ssid\";"
            + "  rate=$(nmcli -t -f IN-USE,RATE device wifi 2>/dev/null"
            + "         | awk -F: '$1==\"*\"{print $2; exit}');"
            + "  echo \"speed=$rate\";"
            + "else"
            + "  sp=$(cat /sys/class/net/$dev/speed 2>/dev/null);"
            + "  [ -n \"$sp\" ] && echo \"speed=$sp Mbit/s\";"
            + "fi;"
            + "ipa=$(nmcli -t -f IP4.ADDRESS device show $dev 2>/dev/null"
            + "      | head -n1 | cut -d: -f2 | cut -d/ -f1);"
            + "echo \"ip=$ipa\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var d = "", s = "", ipa = "", spd = "";
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    var eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    var key = line.substring(0, eq);
                    var val = line.substring(eq + 1);
                    if (key === "device") d = val;
                    else if (key === "ssid") s = val;
                    else if (key === "ip") ipa = val;
                    else if (key === "speed") spd = val;
                }
                root.device = d;
                root.ssid = s;
                root.ip = ipa;
                root.speed = spd;
            }
        }
    }
}
