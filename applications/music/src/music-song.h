#pragma once

#include <glib-object.h>

G_BEGIN_DECLS

#define MUSIC_TYPE_SONG (music_song_get_type ())
G_DECLARE_FINAL_TYPE (MusicSong, music_song, MUSIC, SONG, GObject)

MusicSong  *music_song_new                 (const char *uri);
MusicSong  *music_song_new_from_path       (const char *path);

const char *music_song_get_uri             (MusicSong *self);
const char *music_song_get_title           (MusicSong *self);
const char *music_song_get_artist          (MusicSong *self);
const char *music_song_get_album           (MusicSong *self);
gint64      music_song_get_duration        (MusicSong *self);
gint64      music_song_get_mtime           (MusicSong *self);
gboolean    music_song_get_favorite        (MusicSong *self);
gboolean    music_song_get_has_metadata    (MusicSong *self);

void        music_song_set_title           (MusicSong *self, const char *title);
void        music_song_set_artist          (MusicSong *self, const char *artist);
void        music_song_set_album           (MusicSong *self, const char *album);
void        music_song_set_duration        (MusicSong *self, gint64 duration_seconds);
void        music_song_set_mtime           (MusicSong *self, gint64 mtime);
void        music_song_set_favorite        (MusicSong *self, gboolean favorite);
void        music_song_set_has_metadata    (MusicSong *self, gboolean has);

G_END_DECLS
