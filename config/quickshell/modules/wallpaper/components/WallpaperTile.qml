import QtQuick
import "../../../styles"

Rectangle {
    id: root

    property string path: ""
    property string fileName: ""
    property bool selected: false

    signal clicked()

    color: hover.hovered ? Theme.hoverBg : Theme.startmenuSearchInputBg
    radius: 8
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.barAccent : Theme.calendarBorder
    clip: true

    HoverHandler { id: hover }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    Image {
        anchors.fill: parent
        anchors.margins: 4
        source: root.path ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize.width: 320
        sourceSize.height: 200
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        height: 22
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: hover.hovered || root.selected

        Text {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: Text.AlignVCenter
            text: root.fileName
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyle
            font.pixelSize: 11
            elide: Text.ElideMiddle
        }
    }
}
