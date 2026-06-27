import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../styles"

// Power menu flyout — opened from the bar's PowerButton. Lives on the
// Overlay layer and slides down from behind the top bar, mirroring the
// calendar / quick-settings panels.
PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool open: false
    // Keep the window rendered while the slide-out animation finishes.
    property bool _renderVisible: open
    visible: _renderVisible

    // Negative: the panel tucks up behind the top bar when hidden.
    readonly property real _hiddenOffset: -(panel.height + panel.anchors.topMargin)

    function close() { open = false; }

    onOpenChanged: {
        if (open) {
            _renderVisible = true;
            slideOutAnim.stop();
            slideTransform.y = _hiddenOffset;
            slideInAnim.restart();
        } else {
            slideInAnim.stop();
            slideOutAnim.restart();
        }
    }

    Keys.onEscapePressed: root.close()

    readonly property real itemHeight: 40
    readonly property real separatorHeight: 13
    readonly property real menuPadding: 6

    // [{ label, icon, onTrigger }] — or { separator: true } for a divider.
    readonly property var actions: [
        {
            label: "Lock",
            icon: Qt.resolvedUrl("../../icons/lock.svg"),
            onTrigger: () => Quickshell.execDetached(["loginctl", "lock-session"])
        },
        {
            label: "Sign out",
            icon: Qt.resolvedUrl("../../icons/logout.svg"),
            onTrigger: () => Quickshell.execDetached(["loginctl", "terminate-user", Quickshell.env("USER") || ""])
        },
        { separator: true },
        {
            label: "Sleep",
            icon: Qt.resolvedUrl("../../icons/sleep.svg"),
            onTrigger: () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            label: "Shut down",
            icon: Qt.resolvedUrl("../../icons/power.svg"),
            onTrigger: () => Quickshell.execDetached(["systemctl", "poweroff"])
        },
        {
            label: "Restart",
            icon: Qt.resolvedUrl("../../icons/restart.svg"),
            onTrigger: () => Quickshell.execDetached(["systemctl", "reboot"])
        }
    ]

    // Outside-click dismiss
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    // Clipping container: its top edge sits at the bottom of the bar so
    // anything above that line is cut off, producing the "tuck behind the
    // bar" slide. The bar (a separate layer-shell surface) keeps painting
    // normally over the clipped pixels.
    Item {
        id: slideClip
        anchors.fill: parent
        anchors.topMargin: Theme.barHeight
        clip: true

        Item {
            id: slideContent
            anchors.fill: parent
            transform: Translate { id: slideTransform; y: 0 }
        }

        NumberAnimation {
            id: slideInAnim
            target: slideTransform
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: slideTransform
            property: "y"
            to: root._hiddenOffset
            duration: 220
            easing.type: Easing.InCubic
            onFinished: root._renderVisible = false
        }

    Rectangle {
        id: panel
        parent: slideContent

        width: 200
        height: {
            var h = root.menuPadding * 2;
            for (var i = 0; i < root.actions.length; i++)
                h += root.actions[i].separator ? root.separatorHeight : root.itemHeight;
            return h;
        }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 8
        anchors.topMargin: 6

        color: Theme.dropdownBg
        radius: 8
        border.color: Theme.dropdownBorder
        border.width: 1

        // Soft drop shadow — same stacked-ring trick as the other panels.
        Repeater {
            parent: slideContent
            model: 6
            delegate: Rectangle {
                anchors.fill: panel
                anchors.leftMargin:   -(index + 1)
                anchors.rightMargin:  -(index + 1)
                anchors.topMargin:    0
                anchors.bottomMargin: -(index + 1) - 2
                z: -1 - index
                color: "transparent"
                radius: panel.radius + (index + 1)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.18 / (index + 1))
            }
        }

        // Eat inside-clicks so they don't reach the outside dismiss.
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
                    color: (!modelData.separator && hover.hovered) ? Theme.highlightBg : "transparent"

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
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            if (modelData.onTrigger) modelData.onTrigger();
                            root.close();
                        }
                    }

                    Row {
                        visible: !modelData.separator
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

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
    }
}
