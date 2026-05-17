import QtQuick
import "../../../styles"

Item {
    id: root

    property string iconSource: ""
    property real value: 0      // 0..1
    property real minValue: 0
    property real maxValue: 1

    signal valueDragged(real value)    // while user drags
    signal valueCommitted(real value)  // on release / click

    height: 28

    Image {
        id: leftIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: source.toString().length > 0
    }

    Item {
        id: trackArea
        anchors.left: leftIcon.visible ? leftIcon.right : parent.left
        anchors.leftMargin: leftIcon.visible ? 14 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        readonly property real norm: {
            var span = root.maxValue - root.minValue;
            if (span <= 0) return 0;
            return Math.max(0, Math.min(1, (root.value - root.minValue) / span));
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.highlightBg
        }
        Rectangle {
            id: filled
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: trackArea.width * trackArea.norm
            height: 4
            radius: 2
            color: Theme.barAccent
        }
        Rectangle {
            id: thumb
            anchors.verticalCenter: parent.verticalCenter
            x: filled.width - width / 2
            width: 14
            height: 14
            radius: 7
            color: Theme.textPrimary
            border.color: Theme.barAccent
            border.width: 2
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function setFromX(mx) {
                var n = Math.max(0, Math.min(1, mx / width));
                var span = root.maxValue - root.minValue;
                var v = root.minValue + n * span;
                root.value = v;
                root.valueDragged(v);
            }

            onPressed: (m) => setFromX(m.x)
            onPositionChanged: (m) => { if (pressed) setFromX(m.x); }
            onReleased: (m) => root.valueCommitted(root.value)
        }
    }
}
