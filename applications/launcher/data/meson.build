# Compiled-in resources: stylesheet + the three glyph icons the launcher draws
# for calculator / web / search results. Bundled so the binary is self-contained
# and doesn't depend on the Quickshell icon dir at runtime.
launcher_resources = gnome.compile_resources(
  'launcher-resources',
  'launcher.gresource.xml',
  source_dir: meson.current_source_dir(),
  c_name: 'launcher',
)

# systemd user unit — installed into the XDG_DATA_HOME unit search path
# (~/.local/share/systemd/user) so the resident service starts on login.
install_data('launcher.service',
  install_dir: get_option('datadir') / 'systemd' / 'user',
)

# App icons (original — see CREDITS). No .desktop entry: the launcher is a
# keybind-driven resident service, not something to show in the app grid.
install_data(app_id + '.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)
install_data(app_id + '-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)
