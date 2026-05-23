music_sources = files(
  'main.c',
  'music-application.c',
  'music-window.c',
  'music-song.c',
  'music-playlist.c',
  'music-library.c',
  'music-player.c',
  'music-song-row.c',
  'music-player-bar.c',
  'music-all-songs-view.c',
  'music-playlists-view.c',
  'music-preferences.c',
)

music_deps = [gtk_dep, adw_dep, gst_dep, gst_pbu_dep, m_dep]

executable('music',
  music_sources,
  dependencies:        music_deps,
  c_args:              common_c_args,
  include_directories: include_directories('.'),
  install:             true,
)
