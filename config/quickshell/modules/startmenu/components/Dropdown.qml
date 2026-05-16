import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root

    property var actions: []   // [{ label, icon, onTrigger }]
    property real itemHeight: 40
    property real menuPadding: 6

    visible: false
    color: Theme.dropdownBg
    border.color: Theme.dropdownBorder
    border.width: 1
    radius: 8

    width: 200
    height: actions.length * itemHeight + menuPadding * 2

    Column {
        anchors.fill: parent
        anchors.margins: root.menuPadding

        Repeater {
            model: root.actions
            delegate: Rectangle {
                width: parent.width
                height: root.itemHeight
                radius: 4
                color: hover.hovered ? Theme.hoverBg : "transparent"

                HoverHandler { id: hover }
                TapHandler {
                    onTapped: {
                        if (modelData.onTrigger) modelData.onTrigger();
                        root.visible = false;
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // SVG icon from quickshell/icons/.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18

                        Image {
                            anchors.fill: parent
                            source: modelData.icon || ""
                            visible: source.toString().length > 0
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.textPrimary
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
