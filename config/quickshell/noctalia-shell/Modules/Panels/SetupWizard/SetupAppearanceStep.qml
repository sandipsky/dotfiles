import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.Theming
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Beautiful header with icon
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginL
    spacing: Style.marginM

    Rectangle {
      width: 40
      height: 40
      radius: Style.radiusL
      color: Color.mSurfaceVariant
      opacity: 0.6

      NIcon {
        icon: "palette"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        anchors.centerIn: parent
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: I18n.tr("common.appearance")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mPrimary
      }

      NText {
        text: I18n.tr("setup.appearance.subheader")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }
    }
  }

  NScrollView {
    id: appearanceScrollView
    Layout.fillWidth: true
    Layout.fillHeight: true
    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded

    ColumnLayout {
      width: appearanceScrollView.availableWidth
      spacing: Style.marginM

      // Dark Mode Toggle
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Rectangle {
          width: 28
          height: 28
          radius: Style.radiusM
          color: Color.mSurface

          NIcon {
            icon: "moon"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
            anchors.centerIn: parent
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: I18n.tr("tooltips.switch-to-dark-mode")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }

          NText {
            text: I18n.tr("panels.color-scheme.dark-mode-switch-description")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }

        NToggle {
          checked: Settings.data.colorSchemes.darkMode
          onToggled: checked => Settings.data.colorSchemes.darkMode = checked
        }
      }

      // Bottom spacer
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.marginL
      }
    }
  }

}
