import QtQuick
import Quickshell
import "../../../styles"

Item {
    id: root

    property string filter: ""
    property int selectedIndex: 0
    // PinnedApps service from shell.qml; null-safe so AppList still
    // renders in isolation (e.g. previews).
    property var pinned: null
    signal appLaunched()

    readonly property var entries: {
        var all = DesktopEntries.applications.values;
        var q = filter.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < all.length; ++i) {
            var e = all[i];
            if (e.noDisplay) continue;
            if (q !== "") {
                var hay = (e.name || "") + " " +
                          (e.genericName || "") + " " +
                          (e.comment || "") + " " +
                          ((e.keywords || []).join(" "));
                if (hay.toLowerCase().indexOf(q) === -1) continue;
            }
            out.push(e);
        }
        out.sort(function (a, b) {
            return (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" });
        });
        return out;
    }

    onFilterChanged: {
        flick.targetY = 0;
        scrollAnim.enabled = false;
        flick.contentY = 0;
        selectedIndex = 0;
    }

    function launch(entry) {
        if (entry && entry.execute) {
            entry.execute();
            root.appLaunched();
        }
    }

    function moveSelection(delta) {
        var n = entries.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        ensureSelectedVisible();
    }

    function launchSelected() {
        if (entries.length === 0) return;
        var i = Math.max(0, Math.min(entries.length - 1, selectedIndex));
        launch(entries[i]);
    }

    function ensureSelectedVisible() {
        var item = repeater.itemAt(selectedIndex);
        if (!item) return;
        var top = item.y;
        var bottom = top + item.height;
        var newY = flick.contentY;
        if (top < flick.contentY) {
            newY = top;
        } else if (bottom > flick.contentY + flick.height) {
            newY = bottom - flick.height;
        } else {
            return;
        }
        scrollAnim.enabled = true;
        flick.contentY = newY;
        flick.targetY = newY;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: list.height
        clip: true
        // Must stay true for touchpad 2-finger gesture scrolling to work
        // (Wayland routes touchpad scroll through the Flickable's input
        // path as touch/drag events, not wheel events).
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 4000
        pressDelay: 0

        property real targetY: 0
        Behavior on contentY {
            id: scrollAnim
            enabled: false
            NumberAnimation { duration: 480; easing.type: Easing.OutQuart }
        }

        // Touchpad sensitivity boost: Flickable tracks drag input 1:1, so to
        // make 2-finger touchpad gestures scroll further per finger movement
        // we add an extra delta on every contentY change that came from a
        // user drag. inAmplify guards against re-entry.
        readonly property real touchpadBoost: 2.4
        property bool inAmplify: false
        property real lastDragY: 0
        onDraggingChanged: if (dragging) lastDragY = contentY
        onContentYChanged: {
            if (inAmplify || !dragging) return;
            var delta = contentY - lastDragY;
            if (delta === 0) return;
            inAmplify = true;
            var maxY = Math.max(0, contentHeight - height);
            contentY = Math.max(0, Math.min(maxY, contentY + delta * touchpadBoost));
            lastDragY = contentY;
            inAmplify = false;
        }

        WheelHandler {
            target: null
            onWheel: (event) => {
                var dy = 0;
                // Touchpad 2-finger / hi-res wheel: pixel-precise deltas.
                // Track them 1:1 (no easing fight, follows the fingers),
                // with a small multiplier for snappier feel.
                if (event.pixelDelta && event.pixelDelta.y !== 0) {
                    // Match the touchpad drag amplification (1 + touchpadBoost).
                    dy = -event.pixelDelta.y * (1 + flick.touchpadBoost);
                    scrollAnim.enabled = false;
                } else if (event.angleDelta.y !== 0) {
                    // Discrete mouse wheel notches → stepped + animated.
                    // Natural ~140 px line × (1 + touchpadBoost) so each notch
                    // covers a bit more than an amplified touchpad gesture,
                    // since the wheel only ticks discretely.
                    var step = 140 * (1 + flick.touchpadBoost);
                    dy = -event.angleDelta.y / 120 * step;
                    scrollAnim.enabled = true;
                } else {
                    return;
                }
                var maxY = Math.max(0, flick.contentHeight - flick.height);
                flick.targetY = Math.max(0, Math.min(maxY, flick.targetY + dy));
                flick.contentY = flick.targetY;
                event.accepted = true;
            }
        }
        onMovementEnded: {
            scrollAnim.enabled = false;
            targetY = contentY;
        }

        Column {
            id: list
            width: flick.width
            spacing: 0

            Item {
                width: list.width
                height: 80
                visible: root.entries.length === 0
                Text {
                    anchors.centerIn: parent
                    text: root.filter.length > 0 ? "No results" : "No applications found"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                }
            }

            Repeater {
                id: repeater
                model: root.entries
                delegate: Column {
                    width: list.width
                    spacing: 0

                    readonly property string firstChar: {
                        var n = (modelData.name || "?").charAt(0).toUpperCase();
                        return /[A-Z]/.test(n) ? n : "#";
                    }
                    readonly property bool showSection: {
                        if (root.filter.length > 0) return false;
                        if (index === 0) return true;
                        var prev = root.entries[index - 1];
                        var p = (prev.name || "?").charAt(0).toUpperCase();
                        if (!/[A-Z]/.test(p)) p = "#";
                        return p !== firstChar;
                    }
                    readonly property bool isHighlighted: index === root.selectedIndex

                    Item {
                        width: list.width
                        height: showSection ? 28 : 0
                        visible: showSection

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: firstChar
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        width: list.width
                        height: 52
                        radius: 6
                        color: hover.hovered
                            ? Theme.hoverBg
                            : (isHighlighted ? Theme.highlightBg : "transparent")

                        HoverHandler { id: hover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.launch(modelData)
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: (ep) => {
                                var p = mapToItem(root, ep.position.x, ep.position.y);
                                contextMenu.showAt(p.x, p.y, modelData.id);
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                sourceSize.width: 56
                                sourceSize.height: 56
                                source: Quickshell.iconPath(modelData.icon || "", "application-x-executable")
                                smooth: true
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: modelData.name || modelData.id || ""
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.styleName: Theme.fontStyle
                                    font.pixelSize: 16
                                }
                                Text {
                                    text: modelData.genericName || ""
                                    visible: text.length > 0 && text !== (modelData.name || "")
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.styleName: Theme.fontStyle
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    // Click-anywhere-else inside AppList closes the context menu.
    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 999
        onPressed: (m) => { contextMenu.visible = false; m.accepted = true; }
    }

    // Right-click "Pin to taskbar / Unpin from taskbar" popup. Positioned
    // at the click point in AppList-local coordinates by showAt().
    Rectangle {
        id: contextMenu
        visible: false
        z: 1000

        property string targetId: ""
        property bool targetPinned: false

        width: 180
        height: 40
        color: Theme.dropdownBg
        border.color: Theme.dropdownBorder
        border.width: 1
        radius: 8

        function showAt(localX, localY, id) {
            targetId = id;
            targetPinned = root.pinned ? root.pinned.isPinned(id) : false;
            x = Math.max(0, Math.min(localX, root.width - width));
            y = Math.max(0, Math.min(localY, root.height - height));
            visible = true;
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 4
            color: itemHover.hovered ? Theme.hoverBg : "transparent"
            HoverHandler { id: itemHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: {
                    if (root.pinned) {
                        if (contextMenu.targetPinned) root.pinned.unpin(contextMenu.targetId);
                        else root.pinned.pin(contextMenu.targetId);
                    }
                    contextMenu.visible = false;
                }
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: contextMenu.targetPinned ? "Unpin from taskbar" : "Pin to taskbar"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyle
                font.pixelSize: 14
            }
        }
    }

    // Interactive scrollbar: drag the thumb or click anywhere on the
    // track to jump. Width expands on hover for an easier grab target.
    Item {
        id: scrollbar
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: scrollHover.hovered || scrollArea.pressed ? 12 : 6
        visible: flick.contentHeight > flick.height

        Behavior on width { NumberAnimation { duration: 120 } }

        HoverHandler { id: scrollHover }

        Item {
            id: track
            anchors.fill: parent
        }

        MouseArea {
            id: scrollArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            preventStealing: true

            property real grabOffset: 0

            function moveTo(localY) {
                var maxThumbY = Math.max(0, track.height - thumb.height);
                var maxContentY = Math.max(0, flick.contentHeight - flick.height);
                if (maxThumbY <= 0 || maxContentY <= 0) return;
                var newThumbY = Math.max(0, Math.min(maxThumbY, localY - grabOffset));
                var newContentY = (newThumbY / maxThumbY) * maxContentY;
                scrollAnim.enabled = false;
                flick.contentY = newContentY;
                flick.targetY = newContentY;
            }

            onPressed: (mouse) => {
                if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                    grabOffset = mouse.y - thumb.y;
                } else {
                    grabOffset = thumb.height / 2;
                    moveTo(mouse.y);
                }
            }
            onPositionChanged: (mouse) => {
                if (pressed) moveTo(mouse.y);
            }
        }

        Rectangle {
            id: thumb
            x: 2
            width: Math.max(0, scrollbar.width - 4)
            radius: width / 2
            color: scrollHover.hovered || scrollArea.pressed
                ? "#6a6a6a"
                : Theme.startmenuSearchBorder

            readonly property real maxContentY: Math.max(1, flick.contentHeight - flick.height)
            y: (flick.contentY / maxContentY) * (track.height - height)
            height: Math.max(30, track.height * Math.min(1, flick.height / flick.contentHeight))
        }
    }
}
