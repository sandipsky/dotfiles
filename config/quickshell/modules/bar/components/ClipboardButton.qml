import QtQuick
import "../../../styles"

Rectangle {
    id: root
    width: 32
    height: 32
    radius: 6
    color: (hover.hovered || root.active) ? Theme.hoverBg : "transparent"

    property bool active: false
    signal clicked()

    HoverHandler { id: hover }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    Image {
        anchors.centerIn: parent
        width: 24
        height: 24
        sourceSize.width: 32
        sourceSize.height: 32
        source: Qt.resolvedUrl("../../../icons/clipboard.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
