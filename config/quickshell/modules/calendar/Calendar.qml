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

    // Negative: the panel tucks up behind the top bar when hidden.
    readonly property real _hiddenOffset: -(panel.height + panel.anchors.topMargin)

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
    // Direction of the last month change: +1 = next, -1 = prev. Drives the
    // day-grid slide-in animation.
    property int slideDir: 1

    // Re-resolve "today" each time the calendar is opened so the
    // highlight stays correct after the day rolls over.
    onVisibleChanged: if (visible) today = new Date()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayShort: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function gotoPrev() {
        var m = viewMonth - 1, y = viewYear;
        if (m < 0) { m = 11; y -= 1; }
        slideDir = -1;
        viewMonth = m; viewYear = y;
        animateMonthChange();
    }
    function gotoNext() {
        var m = viewMonth + 1, y = viewYear;
        if (m > 11) { m = 0; y += 1; }
        slideDir = 1;
        viewMonth = m; viewYear = y;
        animateMonthChange();
    }

    // Kick off the directional slide + fade for the day grid. The cells have
    // already been rebuilt synchronously by the time this runs, so it reads
    // as an "enter": start offset + transparent, settle to centred + opaque.
    function animateMonthChange() {
        gridSlide.x = slideDir * 26;
        dayGrid.opacity = 0;
        monthAnim.restart();
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

    // Clipping container: its top edge sits at the bottom of the bar so
    // anything above that line is cut off, producing the "tuck behind the
    // bar" slide. The bar (a separate layer-shell surface) keeps painting
    // normally over the clipped pixels.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.topMargin: Theme.barHeight
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
        height: 412

        // Centred under the clock, just below the top bar.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6

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

            // ---------- Month navigator (top bar) ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.calendarHeaderBg
                // Round only the top corners so it matches the panel's
                // rounded top while sitting flush against the grid below.
                topLeftRadius: Theme.calendarRadius
                topRightRadius: Theme.calendarRadius
                bottomLeftRadius: 0
                bottomRightRadius: 0

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
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Previous month (left)
                    Rectangle {
                        width: 28; height: 28; radius: 4
                        color: prevHover.hovered ? Theme.hoverBg : "transparent"
                        HoverHandler { id: prevHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.gotoPrev()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "◀"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 12
                        }
                    }
                    // Next month (right)
                    Rectangle {
                        width: 28; height: 28; radius: 4
                        color: nextHover.hovered ? Theme.hoverBg : "transparent"
                        HoverHandler { id: nextHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.gotoNext()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
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
                clip: true
                readonly property real cellW: (width - 24) / 7
                readonly property real cellH: height / 6

                // Directional slide + fade played whenever the month changes.
                ParallelAnimation {
                    id: monthAnim
                    NumberAnimation {
                        target: gridSlide; property: "x"
                        to: 0; duration: 220; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: dayGrid; property: "opacity"
                        to: 1; duration: 220; easing.type: Easing.OutCubic
                    }
                }

                Grid {
                    id: dayGrid
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    columns: 7
                    rowSpacing: 0
                    columnSpacing: 0
                    transform: Translate { id: gridSlide }

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
