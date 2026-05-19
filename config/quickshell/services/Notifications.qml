import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Replaces dunst as the org.freedesktop.Notifications DBus daemon. Holds
// the on-screen popup queue; the actual rendering lives in
// modules/notifications/NotificationPopup.qml, which binds to `popups`.
QtObject {
    id: root

    // Notifications currently visible as popups. Newest last so the
    // bottom-right stack grows upward (newest closest to the bar).
    property var popups: []

    // Mirrors dunst's `notification_limit = 5`.
    readonly property int maxPopups: 5

    // Timeouts (ms) by urgency when the sender doesn't request one of its
    // own. Critical never auto-expires, matching the existing dunstrc.
    function timeoutForUrgency(u) {
        switch (u) {
            case NotificationUrgency.Low:      return 3000;
            case NotificationUrgency.Critical: return 0;
            default:                            return 8000;
        }
    }

    function dismissAll() {
        var arr = root.popups.slice();
        root.popups = [];
        for (var i = 0; i < arr.length; ++i) arr[i].dismiss();
    }

    function _add(notif) {
        // Keep the C++ Notification alive past the sender's lifetime so we
        // can show it for the full timeout and respond to actions.
        notif.tracked = true;

        var arr = root.popups.slice();
        arr.push(notif);
        while (arr.length > root.maxPopups) {
            var old = arr.shift();
            old.dismiss();
        }
        root.popups = arr;
    }

    function _remove(notif) {
        var arr = root.popups.slice();
        var i = arr.indexOf(notif);
        if (i === -1) return;
        arr.splice(i, 1);
        root.popups = arr;
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: false

        onNotification: (n) => {
            n.closed.connect(function (reason) { root._remove(n); });
            root._add(n);
        }
    }
}
