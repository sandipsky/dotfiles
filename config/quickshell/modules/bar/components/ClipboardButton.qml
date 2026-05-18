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
        width: 20
        height: 20
        source: Qt.resolvedUrl("../../../icons/clipboard.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
