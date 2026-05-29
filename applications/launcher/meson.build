project('launcher', 'c',
  version: '0.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.62.0',
  default_options: [
    'warning_level=2',
    'c_std=gnu11',
    'buildtype=debugoptimized',
  ],
)

app_id = 'dev.sandip.Launcher'

cc = meson.get_compiler('c')

gtk_dep      = dependency('gtk4',         version: '>= 4.10')
adw_dep      = dependency('libadwaita-1', version: '>= 1.4')
gio_unix_dep = dependency('gio-unix-2.0', version: '>= 2.66')
m_dep        = cc.find_library('m', required: false)

gnome = import('gnome')

common_c_args = [
  '-DG_LOG_DOMAIN="Launcher"',
  '-DAPP_ID="' + app_id + '"',
  '-DAPP_VERSION="' + meson.project_version() + '"',
]

# Silence a few warnings that fire on GTK/GObject macro use
foreach a : ['-Wno-unused-parameter', '-Wno-cast-function-type']
  if cc.has_argument(a)
    common_c_args += a
  endif
endforeach

subdir('data')
subdir('src')

gnome.post_install(
  gtk_update_icon_cache: true,
)
