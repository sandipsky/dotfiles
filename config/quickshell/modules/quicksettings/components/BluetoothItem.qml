import QtQuick
import "../../../styles"

Item {
    id: root

    property string mac: ""
    property string name: ""
    property string iconName: ""   // bluez icon hint (audio-headset, input-mouse, ...)
    property bool paired: false
    property bool connected: false
    property bool busy: false      // optimistic "connecting…" / "disconnecting…"

    signal connectClicked()
    signal disconnectClicked()
    signal pairClicked()
    signal unpairClicked()

    height: 56

    // Font Awesome 7 Brands: fa-bluetooth (U+F293). Single glyph regardless
    // of the bluez icon hint — the Segoe Fluent fallbacks we used before
    // weren't rendering on this system, so the icon box looked empty.
    readonly property string deviceGlyph: ""

    Rectangle {
        id: rowBg
        anchors.fill: parent
        color: rowHover.hovered ? Theme.hoverBg : "transparent"
        radius: 6

        HoverHandler { id: rowHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                if (root.busy || root.connected) return;
                if (root.paired) root.connectClicked();
                else             root.pairClicked();
            }
        }
    }

    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32

        Text {
            anchors.centerIn: parent
            text: root.deviceGlyph
            color: Theme.textPrimary
            font.family: "Font Awesome 7 Brands"
            font.pixelSize: 20
            renderType: Text.NativeRendering
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 12
        anchors.right: rightArea.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            text: root.name.length > 0 ? root.name : root.mac
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyle
            font.pixelSize: 16
            font.weight: root.connected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: parent.width
        }
        Text {
            text: root.busy ? "Working…"
                            : (root.connected ? "Connected"
                                              : (root.paired ? "Paired" : "Not paired"))
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyle
            font.pixelSize: 12
            visible: text.length > 0
        }
    }

    Row {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Small "Unpair" link, only shown when the device is paired (i.e.
        // we have something to remove). Sits to the left of the primary
        // button so the main action stays on the right.
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: root.paired
            visible: active
            sourceComponent: unpairLink
        }

        // Primary action button: Pair (unpaired) → Connect (paired) → Disconnect (connected).
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: !root.paired ? pairButton
                           : (root.connected ? disconnectButton : connectButton)
        }
    }

    Component {
        id: pairButton
        Rectangle {
            width: pairText.implicitWidth + 22
            height: 28
            radius: 14
            color: pairHover.hovered ? Theme.barAccent : Theme.dropdownBg
            border.color: Theme.barAccent
            border.width: 1
            opacity: root.busy ? 0.5 : 1.0

            HoverHandler { id: pairHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (!root.busy) root.pairClicked()
            }

            Text {
                id: pairText
                anchors.centerIn: parent
                text: "Pair"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 14
            }
        }
    }

    Component {
        id: connectButton
        Rectangle {
            width: btnText.implicitWidth + 22
            height: 28
            radius: 14
            color: btnHover.hovered ? Theme.barAccent : Theme.dropdownBg
            border.color: Theme.barAccent
            border.width: 1
            opacity: root.busy ? 0.5 : 1.0

            HoverHandler { id: btnHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (!root.busy) root.connectClicked()
            }

            Text {
                id: btnText
                anchors.centerIn: parent
                text: "Connect"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 14
            }
        }
    }

    Component {
        id: disconnectButton
        Rectangle {
            width: discText.implicitWidth + 22
            height: 28
            radius: 14
            color: discHover.hovered ? Theme.hoverBg : "transparent"
            border.color: Theme.calendarBorder
            border.width: 1
            opacity: root.busy ? 0.5 : 1.0

            HoverHandler { id: discHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (!root.busy) root.disconnectClicked()
            }

            Text {
                id: discText
                anchors.centerIn: parent
                text: "Disconnect"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 14
            }
        }
    }

    // Borderless text link — secondary "Forget device" action.
    Component {
        id: unpairLink
        Item {
            width: unpairText.implicitWidth + 8
            height: 28
            opacity: root.busy ? 0.5 : 1.0

            HoverHandler { id: unpairHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: if (!root.busy) root.unpairClicked()
            }

            Text {
                id: unpairText
                anchors.centerIn: parent
                text: "Unpair"
                color: unpairHover.hovered ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 13
                font.underline: unpairHover.hovered
            }
        }
    }
}
