import QtQuick
import "../../../styles"

Item {
    id: root

    property string iconSource: ""
    // When set, renders a Segoe Fluent Icons glyph in place of iconSource.
    property string iconChar: ""
    property real value: 0      // 0..1
    property real minValue: 0
    property real maxValue: 1
    property bool showPercent: false

    signal valueDragged(real value)    // while user drags
    signal valueCommitted(real value)  // on release / click
    signal iconClicked()

    height: 28

    Text {
        id: percentLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: {
            var span = root.maxValue - root.minValue;
            var n = span > 0 ? (root.value - root.minValue) / span : 0;
            return Math.round(Math.max(0, Math.min(1, n)) * 100) + "%";
        }
        color: Theme.textPrimary
        font.pixelSize: 15
        horizontalAlignment: Text.AlignRight
        width: 38
        visible: root.showPercent
    }

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
        visible: root.iconChar.length === 0 && source.toString().length > 0
    }

    Text {
        id: leftGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.iconChar
        color: Theme.textPrimary
        font.family: "Segoe Fluent Icons"
        font.pixelSize: 18
        renderType: Text.NativeRendering
        visible: root.iconChar.length > 0
    }

    MouseArea {
        id: iconHit
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(
            (leftGlyph.visible ? leftGlyph.width : 0),
            (leftIcon.visible  ? leftIcon.width  : 0),
            20
        ) + 12
        height: Math.max(parent.height, 24)
        z: 2
        enabled: leftGlyph.visible || leftIcon.visible
        visible: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
    }

    Item {
        id: trackArea
        anchors.left: leftGlyph.visible ? leftGlyph.right
                       : (leftIcon.visible ? leftIcon.right : parent.left)
        anchors.leftMargin: (leftGlyph.visible || leftIcon.visible) ? 14 : 0
        anchors.right: percentLabel.visible ? percentLabel.left : parent.right
        anchors.rightMargin: percentLabel.visible ? 8 : 0
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
