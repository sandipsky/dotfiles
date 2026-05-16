import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root

    property var item: null
    property bool isSelected: false

    signal activated()
    signal hovered()

    color: isSelected
        ? Theme.highlightBg
        : (hover.hovered ? Theme.hoverBg : "transparent")
    radius: 6

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) root.hovered()
    }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.activated()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        // Icon slot — app icon, calc "=", or google search glyph
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32

            Image {
                anchors.fill: parent
                visible: item && item.type === "app"
                source: item && item.type === "app"
                    ? Quickshell.iconPath(item.icon || "", "application-x-executable")
                    : ""
                sourceSize.width: 64
                sourceSize.height: 64
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            Image {
                anchors.fill: parent
                visible: item && item.type === "calc"
                source: Qt.resolvedUrl("../../../icons/calculator.svg")
                sourceSize.width: 64
                sourceSize.height: 64
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            Image {
                anchors.fill: parent
                visible: item && item.type === "google"
                source: Qt.resolvedUrl("../../../icons/web.svg")
                sourceSize.width: 64
                sourceSize.height: 64
                smooth: true
                fillMode: Image.PreserveAspectFit
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: item ? item.title : ""
                color: Theme.textPrimary
                font.pixelSize: 14
                elide: Text.ElideRight
                width: root.width - 70
            }
            Text {
                text: item ? (item.subtitle || "") : ""
                visible: text.length > 0
                color: Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
                width: root.width - 70
            }
        }
    }
}
