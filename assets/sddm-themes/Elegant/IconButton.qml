// Round 30 px icon button — button.lock-power in hypr-shell's lock.css:
// translucent surface, accent fill on hover/focus/while its menu is open.
import QtQuick 2.15

Rectangle {
    id: button
    property string glyph: ""
    property bool active: false
    signal clicked()

    readonly property bool hot: hover.containsMouse || active || activeFocus

    width: 30
    height: 30
    radius: 15
    color: hot ? mPrimary : alpha(mSurface, 0.65)
    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    activeFocusOnTab: true

    Text {
        anchors.centerIn: parent
        text: button.glyph
        font.family: iconFamily
        font.pointSize: 14
        color: button.hot ? mOnPrimary : mOnSurface
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
}
