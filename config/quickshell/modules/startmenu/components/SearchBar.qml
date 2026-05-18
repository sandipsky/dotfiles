import QtQuick
import QtQuick.Controls
import Quickshell
import "../../../styles"

Rectangle {
    id: root

    property alias text: input.text

    signal accepted()
    signal escapePressed()

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

    TextField {
        id: input
        anchors.left: searchIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 4

        background: Item {}
        color: Theme.textPrimary
        placeholderText: "Search for apps"
        placeholderTextColor: Theme.startmenuSearchPlaceholder
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 16
        selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        focus: true

        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
    }

    Component.onCompleted: input.forceActiveFocus()
}
