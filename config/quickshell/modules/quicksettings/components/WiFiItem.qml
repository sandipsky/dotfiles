import QtQuick
import "../../../styles"

Item {
    id: root

    property string ssid: ""
    property int signalStrength: 0
    property string security: ""
    property bool inUse: false
    property bool known: false
    property bool expanded: false

    signal connectClicked()
    signal submitClicked(string password)
    signal cancelClicked()

    readonly property bool secured: security.length > 0 && security !== "--"

    // 56 px when collapsed; expands to 56 + 84 = 140 px when the
    // password form is showing.
    height: expanded ? 140 : 56
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // Segoe Fluent Icons signal-strength glyphs: Wifi4 E701, Wifi3 E874,
    // Wifi2 E873, Wifi1 E872.
    function iconChar() {
        if (signalStrength >= 75) return "\uE701";
        if (signalStrength >= 50) return "\uE874";
        if (signalStrength >= 25) return "\uE873";
        return "\uE872";
    }

    // ---- Row backdrop (hover + faint divider) ----
    Rectangle {
        id: rowBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 56
        color: rowHover.hovered || root.expanded ? Theme.hoverBg : "transparent"
        radius: 6

        HoverHandler { id: rowHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                // Tapping the row itself = behave like Connect; the Connect
                // button on the right is just a more obvious affordance.
                if (!root.inUse) root.connectClicked();
            }
        }
    }

    // ---- Icon + SSID ----
    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        width: 32
        height: 56

        Text {
            anchors.centerIn: parent
            text: root.iconChar()
            color: Theme.textPrimary
            font.family: "Segoe Fluent Icons"
            font.pixelSize: 18
            renderType: Text.NativeRendering
        }

        // Small lock badge for secured networks
        Image {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 0
            anchors.bottomMargin: 12
            width: 11
            height: 11
            sourceSize.width: 22
            sourceSize.height: 22
            source: Qt.resolvedUrl("../../../icons/lock.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: root.secured
        }
    }

    Text {
        anchors.left: iconBox.right
        anchors.leftMargin: 12
        anchors.right: rightArea.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        height: 56
        verticalAlignment: Text.AlignVCenter
        text: root.ssid
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 13
        font.weight: root.inUse ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }

    // ---- Right side: Connect button OR "Connected" label ----
    Item {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        height: 56
        width: rightContent.implicitWidth

        Loader {
            id: rightContent
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            sourceComponent: root.inUse ? connectedLabel
                              : (root.expanded ? cancelButton : connectButton)
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

                HoverHandler { id: btnHover }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.connectClicked()
                }

                Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: "Connect"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 12
                }
            }
        }

        Component {
            id: cancelButton
            Rectangle {
                width: cancelText.implicitWidth + 22
                height: 28
                radius: 14
                color: cancelHover.hovered ? Theme.hoverBg : "transparent"
                border.color: Theme.calendarBorder
                border.width: 1

                HoverHandler { id: cancelHover }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.cancelClicked()
                }

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 12
                }
            }
        }

        Component {
            id: connectedLabel
            Text {
                text: "Connected"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 12
            }
        }
    }

    // ---- Expanded area: password input + submit button ----
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rowBg.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56          // align under SSID label
        anchors.rightMargin: 12
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            id: pwLabel
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 2
            text: "Enter the password"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyle
            font.pixelSize: 12
        }

        Rectangle {
            id: pwField
            anchors.left: parent.left
            anchors.right: connectBtn.left
            anchors.rightMargin: 10
            anchors.top: pwLabel.bottom
            anchors.topMargin: 6
            height: 32
            color: Theme.startmenuSearchInputBg
            radius: 4

            TextInput {
                id: pwInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 13
                color: Theme.textPrimary
                clip: true
                selectByMouse: true
                echoMode: TextInput.Password
                passwordCharacter: "●"
                focus: root.expanded
                onAccepted: root.submitClicked(pwInput.text)
                Keys.onEscapePressed: root.cancelClicked()
            }

            // Blue underline accent
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: pwInput.activeFocus ? 2 : 1
                color: pwInput.activeFocus ? Theme.barAccent : Theme.calendarBorder
            }
        }

        Rectangle {
            id: connectBtn
            anchors.right: parent.right
            anchors.verticalCenter: pwField.verticalCenter
            width: connectBtnText.implicitWidth + 24
            height: 30
            radius: 15
            color: connectBtnHover.hovered ? Qt.lighter(Theme.barAccent, 1.1) : Theme.barAccent

            HoverHandler { id: connectBtnHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: root.submitClicked(pwInput.text)
            }

            Text {
                id: connectBtnText
                anchors.centerIn: parent
                text: "Connect"
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    // Clear the field when collapsing so the next attempt starts blank.
    onExpandedChanged: if (!expanded) pwInput.text = ""
}
