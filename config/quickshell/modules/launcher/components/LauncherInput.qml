import QtQuick
import QtQuick.Controls
import "../../../styles"

Rectangle {
    id: root

    property alias text: input.text

    signal accepted()
    signal escapePressed()
    signal upRequested()
    signal downRequested()

    color: "transparent"

    Image {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        sourceSize.width: 44
        sourceSize.height: 44
        source: Qt.resolvedUrl("../../../icons/search.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    TextField {
        id: input
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 4

        background: Item {}
        color: Theme.textPrimary
        placeholderText: "Search..."
        placeholderTextColor: Theme.startmenuSearchPlaceholder
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyle
        font.pixelSize: 20
        selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        focus: true

        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
        Keys.onUpPressed: (event) => { root.upRequested(); event.accepted = true; }
        Keys.onDownPressed: (event) => { root.downRequested(); event.accepted = true; }
    }

    Component.onCompleted: input.forceActiveFocus()
}
