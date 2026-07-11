import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL

  NTextInputButton {
    label: "Lock screen background"
    description: "Custom image for the lock screen. Leave empty to use the current wallpaper."
    text: Settings.data.general.lockScreenWallpaper
    placeholderText: "Current wallpaper"
    buttonIcon: "photo"
    buttonTooltip: "Select an image"
    onInputTextChanged: text => Settings.data.general.lockScreenWallpaper = text
    onButtonClicked: {
      lockWallpaperPicker.openFilePicker();
    }
  }

  NFilePicker {
    id: lockWallpaperPicker
    title: "Select lock screen background"
    selectionMode: "files"
    initialPath: Settings.preprocessPath(Settings.data.general.lockScreenWallpaper).substr(0, Settings.preprocessPath(Settings.data.general.lockScreenWallpaper).lastIndexOf("/")) || Quickshell.env("HOME")
    nameFilters: ImageCacheService.basicImageFilters
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.general.lockScreenWallpaper = paths[0];
                  }
                }
  }

  NSearchableComboBox {
    label: "Lock screen font"
    description: "Font used for the clock and date on the lock screen."
    model: FontService.availableFonts
    currentKey: Settings.data.general.lockScreenFont || Settings.data.ui.fontFixed
    placeholder: "Select a font"
    searchPlaceholder: "Search fonts"
    popupHeight: 420
    defaultValue: Settings.getDefaultValue("general.lockScreenFont")
    settingsPath: "general.lockScreenFont"
    onSelected: key => Settings.data.general.lockScreenFont = key
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.password-chars-label")
    description: I18n.tr("panels.lock-screen.password-chars-description")
    checked: Settings.data.general.passwordChars
    onToggled: checked => Settings.data.general.passwordChars = checked
    defaultValue: Settings.getDefaultValue("general.passwordChars")
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.lock-screen-animations-label")
    description: I18n.tr("panels.lock-screen.lock-screen-animations-description")
    checked: Settings.data.general.lockScreenAnimations
    onToggled: checked => Settings.data.general.lockScreenAnimations = checked
    defaultValue: Settings.getDefaultValue("general.lockScreenAnimations")
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.lock-screen.lock-screen-blur-strength-label")
    description: I18n.tr("panels.lock-screen.lock-screen-blur-strength-description")
    from: 0.0
    to: 1.0
    stepSize: 0.01
    showReset: true
    value: Settings.data.general.lockScreenBlur
    onMoved: value => Settings.data.general.lockScreenBlur = value
    text: ((Settings.data.general.lockScreenBlur) * 100).toFixed(0) + "%"
    defaultValue: Settings.getDefaultValue("general.lockScreenBlur")
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.lock-screen.lock-screen-tint-strength-label")
    description: I18n.tr("panels.lock-screen.lock-screen-tint-strength-description")
    from: 0.0
    to: 1.0
    stepSize: 0.01
    showReset: true
    value: Settings.data.general.lockScreenTint
    onMoved: value => Settings.data.general.lockScreenTint = value
    text: ((Settings.data.general.lockScreenTint) * 100).toFixed(0) + "%"
    defaultValue: Settings.getDefaultValue("general.lockScreenTint")
  }
}
