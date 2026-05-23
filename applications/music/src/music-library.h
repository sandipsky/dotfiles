#pragma once

#include <gio/gio.h>
#include "music-song.h"
#include "music-playlist.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_LIBRARY (music_library_get_type ())
G_DECLARE_FINAL_TYPE (MusicLibrary, music_library, MUSIC, LIBRARY, GObject)

MusicLibrary  *music_library_get_default          (void);

GListModel    *music_library_get_songs            (MusicLibrary *self);
GListModel    *music_library_get_playlists        (MusicLibrary *self);

/* Returned pointer array is owned by the library, do not modify or free. */
GPtrArray     *music_library_get_directories      (MusicLibrary *self);
gboolean       music_library_add_directory        (MusicLibrary *self, const char *path);
gboolean       music_library_remove_directory     (MusicLibrary *self, const char *path);

void           music_library_scan                 (MusicLibrary *self);
gboolean       music_library_is_scanning          (MusicLibrary *self);

/* Look up or create a MusicSong by URI. Returns a borrowed reference. */
MusicSong     *music_library_ensure_song_for_uri  (MusicLibrary *self, const char *uri);
/* Convenience: build URI from path and ensure. Returns borrowed reference. */
MusicSong     *music_library_ensure_song_for_path (MusicLibrary *self, const char *path);

MusicPlaylist *music_library_create_playlist      (MusicLibrary *self, const char *name);
void           music_library_remove_playlist      (MusicLibrary *self, MusicPlaylist *playlist);

/* Queue metadata extraction for a single song (e.g. one opened from a file manager). */
void           music_library_queue_metadata       (MusicLibrary *self, MusicSong *song);

void           music_library_save                 (MusicLibrary *self);

G_END_DECLS
