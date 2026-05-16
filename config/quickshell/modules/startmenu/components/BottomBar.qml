import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root
    color: Theme.startmenuUserBg

    // Match the container's bottom-corner radius so the menu's
    // outline curves cleanly along the user bar. Qt 6.7+ per-corner radii.
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: Theme.menuRadius
    bottomRightRadius: Theme.menuRadius

    signal toggleUserMenu()
    signal togglePowerMenu()

    // ---- User button (left) ----
    Rectangle {
        id: userBtn
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 48
        width: userRow.implicitWidth + 24
        radius: 6
        color: userHover.hovered ? Theme.hoverBg : "transparent"

        HoverHandler { id: userHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.toggleUserMenu()
        }

        Row {
            id: userRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: "#444"
                clip: true

                Image {
                    anchors.fill: parent
                    source: Quickshell.iconPath("avatar-default", "user-info")
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sandip Shakya"
                color: Theme.textPrimary
                font.pixelSize: 13
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
        color: powerHover.hovered ? Theme.hoverBg : "transparent"

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
