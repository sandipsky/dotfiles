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

    // Distance the panel must travel to be fully tucked behind the bar.
    readonly property real _hiddenOffset: panel.height + panel.anchors.bottomMargin

    function close() { open = false; }
    function refresh() {
        powerQuery.running = true;
        if (powered) listQuery.running = true;
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
            // Stop any background scan we may have started.
            Quickshell.execDetached(["bluetoothctl", "scan", "off"]);
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    Keys.onEscapePressed: root.close()

    // ----- state -----
    property bool powered: false
    property var devices: []          // [{ mac, name, icon, paired, connected }]
    property bool scanning: false
    // Each entry: mac → { action: "connect"|"disconnect"|"pair"|"unpair" }.
    // Used both as the busy flag for BluetoothItem and as a hint so the
    // next listQuery can decide whether the device reached its target state.
    property var busyMacs: ({})

    function setBusy(mac, action) {
        var copy = {};
        for (var k in busyMacs) copy[k] = busyMacs[k];
        if (action) copy[mac] = { action: action };
        else        delete copy[mac];
        busyMacs = copy;
        if (action) busyTimeout.restart();
    }
    function isBusy(mac) { return !!busyMacs[mac]; }

    // Hard safety net: if a bluetoothctl action never produces a state
    // change (out-of-range device, agent never replied, etc.) the device
    // would otherwise be stuck on "Working…" until the next scan timeout.
    Timer {
        id: busyTimeout
        interval: 8000
        onTriggered: root.busyMacs = ({})
    }

    function startScan() {
        var showLoading = devices.length === 0;
        scanning = showLoading;
        scanPoller.attempts = showLoading ? 0 : 4;
        // `--timeout` makes bluetoothctl auto-stop scanning after N seconds,
        // so we don't leak a discovery session if the panel is force-closed.
        Quickshell.execDetached(["bluetoothctl", "--timeout", "15", "scan", "on"]);
        listQuery.running = true;
        scanPoller.restart();
    }

    function connectDevice(mac) {
        setBusy(mac, "connect");
        Quickshell.execDetached(["bluetoothctl", "connect", mac]);
        actionRecheck.restart();
    }
    function disconnectDevice(mac) {
        setBusy(mac, "disconnect");
        Quickshell.execDetached(["bluetoothctl", "disconnect", mac]);
        actionRecheck.restart();
    }
    // Pair → trust → connect in one hop. The mac is passed as a positional
    // arg ($1) so it's never spliced into the shell string directly.
    function pairDevice(mac) {
        setBusy(mac, "pair");
        Quickshell.execDetached([
            "sh", "-c",
            "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"",
            "sh", mac
        ]);
        actionRecheck.restart();
    }
    function unpairDevice(mac) {
        setBusy(mac, "unpair");
        Quickshell.execDetached(["bluetoothctl", "remove", mac]);
        actionRecheck.restart();
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

            // ---------- Header: "Bluetooth" + refresh + toggle ----------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                Rectangle {
                    id: refreshBtn
                    anchors.right: btToggle.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 6
                    visible: root.powered
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
                    id: btToggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.powered
                    onToggled: {
                        var next = !root.powered;
                        Quickshell.execDetached([
                            "bluetoothctl", "power", next ? "on" : "off"
                        ]);
                        root.powered = next;
                        if (next) {
                            scanKick.restart();
                        } else {
                            root.devices = [];
                            root.scanning = false;
                            scanPoller.stop();
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                sourceComponent: !root.powered
                    ? offState
                    : (root.devices.length === 0 && root.scanning
                        ? scanningState
                        : deviceList)
            }
        }
    }
    }

    Component {
        id: offState
        Column {
            spacing: 8
            topPadding: 14
            bottomPadding: 16

            Text {
                text: "Bluetooth is off"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Turn on Bluetooth to discover and connect to nearby devices."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 13
                lineHeight: 1.2
            }
        }
    }

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
                text: "Searching for devices" + ".".repeat(scanCol.dotPhase)
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Looking for available Bluetooth devices."
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 13
                lineHeight: 1.2
            }
        }
    }

    Component {
        id: deviceList
        Item {
            readonly property real maxHeight: 360
            implicitHeight: Math.min(list.contentHeight + 4, maxHeight)

            ListView {
                id: list
                anchors.fill: parent
                anchors.rightMargin: 10
                clip: true
                model: root.devices
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: BluetoothItem {
                    width: ListView.view.width
                    mac: modelData.mac
                    name: modelData.name
                    iconName: modelData.icon
                    paired: modelData.paired
                    connected: modelData.connected
                    busy: root.isBusy(modelData.mac)

                    onConnectClicked:    root.connectDevice(mac)
                    onDisconnectClicked: root.disconnectDevice(mac)
                    onPairClicked:       root.pairDevice(mac)
                    onUnpairClicked:     root.unpairDevice(mac)
                }
            }

            // Same scrollbar style as the WiFi panel.
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
        id: powerQuery
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null | awk '/^\\s*Powered:/ {print $2; exit}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var nowOn = (text.trim() === "yes");
                root.powered = nowOn;
                if (nowOn && root.open) root.startScan();
            }
        }
    }

    // One shot dump of every known/discovered device along with its
    // paired/connected/icon attributes. `bluetoothctl devices` lists all
    // controllers see; `info <MAC>` gives per-device detail.
    Process {
        id: listQuery
        command: ["sh", "-c",
            "for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do"
            + "  info=$(bluetoothctl info \"$mac\" 2>/dev/null);"
            + "  [ -z \"$info\" ] && continue;"
            + "  name=$(echo \"$info\"   | awk -F': ' '/^\\s*Name:/      {sub(/^[[:space:]]+/,\"\"); sub(/^Name: /, \"\"); print; exit}');"
            + "  icon=$(echo \"$info\"   | awk -F': ' '/^\\s*Icon:/      {print $2; exit}');"
            + "  paired=$(echo \"$info\" | awk     '/^\\s*Paired:/    {print $2; exit}');"
            + "  conn=$(echo \"$info\"   | awk     '/^\\s*Connected:/ {print $2; exit}');"
            + "  echo \"$mac|$name|$icon|$paired|$conn\";"
            + "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (!line) continue;
                    var parts = line.split("|");
                    if (parts.length < 5) continue;
                    out.push({
                        mac: parts[0],
                        name: parts[1],
                        icon: parts[2],
                        paired: parts[3] === "yes",
                        connected: parts[4] === "yes"
                    });
                }
                // Connected first, then paired, then everything else, each
                // group alpha-sorted by display name.
                out.sort(function (a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1;
                    if (a.paired !== b.paired)       return a.paired ? -1 : 1;
                    var an = (a.name || a.mac).toLowerCase();
                    var bn = (b.name || b.mac).toLowerCase();
                    return an < bn ? -1 : an > bn ? 1 : 0;
                });

                // Clear the busy flag for any device that has reached the
                // state its pending action was waiting for, so the row stops
                // showing "Working…" once bluetoothctl actually settles.
                var newByMac = {};
                for (var k = 0; k < out.length; k++) newByMac[out[k].mac] = out[k];
                var stillBusy = {};
                for (var mac in root.busyMacs) {
                    var entry  = root.busyMacs[mac];
                    var action = entry && entry.action;
                    var now    = newByMac[mac];
                    var done = false;
                    if (action === "connect")    done = now && now.connected;
                    else if (action === "disconnect") done = !now || !now.connected;
                    else if (action === "pair")  done = now && now.paired;
                    else if (action === "unpair") done = !now;
                    if (!done) stillBusy[mac] = entry;
                }
                root.busyMacs = stillBusy;

                root.devices = out;
                if (out.length > 0 && root.scanning) {
                    root.scanning = false;
                    scanPoller.stop();
                }
            }
        }
    }

    Timer { id: scanKick;    interval: 400;  onTriggered: root.startScan() }
    Timer { id: actionRecheck; interval: 1500; onTriggered: listQuery.running = true }
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
                // Clear any optimistic busy markers that didn't resolve.
                root.busyMacs = ({});
                stop();
            }
        }
    }
}
