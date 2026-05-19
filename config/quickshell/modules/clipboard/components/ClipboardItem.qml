import QtQuick
import "../../../styles"

Rectangle {
    id: root

    property string entryId: ""
    property string preview: ""

    signal copy()
    signal removeEntry()

    height: 44
    radius: 6
    color: rowHover.hovered ? Theme.hoverBg : "transparent"

    HoverHandler { id: rowHover }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.copy()
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: deleteBtn.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.preview
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 16
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // Delete button. Its own TapHandler takes the press first (child
    // handlers preempt parent handlers in Qt 6), so clicking the trash
    // icon never bubbles up as a "copy" tap on the row.
    Rectangle {
        id: deleteBtn
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 4
        color: delHover.hovered ? Theme.highlightBg : "transparent"
        opacity: rowHover.hovered || delHover.hovered ? 1.0 : 0.5

        HoverHandler { id: delHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.removeEntry()
        }

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize.width: 28
            sourceSize.height: 28
            source: Qt.resolvedUrl("../../../icons/delete.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
}
