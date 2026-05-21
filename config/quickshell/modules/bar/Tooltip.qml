import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../styles"

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

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Confine input to the bubble only — the rest of this fullscreen
    // overlay is click-through, so hovering an indicator (or anything else)
    // never has its click swallowed by the tooltip surface.
    mask: Region { item: bubble }

    property string text: ""
    property real anchorX: 0
    property bool open: false

    // The indicator that currently "owns" the tooltip. Used to resolve the
    // ambiguous event order when the cursor crosses from one indicator to
    // another: the entering indicator's show() may fire before OR after
    // the leaving one's hide(). Tracking ownership makes hide() ignored
    // when a different source already took over.
    property var owner: null

    visible: open && text.length > 0

    function show(t, x, src) {
        owner = src || null;
        text = t;
        anchorX = x;
        open = true;
    }
    function hide(src) {
        if (src !== undefined && src !== owner) return;
        owner = null;
        open = false;
    }

    Rectangle {
        id: bubble
        x: Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        y: parent.height - height - Theme.barHeight - 8

        width: label.implicitWidth + 20
        height: label.implicitHeight + 14

        color: Theme.dropdownBg
        radius: 6
        border.color: Theme.dropdownBorder
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyle
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.2
        }
    }
}
