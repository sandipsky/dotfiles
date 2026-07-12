import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(500 * Style.uiScaleRatio)

  // Refresh the profile list every time the panel opens
  onOpened: VPNService.refresh()

  panelContent: Rectangle {
    id: panelContent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: VPNService.hasActiveConnection ? "shield-lock" : "shield"
            pointSize: Style.fontSizeXXL
            color: VPNService.hasActiveConnection ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          NLabel {
            label: I18n.tr("vpn.panel.title")
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "plus"
            tooltipText: I18n.tr("vpn.panel.import")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !VPNService.importing
            onClicked: importPicker.openFilePicker()
          }

          NIconButton {
            icon: "refresh"
            tooltipText: I18n.tr("vpn.panel.refresh")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !VPNService.refreshing
            onClicked: VPNService.refresh()
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      NScrollView {
        id: vpnScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.mSurface

        ColumnLayout {
          id: profilesList
          width: vpnScrollView.availableWidth
          spacing: Style.marginM

          // Empty state when no VPN profiles are configured
          NBox {
            id: emptyBox
            visible: VPNService.activeConnections.length === 0 && VPNService.inactiveConnections.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: emptyColumn.implicitHeight + Style.margin2M

            ColumnLayout {
              id: emptyColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }

              NIcon {
                icon: "shield-off"
                pointSize: 48
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: I18n.tr("vpn.panel.no-profiles")
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: I18n.tr("vpn.panel.no-profiles-hint")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }

              NButton {
                text: I18n.tr("vpn.panel.import")
                icon: "plus"
                Layout.alignment: Qt.AlignHCenter
                enabled: !VPNService.importing
                onClicked: importPicker.openFilePicker()
              }

              Item {
                Layout.fillHeight: true
              }
            }
          }

          // One row per VPN profile: active connections first, then inactive
          Repeater {
            model: {
              const list = [];
              const active = VPNService.activeConnections;
              for (let i = 0; i < active.length; ++i) {
                list.push(active[i]);
              }
              const inactive = VPNService.inactiveConnections;
              for (let i = 0; i < inactive.length; ++i) {
                list.push(inactive[i]);
              }
              return list;
            }

            delegate: NBox {
              id: profileBox
              required property var modelData
              property bool confirmingDelete: false
              Layout.fillWidth: true
              Layout.preferredHeight: Math.max(normalRow.implicitHeight, confirmRow.implicitHeight) + Style.margin2M

              readonly property bool isConnecting: VPNService.connecting && VPNService.connectingUuid === modelData.uuid
              readonly property bool isDisconnecting: VPNService.disconnecting && VPNService.disconnectingUuid === modelData.uuid
              readonly property bool isRemoving: VPNService.removing && VPNService.removingUuid === modelData.uuid
              // Block interaction on every row while any operation is in flight
              readonly property bool anyBusy: VPNService.connecting || VPNService.disconnecting || VPNService.removing

              // Normal state: connect/disconnect toggle + delete button
              RowLayout {
                id: normalRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS
                visible: !profileBox.confirmingDelete

                NToggle {
                  Layout.fillWidth: true
                  icon: modelData.active ? "shield-lock" : "shield"
                  label: modelData.name
                  description: {
                    if (profileBox.isConnecting) {
                      return I18n.tr("vpn.panel.connecting");
                    }
                    if (profileBox.isDisconnecting) {
                      return I18n.tr("vpn.panel.disconnecting");
                    }
                    if (profileBox.isRemoving) {
                      return I18n.tr("vpn.panel.removing");
                    }
                    return modelData.active ? I18n.tr("vpn.panel.connected") : I18n.tr("vpn.panel.disconnected");
                  }
                  checked: modelData.active
                  enabled: !profileBox.anyBusy
                  baseSize: Style.baseWidgetSize * 0.65
                  onToggled: checked => {
                               if (checked) {
                                 VPNService.connect(modelData.uuid);
                               } else {
                                 VPNService.disconnect(modelData.uuid);
                               }
                             }
                }

                NIconButton {
                  icon: "trash"
                  tooltipText: I18n.tr("vpn.panel.delete")
                  baseSize: Style.baseWidgetSize * 0.7
                  colorFg: Color.mError
                  enabled: !profileBox.anyBusy
                  onClicked: profileBox.confirmingDelete = true
                }
              }

              // Confirm-delete state: warning + confirm / cancel
              RowLayout {
                id: confirmRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS
                visible: profileBox.confirmingDelete

                NIcon {
                  icon: "trash"
                  pointSize: Style.fontSizeL
                  color: Color.mError
                }

                NText {
                  text: I18n.tr("vpn.panel.delete-confirm")
                  pointSize: Style.fontSizeS
                  color: Color.mError
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                NButton {
                  text: I18n.tr("vpn.panel.delete")
                  fontSize: Style.fontSizeXS
                  backgroundColor: Color.mError
                  textColor: Color.mOnError
                  enabled: !profileBox.anyBusy
                  onClicked: {
                    VPNService.remove(modelData.uuid);
                    profileBox.confirmingDelete = false;
                  }
                }

                NIconButton {
                  icon: "close"
                  tooltipText: I18n.tr("common.cancel")
                  baseSize: Style.baseWidgetSize * 0.7
                  onClicked: profileBox.confirmingDelete = false
                }
              }
            }
          }
        }
      }
    }

    NFilePicker {
      id: importPicker
      title: I18n.tr("vpn.panel.import-title")
      initialPath: (Quickshell.env("HOME") || "/home") + "/Downloads"
      nameFilters: ["*.conf", "*.ovpn", "*"]
      onAccepted: paths => {
                    if (paths && paths.length > 0) {
                      VPNService.importConfig(paths[0]);
                    }
                  }
    }
  }
}
