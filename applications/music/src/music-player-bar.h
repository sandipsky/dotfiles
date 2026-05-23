#pragma once

#include <gtk/gtk.h>
#include "music-player.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_PLAYER_BAR (music_player_bar_get_type ())
G_DECLARE_FINAL_TYPE (MusicPlayerBar, music_player_bar, MUSIC, PLAYER_BAR, GtkBox)

GtkWidget *music_player_bar_new (MusicPlayer *player);

G_END_DECLS
