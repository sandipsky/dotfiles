desktop_conf = configuration_data()
desktop_conf.set('APP_ID', app_id)
desktop_conf.set('BINDIR', get_option('prefix') / get_option('bindir'))

desktop_file = configure_file(
  input:         app_id + '.desktop.in',
  output:        app_id + '.desktop',
  configuration: desktop_conf,
)

install_data(desktop_file,
  install_dir: get_option('datadir') / 'applications',
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

# Icons (derived from GNOME Music, GPL-2.0-or-later — see CREDITS)
install_data(app_id + '.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)
install_data(app_id + '-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)
