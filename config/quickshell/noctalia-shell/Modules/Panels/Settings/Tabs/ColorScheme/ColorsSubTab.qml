import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var timeOptions
  property var screen

  // Preset accent seeds; the full scheme is generated from the chosen color
  // by the same material pipeline used for wallpaper colors.
  readonly property var accentPresets: ["#0078D4", "#744DA9", "#C30052", "#E81123", "#F7630C", "#FFB900", "#107C10", "#00B7C3"]

  readonly property string currentAccent: Settings.data.colorSchemes.accentColor

  function setAccent(hexColor) {
    Settings.data.colorSchemes.accentColor = hexColor;
    // AppThemeService regenerates via onAccentColorChanged
  }

  NToggle {
    label: I18n.tr("tooltips.switch-to-dark-mode")
    description: I18n.tr("panels.color-scheme.dark-mode-switch-description")
    checked: Settings.data.colorSchemes.darkMode
    onToggled: checked => {
                 Settings.data.colorSchemes.darkMode = checked;
               }
  }

  NToggle {
    label: I18n.tr("panels.color-scheme.sync-gsettings-label")
    description: I18n.tr("panels.color-scheme.sync-gsettings-description")
    checked: Settings.data.colorSchemes.syncGsettings
    defaultValue: Settings.getDefaultValue("colorSchemes.syncGsettings")
    onToggled: checked => {
                 Settings.data.colorSchemes.syncGsettings = checked;
                 if (checked)
                 ColorSchemeService.pushSystemColorScheme();
               }
  }

  NComboBox {
    label: I18n.tr("panels.color-scheme.dark-mode-mode-label")
    description: I18n.tr("panels.color-scheme.dark-mode-mode-description")

    model: [
      {
        "name": I18n.tr("panels.color-scheme.dark-mode-mode-off"),
        "key": "off"
      },
      {
        "name": I18n.tr("panels.color-scheme.dark-mode-mode-manual"),
        "key": "manual"
      },
      {
        "name": I18n.tr("common.location"),
        "key": "location"
      }
    ]

    currentKey: Settings.data.colorSchemes.schedulingMode
    defaultValue: Settings.getDefaultValue("colorSchemes.schedulingMode")

    onSelected: key => {
                  Settings.data.colorSchemes.schedulingMode = key;
                  AppThemeService.generate();
                }
  }

  ColumnLayout {
    spacing: Style.marginS
    visible: Settings.data.colorSchemes.schedulingMode === "manual"

    NLabel {
      label: I18n.tr("panels.display.night-light-manual-schedule-label")
      description: I18n.tr("panels.display.night-light-manual-schedule-description")
    }

    RowLayout {
      Layout.fillWidth: false
      spacing: Style.marginS

      NText {
        text: I18n.tr("panels.display.night-light-manual-schedule-sunrise")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: Settings.data.colorSchemes.manualSunrise
        placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-start")
        onSelected: key => Settings.data.colorSchemes.manualSunrise = key
        minimumWidth: 120
      }

      Item {
        Layout.preferredWidth: 20
      }

      NText {
        text: I18n.tr("panels.display.night-light-manual-schedule-sunset")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: Settings.data.colorSchemes.manualSunset
        placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-stop")
        onSelected: key => Settings.data.colorSchemes.manualSunset = key
        minimumWidth: 120
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // ====================================================================
  // Accent color: auto (wallpaper) or a chosen seed color
  // ====================================================================
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("panels.color-scheme.accent-color-title")
      description: I18n.tr("panels.color-scheme.accent-color-desc")
      Layout.fillWidth: true
    }

    RowLayout {
      id: accentRow
      spacing: Style.marginM
      Layout.fillWidth: true

      readonly property int diameter: Math.round(Style.baseWidgetSize * 0.9 * Style.uiScaleRatio)

      // Auto: extract the seed from the wallpaper
      Rectangle {
        implicitWidth: accentRow.diameter
        implicitHeight: accentRow.diameter
        radius: accentRow.diameter * 0.5
        color: Color.mSurfaceVariant
        border.width: Style.borderM
        border.color: (root.currentAccent === "" || autoMouseArea.containsMouse) ? Color.mOnSurface : Color.mOutline

        NIcon {
          icon: "wallpaper-selector"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          anchors.centerIn: parent
        }

        MouseArea {
          id: autoMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: TooltipService.show(parent, I18n.tr("panels.color-scheme.accent-color-auto"))
          onExited: TooltipService.hide()
          onClicked: root.setAccent("")
        }
      }

      // Preset accent swatches
      Repeater {
        model: root.accentPresets

        Rectangle {
          implicitWidth: accentRow.diameter
          implicitHeight: accentRow.diameter
          radius: accentRow.diameter * 0.5
          color: modelData
          border.width: Style.borderM
          border.color: (root.currentAccent.toLowerCase() === modelData.toLowerCase() || presetMouseArea.containsMouse) ? Color.mOnSurface : Color.mOutline

          NIcon {
            visible: root.currentAccent.toLowerCase() === modelData.toLowerCase()
            icon: "check"
            pointSize: Style.fontSizeS
            color: "#FFFFFF"
            anchors.centerIn: parent
          }

          MouseArea {
            id: presetMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setAccent(modelData)
          }
        }
      }
    }

    // Custom accent via the color picker dialog
    RowLayout {
      spacing: Style.marginM
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("panels.color-scheme.accent-color-custom-label")
        description: I18n.tr("panels.color-scheme.accent-color-custom-desc")
      }

      NColorPicker {
        screen: root.screen
        selectedColor: root.currentAccent !== "" ? root.currentAccent : Color.mPrimary
        onColorSelected: color => {
                           root.setAccent(color.toString());
                         }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.color-scheme.wallpaper-monitor-source-label")
    description: I18n.tr("panels.color-scheme.wallpaper-monitor-source-description")
    enabled: root.currentAccent === ""
    model: {
      var m = [];
      if (Quickshell.screens) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screen = Quickshell.screens[i];
          var name = screen.name;
          var displayName = name + " (" + screen.width + "x" + screen.height + ")";
          m.push({
                   "key": name,
                   "name": displayName
                 });
        }
      }
      return m;
    }
    currentKey: Settings.data.colorSchemes.monitorForColors || (screen ? screen.name : "")
    onSelected: key => {
                  Settings.data.colorSchemes.monitorForColors = key;
                  AppThemeService.generate();
                }
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.color-scheme.wallpaper-method-label")
    description: I18n.tr("panels.color-scheme.wallpaper-method-description")
    model: TemplateProcessor.schemeTypes
    currentKey: Settings.data.colorSchemes.generationMethod
    onSelected: key => {
                  Settings.data.colorSchemes.generationMethod = key;
                  AppThemeService.generate();
                }
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: descriptionColumn.implicitHeight + Style.margin2L
    color: Color.mSurface

    Column {
      id: descriptionColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("panels.color-scheme.method-description." + Settings.data.colorSchemes.generationMethod)
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }

      Row {
        id: colorPreviewRow
        spacing: Style.marginS

        property int diameter: 16 * Style.uiScaleRatio

        Repeater {
          model: [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError]

          Rectangle {
            width: colorPreviewRow.diameter
            height: colorPreviewRow.diameter
            radius: width * 0.5
            color: modelData
          }
        }
      }
    }
  }
}
