pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  Connections {
    target: WallpaperService

    // When the wallpaper changes, regenerate theme if necessary
    function onWallpaperChanged(screenName, path) {
      var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
      if (effectiveMonitor === "" || effectiveMonitor === undefined) {
        effectiveMonitor = Screen.name;
      }

      if (screenName !== effectiveMonitor)
        return;

      // Colors are always generated (from the wallpaper, or from the accent seed when set).
      // With an accent seed the palette is stable across wallpapers, but regeneration is
      // idempotent (skip-identical writes) and keeps wallpaper-dependent templates fresh.
      generateFromWallpaper();
    }
  }

  Connections {
    target: Settings.data.colorSchemes
    function onDarkModeChanged() {
      Logger.d("AppThemeService", "Detected dark mode change");
      generate();
    }
    function onMonitorForColorsChanged() {
      if (Settings.data.colorSchemes.useWallpaperColors) {
        Logger.d("AppThemeService", "Monitor for colors changed to:", Settings.data.colorSchemes.monitorForColors);
        generateFromWallpaper();
      }
    }
    function onGenerationMethodChanged() {
      Logger.d("AppThemeService", "Generation method changed to:", Settings.data.colorSchemes.generationMethod);
      generate();
    }
    function onAccentColorChanged() {
      Logger.d("AppThemeService", "Accent color changed to:", Settings.data.colorSchemes.accentColor);
      generate();
    }
  }

  // PUBLIC FUNCTIONS
  function init() {
    Logger.i("AppThemeService", "Service started");
  }

  function generate() {
    generateFromWallpaper();
  }

  function generateFromWallpaper() {
    var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }

    const wp = WallpaperService.getWallpaper(effectiveMonitor);
    if (!wp) {
      Logger.e("AppThemeService", "No wallpaper found for monitor:", effectiveMonitor);
      return;
    }
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    TemplateProcessor.processWallpaperColors(wp, mode);
  }

}
