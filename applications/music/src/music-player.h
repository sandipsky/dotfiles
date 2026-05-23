#pragma once

#include <gio/gio.h>
#include "music-song.h"

G_BEGIN_DECLS

typedef enum {
  MUSIC_REPEAT_NONE,
  MUSIC_REPEAT_ALL,
  MUSIC_REPEAT_ONE,
} MusicRepeatMode;

#define MUSIC_TYPE_PLAYER (music_player_get_type ())
G_DECLARE_FINAL_TYPE (MusicPlayer, music_player, MUSIC, PLAYER, GObject)

MusicPlayer    *music_player_new            (void);

MusicSong      *music_player_get_current    (MusicPlayer *self);
gboolean        music_player_is_playing     (MusicPlayer *self);
gint64          music_player_get_position   (MusicPlayer *self);   /* seconds */
gint64          music_player_get_duration   (MusicPlayer *self);   /* seconds */
double          music_player_get_volume     (MusicPlayer *self);
gboolean        music_player_get_shuffle    (MusicPlayer *self);
MusicRepeatMode music_player_get_repeat     (MusicPlayer *self);

void            music_player_play_song      (MusicPlayer *self, MusicSong *song);
/* Play `song` from `queue`. If `song` is NULL, plays first item. Keeps a ref to queue. */
void            music_player_play_in_queue  (MusicPlayer *self,
                                             GListModel  *queue,
                                             guint        start_index);

void            music_player_toggle         (MusicPlayer *self);
void            music_player_play           (MusicPlayer *self);
void            music_player_pause          (MusicPlayer *self);
void            music_player_stop           (MusicPlayer *self);
void            music_player_next           (MusicPlayer *self);
void            music_player_previous       (MusicPlayer *self);

void            music_player_seek           (MusicPlayer *self, gint64 seconds);
void            music_player_set_volume     (MusicPlayer *self, double v);
void            music_player_set_shuffle    (MusicPlayer *self, gboolean shuffle);
void            music_player_set_repeat     (MusicPlayer *self, MusicRepeatMode mode);

G_END_DECLS
