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
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        source: Qt.resolvedUrl("../../../icons/power.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
