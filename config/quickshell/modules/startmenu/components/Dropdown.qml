import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root

    // [{ label, icon, onTrigger }] — or { separator: true } for a divider line.
    property var actions: []
    property real itemHeight: 40
    property real separatorHeight: 13
    property real menuPadding: 6

    // Slide down/up open-close, mirroring the bar's calendar panel.
    property bool open: false
    // Keep rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    // How far it slides while opening/closing. Negative so it descends from
    // above into place, matching the top bar.
    property real slideDistance: -24

    visible: _renderVisible
    opacity: open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    transform: Translate { id: slideTransform; y: root.slideDistance }

    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            slideOutAnim.stop();
            slideTransform.y = slideDistance;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    NumberAnimation {
        id: slideInAnim
        target: slideTransform
        property: "y"
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: slideOutAnim
        target: slideTransform
        property: "y"
        to: root.slideDistance
        duration: 180
        easing.type: Easing.InCubic
        onFinished: root._renderVisible = false
    }

    color: Theme.dropdownBg
    border.color: Theme.dropdownBorder
    border.width: 1
    radius: 8

    width: 200
    height: {
        var h = menuPadding * 2;
        for (var i = 0; i < actions.length; i++)
            h += actions[i].separator ? separatorHeight : itemHeight;
        return h;
    }

    // Eat inside-clicks so they don't fall through to the app list beneath.
    MouseArea {
        anchors.fill: parent
        onPressed: (m) => { m.accepted = true; }
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.menuPadding

        Repeater {
            model: root.actions
            delegate: Rectangle {
                width: parent.width
                height: modelData.separator ? root.separatorHeight : root.itemHeight
                radius: 4
                color: (!modelData.separator && hover.hovered) ? Theme.hoverBg : "transparent"

                // Divider line for separator entries.
                Rectangle {
                    visible: modelData.separator === true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.dropdownBorder
                }

                HoverHandler { id: hover; enabled: !modelData.separator }
                TapHandler {
                    enabled: !modelData.separator
                    onTapped: {
                        if (modelData.onTrigger) modelData.onTrigger();
                        root.open = false;
                    }
                }

                Row {
                    visible: !modelData.separator
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
                        text: modelData.label || ""
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.styleName: Theme.fontStyle
                        font.pixelSize: 15
                    }
                }
            }
        }
    }
}
