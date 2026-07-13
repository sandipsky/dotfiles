pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Queries and switches monitor refresh rates via hyprctl (Hyprland only).
// Exposes, per monitor, the distinct refresh rates available at the *current*
// resolution so the UI can offer a simple switcher on supported displays.
Singleton {
  id: root

  // Map: monitor name -> { current, rates: [int...], width, height, x, y, scale, transform }
  property var monitorInfo: ({})
  // Bumped whenever monitorInfo is replaced, so bindings re-evaluate.
  property int revision: 0

  // Refresh-rate switching is currently implemented for Hyprland only.
  readonly property bool available: CompositorService.isHyprland

  function refresh(): void {
    if (!CompositorService.isHyprland)
      return;
    queryProc.running = true;
  }

  function getInfo(screenName): var {
    return (screenName && monitorInfo[screenName]) ? monitorInfo[screenName] : null;
  }

  // Distinct refresh rates (rounded ints) available at the current resolution.
  function getRates(screenName): var {
    var info = getInfo(screenName);
    return info ? info.rates : [];
  }

  function getCurrentRate(screenName): int {
    var info = getInfo(screenName);
    return info ? info.current : 0;
  }

  // A display is "supported" when it advertises more than one rate at its
  // current resolution, i.e. there is actually something to switch between.
  function isSupported(screenName): bool {
    return available && getRates(screenName).length > 1;
  }

  function setRefreshRate(screenName, rate): void {
    var info = getInfo(screenName);
    if (!info)
      return;

    var res = info.width + "x" + info.height + "@" + rate;
    var pos = info.x + "x" + info.y;
    var arg = screenName + "," + res + "," + pos + "," + info.scale;
    if (info.transform && info.transform !== 0)
      arg += ",transform," + info.transform;

    setProc.pendingRate = rate;
    setProc.command = ["hyprctl", "keyword", "monitor", arg];
    setProc.running = true;
  }

  Process {
    id: queryProc
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim());
          var map = {};
          for (var i = 0; i < data.length; i++) {
            var m = data[i];
            if (!m.name)
              continue;

            var w = m.width;
            var h = m.height;
            var rates = [];
            var seen = ({});
            var modes = m.availableModes || [];
            for (var j = 0; j < modes.length; j++) {
              // Mode strings look like "1920x1080@60.00Hz".
              var match = modes[j].match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
              if (!match)
                continue;
              if (parseInt(match[1]) !== w || parseInt(match[2]) !== h)
                continue;
              var r = Math.round(parseFloat(match[3]));
              if (!seen[r]) {
                seen[r] = true;
                rates.push(r);
              }
            }
            rates.sort((a, b) => a - b);

            map[m.name] = {
              "current": Math.round(m.refreshRate || 0),
              "rates": rates,
              "width": w,
              "height": h,
              "x": m.x || 0,
              "y": m.y || 0,
              "scale": m.scale || 1,
              "transform": m.transform || 0
            };
          }
          root.monitorInfo = map;
          root.revision++;
        } catch (e) {
          Logger.e("RefreshRate", "Failed to parse monitors:", e);
        }
      }
    }
  }

  Process {
    id: setProc
    property int pendingRate: 0
    stdout: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        ToastService.showNotice(I18n.tr("common.refresh-rate"), I18n.tr("toast.refresh-rate.changed", {
                                                                          "rate": setProc.pendingRate
                                                                        }), "refresh");
        root.refresh();
      } else {
        ToastService.showWarning(I18n.tr("common.refresh-rate"), I18n.tr("toast.refresh-rate.failed"));
      }
    }
  }
}
