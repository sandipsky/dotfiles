#pragma once

#include <gio/gio.h>
#include "music-song.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_PLAYLIST (music_playlist_get_type ())
G_DECLARE_FINAL_TYPE (MusicPlaylist, music_playlist, MUSIC, PLAYLIST, GObject)

MusicPlaylist *music_playlist_new         (const char *name);
const char    *music_playlist_get_name    (MusicPlaylist *self);
void           music_playlist_set_name    (MusicPlaylist *self, const char *name);
GListModel    *music_playlist_get_songs   (MusicPlaylist *self);
guint          music_playlist_get_n_songs (MusicPlaylist *self);

void           music_playlist_add_song    (MusicPlaylist *self, MusicSong *song);
void           music_playlist_remove_song (MusicPlaylist *self, guint position);
gboolean       music_playlist_contains    (MusicPlaylist *self, MusicSong *song);

G_END_DECLS
