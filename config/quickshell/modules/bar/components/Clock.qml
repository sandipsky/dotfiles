import QtQuick
import "../../../styles"

Rectangle {
    id: root

    signal leftClicked()

    property bool active: false
    property var now: new Date()

    readonly property var monthShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    function pad2(n) { return n < 10 ? "0" + n : "" + n; }

    // Bar label, e.g. "Sat, Jun 27 | 08:00 AM" (hour zero-padded).
    function barText() {
        var h = now.getHours();
        var ampm = h >= 12 ? "PM" : "AM";
        var h12 = h % 12; if (h12 === 0) h12 = 12;
        return dayShort[now.getDay()] + ", "
            + monthShort[now.getMonth()] + " "
            + now.getDate() + " | "
            + pad2(h12) + ":" + pad2(now.getMinutes()) + " " + ampm;
    }

    width: label.implicitWidth + 10
    height: 32
    radius: 6
    color: (hover.hovered || root.active) ? Theme.hoverBg : "transparent"

    HoverHandler { id: hover }

    // Left click opens calendar
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.leftClicked()
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.barText()
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 16
    }

    // Tick every second so the minute rolls over promptly without
    // sub-second drift accumulating into a stale display.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

}
