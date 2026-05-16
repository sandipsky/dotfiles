import QtQuick
import Quickshell
import "../../../styles"

Item {
    id: root

    property string query: ""
    property int selectedIndex: 0
    signal activated(var item)

    readonly property var items: buildItems(query)

    function buildItems(q) {
        var out = [];
        q = (q || "").trim();
        if (q === "") return out;

        // 1) Calculator — only if expression contains a math operator
        var calc = tryCalculate(q);
        if (calc !== null) {
            out.push({
                type:     "calc",
                title:    "= " + calc,
                subtitle: q,
                result:   String(calc)
            });
        }

        // 2) App matches — substring against name + genericName + comment
        var all = DesktopEntries.applications.values;
        var qLow = q.toLowerCase();
        var apps = [];
        for (var i = 0; i < all.length; ++i) {
            var e = all[i];
            if (e.noDisplay) continue;
            var hay = (e.name || "") + " " +
                      (e.genericName || "") + " " +
                      (e.comment || "") + " " +
                      ((e.keywords || []).join(" "));
            if (hay.toLowerCase().indexOf(qLow) === -1) continue;
            apps.push({
                type:     "app",
                title:    e.name,
                subtitle: e.genericName || e.comment || "",
                icon:     e.icon || "",
                entry:    e
            });
        }
        apps.sort(function (a, b) {
            // Prefer names that start with the query
            var as = a.title.toLowerCase().indexOf(qLow) === 0 ? 0 : 1;
            var bs = b.title.toLowerCase().indexOf(qLow) === 0 ? 0 : 1;
            if (as !== bs) return as - bs;
            return a.title.localeCompare(b.title, undefined, { sensitivity: "base" });
        });
        for (var j = 0; j < Math.min(apps.length, 6); ++j) out.push(apps[j]);

        // 3) Google search — always at the end as a fallback action
        out.push({
            type:     "google",
            title:    "Search Google for \"" + q + "\"",
            subtitle: "Open in browser",
            query:    q
        });

        return out;
    }

    function tryCalculate(text) {
        var t = text.trim();
        // Must look like a math expression and contain an operator
        if (!/^[\d\s+\-*/().%^]+$/.test(t)) return null;
        if (!/[+\-*/^%]/.test(t)) return null;
        try {
            var expr = t.replace(/\^/g, "**");
            var result = Function('"use strict"; return (' + expr + ');')();
            if (typeof result !== "number" || !isFinite(result)) return null;
            // Trim FP noise
            return Math.round(result * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    function moveSelection(delta) {
        if (items.length === 0) return;
        var n = items.length;
        selectedIndex = ((selectedIndex + delta) % n + n) % n;
        ensureSelectedVisible();
    }

    function ensureSelectedVisible() {
        var rowH = 56;
        var top = selectedIndex * rowH;
        var bot = top + rowH;
        if (top < flick.contentY) {
            flick.contentY = top;
            flick.targetY = top;
        } else if (bot > flick.contentY + flick.height) {
            flick.contentY = bot - flick.height;
            flick.targetY = flick.contentY;
        }
    }

    onItemsChanged: {
        if (selectedIndex >= items.length) selectedIndex = 0;
    }

    // Height fits content but caps so the launcher doesn't get huge.
    height: Math.min(items.length * 56 + 12, 400)

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 6
        contentWidth: width
        contentHeight: list.height
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 4000

        property real targetY: 0
        Behavior on contentY {
            id: scrollAnim
            enabled: false
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        WheelHandler {
            target: null
            onWheel: (event) => {
                var dy = 0;
                if (event.pixelDelta && event.pixelDelta.y !== 0) {
                    dy = -event.pixelDelta.y;
                    scrollAnim.enabled = false;
                } else if (event.angleDelta.y !== 0) {
                    dy = -event.angleDelta.y / 120 * 80;
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

            Repeater {
                model: root.items
                delegate: ResultItem {
                    width: list.width
                    height: 56
                    item: modelData
                    isSelected: index === root.selectedIndex
                    onActivated: root.activated(modelData)
                    onHovered: root.selectedIndex = index
                }
            }
        }
    }

    // Scrollbar — same design as startmenu's
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
