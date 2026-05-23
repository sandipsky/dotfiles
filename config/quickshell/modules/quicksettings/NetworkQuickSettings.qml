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
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Distance the panel must travel to be fully tucked behind the bar.
    readonly property real _hiddenOffset: panel.height + panel.anchors.bottomMargin

    function close() { open = false; }
    function refresh() {
        wifiQuery.running = true;
        knownQuery.running = true;
        if (wifiOn) listQuery.running = true;
    }
    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            refresh();
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            scanPoller.stop();
            scanning = false;
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    Keys.onEscapePressed: root.close()

    // ----- state -----
    property bool wifiOn: false
    property var networks: []            // [{ssid, signal, security, inUse}]
    property var knownSsids: []          // saved-connection SSIDs
    property string passwordSsid: ""     // SSID currently expanded for password
    property bool scanning: false        // true while waiting for scan results

    function isKnown(ssid) { return knownSsids.indexOf(ssid) >= 0; }
    function isSecured(sec) { return sec.length > 0 && sec !== "--"; }

    function startScan() {
        // Show the "Scanning…" state only when the list is empty — otherwise
        // refresh in the background while keeping existing entries visible.
        var showLoading = networks.length === 0;
        scanning = showLoading;
        // showLoading: 0 → 8 polls (~12s). Background refresh: 4 → 8 polls (~6s).
        scanPoller.attempts = showLoading ? 0 : 4;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        listQuery.running = true;
        scanPoller.restart();
    }

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
    function disconnect(ssid) {
        // Bring the saved connection down. Connection names usually match
        // the SSID for connections created by `nmcli device wifi connect`.
        Quickshell.execDetached(["nmcli", "connection", "down", "id", ssid]);
        connectRecheck.restart();
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
        width: 360
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 6

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
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                // Refresh button — triggers a fresh nmcli rescan. Only shown
                // when WiFi is on (no point scanning while the radio is off).
                Rectangle {
                    id: refreshBtn
                    anchors.right: wifiToggle.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 6
                    visible: root.wifiOn
                    color: refreshHover.hovered ? Theme.hoverBg : "transparent"

                    HoverHandler { id: refreshHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.startScan()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""   // Segoe Fluent Icons: Refresh
                        color: Theme.textPrimary
                        font.family: "Segoe Fluent Icons"
                        font.pixelSize: 14
                        renderType: Text.NativeRendering

                        // Spin while scanning so it doubles as a progress hint.
                        RotationAnimation on rotation {
                            running: root.scanning
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                        rotation: root.scanning ? rotation : 0
                    }
                }

                ToggleSwitch {
                    id: wifiToggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.wifiOn
                    onToggled: {
                        var next = !root.wifiOn;
                        Quickshell.execDetached([
                            "nmcli", "radio", "wifi", next ? "on" : "off"
                        ]);
                        root.wifiOn = next;
                        if (next) {
                            // Give the radio a moment to come up before the
                            // first scan attempt, then poll for results.
                            scanKick.restart();
                        } else {
                            root.networks = [];
                            root.passwordSsid = "";
                            root.scanning = false;
                            scanPoller.stop();
                        }
                    }
                }
            }

            // ---------- Body: off-state, scanning, or network list ----------
            Loader {
                Layout.fillWidth: true
                sourceComponent: !root.wifiOn
                    ? offState
                    : (root.networks.length === 0 && root.scanning
                        ? scanningState
                        : networkList)
            }
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

    // ---------- "Scanning…" body ----------
    Component {
        id: scanningState
        Column {
            id: scanCol
            spacing: 8
            topPadding: 14
            bottomPadding: 16

            property int dotPhase: 0
            Timer {
                interval: 400
                repeat: true
                running: true
                onTriggered: scanCol.dotPhase = (scanCol.dotPhase + 1) % 4
            }

            Text {
                text: "Scanning for networks" + ".".repeat(scanCol.dotPhase)
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Looking for available Wi-Fi networks."
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
                anchors.rightMargin: 10   // reserve a sliver for the scrollbar
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

                    onConnectClicked:    root.tryConnect(ssid, security)
                    onSubmitClicked:     (pw) => root.submitConnect(ssid, pw)
                    onCancelClicked:     root.passwordSsid = ""
                    onDisconnectClicked: root.disconnect(ssid)
                }
            }

            // Custom scrollbar — mirrors the one in the start menu's AppList.
            Item {
                id: scrollbar
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: scrollHover.hovered || scrollArea.pressed ? 12 : 6
                visible: list.contentHeight > list.height

                Behavior on width { NumberAnimation { duration: 120 } }

                HoverHandler { id: scrollHover }

                Item { id: track; anchors.fill: parent }

                MouseArea {
                    id: scrollArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true

                    property real grabOffset: 0

                    function moveTo(localY) {
                        var maxThumbY = Math.max(0, track.height - thumb.height);
                        var maxContentY = Math.max(0, list.contentHeight - list.height);
                        if (maxThumbY <= 0 || maxContentY <= 0) return;
                        var newThumbY = Math.max(0, Math.min(maxThumbY, localY - grabOffset));
                        list.contentY = (newThumbY / maxThumbY) * maxContentY;
                    }

                    onPressed: (mouse) => {
                        if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                            grabOffset = mouse.y - thumb.y;
                        } else {
                            grabOffset = thumb.height / 2;
                            moveTo(mouse.y);
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) moveTo(mouse.y);
                    }
                }

                Rectangle {
                    id: thumb
                    x: 2
                    width: Math.max(0, scrollbar.width - 4)
                    radius: width / 2
                    color: scrollHover.hovered || scrollArea.pressed
                        ? "#6a6a6a"
                        : Theme.startmenuSearchBorder

                    readonly property real maxContentY: Math.max(1, list.contentHeight - list.height)
                    y: (list.contentY / maxContentY) * (track.height - height)
                    height: Math.max(30, track.height * Math.min(1, list.height / list.contentHeight))
                }
            }
        }
    }

    // ----- queries -----

    Process {
        id: wifiQuery
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var nowOn = (text.trim() === "enabled");
                root.wifiOn = nowOn;
                if (nowOn && root.open) {
                    // refresh() can't kick listQuery itself because it runs
                    // before this query returns. Always trigger a fresh scan
                    // here so the list reflects current airwaves, not whatever
                    // happened to be in nmcli's cache.
                    root.startScan();
                }
            }
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
                if (out.length > 0 && root.scanning) {
                    root.scanning = false;
                    scanPoller.stop();
                }
            }
        }
    }
    // Fires once shortly after WiFi is toggled on, then hands off to scanPoller.
    Timer { id: scanKick; interval: 400; onTriggered: root.startScan() }
    // Polls the wifi list while scanning is in progress. Gives up after ~12s
    // even if no networks show up so we don't poll forever.
    Timer {
        id: scanPoller
        interval: 1500
        repeat: true
        property int attempts: 0
        onTriggered: {
            listQuery.running = true;
            attempts++;
            if (attempts >= 8) {
                root.scanning = false;
                stop();
            }
        }
    }
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
