#pragma once

#include <gtk/gtk.h>
#include "music-library.h"
#include "music-player.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_ALL_SONGS_VIEW (music_all_songs_view_get_type ())
G_DECLARE_FINAL_TYPE (MusicAllSongsView, music_all_songs_view, MUSIC, ALL_SONGS_VIEW, GtkBox)

GtkWidget *music_all_songs_view_new          (MusicLibrary *library,
                                              MusicPlayer  *player);
void       music_all_songs_view_toggle_search (MusicAllSongsView *self);

G_END_DECLS
