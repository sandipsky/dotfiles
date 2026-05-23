import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../styles"
import "components"

PanelWindow {
    id: root

    screen: Quickshell.screens[0]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Exclusive so the panel grabs keyboard input the moment it opens —
    // needed for Escape-to-close.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool open: false
    visible: open

    // Resolved at runtime so the home path doesn't need to be hardcoded.
    readonly property string wallpapersDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    readonly property string configPath:    (Quickshell.env("HOME") || "") + "/.config/wpaperd/config.toml"

    // Per-file entries: { path, name }
    property var entries: []

    // Current config state — populated by parsing the existing config.toml.
    property string currentPath: ""
    property string currentDuration: "10m"
    property string currentSorting: "ascending"
    property bool   slideshow: false

    // Editable slideshow interval, split into value + unit so the user has
    // a number field plus a unit dropdown rather than typing humantime.
    property int    intervalValue: 10
    property string intervalUnit: "m"
    readonly property var unitChoices: ["s", "m", "h"]

    // Transition style. "none" disables the transition by setting
    // transition_time = 0; any other name selects a wpaperd transition via
    // a `[default.transition.<name>]` section. Curated list — wpaperd
    // ships many more but these cover the popular looks.
    property string transitionName: "none"
    // Curated subset of wpaperd's transitions — only names that actually
    // appear in /usr/share/doc/wpaperd/README.md. Picking an unsupported
    // name fails the TOML parse and wpaperd falls back to a black screen.
    readonly property var transitionChoices: [
        "none", "fade", "circle", "circle-open", "directional",
        "dissolve", "pixelize", "ripple", "swirl",
        "linear-blur", "hexagonalize"
    ]

    function close() { open = false; }

    onOpenChanged: {
        if (open) {
            refresh();
        }
    }

    function refresh() {
        listProc.running = true;
        configProc.running = true;
    }

    // --- list wallpapers ---
    Process {
        id: listProc
        command: ["sh", "-c",
            "ls -1 \"" + root.wallpapersDir + "\" 2>/dev/null"
            + " | grep -Ei '\\.(png|jpe?g|webp|bmp|gif)$' | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; ++i) {
                    var name = lines[i].trim();
                    if (!name) continue;
                    out.push({
                        path: root.wallpapersDir + "/" + name,
                        name: name
                    });
                }
                root.entries = out;
            }
        }
    }

    // --- read current config ---
    Process {
        id: configProc
        command: ["cat", root.configPath]
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseConfig(text);
            }
        }
    }

    function _parseConfig(text) {
        var lines = text.split("\n");
        var path = "", duration = "10m", sorting = "ascending";
        var trans = "none", transTime = -1;
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line.indexOf("#") === 0) continue;
            var m;
            // Pick up the transition section name. wpaperd's syntax is
            // `[default.transition.<name>]` — anything else is fine to skip.
            m = line.match(/^\[default\.transition\.([a-z0-9_-]+)\]\s*$/);
            if (m) { trans = m[1]; continue; }
            m = line.match(/^transition-time\s*=\s*(\d+)\s*$/);
            if (m) { transTime = parseInt(m[1]); continue; }
            m = line.match(/^path\s*=\s*"(.*)"\s*$/);
            if (m) { path = m[1]; continue; }
            m = line.match(/^duration\s*=\s*"(.*)"\s*$/);
            if (m) { duration = m[1]; continue; }
            m = line.match(/^sorting\s*=\s*"(.*)"\s*$/);
            if (m) { sorting = m[1]; continue; }
        }
        // transition_time = 0 means we intentionally disabled it.
        if (transTime === 0) trans = "none";
        currentPath = path;
        currentDuration = duration;
        currentSorting = sorting;
        transitionName = trans;
        // Expand "~/" so we can compare against absolute paths from listProc.
        var expanded = path;
        if (expanded.indexOf("~/") === 0) {
            expanded = (Quickshell.env("HOME") || "") + expanded.substring(1);
        }
        // Slideshow on means path points at a directory rather than a file.
        slideshow = (expanded === wallpapersDir);
        // Parse duration into value + unit. Default to 10m if it doesn't
        // match our limited shape — wpaperd accepts richer formats but the
        // UI only exposes single-unit values.
        var dm = duration.match(/^(\d+)\s*(s|m|h|sec|min|hour|seconds|minutes|hours)?$/);
        if (dm) {
            intervalValue = parseInt(dm[1]);
            var u = (dm[2] || "m");
            if (u.indexOf("s") === 0) intervalUnit = "s";
            else if (u.indexOf("h") === 0) intervalUnit = "h";
            else intervalUnit = "m";
        }
    }

    function _expandedPath(p) {
        if (!p) return "";
        if (p.indexOf("~/") === 0) {
            return (Quickshell.env("HOME") || "") + p.substring(1);
        }
        return p;
    }

    // Writes a fresh config.toml and bounces wpaperd so it picks up the
    // change. `duration` and `sorting` are only valid when `path` points to
    // a directory — wpaperd rejects the whole config otherwise — so we
    // omit them in single-file mode. Despite the wpaperd-output(5) claim
    // that config changes are picked up automatically, the running daemon
    // does not actually re-read its config; restarting it is the only
    // reliable trigger.
    function _writeConfig(pathValue, durationValue, sortingValue, resumeFile) {
        var isDir = (pathValue === wallpapersDir);
        var contents = "[default]\n"
                     + "path = \"" + pathValue + "\"\n";
        if (isDir) {
            contents += "duration = \"" + durationValue + "\"\n"
                     +  "sorting = \"" + sortingValue + "\"\n";
        }
        // Transition: "none" → transition-time = 0 (in-place swap, no
        // animation). Anything else picks a named gl-transition via its
        // own subsection. The subsection can be empty; wpaperd uses the
        // transition's own defaults.
        if (transitionName === "none") {
            contents += "transition-time = 0\n";
        } else {
            contents += "\n[default.transition." + transitionName + "]\n";
        }
        var script = "printf %s '" + contents.replace(/'/g, "'\\''") + "' > \""
                   + root.configPath + "\""
                   + " && { pkill wpaperd; sleep 0.2; wpaperd -d; }";

        // When starting slideshow from a specific file, wait for wpaperd
        // to settle, find that file's index in the sorted directory, and
        // fire `wpaperctl next` that many times so it lands on the file
        // the user was viewing instead of resetting to the first image.
        if (resumeFile && resumeFile.length > 0) {
            var fname = resumeFile.replace(/^.*\//, "");
            script += "; sleep 1.0"
                + "; n=$(ls -1 \"" + wallpapersDir + "\""
                + "        | grep -Ei '\\.(png|jpe?g|webp|bmp|gif)$' | sort"
                + "        | awk -v t='" + fname + "' '$0==t{print NR-1; exit}')"
                + "; [ -z \"$n\" ] && n=0"
                + "; monitors=$(hyprctl monitors -j 2>/dev/null"
                + "             | grep -oE '\"name\": \"[^\"]+\"'"
                + "             | sed 's/\"name\": \"//; s/\"$//')"
                + "; [ -z \"$monitors\" ] && monitors=$(wpaperctl all-wallpapers 2>/dev/null | cut -d: -f1)"
                + "; for m in $monitors; do"
                + "    i=0; while [ $i -lt $n ]; do"
                + "      wpaperctl next \"$m\" >/dev/null 2>&1; i=$((i+1));"
                + "    done;"
                + "  done";
        }

        Quickshell.execDetached(["sh", "-c", script]);
        currentPath = pathValue;
        currentDuration = durationValue;
        currentSorting = sortingValue;
    }

    function applyWallpaper(path) {
        // Picking a specific image turns slideshow off — path becomes the
        // single file. Keep duration/sorting around so toggling slideshow
        // back on restores them.
        slideshow = false;
        _writeConfig(path, intervalDurationString(), currentSorting);
    }

    function intervalDurationString() {
        var v = Math.max(1, intervalValue);
        return v + intervalUnit;
    }

    function applySlideshow() {
        if (slideshow) {
            // Resume from the file we were viewing so the slideshow
            // doesn't reset to the alphabetically-first image.
            var resume = currentPath;
            var expanded = _expandedPath(resume);
            if (!resume || expanded === wallpapersDir) resume = "";
            _writeConfig(wallpapersDir, intervalDurationString(), currentSorting, resume);
        } else {
            // Off — fall back to the most recently selected file, or the
            // first wallpaper in the folder if we don't have one yet.
            var target = currentPath;
            var expanded2 = _expandedPath(target);
            if (!target || expanded2 === wallpapersDir) {
                target = entries.length > 0 ? entries[0].path : "";
            }
            if (!target) return;
            _writeConfig(target, intervalDurationString(), currentSorting);
        }
    }

    function applyInterval() {
        // Only meaningful while slideshow is on, but we still rewrite so the
        // duration sticks if the user flips slideshow on later.
        _writeConfig(currentPath, intervalDurationString(), currentSorting);
    }

    function applyTransition(name) {
        transitionName = name;
        _writeConfig(currentPath, intervalDurationString(), currentSorting);
    }

    // Outside-click dismiss
    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    // FocusScope captures keyboard input while the panel is open. Esc
    // closes; PanelWindow itself isn't an Item so Keys can't attach there.
    FocusScope {
        id: keyboardScope
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()
    }

    // Drop shadow stack (matches the launcher).
    Repeater {
        model: 6
        delegate: Rectangle {
            anchors.fill: panel
            anchors.leftMargin:   -(index + 1)
            anchors.rightMargin:  -(index + 1)
            anchors.topMargin:    0
            anchors.bottomMargin: -(index + 1) - 2
            z: -1 - index
            color: "transparent"
            radius: panel.radius + (index + 1)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18 / (index + 1))
        }
    }

    Rectangle {
        id: panel
        width: 880
        height: 600
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        color: Theme.calendarBg
        radius: Theme.calendarRadius
        border.color: Theme.calendarBorder
        border.width: 1
        clip: true

        // Eat inside clicks so they don't reach the outside dismiss.
        MouseArea {
            anchors.fill: parent
            onPressed: (m) => { m.accepted = true; }
        }

        // Transition popover — defined as a sibling of the ColumnLayout
        // so it floats above the grid. Positioned under the trigger.
        Rectangle {
            id: transitionMenu
            visible: false
            z: 100
            // Position relative to the trigger using direct arithmetic so
            // the binding tracks layout changes — mapToItem is a function
            // call and QML can't track its dependencies. The chain is
            // panel → header (ColumnLayout child at 0,0) → Row → trigger.
            x: transitionTrigger.parent.x + transitionTrigger.x
            y: transitionTrigger.parent.y + transitionTrigger.y
               + transitionTrigger.height + 4
            width: 160
            height: root.transitionChoices.length * 32 + 8
            color: Theme.dropdownBg
            border.color: Theme.dropdownBorder
            border.width: 1
            radius: 8

            // Eat outside clicks so they hit a global handler that dismisses
            // the menu without dismissing the whole panel.
            MouseArea {
                anchors.fill: parent
                onPressed: (m) => { m.accepted = true; }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 4

                Repeater {
                    model: root.transitionChoices
                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        radius: 4
                        color: itemHover.hovered ? Theme.hoverBg
                                                 : (modelData === root.transitionName
                                                       ? Theme.highlightBg
                                                       : "transparent")

                        HoverHandler { id: itemHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                root.applyTransition(modelData);
                                transitionMenu.visible = false;
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        // Click anywhere else inside the panel to close the transition menu.
        MouseArea {
            anchors.fill: parent
            visible: transitionMenu.visible
            z: 99
            onPressed: (m) => {
                transitionMenu.visible = false;
                m.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- Header ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: Theme.calendarHeaderBg
                // Match the panel's top corners so the header doesn't
                // square them off (clip:true on the parent has fuzzy
                // results on some Wayland render paths).
                topLeftRadius: panel.radius
                topRightRadius: panel.radius
                bottomLeftRadius: 0
                bottomRightRadius: 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wallpapers"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                // Slideshow controls cluster (right-aligned). Trailing
                // close button sits past it via its own anchor so the
                // cluster's spacing/width logic stays simple.
                Row {
                    id: headerControls
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // Transition style dropdown trigger
                    Rectangle {
                        id: transitionTrigger
                        width: transitionText.implicitWidth + caret.implicitWidth + 28
                        height: 32
                        radius: 6
                        color: transitionHover.hovered ? Theme.hoverBg : Theme.startmenuSearchInputBg
                        border.color: Theme.calendarBorder
                        border.width: 1

                        HoverHandler { id: transitionHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: transitionMenu.visible = !transitionMenu.visible
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                id: transitionText
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.transitionName
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.styleName: Theme.fontStyle
                                font.pixelSize: 13
                            }
                            Text {
                                id: caret
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Slideshow on/off toggle
                    Rectangle {
                        id: toggleBtn
                        width: toggleText.implicitWidth + 36
                        height: 32
                        radius: 16
                        color: root.slideshow ? Theme.barAccent
                                              : (toggleHover.hovered ? Theme.hoverBg
                                                                     : Theme.startmenuSearchInputBg)
                        border.color: root.slideshow ? Theme.barAccent : Theme.calendarBorder
                        border.width: 1

                        HoverHandler { id: toggleHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                root.slideshow = !root.slideshow;
                                root.applySlideshow();
                            }
                        }

                        Text {
                            id: toggleText
                            anchors.centerIn: parent
                            text: "Slideshow: " + (root.slideshow ? "On" : "Off")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.styleName: Theme.fontStyle
                            font.pixelSize: 13
                        }
                    }

                    // Interval value field
                    Rectangle {
                        width: 60
                        height: 32
                        radius: 6
                        color: Theme.startmenuSearchInputBg
                        border.color: Theme.calendarBorder
                        border.width: 1
                        opacity: root.slideshow ? 1.0 : 0.5

                        TextField {
                            id: intervalField
                            anchors.fill: parent
                            anchors.margins: 2
                            text: root.intervalValue.toString()
                            color: Theme.textPrimary
                            background: Item {}
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            selectByMouse: true
                            enabled: root.slideshow
                            validator: IntValidator { bottom: 1; top: 9999 }

                            onEditingFinished: {
                                var n = parseInt(text);
                                if (!isNaN(n) && n > 0) {
                                    root.intervalValue = n;
                                    root.applyInterval();
                                } else {
                                    text = root.intervalValue.toString();
                                }
                            }
                        }
                    }

                    // Unit dropdown — small inline cycler.
                    Rectangle {
                        width: 44
                        height: 32
                        radius: 6
                        color: unitHover.hovered ? Theme.hoverBg : Theme.startmenuSearchInputBg
                        border.color: Theme.calendarBorder
                        border.width: 1
                        opacity: root.slideshow ? 1.0 : 0.5

                        HoverHandler { id: unitHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (!root.slideshow) return;
                                var idx = root.unitChoices.indexOf(root.intervalUnit);
                                if (idx < 0) idx = 1;
                                root.intervalUnit = root.unitChoices[(idx + 1) % root.unitChoices.length];
                                root.applyInterval();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.intervalUnit
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }

                // Close (X) button — mirrors the NotificationCard close
                // affordance: small round hit area, fades in on hover.
                Rectangle {
                    id: closeBtn
                    width: 28
                    height: 28
                    radius: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeHover.hovered ? Theme.hoverBg : "transparent"

                    HoverHandler { id: closeHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.close()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textPrimary
                        opacity: closeHover.hovered ? 1.0 : 0.7
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }
            }

            // Hairline divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.calendarBorder
            }

            // ---------- Wallpaper grid ----------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 12
                    // Leave room for the scrollbar gutter on the right so
                    // it doesn't overlap the rightmost column's hit area.
                    anchors.rightMargin: 18
                    clip: true
                    // Pick the column count from the available width, then
                    // grow the cells to absorb the leftover pixels — this
                    // eats the dead gap on the right.
                    readonly property int columns: Math.max(1, Math.floor(width / 200))
                    cellWidth: columns > 0 ? Math.floor(width / columns) : width
                    cellHeight: Math.round(cellWidth * 0.65)
                    model: root.entries
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        WallpaperTile {
                            anchors.fill: parent
                            anchors.margins: 6
                            path: modelData.path
                            fileName: modelData.name
                            selected: !root.slideshow && (root._expandedPath(root.currentPath) === modelData.path)
                            onClicked: root.applyWallpaper(modelData.path)
                        }
                    }
                }

                // Interactive scrollbar — drag the thumb or click anywhere
                // on the track to jump. Width expands on hover for an
                // easier grab target. Pattern mirrors startmenu/AppList.
                Item {
                    id: scrollbar
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    width: scrollHover.hovered || scrollArea.pressed ? 12 : 6
                    visible: grid.contentHeight > grid.height

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
                            var maxContentY = Math.max(0, grid.contentHeight - grid.height);
                            if (maxThumbY <= 0 || maxContentY <= 0) return;
                            var newThumbY = Math.max(0, Math.min(maxThumbY, localY - grabOffset));
                            grid.contentY = (newThumbY / maxThumbY) * maxContentY;
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

                        readonly property real maxContentY: Math.max(1, grid.contentHeight - grid.height)
                        y: (grid.contentY / maxContentY) * (track.height - height)
                        height: Math.max(30, track.height * Math.min(1, grid.height / grid.contentHeight))
                    }
                }

                // Empty-state message
                Text {
                    anchors.centerIn: parent
                    visible: root.entries.length === 0
                    text: "No wallpapers in ~/Pictures/Wallpapers"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.styleName: Theme.fontStyle
                    font.pixelSize: 16
                }
            }
        }
    }
}
