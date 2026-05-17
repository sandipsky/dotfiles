import QtQuick
import "../../../styles"

Rectangle {
    id: root
    property bool on: false
    signal toggled()

    width: 42
    height: 22
    radius: height / 2
    color: on ? Theme.barAccent : "#555555"

    Behavior on color { ColorAnimation { duration: 120 } }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.toggled()
    }

    Rectangle {
        id: thumb
        x: root.on ? root.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
