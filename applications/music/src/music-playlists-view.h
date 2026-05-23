#pragma once

#include <adwaita.h>
#include "music-library.h"
#include "music-player.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_PLAYLISTS_VIEW (music_playlists_view_get_type ())
G_DECLARE_FINAL_TYPE (MusicPlaylistsView, music_playlists_view, MUSIC, PLAYLISTS_VIEW, AdwBin)

GtkWidget *music_playlists_view_new (MusicLibrary *library, MusicPlayer *player);

G_END_DECLS
