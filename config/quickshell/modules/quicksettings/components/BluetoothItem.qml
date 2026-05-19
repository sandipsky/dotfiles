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

    height: 56

    function glyph() {
        // Map bluez icon hints to Segoe Fluent Icons glyphs.
        if (iconName.indexOf("audio-headset") === 0)   return "";   // Headset (MDL2)
        if (iconName.indexOf("audio-headphones") === 0)return "";   // Headphone
        if (iconName.indexOf("audio-card") === 0)      return "";   // Speakers
        if (iconName.indexOf("input-keyboard") === 0)  return "";   // KeyboardClassic
        if (iconName.indexOf("input-mouse") === 0)     return "";   // Mouse
        if (iconName.indexOf("input-gaming") === 0)    return "";   // Gamepad / GameController
        if (iconName.indexOf("phone") === 0)           return "";   // CellPhone
        if (iconName.indexOf("computer") === 0)        return "";   // Devices2
        return "";                                                   // Bluetooth fallback
    }

    Rectangle {
        id: rowBg
        anchors.fill: parent
        color: rowHover.hovered ? Theme.hoverBg : "transparent"
        radius: 6

        HoverHandler { id: rowHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                if (!root.connected && !root.busy) root.connectClicked();
            }
        }
    }

    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32

        Text {
            anchors.centerIn: parent
            text: root.glyph()
            color: Theme.textPrimary
            font.family: "Segoe Fluent Icons"
            font.pixelSize: 22
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

    Item {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 56
        width: rightContent.implicitWidth

        Loader {
            id: rightContent
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            sourceComponent: root.connected ? disconnectButton : connectButton
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
    }
}
