project('music', 'c',
  version: '0.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.62.0',
  default_options: [
    'warning_level=2',
    'c_std=gnu11',
    'buildtype=debugoptimized',
  ],
)

app_id = 'dev.sandip.Music'

cc = meson.get_compiler('c')

gtk_dep     = dependency('gtk4',                   version: '>= 4.10')
adw_dep     = dependency('libadwaita-1',           version: '>= 1.4')
gst_dep     = dependency('gstreamer-1.0',          version: '>= 1.20')
gst_pbu_dep = dependency('gstreamer-pbutils-1.0',  version: '>= 1.20')
m_dep       = cc.find_library('m', required: false)

common_c_args = [
  '-DG_LOG_DOMAIN="Music"',
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

gnome = import('gnome')
gnome.post_install(
  update_desktop_database: true,
)
