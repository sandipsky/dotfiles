import QtQuick
import "../../../styles"

Rectangle {
    id: root

    property string iconSource: ""
    property string label: ""
    property bool active: false
    property bool showChevron: true

    signal clicked()

    height: 44
    radius: height / 2
    color: active ? Theme.barAccent : Theme.dropdownBg

    HoverHandler { id: hover }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    // Subtle hover lift — slight tint when not pressed.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hover.hovered ? "#ffffff" : "transparent"
        opacity: 0.06
    }

    Image {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: source.toString().length > 0
    }

    Text {
        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible ? 12 : 16
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 20
        font.weight: Font.Light
        visible: root.showChevron
    }
}
