import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.MainScreen
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // Positioning
  readonly property string controlCenterPosition: Settings.data.controlCenter.position

  // Check if there's a bar on this screen
  readonly property bool hasBarOnScreen: {
    var monitors = Settings.data.bar.monitors || [];
    return monitors.length === 0 || monitors.includes(screen?.name);
  }

  // When position is "close_to_bar_button" but there's no bar, fall back to center
  readonly property bool shouldCenter: controlCenterPosition === "close_to_bar_button" && !hasBarOnScreen

  panelAnchorHorizontalCenter: shouldCenter || (controlCenterPosition !== "close_to_bar_button" && (controlCenterPosition.endsWith("_center") || controlCenterPosition === "center"))
  panelAnchorVerticalCenter: shouldCenter || controlCenterPosition === "center"
  panelAnchorLeft: !shouldCenter && controlCenterPosition !== "close_to_bar_button" && controlCenterPosition.endsWith("_left")
  panelAnchorRight: !shouldCenter && controlCenterPosition !== "close_to_bar_button" && controlCenterPosition.endsWith("_right")
  panelAnchorBottom: !shouldCenter && controlCenterPosition !== "close_to_bar_button" && controlCenterPosition.startsWith("bottom_")
  panelAnchorTop: !shouldCenter && controlCenterPosition !== "close_to_bar_button" && controlCenterPosition.startsWith("top_")

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: {
    var height = 0;
    var count = 0;
    for (var i = 0; i < Settings.data.controlCenter.cards.length; i++) {
      const card = Settings.data.controlCenter.cards[i];
      if (!card.enabled)
        continue;
      const contributes = (card.id !== "weather-card" || Settings.data.location.weatherEnabled);
      if (!contributes)
        continue;
      count++;
      switch (card.id) {
      case "profile-card":
        height += profileHeight;
        break;
      case "shortcuts-card":
        height += shortcutsHeight;
        break;
      case "audio-card":
        height += audioHeight;
        break;
      case "brightness-card":
        height += brightnessHeight;
        break;
      case "weather-card":
        height += weatherHeight;
        break;
      case "media-card":
        height += mediaHeight;
        break;
      case "sysmon-card":
        height += sysmonHeight;
        break;
      default:
        break;
      }
    }
    return height + (count + 1) * Style.marginL;
  }

  readonly property int profileHeight: Math.round(64 * Style.uiScaleRatio)
  readonly property int shortcutsHeight: Math.round(52 * Style.uiScaleRatio)
  readonly property int audioHeight: Math.round(60 * Style.uiScaleRatio)
  readonly property int brightnessHeight: Math.round(60 * Style.uiScaleRatio)
  readonly property int mediaHeight: Math.round(220 * Style.uiScaleRatio)
  readonly property int sysmonHeight: Math.round(84 * Style.uiScaleRatio)

  // We keep a dynamic weather height due to a more complex layout and font scaling
  property int weatherHeight: Math.round(210 * Style.uiScaleRatio)

  onOpened: {
    MediaService.autoSwitchingPaused = true;
  }

  onClosed: {
    MediaService.autoSwitchingPaused = false;
  }

  panelContent: Item {
    id: panelContent

    ColumnLayout {
      id: layout
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginL

      Repeater {
        model: Settings.data.controlCenter.cards
        Loader {
          active: modelData.enabled && (modelData.id !== "weather-card" || Settings.data.location.weatherEnabled)
          visible: active
          Layout.fillWidth: true
          Layout.preferredHeight: {
            switch (modelData.id) {
            case "profile-card":
              return profileHeight;
            case "shortcuts-card":
              return shortcutsHeight;
            case "audio-card":
              return audioHeight;
            case "brightness-card":
              return brightnessHeight;
            case "weather-card":
              return weatherHeight;
            case "media-card":
              return mediaHeight;
            case "sysmon-card":
              return sysmonHeight;
            default:
              return 0;
            }
          }
          sourceComponent: {
            switch (modelData.id) {
            case "profile-card":
              return profileCard;
            case "shortcuts-card":
              return shortcutsCard;
            case "audio-card":
              return audioCard;
            case "brightness-card":
              return brightnessCard;
            case "weather-card":
              return weatherCard;
            case "media-card":
              return mediaCard;
            case "sysmon-card":
              return sysmonCard;
            }
          }
        }
      }
    }

    Component {
      id: profileCard
      ProfileCard {}
    }

    Component {
      id: shortcutsCard
      ShortcutsCard {}
    }

    Component {
      id: audioCard
      AudioCard {}
    }

    Component {
      id: brightnessCard
      BrightnessCard {}
    }

    Component {
      id: weatherCard
      WeatherCard {
        Component.onCompleted: {
          root.weatherHeight = this.height;
        }
      }
    }

    Component {
      id: mediaCard
      MediaCard {}
    }

    Component {
      id: sysmonCard
      SystemMonitorCard {}
    }
  }
}
