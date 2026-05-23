import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../styles"

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

    property bool open: true
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Distance the panel must travel to be fully tucked behind the bar.
    readonly property real _hiddenOffset: panel.height + panel.anchors.bottomMargin

    function close() { open = false; }

    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    // -------- state --------
    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()    // 0-based

    // Re-resolve "today" each time the calendar is opened so the
    // highlight stays correct after the day rolls over.
    onVisibleChanged: if (visible) today = new Date()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekdayLong: [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]
    readonly property var dayShort: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function gotoPrev() {
        var m = viewMonth - 1, y = viewYear;
        if (m < 0) { m = 11; y -= 1; }
        viewMonth = m; viewYear = y;
    }
    function gotoNext() {
        var m = viewMonth + 1, y = viewYear;
        if (m > 11) { m = 0; y += 1; }
        viewMonth = m; viewYear = y;
    }

    // 6-row × 7-col grid filled with leading prev-month + month + trailing next.
    function buildCells(year, month) {
        var cells = [];
        var firstDow      = new Date(year, month, 1).getDay();
        var daysInMonth   = new Date(year, month + 1, 0).getDate();
        var daysInPrev    = new Date(year, month, 0).getDate();
        for (var i = firstDow - 1; i >= 0; --i)
            cells.push({ day: daysInPrev - i, type: "prev"    });
        for (var d = 1; d <= daysInMonth; ++d)
            cells.push({ day: d,              type: "current" });
        var nx = 1;
        while (cells.length < 42)
            cells.push({ day: nx++, type: "next" });
        return cells;
    }
    readonly property var cells: buildCells(viewYear, viewMonth)

    // -------- outside-click dismiss --------
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
        height: 460

        // Bottom-right (system-tray corner), with breathing room
        // for the taskbar/dock area.
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 6

        color: Theme.calendarBg
        radius: Theme.calendarRadius
        border.color: Theme.calendarBorder
        border.width: 1
        clip: true

        // Light drop shadow (stacked rings; no MultiEffect for VM compat).
        Repeater {
            parent: slideContent
            model: 6
            delegate: Rectangle {
                anchors.fill: panel
                anchors.leftMargin:   -(index + 1)
                anchors.rightMargin:  -(index + 1)
                anchors.topMargin:    0
                anchors.bottomMargin: -(index + 1) - 2
                z: -1 - index
                color: "transparent"
                radius: panel.radius + (index + 1)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.18 / (index + 1))
            }
        }

        // Eat inside-clicks so they don't bubble to the outside dismiss.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- Today header ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.calendarHeaderBg
                radius: Theme.calendarRadius

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weekdayLong[root.today.getDay()]
                        + ", " + root.monthNames[root.today.getMonth()]
                        + " "  + root.today.getDate()
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }

            // ---------- Month navigator ----------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.monthNames[root.viewMonth] + " " + root.viewYear
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Rectangle {
                        width: 28; height: 28; radius: 4
                        color: upHover.hovered ? Theme.hoverBg : "transparent"
                        HoverHandler { id: upHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.gotoPrev()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "▲"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 4
                        color: dnHover.hovered ? Theme.hoverBg : "transparent"
                        HoverHandler { id: dnHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.gotoNext()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "▼"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // ---------- Day-of-week labels ----------
            Item {
                id: dayLabels
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                readonly property real cellW: (width - 24) / 7

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Repeater {
                        model: root.dayShort
                        delegate: Item {
                            width: dayLabels.cellW
                            height: dayLabels.height
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.styleName: Theme.fontStyle
                                font.pixelSize: 16
                            }
                        }
                    }
                }
            }

            // ---------- Day grid ----------
            Item {
                id: gridContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: 12
                readonly property real cellW: (width - 24) / 7
                readonly property real cellH: height / 6

                Grid {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    columns: 7
                    rowSpacing: 0
                    columnSpacing: 0

                    Repeater {
                        model: root.cells
                        delegate: Item {
                            width: gridContainer.cellW
                            height: gridContainer.cellH

                            readonly property bool isCurrent: modelData.type === "current"
                            readonly property bool isToday: isCurrent
                                && modelData.day  === root.today.getDate()
                                && root.viewYear  === root.today.getFullYear()
                                && root.viewMonth === root.today.getMonth()

                            Rectangle {
                                width: Math.min(parent.width, parent.height) - 6
                                height: width
                                anchors.centerIn: parent
                                radius: width / 2
                                color: isToday
                                    ? Theme.calendarTodayBg
                                    : (cellHover.hovered && isCurrent ? Theme.hoverBg : "transparent")

                                HoverHandler { id: cellHover }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    color: isToday
                                        ? Theme.calendarTodayText
                                        : (isCurrent ? Theme.textPrimary : Theme.calendarDimText)
                                    font.family: Theme.fontFamily
                                    font.styleName: Theme.fontStyle
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
