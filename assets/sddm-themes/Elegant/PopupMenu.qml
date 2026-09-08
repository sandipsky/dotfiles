// Lock-screen menu (.lock-session-menu / .lock-session-item in hypr-shell's
// lock.css): a 210 px surface panel with a faint outline and 36 px rows that
// fill with the accent on hover or keyboard focus; destructive rows use the
// error colour. Rows come from a ListModel with label, glyph, destructive,
// checked (current session/user gets a check mark) and action.
import QtQuick 2.15

Rectangle {
    id: menu
    property alias model: list.model
    property bool open: false
    signal triggered(int index)
    signal closed()

    // 210 like the lock screen's menu, wider when a label needs it (session
    // names such as "Hyprland (uwsm-managed)"), never past 360.
    property real widestRow: 0
    width: Math.min(360, Math.max(210, widestRow + 18))
    height: list.contentHeight + 18
    radius: 16
    color: mSurface
    border.width: 1
    border.color: alpha(mOutline, 0.3)
    opacity: open ? 1 : 0
    visible: opacity > 0
    enabled: open
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function show() {
        widestRow = 0
        list.currentIndex = -1
        open = true
        list.forceActiveFocus()
    }
    function hide() {
        if (!open) return
        open = false
        closed()
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 9
        spacing: 2
        interactive: false
        keyNavigationWraps: true
        highlightFollowsCurrentItem: false

        delegate: Rectangle {
            id: row
            readonly property bool hot: hover.containsMouse || list.currentIndex === index
            readonly property bool destructive: model.destructive
            width: list.width
            height: 36
            radius: 12
            color: hot ? (destructive ? mError : mPrimary) : "transparent"
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Text {
                id: glyph
                anchors {
                    left: parent.left
                    leftMargin: 9
                    verticalCenter: parent.verticalCenter
                }
                text: model.glyph
                font.family: iconFamily
                font.pointSize: 13
                color: row.hot ? (row.destructive ? mOnError : mOnPrimary)
                               : (row.destructive ? mError : mOnSurface)
            }
            Text {
                id: label
                anchors {
                    left: glyph.right
                    leftMargin: 9
                    right: check.visible ? check.left : parent.right
                    rightMargin: 9
                    verticalCenter: parent.verticalCenter
                }
                text: model.label
                elide: Text.ElideRight
                font.family: fontFamily
                font.pointSize: 11
                color: row.hot ? (row.destructive ? mOnError : mOnPrimary) : mOnSurface
            }
            Text {
                id: check
                visible: model.checked
                anchors {
                    right: parent.right
                    rightMargin: 9
                    verticalCenter: parent.verticalCenter
                }
                text: ""
                font.family: iconFamily
                font.pointSize: 13
                color: row.hot ? mOnPrimary : mPrimary
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.triggered(index)
            }

            // glyph + gap + full label + gap (+ check mark), plus the row's own padding
            Component.onCompleted: {
                var need = 9 + glyph.implicitWidth + 9 + label.implicitWidth + 9 + (check.visible ? check.implicitWidth + 9 : 0)
                if (need > menu.widestRow) menu.widestRow = need
            }
        }

        Keys.onUpPressed: currentIndex = currentIndex <= 0 ? count - 1 : currentIndex - 1
        Keys.onDownPressed: currentIndex = (currentIndex + 1) % count
        Keys.onReturnPressed: if (currentIndex >= 0) menu.triggered(currentIndex)
        Keys.onEnterPressed: if (currentIndex >= 0) menu.triggered(currentIndex)
        Keys.onEscapePressed: menu.hide()
    }
}
