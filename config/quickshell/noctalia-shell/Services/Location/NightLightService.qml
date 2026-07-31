pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  // Night Light properties - directly bound to settings
  readonly property var params: Settings.data.nightLight
  property var lastCommand: []

  // Crash tracking for auto-restart
  property int _crashCount: 0
  property int _maxCrashes: 5

  // Manual schedule tracking
  property bool _manualNightPhase: false

  // Kill any stale night light processes on startup to prevent issues after shell restart
  Component.onCompleted: {
    killStaleProcess.running = true;
  }

  Process {
    id: killStaleProcess
    running: false
    command: ["sh", "-c", "pkill -x hyprsunset; pkill -x wlsunset"]
    onExited: function (code, status) {
      if (code === 0) {
        Logger.i("NightLight", "Killed stale night light process from previous session");
      }
      // Now apply the settings after cleanup
      root.apply();
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (root.params.enabled && !runner.running) {
        Logger.w("NightLight", "Restarting after crash...");
        if (root.isScheduledMode()) {
          root.applyManualSchedule();
        } else {
          runner.running = true;
        }
      }
    }
  }

  Timer {
    id: manualScheduleTimer
    repeat: false
    onTriggered: {
      Logger.i("NightLight", "Manual schedule: phase boundary reached");
      root.applyManualSchedule();
    }
  }

  function timeToMinutes(timeStr) {
    var parts = timeStr.split(":").map(Number);
    return parts[0] * 60 + parts[1];
  }

  // hyprsunset has no built-in scheduling, so every non-forced mode is scheduled by us
  function isScheduledMode() {
    return !params.forced;
  }

  // Sunrise/sunset in minutes-since-midnight; auto mode reads today's real times
  // from the weather data, falling back to the manual settings until it arrives
  function scheduleTimes() {
    if (params.autoSchedule) {
      var w = LocationService.data.weather;
      if (w && w.daily && w.daily.sunrise && w.daily.sunrise.length > 0) {
        var sr = new Date(w.daily.sunrise[0]);
        var ss = new Date(w.daily.sunset[0]);
        return {
          "sunrise": sr.getHours() * 60 + sr.getMinutes(),
          "sunset": ss.getHours() * 60 + ss.getMinutes()
        };
      }
    }
    return {
      "sunrise": timeToMinutes(params.manualSunrise),
      "sunset": timeToMinutes(params.manualSunset)
    };
  }

  function isCurrentlyNight() {
    var now = new Date();
    var nowMin = now.getHours() * 60 + now.getMinutes();
    var times = scheduleTimes();
    var sunsetMin = times.sunset;
    var sunriseMin = times.sunrise;

    if (sunsetMin < sunriseMin) {
      // Inverted: e.g. sunset=03:00, sunrise=07:00 → night is [03:00, 07:00)
      return nowMin >= sunsetMin && nowMin < sunriseMin;
    } else {
      // Normal: e.g. sunset=18:00, sunrise=06:00 → night is [18:00, 06:00)
      return nowMin >= sunsetMin || nowMin < sunriseMin;
    }
  }

  function msUntilNextBoundary() {
    var now = new Date();
    var nowMin = now.getHours() * 60 + now.getMinutes();
    var times = scheduleTimes();
    var sunsetMin = times.sunset;
    var sunriseMin = times.sunrise;

    var targetMin = isCurrentlyNight() ? sunriseMin : sunsetMin;
    var diffMin = targetMin - nowMin;
    if (diffMin <= 0)
      diffMin += 1440;

    return diffMin * 60 * 1000 - now.getSeconds() * 1000 - now.getMilliseconds();
  }

  function applyManualSchedule() {
    if (!params.enabled) {
      manualScheduleTimer.stop();
      runner.running = false;
      return;
    }

    var night = isCurrentlyNight();
    _manualNightPhase = night;

    if (!night && `${params.dayTemp}` === "6500") {
      // Day phase at neutral temperature: no filter process needed
      lastCommand = [];
      runner.running = false;
      Logger.i("NightLight", "Schedule: day phase - hyprsunset stopped");
    } else {
      var temp = night ? params.nightTemp : params.dayTemp;
      var cmd = ["hyprsunset", "-t", `${temp}`];

      if (JSON.stringify(cmd) !== JSON.stringify(lastCommand) || !runner.running) {
        lastCommand = cmd;
        runner.command = cmd;
        runner.running = false;
        runner.running = true;
      }
      Logger.i("NightLight", "Schedule: " + (night ? "night" : "day") + " phase - hyprsunset at " + temp + "K");
    }

    var ms = msUntilNextBoundary();
    manualScheduleTimer.interval = Math.max(ms, 1000);
    manualScheduleTimer.restart();
    Logger.i("NightLight", "Manual schedule: next boundary in " + Math.round(ms / 1000) + "s");
  }

  function apply(force = false) {
    // If using LocationService, wait for it to be ready
    if (!params.forced && params.autoSchedule && !LocationService.coordinatesReady) {
      return;
    }

    // Scheduled mode (manual or auto): handle scheduling ourselves
    if (isScheduledMode() && params.enabled) {
      _crashCount = 0;
      restartTimer.stop();
      applyManualSchedule();
      return;
    }

    // Not in scheduled mode - clean up schedule timer
    manualScheduleTimer.stop();

    var command = buildCommand();

    // Compare with previous command to avoid unnecessary restart
    if (force || JSON.stringify(command) !== JSON.stringify(lastCommand)) {
      lastCommand = command;
      runner.command = command;

      // Set running to false so it may restart below if still enabled
      runner.running = false;
    }
    runner.running = params.enabled;
  }

  function buildCommand() {
    // Only forced mode reaches here; scheduled modes go through applyManualSchedule
    var cmd = ["hyprsunset"];
    if (params.forced) {
      // Force immediate full night temperature regardless of time
      cmd.push("-t", `${params.nightTemp}`);
    }
    return cmd;
  }

  // Observe setting changes and location readiness
  Connections {
    target: Settings.data.nightLight
    function onEnabledChanged() {
      apply();
      // Toast: night light toggled
      const enabled = !!Settings.data.nightLight.enabled;
      ToastService.showNotice(I18n.tr("common.night-light"), enabled ? I18n.tr("common.enabled") : I18n.tr("common.disabled"), enabled ? "nightlight-on" : "nightlight-off");
    }
    function onForcedChanged() {
      apply();
      if (Settings.data.nightLight.enabled) {
        ToastService.showNotice(I18n.tr("common.night-light"), Settings.data.nightLight.forced ? I18n.tr("toast.night-light.forced") : I18n.tr("toast.night-light.normal"), Settings.data.nightLight.forced ? "nightlight-forced" : "nightlight-on");
      }
    }
    function onNightTempChanged() {
      apply();
    }
    function onDayTempChanged() {
      apply();
    }
    function onManualSunriseChanged() {
      apply();
    }
    function onManualSunsetChanged() {
      apply();
    }
    function onAutoScheduleChanged() {
      apply();
    }
  }

  Connections {
    target: LocationService
    function onCoordinatesReadyChanged() {
      if (LocationService.coordinatesReady) {
        root.apply();
      }
    }
  }

  Timer {
    id: resumeRetryTimer
    interval: 2000
    repeat: false
    onTriggered: {
      Logger.i("NightLight", "Resume retry - re-applying night light again");
      root.apply(true);
    }
  }

  Connections {
    target: Time
    function onResumed() {
      Logger.i("NightLight", "System resumed - re-applying night light");
      root.apply(true);
      resumeRetryTimer.restart();
    }
  }

  // Foreground process runner
  Process {
    id: runner
    running: false
    onStarted: {
      Logger.i("NightLight", "Hyprsunset started:", runner.command);
      // Reset crash count on successful start
      if (root._crashCount > 0) {
        root._crashCount = 0;
      }
    }
    onExited: function (code, status) {
      if (root.params.enabled && root.isScheduledMode()) {
        // Scheduled mode: only treat as crash if we're in the night phase
        if (root._manualNightPhase) {
          root._crashCount++;
          if (root._crashCount <= root._maxCrashes) {
            Logger.w("NightLight", "Hyprsunset exited unexpectedly during night phase (code: " + code + "), restarting in 2s... (attempt " + root._crashCount + "/" + root._maxCrashes + ")");
            restartTimer.start();
          } else {
            Logger.e("NightLight", "Hyprsunset crashed too many times (" + root._maxCrashes + "), giving up");
          }
        } else {
          Logger.i("NightLight", "Hyprsunset exited (day phase):", code, status);
          root._crashCount = 0;
        }
      } else if (root.params.enabled) {
        // Forced mode: any exit while enabled is a crash
        root._crashCount++;
        if (root._crashCount <= root._maxCrashes) {
          Logger.w("NightLight", "Hyprsunset exited unexpectedly (code: " + code + "), restarting in 2s... (attempt " + root._crashCount + "/" + root._maxCrashes + ")");
          restartTimer.start();
        } else {
          Logger.e("NightLight", "Hyprsunset crashed too many times (" + root._maxCrashes + "), giving up");
        }
      } else {
        Logger.i("NightLight", "Hyprsunset exited (disabled):", code, status);
        root._crashCount = 0;
      }
    }
  }
}
