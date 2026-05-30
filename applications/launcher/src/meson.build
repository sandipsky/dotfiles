launcher_sources = files(
  'main.c',
  'launcher-application.c',
  'launcher-window.c',
  'launcher-result.c',
  'launcher-result-row.c',
  'launcher-search.c',
)

launcher_deps = [gtk_dep, adw_dep, gio_unix_dep, m_dep, layer_shell_dep]

executable('launcher',
  launcher_sources,
  launcher_resources,
  dependencies:        launcher_deps,
  c_args:              common_c_args,
  include_directories: include_directories('.'),
  install:             true,
)
