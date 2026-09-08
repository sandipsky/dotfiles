// Elegant — SDDM greeter styled after hypr-shell's lock screen
// (~/Projects/hypr-shell: data/css/lock.css, src/bar/lock_surface.cpp).
//
// GDM's solid login background, a 130 px round avatar with the account's full
// name under it, a 200×30 password pill (no button — Enter submits, an eye
// toggle reveals the text) and round icon buttons in the bottom-right corner
// that open lock-screen-style menus: sessions, users (when there are several)
// and power. Colours are the tokens hypr-shell derives from ui.accent in dark
// mode, so the greeter matches whatever accent the desktop uses.
import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    // GDM's login background: gnome-shell's #lockDialogGroup uses $_gdm_bg =
    // $system_base_color = $_base_color_dark = #222226 (_default-colors.scss).
    color: isHex(config.background) ? config.background : "#222226"

    function isHex(v) { return /^#[0-9a-fA-F]{6}$/.test(String(v)) }

    // ---- palette ----------------------------------------------------------
    // hypr-shell's derive_palette(accent, dark) from src/services/palette.hpp,
    // token for token. The accent is read from theme.conf(.user) — scripts/
    // sddm.sh writes the live ui.accent there; the default is the repo's.
    readonly property color accent: isHex(config.accent) ? config.accent : "#3584e4"
    readonly property real accentHue: accent.hslHue < 0 ? 0 : accent.hslHue * 360
    readonly property real accentSat: accent.hslSaturation

    function hsl(h, s, l) {
        return Qt.hsla((((h % 360) + 360) % 360) / 360,
                       Math.min(1, Math.max(0, s)), Math.min(1, Math.max(0, l)), 1)
    }
    function relativeLuminance(c) {
        function lin(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property color mPrimary: accent
    readonly property color mOnPrimary: relativeLuminance(accent) > 0.35
                                        ? hsl(accentHue, Math.min(1, accentSat * 0.6 + 0.1), 0.30)
                                        : "#ffffff"
    readonly property color mSurface: hsl(accentHue + 3, 0.07, 0.08)
    readonly property color mOnSurface: hsl(accentHue + 51, 0.09, 0.89)
    readonly property color mSurfaceVariant: hsl(accentHue + 18, 0.06, 0.13)
    readonly property color mOnSurfaceVariant: hsl(accentHue + 14, 0.10, 0.79)
    readonly property color mOutline: hsl(accentHue + 3, 0.06, 0.29)
    readonly property color mError: "#ffb4ab"
    readonly property color mOnError: "#690005"

    // Text in the desktop's interface font; icons are glyphs from the same
    // Tabler icon font hypr-shell uses (bundled — the greeter runs as the sddm
    // user and can't read ~/.local/share/fonts). Point sizes are lock.css's.
    readonly property string fontFamily: "Fira Sans"
    readonly property string iconFamily: iconFont.name
    FontLoader { id: iconFont; source: "fonts/noctalia-tabler-icons.ttf" }
    TextConstants { id: textConstants }

    // ---- state ------------------------------------------------------------
    property string userName: userModel.lastUser
    property string displayName: userName
    property url avatarSource: ""
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property bool busy: false

    // Invisible copies of the two models so rows can be looked up by index.
    Item {
        visible: false
        Repeater {
            id: users
            model: userModel
            delegate: Item {
                property string login: name
                property string fullName: realName
                property string face: icon
            }
        }
        Repeater {
            id: sessions
            model: sessionModel
            delegate: Item { property string label: name }
        }
    }

    function selectUser(i) {
        var u = users.itemAt(i)
        if (!u) return
        userName = u.login
        // Full name from the account (GECOS), the login name when unset.
        displayName = u.fullName || u.login
        avatarSource = u.face
    }

    Component.onCompleted: {
        var idx = 0
        for (var i = 0; i < users.count; i++)
            if (users.itemAt(i).login === userModel.lastUser) idx = i
        selectUser(idx)
    }

    function login() {
        if (busy || userName === "") return
        busy = true
        errorPill.shown = false
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { busy = false }
        function onLoginFailed() {
            busy = false
            password.text = ""
            errorPill.message = qsTr("Authentication failed")
            errorPill.shown = true
            password.forceActiveFocus()
        }
    }

    function closeMenus() {
        powerMenu.hide()
        sessionMenu.hide()
        userMenu.hide()
    }

    function toggleMenu(menu) {
        if (menu.open) { menu.hide(); return }
        closeMenus()
        var i
        if (menu === powerMenu) {
            powerModel.clear()
            if (sddm.canSuspend)
                powerModel.append({ label: qsTr("Suspend"), glyph: "", destructive: false, checked: false, action: "suspend" })
            if (sddm.canReboot)
                powerModel.append({ label: qsTr("Reboot"), glyph: "", destructive: false, checked: false, action: "reboot" })
            if (sddm.canPowerOff)
                powerModel.append({ label: qsTr("Shutdown"), glyph: "", destructive: true, checked: false, action: "poweroff" })
        } else if (menu === sessionMenu) {
            sessionListModel.clear()
            for (i = 0; i < sessions.count; i++)
                sessionListModel.append({ label: sessions.itemAt(i).label, glyph: "", destructive: false, checked: i === sessionIndex, action: "" })
        } else {
            userListModel.clear()
            for (i = 0; i < users.count; i++) {
                var u = users.itemAt(i)
                userListModel.append({ label: u.fullName || u.login, glyph: "", destructive: false, checked: u.login === userName, action: "" })
            }
        }
        if (menu.model.count > 0) menu.show()
    }

    // Click anywhere else: close the menus, back to the password.
    MouseArea {
        anchors.fill: parent
        onClicked: { closeMenus(); password.forceActiveFocus() }
    }

    // ---- login column -----------------------------------------------------
    // avatar (130) → 13 → name → 31 → password pill, centred at 42 % of the
    // screen height like the lock screen's login stage.
    Column {
        id: loginColumn
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.42 - height / 2)

        Item {
            id: avatarBox
            width: 130
            height: 130
            anchors.horizontalCenter: parent.horizontalCenter

            // Fallback while the image loads or when the account has none.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: mSurfaceVariant
                visible: avatar.status !== Image.Ready
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: iconFamily
                    font.pointSize: 56
                    color: mOnSurfaceVariant
                }
            }
            Image {
                id: avatar
                anchors.fill: parent
                source: avatarSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: avatarMask }
            }
            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
            }
            MouseArea {
                anchors.fill: parent
                enabled: users.count > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: toggleMenu(userMenu)
            }
        }

        Item { width: 1; height: 13 }

        Text {
            id: nameText
            anchors.horizontalCenter: parent.horizontalCenter
            text: displayName
            font.family: fontFamily
            font.pointSize: 24
            font.weight: Font.DemiBold
            color: mOnSurface
        }

        Item { width: 1; height: 31 }

        Rectangle {
            id: pill
            property bool revealed: false
            width: 200
            height: 30
            radius: 15
            anchors.horizontalCenter: parent.horizontalCenter
            color: mSurface
            border.width: 1
            border.color: alpha(mOutline, 0.3)
            opacity: busy ? 0.6 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }

            TextInput {
                id: password
                anchors {
                    left: parent.left
                    leftMargin: 16
                    right: eye.visible ? eye.left : parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                height: 20
                clip: true
                focus: true
                enabled: !busy
                echoMode: pill.revealed ? TextInput.Normal : TextInput.Password
                // Dots are the icon font's circle-filled glyph, like .lock-dots.
                passwordCharacter: ""
                passwordMaskDelay: 0
                font.family: pill.revealed ? fontFamily : iconFamily
                font.pointSize: pill.revealed ? 11 : 13
                font.letterSpacing: pill.revealed ? 0 : 1
                color: mPrimary
                selectionColor: mPrimary
                selectedTextColor: mOnPrimary
                verticalAlignment: TextInput.AlignVCenter
                // 2×20 accent caret fading in and out every 530 ms (.lock-caret).
                cursorDelegate: Rectangle {
                    width: 2
                    height: 20
                    color: mPrimary
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: password.activeFocus
                        NumberAnimation { to: 0; duration: 530 }
                        NumberAnimation { to: 1; duration: 530 }
                    }
                }
                onAccepted: login()
                onTextChanged: if (errorPill.shown) errorPill.shown = false
                Keys.onEscapePressed: { closeMenus(); text = "" }
            }

            // Reveal toggle, only once something has been typed (button.lock-eye).
            Rectangle {
                id: eye
                visible: password.text.length > 0
                anchors {
                    right: parent.right
                    rightMargin: 2
                    verticalCenter: parent.verticalCenter
                }
                width: 26
                height: 26
                radius: 13
                color: eyeHover.containsMouse ? mPrimary : "transparent"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: pill.revealed ? "" : ""
                    font.family: iconFamily
                    font.pointSize: 14
                    color: eyeHover.containsMouse ? mOnPrimary : mOnSurfaceVariant
                }
                MouseArea {
                    id: eyeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pill.revealed = !pill.revealed; password.forceActiveFocus() }
                }
            }
        }
    }

    // The greeter sometimes leaves focus elsewhere at startup.
    Timer {
        interval: 200
        running: true
        onTriggered: password.forceActiveFocus()
    }

    // ---- failure pill (.lock-pill.error) ------------------------------------
    Rectangle {
        id: errorPill
        property bool shown: false
        property string message: ""
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 200
        }
        width: errorRow.width + 28
        height: 50
        radius: 20
        color: mError
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Row {
            id: errorRow
            anchors.centerIn: parent
            spacing: 9
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: iconFamily
                font.pointSize: 16
                color: mOnError
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: errorPill.message
                font.family: fontFamily
                font.pointSize: 13
                color: mOnError
            }
        }
    }

    // ---- bottom-right corner ----------------------------------------------
    Row {
        id: corner
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 28
        }
        spacing: 13
        IconButton {
            id: userButton
            visible: users.count > 1
            glyph: ""
            active: userMenu.open
            onClicked: toggleMenu(userMenu)
        }
        IconButton {
            id: sessionButton
            visible: sessions.count > 1
            glyph: ""
            active: sessionMenu.open
            onClicked: toggleMenu(sessionMenu)
        }
        IconButton {
            id: powerButton
            glyph: ""
            active: powerMenu.open
            onClicked: toggleMenu(powerMenu)
        }
    }

    // Menus open above the corner buttons (lock: margin-bottom 28 + 30 + 9).
    PopupMenu {
        id: powerMenu
        anchors { right: parent.right; rightMargin: 28; bottom: corner.top; bottomMargin: 9 }
        model: ListModel { id: powerModel }
        onTriggered: (index) => {
            var action = powerModel.get(index).action
            hide()
            if (action === "suspend") sddm.suspend()
            else if (action === "reboot") sddm.reboot()
            else sddm.powerOff()
        }
        onClosed: password.forceActiveFocus()
    }
    PopupMenu {
        id: sessionMenu
        anchors { right: parent.right; rightMargin: 28; bottom: corner.top; bottomMargin: 9 }
        model: ListModel { id: sessionListModel }
        onTriggered: (index) => { sessionIndex = index; hide() }
        onClosed: password.forceActiveFocus()
    }
    PopupMenu {
        id: userMenu
        anchors { right: parent.right; rightMargin: 28; bottom: corner.top; bottomMargin: 9 }
        model: ListModel { id: userListModel }
        onTriggered: (index) => { selectUser(index); hide() }
        onClosed: password.forceActiveFocus()
    }
}
