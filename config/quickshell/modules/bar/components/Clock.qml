import QtQuick
import "../../../styles"

Rectangle {
    id: root

    signal leftClicked()

    property bool active: false
    property var tooltip
    property var now: new Date()
    // false → "h:mm AM/PM", true → "Mon, Dec 19"
    property bool altFormat: false

    readonly property var monthShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    readonly property var monthLong: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var dayLong: [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]

    function pad2(n) { return n < 10 ? "0" + n : "" + n; }

    function timeText() {
        var h = now.getHours();
        var ampm = h >= 12 ? "PM" : "AM";
        var h12 = h % 12; if (h12 === 0) h12 = 12;
        return h12 + ":" + pad2(now.getMinutes()) + " " + ampm;
    }
    function dateText() {
        return dayShort[now.getDay()] + ", "
            + monthShort[now.getMonth()] + " "
            + now.getDate();
    }
    function tooltipText() {
        return dayLong[now.getDay()] + ", "
            + monthLong[now.getMonth()] + " "
            + now.getDate() + ", " + now.getFullYear()
            + "\n" + timeText();
    }

    width: label.implicitWidth + 20
    height: 32
    radius: 6
    color: (hover.hovered || root.active) ? Theme.hoverBg : "transparent"

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

    // Left click opens calendar
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.leftClicked()
    }
    // Right click toggles format
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.altFormat = !root.altFormat
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.altFormat ? root.dateText() : root.timeText()
        color: Theme.textPrimary
        font.pixelSize: 13
    }

    // Tick every second so the minute rolls over promptly without
    // sub-second drift accumulating into a stale display.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Refresh the tooltip text live while the cursor lingers, so the
    // minute rolls over without dismissing/re-entering the indicator.
    onNowChanged: {
        if (hover.hovered && tooltip) {
            tooltip.text = root.tooltipText();
        }
    }
}
