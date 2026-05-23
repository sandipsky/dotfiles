import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../../../styles"

// One notification popup card. Owns its own expire timer so the popup
// window doesn't need to know per-card timing. Mirrors dunst's layout
// (icon left, app+summary+body right, action buttons below).
Rectangle {
    id: root

    // The Quickshell Notification this card is bound to. The popup window
    // sets this when constructing the delegate.
    property var notification

    readonly property int urgency: notification ? notification.urgency : 1
    readonly property bool isCritical: urgency === NotificationUrgency.Critical

    // Effective timeout (ms). Honour the sender's request if it set one,
    // else fall back to our per-urgency default. expireTimeout is in ms
    // already; -1 means "no preference" per the spec.
    readonly property int effectiveTimeout: {
        if (!notification) return 0;
        var t = notification.expireTimeout;
        if (t === undefined || t === null || t < 0) {
            return defaultTimeoutForUrgency(urgency);
        }
        if (t === 0) return 0;
        return t;
    }

    function defaultTimeoutForUrgency(u) {
        if (u === NotificationUrgency.Low)      return 3000;
        if (u === NotificationUrgency.Critical) return 0;
        return 8000;
    }

    width: 350
    height: layout.implicitHeight + 24
    radius: 10
    color: Theme.notificationBg
    border.color: isCritical ? Theme.notificationCriticalBorder : Theme.notificationBorder
    border.width: 2

    Timer {
        id: expireTimer
        interval: root.effectiveTimeout
        running: !hover.hovered && root.effectiveTimeout > 0 && root.notification !== null
        repeat: false
        onTriggered: if (root.notification) root.notification.expire()
    }

    HoverHandler { id: hover }

    // left_click → close current (dunst parity).
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: if (root.notification) root.notification.dismiss()
    }
    // middle_click → invoke default action + close.
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (!root.notification) return;
            var actions = root.notification.actions || [];
            for (var i = 0; i < actions.length; ++i) {
                if (actions[i].identifier === "default") { actions[i].invoke(); break; }
            }
            root.notification.dismiss();
        }
    }
    // right_click → close all (handled by parent via signal).
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.dismissAllRequested()
    }

    signal dismissAllRequested()

    // Close button (top-right). Sits above the row layout so it's always
    // visible, and gets its own narrow rightMargin reserved by the layout.
    Rectangle {
        id: closeBtn
        z: 1
        width: 22
        height: 22
        radius: 11
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        color: closeHover.hovered ? Theme.hoverBg : "transparent"

        HoverHandler { id: closeHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: if (root.notification) root.notification.dismiss()
        }

        Text {
            anchors.centerIn: parent
            text: "✕"  // ✕
            color: Theme.notificationText
            opacity: closeHover.hovered ? 1.0 : 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 20
        // Reserve room for the close button so summary/body don't run under it.
        anchors.rightMargin: 36
        anchors.topMargin: 12
        spacing: 14

        // Icon: prefer the inline image hint, then the desktop entry icon,
        // then fall back to the appIcon string (also a freedesktop name).
        // If none of those yields a usable image — or the image is the
        // tiny magenta/black "missing texture" placeholder some apps emit
        // (notably blueman's battery notifications) — we render a generic
        // bell glyph instead.
        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54

            // Temporary: log what the daemon hands us so we can pinpoint
            // which field is producing the magenta/black checkerboard.
            Component.onCompleted: {
                if (!root.notification) return;
                var n = root.notification;
                console.log("[notif-icon] app=" + n.appName
                    + " appIcon=" + JSON.stringify(n.appIcon)
                    + " desktopEntry=" + JSON.stringify(n.desktopEntry)
                    + " image=" + JSON.stringify(n.image)
                    + " resolved=" + JSON.stringify(notifIcon.source.toString())
                    + " size=" + notifIcon.sourceSize.width + "x" + notifIcon.sourceSize.height
                    + " status=" + notifIcon.status);
            }

            Image {
                id: notifIcon
                anchors.fill: parent
                sourceSize.width: 108
                sourceSize.height: 108
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
                // We deliberately ignore `notification.image` (the inline
                // pixmap hint). Some apps — notably blueman's battery
                // notifications — pack a magenta/black "missing texture"
                // checkerboard into that hint, and there's no reliable way
                // to tell it apart from a legitimate inline icon. The
                // theme-resolved appIcon / desktopEntry name is much more
                // dependable; if neither resolves we fall through to the
                // bell glyph below.
                source: {
                    if (!root.notification) return "";
                    var name = root.notification.appIcon || root.notification.desktopEntry || "";
                    if (name.length === 0) return "";
                    return Quickshell.iconPath(name, "");
                }
                readonly property bool looksValid: status === Image.Ready
                    && sourceSize.width >= 24 && sourceSize.height >= 24
                visible: looksValid
            }

            Text {
                anchors.centerIn: parent
                visible: !notifIcon.looksValid
                // Font Awesome 7 Free Solid: fa-bell (U+F0F3) — generic
                // fallback for notifications that don't supply a usable icon.
                text: ""
                color: Theme.notificationText
                opacity: 0.7
                font.family: "Font Awesome 7 Free"
                font.styleName: "Solid"
                font.pixelSize: 34
                renderType: Text.NativeRendering
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            Text {
                visible: text.length > 0
                Layout.fillWidth: true
                text: root.notification ? (root.notification.appName || "") : ""
                color: Theme.notificationText
                opacity: 0.7
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 15
            }
            Text {
                visible: text.length > 0
                Layout.fillWidth: true
                text: root.notification ? (root.notification.summary || "") : ""
                color: Theme.notificationText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.styleName: "DemiBold"
                font.pixelSize: 18
            }
            Text {
                visible: text.length > 0
                Layout.fillWidth: true
                text: root.notification ? (root.notification.body || "") : ""
                color: Theme.notificationText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 6
                textFormat: Text.RichText
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 16
                onLinkActivated: (url) => Quickshell.execDetached(["xdg-open", url])
            }

            // Per-notification action buttons (skip the implicit "default"
            // action — that's the click-to-activate behaviour).
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: actionRepeater.count > 0 ? 8 : 0
                spacing: 6
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: root.notification && root.notification.actions
                        ? root.notification.actions.filter(a => a.identifier !== "default")
                        : []
                    delegate: Rectangle {
                        required property var modelData
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: actionLabel.implicitWidth + 20
                        radius: 6
                        color: btnHover.hovered ? Theme.hoverBg : Theme.dropdownBg
                        border.color: Theme.notificationBorder
                        border.width: 1

                        HoverHandler { id: btnHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                modelData.invoke();
                                if (root.notification) root.notification.dismiss();
                            }
                        }
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text || modelData.identifier
                            color: Theme.notificationText
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 16
                        }
                    }
                }
            }
        }
    }
}
