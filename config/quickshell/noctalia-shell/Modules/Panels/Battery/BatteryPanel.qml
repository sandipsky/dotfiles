import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.Power
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(460 * Style.uiScaleRatio)

  onOpened: {
    if (panelContent.brightnessMonitor)
      panelContent.localBrightness = panelContent.brightnessMonitor.brightness || 0;
    if (panelContent.showRefreshRateSwitcher)
      RefreshRateService.refresh();
  }

  panelContent: Item {
    id: panelContent

    property real contentPreferredHeight: mainLayout.implicitHeight + Style.margin2L

    property var batteryWidgetInstance: BarService.lookupWidget("Battery", screen ? screen.name : null)
    readonly property var batteryWidgetSettings: batteryWidgetInstance ? batteryWidgetInstance.widgetSettings : null
    readonly property var batteryWidgetMetadata: BarWidgetRegistry.widgetMetadata["Battery"]
    readonly property bool powerProfileAvailable: PowerProfileService.available
    readonly property var powerProfiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property bool profilesAvailable: PowerProfileService.available
    property int profileIndex: profileToIndex(PowerProfileService.profile)
    readonly property bool showPowerProfiles: panelID ? panelID.showPowerProfiles : resolveWidgetSetting("showPowerProfiles", false)
    readonly property bool showNoctaliaPerformance: panelID ? panelID.showNoctaliaPerformance : resolveWidgetSetting("showNoctaliaPerformance", false)
    readonly property bool showBrightnessSlider: panelID ? panelID.showBrightnessSlider : resolveWidgetSetting("showBrightnessSlider", false)
    readonly property bool showRefreshRateSwitcher: panelID ? panelID.showRefreshRateSwitcher : resolveWidgetSetting("showRefreshRateSwitcher", false)
    readonly property bool isLowBattery: BatteryService.isLowBattery
    readonly property bool isCriticalBattery: BatteryService.isCriticalBattery
    readonly property var primaryDevice: BatteryService.primaryDevice

    // Brightness control for the monitor this panel is shown on
    readonly property var brightnessMonitor: screen ? BrightnessService.getMonitorForScreen(screen) : null
    property real localBrightness: 0
    property bool localBrightnessChanging: false

    // Refresh-rate switcher state (Hyprland only; revision drives re-evaluation)
    readonly property string screenName: screen ? screen.name : ""
    readonly property var refreshRates: (RefreshRateService.revision, RefreshRateService.getRates(screenName))
    readonly property int currentRefreshRate: (RefreshRateService.revision, RefreshRateService.getCurrentRate(screenName))
    readonly property bool refreshRateSupported: (RefreshRateService.revision, RefreshRateService.isSupported(screenName))

    Component.onCompleted: {
      if (brightnessMonitor)
        localBrightness = brightnessMonitor.brightness || 0;
      if (showRefreshRateSwitcher)
        RefreshRateService.refresh();
    }

    Connections {
      target: BrightnessService
      function onMonitorBrightnessChanged(monitor, newBrightness) {
        if (monitor === panelContent.brightnessMonitor && !panelContent.localBrightnessChanging)
          panelContent.localBrightness = newBrightness;
      }
    }

    Timer {
      id: brightnessDebounce
      interval: 100
      repeat: false
      onTriggered: {
        if (panelContent.brightnessMonitor && Math.abs(panelContent.localBrightness - panelContent.brightnessMonitor.brightness) > 0.009)
          panelContent.brightnessMonitor.setBrightness(panelContent.localBrightness);
      }
    }

    function profileToIndex(p) {
      return powerProfiles.indexOf(p) ?? 1;
    }

    function indexToProfile(idx) {
      return powerProfiles[idx] ?? PowerProfile.Balanced;
    }

    function setProfileByIndex(idx) {
      var prof = indexToProfile(idx);
      profileIndex = idx;
      PowerProfileService.setProfile(prof);
    }

    function resolveWidgetSetting(key, defaultValue) {
      if (batteryWidgetSettings && batteryWidgetSettings[key] !== undefined)
        return batteryWidgetSettings[key];
      if (batteryWidgetMetadata && batteryWidgetMetadata[key] !== undefined)
        return batteryWidgetMetadata[key];
      return defaultValue;
    }

    Connections {
      target: PowerProfileService
      function onProfileChanged() {
        panelContent.profileIndex = panelContent.profileToIndex(PowerProfileService.profile);
      }
    }

    Connections {
      target: BarService
      function onActiveWidgetsChanged() {
        panelContent.batteryWidgetInstance = BarService.lookupWidget("Battery", screen ? screen.name : null);
      }
    }

    ColumnLayout {
      id: mainLayout
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // HEADER
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            pointSize: Style.fontSizeXXL
            color: (BatteryService.isCharging(primaryDevice) || BatteryService.isPluggedIn(primaryDevice)) ? Color.mPrimary : (BatteryService.isCriticalBattery(primaryDevice) || BatteryService.isLowBattery(primaryDevice)) ? Color.mError : Color.mOnSurface
            icon: BatteryService.getIcon(BatteryService.getPercentage(primaryDevice), BatteryService.isCharging(primaryDevice), BatteryService.isPluggedIn(primaryDevice), BatteryService.isDeviceReady(primaryDevice))
          }

          ColumnLayout {
            spacing: Style.marginXXS
            Layout.fillWidth: true

            NText {
              text: I18n.tr("common.battery")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      // Charge level + health/time
      NBox {
        Layout.fillWidth: true
        implicitHeight: chargeLayout.implicitHeight + Style.margin2L
        visible: BatteryService.laptopBatteries.length > 0 || BatteryService.bluetoothBatteries.length > 0

        ColumnLayout {
          id: chargeLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginL

          // Laptop batteries section
          Repeater {
            model: BatteryService.laptopBatteries
            delegate: ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  RowLayout {
                    Item {
                      id: batteryInfoItem
                      implicitWidth: batteryInfoRow.implicitWidth
                      implicitHeight: batteryInfoRow.implicitHeight

                      RowLayout {
                        id: batteryInfoRow
                        anchors.fill: parent

                        NIcon {
                          icon: BatteryService.getIcon(BatteryService.getPercentage(modelData), BatteryService.isCharging(modelData), BatteryService.isPluggedIn(modelData), BatteryService.isDeviceReady(modelData))
                          color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                        }

                        NText {
                          readonly property string dName: BatteryService.getDeviceName(modelData)
                          text: dName ? dName : I18n.tr("common.battery")
                          color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                          pointSize: Style.fontSizeS
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                          if (modelData.healthSupported) {
                            TooltipService.show(batteryInfoItem, `${I18n.tr("battery.battery-health")}: ${Math.round(modelData.healthPercentage)}%`);
                          }
                        }
                        onExited: TooltipService.hide(batteryInfoItem)
                      }
                    }

                    Item {
                      Layout.fillWidth: true
                    }

                    NText {
                      text: BatteryService.getTimeRemainingText(modelData)
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS
                    Rectangle {
                      Layout.fillWidth: true
                      height: Math.round(8 * Style.uiScaleRatio)
                      radius: Math.min(Style.radiusL, height / 2)
                      color: Color.mSurface

                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        radius: parent.radius
                        width: {
                          var p = BatteryService.getPercentage(modelData);
                          var ratio = Math.max(0, Math.min(1, p / 100));
                          return parent.width * ratio;
                        }
                        color: Color.mPrimary
                      }
                    }

                    NText {
                      Layout.preferredWidth: 40 * Style.uiScaleRatio
                      horizontalAlignment: Text.AlignRight
                      text: `${BatteryService.getPercentage(modelData)}%`
                      color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                      pointSize: Style.fontSizeS
                      font.weight: Style.fontWeightBold
                    }
                  }
                }
              }
            }
          }

          NDivider {
            Layout.fillWidth: true
            visible: BatteryService.laptopBatteries.length > 0 && BatteryService.bluetoothBatteries.length > 0
          }

          // Other devices (Bluetooth) section
          Repeater {
            model: BatteryService.bluetoothBatteries
            delegate: ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: BluetoothService.getDeviceIcon(modelData)
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                }

                NText {
                  readonly property string dName: BatteryService.getDeviceName(modelData)
                  text: dName ? dName : I18n.tr("common.bluetooth")
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                  pointSize: Style.fontSizeS
                }
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  Layout.fillWidth: true
                  height: Math.round(8 * Style.uiScaleRatio)
                  radius: Math.min(Style.radiusL, height / 2)
                  color: Color.mSurface

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: parent.radius
                    width: {
                      var p = BatteryService.getPercentage(modelData);
                      var ratio = Math.max(0, Math.min(1, p / 100));
                      return parent.width * ratio;
                    }
                    color: Color.mPrimary
                  }
                }

                NText {
                  Layout.preferredWidth: 40 * Style.uiScaleRatio
                  horizontalAlignment: Text.AlignRight
                  text: `${BatteryService.getPercentage(modelData)}%`
                  color: (BatteryService.isCharging(modelData) || BatteryService.isPluggedIn(modelData)) ? Color.mPrimary : (BatteryService.isCriticalBattery(modelData) || BatteryService.isLowBattery(modelData)) ? Color.mError : Color.mOnSurface
                  pointSize: Style.fontSizeS
                  font.weight: Style.fontWeightBold
                }
              }
            }
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        height: controlsLayout.implicitHeight + Style.margin2L
        visible: showPowerProfiles || showNoctaliaPerformance

        ColumnLayout {
          id: controlsLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          ColumnLayout {
            visible: powerProfileAvailable && showPowerProfiles

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NText {
                text: I18n.tr("battery.power-profile")
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
                Layout.fillWidth: true
              }

              NText {
                text: PowerProfileService.getName(profileIndex)
                color: Color.mOnSurfaceVariant
              }
            }

            NValueSlider {
              Layout.fillWidth: true
              from: 0
              to: 2
              stepSize: 1
              snapAlways: true
              heightRatio: 0.5
              value: profileIndex
              enabled: profilesAvailable
              onPressedChanged: (pressed, v) => {
                                  if (!pressed) {
                                    setProfileByIndex(v);
                                  }
                                }
              onMoved: v => {
                         profileIndex = v;
                       }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NIcon {
                icon: "powersaver"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "powersaver" ? Color.mPrimary : Color.mOnSurfaceVariant
              }

              NIcon {
                icon: "balanced"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "balanced" ? Color.mPrimary : Color.mOnSurfaceVariant
                Layout.fillWidth: true
              }

              NIcon {
                icon: "performance"
                pointSize: Style.fontSizeS
                color: PowerProfileService.getIcon() === "performance" ? Color.mPrimary : Color.mOnSurfaceVariant
              }
            }
          }

          NDivider {
            Layout.fillWidth: true
            visible: showPowerProfiles && PowerProfileService.available && showNoctaliaPerformance
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: showNoctaliaPerformance

            NText {
              text: I18n.tr("toast.noctalia-performance.label")
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIcon {
              icon: PowerProfileService.noctaliaPerformanceMode ? "rocket" : "rocket-off"
              pointSize: Style.fontSizeL
              color: PowerProfileService.noctaliaPerformanceMode ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            NToggle {
              checked: PowerProfileService.noctaliaPerformanceMode
              onToggled: checked => PowerProfileService.noctaliaPerformanceMode = checked
            }
          }
        }
      }

      // Brightness slider
      NBox {
        Layout.fillWidth: true
        implicitHeight: brightnessLayout.implicitHeight + Style.margin2L
        visible: showBrightnessSlider && brightnessMonitor && brightnessMonitor.brightnessControlAvailable

        ColumnLayout {
          id: brightnessLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: localBrightness <= 0.001 ? "sun-off" : (localBrightness <= 0.5 ? "brightness-low" : "brightness-high")
              pointSize: Style.fontSizeL
              color: Color.mOnSurface
            }

            NText {
              text: I18n.tr("common.brightness")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: Math.round(localBrightness * 100) + "%"
              color: Color.mOnSurfaceVariant
            }
          }

          NSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: localBrightness
            stepSize: 0.01
            heightRatio: 0.5
            onMoved: {
              localBrightness = value;
              brightnessDebounce.restart();
            }
            onPressedChanged: localBrightnessChanging = pressed
            tooltipText: `${Math.round(localBrightness * 100)}%`

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
              propagateComposedEvents: true
              onWheel: wheel => {
                         const delta = wheel.angleDelta.y || wheel.angleDelta.x;
                         const step = Settings.data.brightness.brightnessStep / 100.0;
                         const increment = delta > 0 ? step : -step;
                         localBrightness = Math.max(0, Math.min(1, localBrightness + increment));
                         brightnessDebounce.restart();
                       }
            }
          }
        }
      }

      // Refresh rate switcher (Hyprland, multi-rate displays only)
      NBox {
        Layout.fillWidth: true
        implicitHeight: refreshRateLayout.implicitHeight + Style.margin2L
        visible: showRefreshRateSwitcher && refreshRateSupported

        ColumnLayout {
          id: refreshRateLayout
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: "refresh"
              pointSize: Style.fontSizeL
              color: Color.mOnSurface
            }

            NText {
              text: I18n.tr("common.refresh-rate")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: `${currentRefreshRate} Hz`
              color: Color.mOnSurfaceVariant
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: refreshRates
              delegate: NButton {
                readonly property bool active: modelData === currentRefreshRate
                Layout.fillWidth: true
                text: `${modelData} Hz`
                fontSize: Style.fontSizeS
                outlined: !active
                backgroundColor: active ? Color.mPrimary : Color.mOnSurfaceVariant
                textColor: Color.mOnPrimary
                onClicked: {
                  if (!active)
                    RefreshRateService.setRefreshRate(screenName, modelData);
                }
              }
            }
          }
        }
      }
    }
  }
}
