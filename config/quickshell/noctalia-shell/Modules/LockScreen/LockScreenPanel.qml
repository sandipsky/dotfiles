import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Widgets

Item {
  id: root
  anchors.fill: parent

  required property var lockControl
  required property var batteryIndicator
  required property var keyboardLayout
  required property TextInput passwordInput

  // Windows 11 style two-stage lock: "cover" shows only the clock,
  // "login" shows avatar + name + password. Any key or click advances,
  // Escape returns to the cover.
  property string stage: "cover"

  // Whether to enable lock screen animations (smooth cursor blink).
  // Defaults to false to reduce GPU usage.  Set Settings.data.general.lockScreenAnimations = true to restore.
  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations || false

  // Font for the cover clock and date, configurable in Settings > Lock Screen
  readonly property string lockFont: Settings.data.general.lockScreenFont || Settings.data.ui.fontFixed

  property date currentTime: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentTime = new Date()
  }

  onStageChanged: {
    sessionMenu.open = false;
    if (stage === "login" && passwordInput) {
      passwordInput.forceActiveFocus();
    }
  }

  Component.onCompleted: {
    if (Settings.data.general.autoStartAuth) {
      root.stage = "login";
      doUnlock();
    }
  }

  function doUnlock() {
    if (lockControl) {
      lockControl.tryUnlock();
    }
  }

  // Timer properties
  readonly property int timerDuration: Settings.data.general.lockScreenCountdownDuration
  property string pendingAction: ""
  property bool timerActive: false
  property int timeRemaining: 0

  // Timer management functions
  function startTimer(action) {
    // Check if global countdown is disabled
    if (!Settings.data.general.enableLockScreenCountdown) {
      executeAction(action);
      return;
    }

    if (timerActive && pendingAction === action) {
      // Second click - execute immediately
      executeAction(action);
      return;
    }

    pendingAction = action;
    timeRemaining = timerDuration;
    timerActive = true;
    countdownTimer.start();
  }

  function cancelTimer() {
    timerActive = false;
    pendingAction = "";
    timeRemaining = 0;
    countdownTimer.stop();
  }

  function executeAction(action) {
    // Stop timer but don't reset other properties yet
    countdownTimer.stop();

    // Execute the action
    switch (action) {
    case "logout":
      CompositorService.logout();
      break;
    case "suspend":
      CompositorService.suspend();
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }

    // Reset timer state
    cancelTimer();
  }

  // Countdown timer
  Timer {
    id: countdownTimer
    interval: 100
    repeat: true
    onTriggered: {
      timeRemaining -= interval;
      if (timeRemaining <= 0) {
        executeAction(pendingAction);
      }
    }
  }

  readonly property var sessionActions: {
    var list = [
                 {
                   "icon": "suspend",
                   "label": I18n.tr("common.suspend"),
                   "action": "suspend"
                 },
                 {
                   "icon": "logout",
                   "label": I18n.tr("common.logout"),
                   "action": "logout"
                 }
               ];
    if (Settings.data.general.showHibernateOnLockScreen) {
      list.push({
                  "icon": "hibernate",
                  "label": I18n.tr("common.hibernate"),
                  "action": "hibernate"
                });
    }
    list.push({
                "icon": "reboot",
                "label": I18n.tr("common.reboot"),
                "action": "reboot"
              });
    list.push({
                "icon": "shutdown",
                "label": I18n.tr("common.shutdown"),
                "action": "shutdown"
              });
    return list;
  }

  // Click anywhere on the cover to reveal the login stage
  MouseArea {
    anchors.fill: parent
    visible: root.stage === "cover"
    onClicked: root.stage = "login"
  }

  // ----------------------------------------------------------------------
  // Stage 1 - cover: time and date only
  // ----------------------------------------------------------------------
  Column {
    id: coverContent
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(parent.height * 0.38 - height / 2) + (root.stage === "cover" ? 0 : -40)
    spacing: Style.marginXS
    opacity: root.stage === "cover" ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on y {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    NText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: {
        var h = root.currentTime.getHours() % 12;
        if (h === 0)
          h = 12;
        var m = root.currentTime.getMinutes();
        return h + ":" + (m < 10 ? "0" + m : m);
      }
      pointSize: 72
      font.weight: Style.fontWeightBold
      family: root.lockFont
      color: Color.mOnSurface
    }

    NText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: I18n.locale.toString(root.currentTime, "dddd, MMMM d")
      pointSize: Style.fontSizeXXL
      font.weight: Style.fontWeightMedium
      family: root.lockFont
      color: Color.mOnSurface
    }
  }

  // ----------------------------------------------------------------------
  // Stage 2 - login: avatar, name, password
  // ----------------------------------------------------------------------
  ColumnLayout {
    id: loginContent
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(parent.height * 0.42 - height / 2) + (root.stage === "login" ? 0 : 40)
    spacing: Style.marginL
    opacity: root.stage === "login" ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on y {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }

    // Avatar
    Item {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 130
      Layout.preferredHeight: 130

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: Qt.alpha(Color.mOnSurface, 0.25)
        border.width: Style.borderS
      }

      NImageRounded {
        anchors.centerIn: parent
        width: 124
        height: 124
        radius: width / 2
        imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
        fallbackIcon: "person"
      }
    }

    // Full name
    NText {
      Layout.alignment: Qt.AlignHCenter
      text: HostService.displayName
      family: "Fira Sans SemiBold"
      pointSize: Style.fontSizeXXXL
      font.weight: Style.fontWeightSemiBold
      color: Color.mOnSurface
      horizontalAlignment: Text.AlignHCenter
    }

    // Password input
    Rectangle {
      id: passwordInputContainer
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: Style.marginXL
      Layout.preferredWidth: 200
      Layout.preferredHeight: 30
      radius: Style.iRadiusL
      color: Color.mSurface
      border.color: passwordInput.activeFocus ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.3)
      border.width: passwordInput.activeFocus ? 2 : 1

      property bool passwordVisible: false

      // Ctrl + A to highlight the portion
      Shortcut {
        sequence: StandardKey.SelectAll
        enabled: passwordInput.activeFocus
        onActivated: passwordInput.selectAll()
      }

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.marginM

        Row {
          spacing: 0

          Rectangle {
            width: 2
            height: 20
            color: Color.mPrimary
            visible: passwordInput.activeFocus && passwordInput.text.length === 0
            anchors.verticalCenter: parent.verticalCenter

            // Smooth fade animation (when animations enabled)
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
              NumberAnimation {
                to: 0
                duration: 530
              }
              NumberAnimation {
                to: 1
                duration: 530
              }
            }

            // Simple toggle (when animations disabled) - no per-frame repaints
            Timer {
              interval: 530
              running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
              repeat: true
              onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
            }
          }

          // Host for dots / plain text and the caret
          Item {
            id: passwordVisualHost
            height: 20
            width: passwordInputContainer.passwordVisible ? Math.min(visiblePasswordPlainText.implicitWidth, 110) : Math.min(passwordDisplayContent.width, 110)
            anchors.verticalCenter: parent.verticalCenter

            readonly property real caretVisualX: {
              const len = passwordInput.text.length;
              if (len <= 0)
                return 0;
              if (passwordInputContainer.passwordVisible) {
                const adv = passwordCaretFontMetrics.advanceWidth(passwordInput.text.substring(0, passwordInput.cursorPosition));
                return Math.max(0, Math.min(adv, width));
              }
              const w = passwordDisplayContent.width;
              if (w <= 0)
                return 0;
              return Math.max(0, Math.min((passwordInput.cursorPosition / len) * w, width));
            }

            // Password dots display
            Item {
              width: Math.min(passwordDisplayContent.width, 110)
              height: 20
              visible: passwordInput.text.length > 0 && !passwordInputContainer.passwordVisible
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              clip: true

              Row {
                id: passwordDisplayContent
                spacing: Style.marginXXXS
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                  id: iconRepeater
                  model: ScriptModel {
                    values: Array(passwordInput.text.length)
                  }

                  property list<string> passwordChars: ["circle-filled", "pentagon-filled", "michelin-star-filled", "square-rounded-filled", "guitar-pick-filled", "blob-filled", "triangle-filled"]

                  NIcon {
                    id: icon

                    required property int index
                    property bool drawCustomChar: index >= 0 && Settings.data.general.passwordChars

                    icon: drawCustomChar ? iconRepeater.passwordChars[index % iconRepeater.passwordChars.length] : "circle-filled"
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                  }
                }
              }
            }

            NText {
              id: visiblePasswordPlainText
              text: passwordInput.text
              color: Color.mPrimary
              pointSize: Style.fontSizeM
              visible: passwordInput.text.length > 0 && passwordInputContainer.passwordVisible
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              width: Math.min(implicitWidth, 110)
            }

            FontMetrics {
              id: passwordCaretFontMetrics
              font: visiblePasswordPlainText.font
            }

            Rectangle {
              width: 2
              height: 20
              x: passwordVisualHost.caretVisualX
              color: Color.mPrimary
              visible: passwordInput.activeFocus && passwordInput.text.length > 0

              anchors.verticalCenter: parent.verticalCenter

              // Smooth fade animation (when animations enabled)
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0
                NumberAnimation {
                  to: 0
                  duration: 530
                }
                NumberAnimation {
                  to: 1
                  duration: 530
                }
              }

              // Simple toggle (when animations disabled) - no per-frame repaints
              Timer {
                interval: 530
                running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0
                repeat: true
                onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
              }
            }
          }
        }
      }

      // Eye button to toggle password visibility
      Rectangle {
        anchors.right: submitButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: Math.min(Style.iRadiusL, width / 2)
        color: eyeButtonArea.containsMouse ? Color.mPrimary : "transparent"
        visible: passwordInput.text.length > 0
        enabled: !lockControl || !lockControl.unlockInProgress

        NIcon {
          anchors.centerIn: parent
          icon: passwordInputContainer.passwordVisible ? "eye-off" : "eye"
          pointSize: Style.fontSizeM
          color: eyeButtonArea.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
        }

        MouseArea {
          id: eyeButtonArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: passwordInputContainer.passwordVisible = !passwordInputContainer.passwordVisible
        }
      }

      // Submit button
      Rectangle {
        id: submitButton
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: Math.min(Style.iRadiusL, width / 2)
        color: submitButtonArea.containsMouse ? Color.mPrimary : "transparent"
        border.color: Color.mPrimary
        border.width: Style.borderS
        enabled: !lockControl || !lockControl.unlockInProgress

        NIcon {
          anchors.centerIn: parent
          icon: "arrow-forward"
          pointSize: Style.fontSizeM
          color: submitButtonArea.containsMouse ? Color.mOnPrimary : Color.mPrimary
        }

        MouseArea {
          id: submitButtonArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.doUnlock()
        }
      }

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  // ----------------------------------------------------------------------
  // Bottom right - battery and power (both stages)
  // ----------------------------------------------------------------------
  RowLayout {
    id: bottomRightControls
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 28
    anchors.bottomMargin: 28
    spacing: Style.marginL

    // Battery with percentage
    RowLayout {
      spacing: Style.marginXS
      visible: batteryIndicator.isReady

      NIcon {
        icon: batteryIndicator.icon
        pointSize: Style.fontSizeXL
        color: batteryIndicator.charging ? Color.mPrimary : Color.mOnSurface
      }

      NText {
        text: Math.round(batteryIndicator.percent) + "%"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }
    }

    // Power button
    NIconButton {
      icon: "shutdown"
      baseSize: 30
      visible: Settings.data.general.showSessionButtonsOnLockScreen
      colorBg: Qt.alpha(Color.mSurface, 0.65)
      colorFg: Color.mOnSurface
      colorBgHover: Color.mPrimary
      colorFgHover: Color.mOnPrimary
      onClicked: sessionMenu.open = !sessionMenu.open
    }
  }

  // Session menu popup (above the power button)
  Rectangle {
    id: sessionMenu
    property bool open: false

    anchors.right: parent.right
    anchors.rightMargin: 28
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28 + 30 + Style.marginM
    width: 210
    height: sessionMenuColumn.implicitHeight + Style.marginM * 2
    radius: Style.radiusM
    color: Color.mSurface
    border.color: Qt.alpha(Color.mOutline, 0.3)
    border.width: Style.borderS
    visible: opacity > 0
    opacity: open ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: sessionMenuColumn
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXXS

      Repeater {
        model: root.sessionActions

        delegate: Rectangle {
          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: 36
          radius: Style.radiusS
          color: actionArea.containsMouse ? (modelData.action === "shutdown" ? Color.mError : Color.mPrimary) : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: modelData.icon
              pointSize: Style.fontSizeL
              color: actionArea.containsMouse ? (modelData.action === "shutdown" ? Color.mOnError : Color.mOnPrimary) : (modelData.action === "shutdown" ? Color.mError : Color.mOnSurface)
            }

            NText {
              Layout.fillWidth: true
              text: modelData.label
              pointSize: Style.fontSizeM
              color: actionArea.containsMouse ? (modelData.action === "shutdown" ? Color.mOnError : Color.mOnPrimary) : Color.mOnSurface
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              sessionMenu.open = false;
              root.startTimer(modelData.action);
            }
          }
        }
      }
    }
  }
}
