#pragma once

#include <gtk/gtk.h>
#include "music-song.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_SONG_ROW (music_song_row_get_type ())
G_DECLARE_FINAL_TYPE (MusicSongRow, music_song_row, MUSIC, SONG_ROW, GtkBox)

GtkWidget *music_song_row_new          (void);
void       music_song_row_set_song     (MusicSongRow *self, MusicSong *song);
MusicSong *music_song_row_get_song     (MusicSongRow *self);
void       music_song_row_set_playing  (MusicSongRow *self, gboolean playing);

G_END_DECLS
