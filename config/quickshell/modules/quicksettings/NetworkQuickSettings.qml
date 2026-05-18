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
    // Need keyboard focus so the password TextInput can actually receive
    // typing. OnDemand only grabs it when the user clicks the field.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool open: false
    visible: open

    function close() { open = false; }
    function refresh() {
        wifiQuery.running = true;
        knownQuery.running = true;
        if (wifiOn) listQuery.running = true;
    }
    onOpenChanged: if (open) refresh()

    Keys.onEscapePressed: root.close()

    // ----- state -----
    property bool wifiOn: false
    property var networks: []            // [{ssid, signal, security, inUse}]
    property var knownSsids: []          // saved-connection SSIDs
    property string passwordSsid: ""     // SSID currently expanded for password

    function isKnown(ssid) { return knownSsids.indexOf(ssid) >= 0; }
    function isSecured(sec) { return sec.length > 0 && sec !== "--"; }

    function tryConnect(ssid, security) {
        if (!isSecured(security) || isKnown(ssid)) {
            Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid]);
            connectRecheck.restart();
        } else {
            passwordSsid = ssid;
        }
    }
    function submitConnect(ssid, password) {
        Quickshell.execDetached([
            "nmcli", "device", "wifi", "connect", ssid, "password", password
        ]);
        passwordSsid = "";
        connectRecheck.restart();
    }

    // ----- outside-click dismiss -----
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    Rectangle {
        id: panel
        width: 360
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 60

        // Height grows with content. List view caps itself so the panel
        // doesn't run off the top of the screen.
        height: column.implicitHeight + 24

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
            anchors.topMargin: 12
            spacing: 4

            // ---------- Header: "Wi-Fi" + toggle ----------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.wifiOn
                    onToggled: {
                        var next = !root.wifiOn;
                        Quickshell.execDetached([
                            "nmcli", "radio", "wifi", next ? "on" : "off"
                        ]);
                        root.wifiOn = next;
                        if (next) listRecheck.restart();
                        else { root.networks = []; root.passwordSsid = ""; }
                    }
                }
            }

            // ---------- Body: off-state copy OR network list ----------
            Loader {
                Layout.fillWidth: true
                sourceComponent: root.wifiOn ? networkList : offState
            }
        }
    }

    // ---------- "Wi-Fi is off" body ----------
    Component {
        id: offState
        Column {
            spacing: 8
            topPadding: 14
            bottomPadding: 16

            Text {
                text: "Wi-Fi is off"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Turn on Wi-Fi to connect to an available Wi-Fi network."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 13
                lineHeight: 1.2
            }
        }
    }

    // ---------- Network list body ----------
    Component {
        id: networkList
        Item {
            // Cap at ~5 collapsed rows + room for the expanded password
            // form; ListView scrolls past that.
            readonly property real maxHeight: 360
            implicitHeight: Math.min(list.contentHeight + 4, maxHeight)

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: root.networks
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: WiFiItem {
                    width: ListView.view.width
                    ssid: modelData.ssid
                    signalStrength: modelData.signal
                    security: modelData.security
                    inUse: modelData.inUse
                    known: root.isKnown(modelData.ssid)
                    expanded: root.passwordSsid === modelData.ssid

                    onConnectClicked: root.tryConnect(ssid, security)
                    onSubmitClicked:  (pw) => root.submitConnect(ssid, pw)
                    onCancelClicked:  root.passwordSsid = ""
                }
            }
        }
    }

    // ----- queries -----

    Process {
        id: wifiQuery
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: { root.wifiOn = (text.trim() === "enabled"); }
        }
    }

    // Visible networks. IN-USE column marks the active one with `*`.
    // Output is colon-separated; SSIDs containing ':' are escaped by nmcli
    // with `\:`, but for simplicity we treat that as rare.
    Process {
        id: listQuery
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {};
                var out = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (!line) continue;
                    var parts = line.split(":");
                    if (parts.length < 4) continue;
                    var inUse = parts[0] === "*";
                    var ssid = parts[1];
                    if (!ssid || seen[ssid]) continue;
                    seen[ssid] = true;
                    out.push({
                        ssid: ssid,
                        signal: parseInt(parts[2]) || 0,
                        security: parts[3],
                        inUse: inUse
                    });
                }
                // Active network first, then by signal strength.
                out.sort(function (a, b) {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                root.networks = out;
            }
        }
    }
    Timer { id: listRecheck; interval: 800; onTriggered: listQuery.running = true }
    Timer { id: connectRecheck; interval: 1500; onTriggered: { listQuery.running = true; } }

    Process {
        id: knownQuery
        command: ["sh", "-c",
            "nmcli -t -f TYPE,NAME connection show 2>/dev/null"
            + " | awk -F: '$1==\"802-11-wireless\"{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; ++i) {
                    var s = lines[i].trim();
                    if (s.length > 0) out.push(s);
                }
                root.knownSsids = out;
            }
        }
    }
}
