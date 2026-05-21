import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root
    color: Theme.startmenuUserBg
    // Shape is handled by the parent ClippingRectangle (menu).

    signal toggleUserMenu()
    signal togglePowerMenu()

    // Driven by StartMenu so the button keeps the hover-bg highlight
    // while its dropdown is open.
    property bool userActive: false
    property bool powerActive: false

    // ---- User button (left) ----
    Rectangle {
        id: userBtn
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 48
        // Auto-fit the hover area to the avatar + name + side padding.
        width: userRow.implicitWidth + 20
        radius: 6
        color: (userHover.hovered || root.userActive) ? Theme.hoverBg : "transparent"

        HoverHandler { id: userHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.toggleUserMenu()
        }

        Row {
            id: userRow
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: "#444"
                clip: true

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    sourceSize.width: 64
                    sourceSize.height: 64
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready
                    asynchronous: true
                }

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    sourceSize.width: 40
                    sourceSize.height: 40
                    source: Qt.resolvedUrl("../../../icons/user.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: avatarImg.status !== Image.Ready
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sandip Shakya"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: "Bold"
                font.pixelSize: 16
            }
        }
    }

    // ---- Power button (right) ----
    Rectangle {
        id: powerBtn
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 6
        color: (powerHover.hovered || root.powerActive) ? Theme.hoverBg : "transparent"

        HoverHandler { id: powerHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.togglePowerMenu()
        }

        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize.width: 36
            sourceSize.height: 36
            source: Qt.resolvedUrl("../../../icons/power.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }
}
