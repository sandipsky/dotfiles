import QtQuick
import Quickshell
import "../../../styles"

Rectangle {
    id: root

    property alias text: input.text

    signal accepted()
    signal escapePressed()
    signal upPressed()
    signal downPressed()

    function focusInput() { input.forceActiveFocus(); }
    function clear()       { input.text = ""; }

    color: Theme.startmenuSearchInputBg
    radius: height / 2
    border.color:  Theme.startmenuSearchBorder
    border.width: 1

    Image {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        sourceSize.width: 32
        sourceSize.height: 32
        source: Qt.resolvedUrl("../../../icons/search.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    TextInput {
        id: input
        anchors.left: searchIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 4

        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 16
        selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        focus: true
        clip: true

        // Intercept Up/Down BEFORE TextInput's cursor-movement consumes them.
        Keys.priority: Keys.BeforeItem
        Keys.onUpPressed: (event) => { root.upPressed(); event.accepted = true; }
        Keys.onDownPressed: (event) => { root.downPressed(); event.accepted = true; }
        Keys.onEscapePressed: root.escapePressed()
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: "Search for apps"
            color: Theme.startmenuSearchPlaceholder
            font: input.font
            visible: input.text.length === 0
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
