#include "music-library.h"

#include <gst/pbutils/pbutils.h>
#include <string.h>

#define DISCOVER_TIMEOUT_NS (10 * GST_SECOND)
#define FAVORITES_PLAYLIST_NAME "Favourite Songs"

struct _MusicLibrary
{
  GObject        parent_instance;

  GListStore    *songs;        /* MusicSong, only items currently in scanned dirs */
  GListStore    *playlists;    /* MusicPlaylist */
  GPtrArray     *directories;  /* char* (free with g_free) */
  GHashTable    *songs_by_uri; /* const char* uri (borrowed from song) -> MusicSong* (refs owned) */

  GstDiscoverer *discoverer;
  guint          pending_discover;

  char          *config_path;  /* $XDG_CONFIG_HOME/music/music.ini */
  guint          save_idle_id;

  gboolean       loading;      /* avoid saving while loading */
  gboolean       scanning;
};

G_DEFINE_FINAL_TYPE (MusicLibrary, music_library, G_TYPE_OBJECT)

enum {
  SIG_SCAN_STARTED,
  SIG_SCAN_FINISHED,
  SIG_DIRECTORIES_CHANGED,
  N_SIGNALS,
};
static guint signals[N_SIGNALS];

/* ---------- forward decls ---------- */

static void  schedule_save             (MusicLibrary *self);
static void  do_save                   (MusicLibrary *self);
static void  load_from_disk            (MusicLibrary *self);
static void  scan_directory_recursive  (MusicLibrary *self, GFile *dir);
static void  queue_discover            (MusicLibrary *self, MusicSong *song);
static void  on_song_favorite_notify   (GObject *song, GParamSpec *p, gpointer self);
static void  on_discovered             (GstDiscoverer       *disc,
                                        GstDiscovererInfo   *info,
                                        GError              *err,
                                        gpointer             user_data);
static void  on_discover_finished      (GstDiscoverer       *disc,
                                        gpointer             user_data);

/* ---------- file extension whitelist ---------- */

static gboolean
is_audio_filename (const char *name)
{
  const char *ext = strrchr (name, '.');
  if (!ext)
    return FALSE;
  static const char *exts[] = {
    ".mp3", ".m4a", ".aac", ".ogg", ".oga", ".opus",
    ".flac", ".wav", ".wma", ".aif", ".aiff", ".ape",
  };
  for (gsize i = 0; i < G_N_ELEMENTS (exts); i++)
    if (g_ascii_strcasecmp (ext, exts[i]) == 0)
      return TRUE;
  return FALSE;
}

/* ---------- lifecycle ---------- */

static void
music_library_finalize (GObject *obj)
{
  MusicLibrary *self = MUSIC_LIBRARY (obj);

  if (self->save_idle_id)
    {
      g_source_remove (self->save_idle_id);
      self->save_idle_id = 0;
      do_save (self);
    }

  if (self->discoverer)
    {
      gst_discoverer_stop (self->discoverer);
      g_clear_object (&self->discoverer);
    }

  g_clear_object  (&self->songs);
  g_clear_object  (&self->playlists);
  g_clear_pointer (&self->directories,  g_ptr_array_unref);
  g_clear_pointer (&self->songs_by_uri, g_hash_table_unref);
  g_clear_pointer (&self->config_path,  g_free);

  G_OBJECT_CLASS (music_library_parent_class)->finalize (obj);
}

static void
music_library_class_init (MusicLibraryClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->finalize = music_library_finalize;

  signals[SIG_SCAN_STARTED] = g_signal_new ("scan-started",
      G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST, 0,
      NULL, NULL, NULL, G_TYPE_NONE, 0);
  signals[SIG_SCAN_FINISHED] = g_signal_new ("scan-finished",
      G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST, 0,
      NULL, NULL, NULL, G_TYPE_NONE, 0);
  signals[SIG_DIRECTORIES_CHANGED] = g_signal_new ("directories-changed",
      G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST, 0,
      NULL, NULL, NULL, G_TYPE_NONE, 0);
}

static void
music_library_init (MusicLibrary *self)
{
  self->songs        = g_list_store_new (MUSIC_TYPE_SONG);
  self->playlists    = g_list_store_new (MUSIC_TYPE_PLAYLIST);
  self->directories  = g_ptr_array_new_with_free_func (g_free);
  self->songs_by_uri = g_hash_table_new_full (g_str_hash, g_str_equal,
                                              NULL, g_object_unref);

  self->config_path = g_build_filename (g_get_user_config_dir (), "music", "music.ini", NULL);

  GError *err = NULL;
  self->discoverer = gst_discoverer_new (DISCOVER_TIMEOUT_NS, &err);
  if (!self->discoverer)
    {
      g_warning ("Could not create GstDiscoverer: %s", err ? err->message : "(unknown)");
      g_clear_error (&err);
    }
  else
    {
      g_signal_connect (self->discoverer, "discovered",
                        G_CALLBACK (on_discovered), self);
      g_signal_connect (self->discoverer, "finished",
                        G_CALLBACK (on_discover_finished), self);
      gst_discoverer_start (self->discoverer);
    }

  load_from_disk (self);

  /* Default music directory if none configured: ~/Music */
  if (self->directories->len == 0)
    {
      const char *xdg = g_get_user_special_dir (G_USER_DIRECTORY_MUSIC);
      g_autofree char *fallback = NULL;
      if (!xdg || !*xdg)
        {
          fallback = g_build_filename (g_get_home_dir (), "Music", NULL);
          xdg = fallback;
        }
      g_ptr_array_add (self->directories, g_strdup (xdg));
    }
}

/* ---------- public: singleton ---------- */

static MusicLibrary *default_library = NULL;

MusicLibrary *
music_library_get_default (void)
{
  if (G_UNLIKELY (default_library == NULL))
    default_library = g_object_new (MUSIC_TYPE_LIBRARY, NULL);
  return default_library;
}

/* ---------- public: accessors ---------- */

GListModel *
music_library_get_songs (MusicLibrary *self)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  return G_LIST_MODEL (self->songs);
}

GListModel *
music_library_get_playlists (MusicLibrary *self)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  return G_LIST_MODEL (self->playlists);
}

GPtrArray *
music_library_get_directories (MusicLibrary *self)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  return self->directories;
}

gboolean
music_library_is_scanning (MusicLibrary *self)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), FALSE);
  return self->scanning;
}

/* ---------- directories ---------- */

static int
find_dir_index (GPtrArray *arr, const char *path)
{
  for (guint i = 0; i < arr->len; i++)
    if (g_strcmp0 (g_ptr_array_index (arr, i), path) == 0)
      return (int) i;
  return -1;
}

gboolean
music_library_add_directory (MusicLibrary *self, const char *path)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), FALSE);
  g_return_val_if_fail (path != NULL, FALSE);

  if (find_dir_index (self->directories, path) >= 0)
    return FALSE;

  g_ptr_array_add (self->directories, g_strdup (path));
  g_signal_emit (self, signals[SIG_DIRECTORIES_CHANGED], 0);
  schedule_save (self);
  music_library_scan (self);
  return TRUE;
}

gboolean
music_library_remove_directory (MusicLibrary *self, const char *path)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), FALSE);
  g_return_val_if_fail (path != NULL, FALSE);

  int idx = find_dir_index (self->directories, path);
  if (idx < 0)
    return FALSE;

  /* Remove songs whose path is under this directory. */
  g_autofree char *prefix_uri = g_filename_to_uri (path, NULL, NULL);
  if (prefix_uri)
    {
      /* Trailing slash to avoid matching siblings: /home/sandip/Music vs /home/sandip/MusicExtra */
      g_autofree char *prefix_uri_slash = g_strconcat (prefix_uri, "/", NULL);
      guint n = g_list_model_get_n_items (G_LIST_MODEL (self->songs));
      /* Walk backwards so removals don't shift indexes we still need. */
      for (gint i = (gint) n - 1; i >= 0; i--)
        {
          g_autoptr (MusicSong) s = g_list_model_get_item (G_LIST_MODEL (self->songs), (guint) i);
          const char *uri = music_song_get_uri (s);
          if (g_str_has_prefix (uri, prefix_uri_slash))
            g_list_store_remove (self->songs, (guint) i);
        }
    }

  g_ptr_array_remove_index (self->directories, (guint) idx);
  g_signal_emit (self, signals[SIG_DIRECTORIES_CHANGED], 0);
  schedule_save (self);
  return TRUE;
}

/* ---------- song lookup / creation ---------- */

MusicSong *
music_library_ensure_song_for_uri (MusicLibrary *self, const char *uri)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  g_return_val_if_fail (uri != NULL, NULL);

  MusicSong *s = g_hash_table_lookup (self->songs_by_uri, uri);
  if (s)
    return s;

  s = music_song_new (uri);

  /* Best-effort title from basename. */
  g_autofree char *path = g_filename_from_uri (uri, NULL, NULL);
  if (path)
    {
      g_autofree char *base = g_path_get_basename (path);
      char *dot = strrchr (base, '.');
      if (dot)
        *dot = '\0';
      music_song_set_title (s, base);
    }

  g_hash_table_insert (self->songs_by_uri,
                       (gpointer) music_song_get_uri (s),
                       s);

  g_signal_connect (s, "notify::favorite",
                    G_CALLBACK (on_song_favorite_notify), self);
  return s;
}

MusicSong *
music_library_ensure_song_for_path (MusicLibrary *self, const char *path)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  g_return_val_if_fail (path != NULL, NULL);

  g_autofree char *uri = g_filename_to_uri (path, NULL, NULL);
  if (!uri)
    return NULL;
  return music_library_ensure_song_for_uri (self, uri);
}

static gboolean
list_store_contains_song (GListStore *store, MusicSong *song)
{
  guint n = g_list_model_get_n_items (G_LIST_MODEL (store));
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicSong) s = g_list_model_get_item (G_LIST_MODEL (store), i);
      if (s == song)
        return TRUE;
    }
  return FALSE;
}

/* ---------- scanning ---------- */

void
music_library_scan (MusicLibrary *self)
{
  g_return_if_fail (MUSIC_IS_LIBRARY (self));

  if (self->scanning)
    return;
  self->scanning = TRUE;
  g_signal_emit (self, signals[SIG_SCAN_STARTED], 0);

  /* Track which URIs are still present after scan, prune missing afterwards. */
  g_autoptr (GHashTable) seen =
      g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);

  for (guint i = 0; i < self->directories->len; i++)
    {
      const char *dir = g_ptr_array_index (self->directories, i);
      g_autoptr (GFile) file = g_file_new_for_path (dir);
      scan_directory_recursive (self, file);
    }

  /* Build "seen" from the dir tree once more — cheap, lets us detect deletions. */
  g_hash_table_remove_all (seen);
  for (guint i = 0; i < self->directories->len; i++)
    {
      const char *dir = g_ptr_array_index (self->directories, i);
      g_autoptr (GFile) file = g_file_new_for_path (dir);
      g_autoptr (GFileEnumerator) en =
          g_file_enumerate_children (file,
              G_FILE_ATTRIBUTE_STANDARD_NAME ","
              G_FILE_ATTRIBUTE_STANDARD_TYPE,
              G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, NULL, NULL);
      (void) en;
      /* We rely on scan_directory_recursive having already added entries to songs store. */
    }

  /* Remove songs from the visible store whose file no longer exists. */
  guint n = g_list_model_get_n_items (G_LIST_MODEL (self->songs));
  for (gint i = (gint) n - 1; i >= 0; i--)
    {
      g_autoptr (MusicSong) s = g_list_model_get_item (G_LIST_MODEL (self->songs), (guint) i);
      g_autofree char *p = g_filename_from_uri (music_song_get_uri (s), NULL, NULL);
      if (!p || !g_file_test (p, G_FILE_TEST_EXISTS))
        g_list_store_remove (self->songs, (guint) i);
    }

  if (self->pending_discover == 0)
    {
      self->scanning = FALSE;
      g_signal_emit (self, signals[SIG_SCAN_FINISHED], 0);
    }
}

static void
scan_directory_recursive (MusicLibrary *self, GFile *dir)
{
  g_autoptr (GFileEnumerator) en =
      g_file_enumerate_children (dir,
          G_FILE_ATTRIBUTE_STANDARD_NAME ","
          G_FILE_ATTRIBUTE_STANDARD_TYPE ","
          G_FILE_ATTRIBUTE_TIME_MODIFIED,
          G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, NULL, NULL);
  if (!en)
    return;

  while (TRUE)
    {
      GFileInfo *info = NULL;
      GFile     *child = NULL;
      if (!g_file_enumerator_iterate (en, &info, &child, NULL, NULL))
        break;
      if (!info)
        break;

      GFileType type = g_file_info_get_file_type (info);
      const char *name = g_file_info_get_name (info);
      if (!name || name[0] == '.')
        continue;

      if (type == G_FILE_TYPE_DIRECTORY)
        {
          scan_directory_recursive (self, child);
        }
      else if (type == G_FILE_TYPE_REGULAR && is_audio_filename (name))
        {
          g_autofree char *path = g_file_get_path (child);
          if (!path)
            continue;
          MusicSong *s = music_library_ensure_song_for_path (self, path);
          if (!s)
            continue;

          gint64 mtime = (gint64) g_file_info_get_attribute_uint64 (
              info, G_FILE_ATTRIBUTE_TIME_MODIFIED);

          if (!list_store_contains_song (self->songs, s))
            g_list_store_append (self->songs, s);

          /* Re-discover metadata if file changed or never discovered. */
          if (!music_song_get_has_metadata (s) || music_song_get_mtime (s) != mtime)
            {
              music_song_set_mtime (s, mtime);
              queue_discover (self, s);
            }
        }
    }
}

/* ---------- gst discoverer ---------- */

static void
queue_discover (MusicLibrary *self, MusicSong *song)
{
  if (!self->discoverer)
    return;
  self->pending_discover++;
  gst_discoverer_discover_uri_async (self->discoverer, music_song_get_uri (song));
}

void
music_library_queue_metadata (MusicLibrary *self, MusicSong *song)
{
  g_return_if_fail (MUSIC_IS_LIBRARY (self));
  g_return_if_fail (MUSIC_IS_SONG (song));
  queue_discover (self, song);
}

static const char *
tag_string (const GstTagList *tags, const char *tag)
{
  static __thread char buf[512];
  gchar *v = NULL;
  if (!tags)
    return NULL;
  if (!gst_tag_list_get_string_index (tags, tag, 0, &v))
    return NULL;
  if (!v)
    return NULL;
  g_strlcpy (buf, v, sizeof (buf));
  g_free (v);
  return buf;
}

static void
on_discovered (GstDiscoverer     *disc,
               GstDiscovererInfo *info,
               GError            *err,
               gpointer           user_data)
{
  (void) disc;
  MusicLibrary *self = MUSIC_LIBRARY (user_data);

  if (self->pending_discover > 0)
    self->pending_discover--;

  if (!info)
    return;

  const char *uri = gst_discoverer_info_get_uri (info);
  if (!uri)
    return;
  MusicSong *song = g_hash_table_lookup (self->songs_by_uri, uri);
  if (!song)
    return;

  GstDiscovererResult res = gst_discoverer_info_get_result (info);
  if (res != GST_DISCOVERER_OK && res != GST_DISCOVERER_MISSING_PLUGINS)
    {
      if (err)
        g_debug ("discoverer error for %s: %s", uri, err->message);
      music_song_set_has_metadata (song, TRUE);
      schedule_save (self);
      return;
    }

  GstClockTime dur_ns = gst_discoverer_info_get_duration (info);
  if (GST_CLOCK_TIME_IS_VALID (dur_ns) && dur_ns > 0)
    music_song_set_duration (song, (gint64) (dur_ns / GST_SECOND));

  const GstTagList *tags = gst_discoverer_info_get_tags (info);
  if (tags)
    {
      const char *title  = tag_string (tags, GST_TAG_TITLE);
      if (title && *title)
        music_song_set_title (song, title);

      const char *artist = tag_string (tags, GST_TAG_ARTIST);
      if (!artist)
        artist = tag_string (tags, GST_TAG_ALBUM_ARTIST);
      if (artist)
        music_song_set_artist (song, artist);

      const char *album = tag_string (tags, GST_TAG_ALBUM);
      if (album)
        music_song_set_album (song, album);
    }

  music_song_set_has_metadata (song, TRUE);
  schedule_save (self);
}

static void
on_discover_finished (GstDiscoverer *disc, gpointer user_data)
{
  (void) disc;
  MusicLibrary *self = MUSIC_LIBRARY (user_data);
  self->pending_discover = 0;
  if (self->scanning)
    {
      self->scanning = FALSE;
      g_signal_emit (self, signals[SIG_SCAN_FINISHED], 0);
    }
}

/* ---------- favorites auto-playlist ---------- */

static MusicPlaylist *
find_favorites_playlist (MusicLibrary *self)
{
  GListModel *m = G_LIST_MODEL (self->playlists);
  guint n = g_list_model_get_n_items (m);
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicPlaylist) p = g_list_model_get_item (m, i);
      if (g_strcmp0 (music_playlist_get_name (p), FAVORITES_PLAYLIST_NAME) == 0)
        return p;
    }
  return NULL;
}

static void
on_song_favorite_notify (GObject *obj, GParamSpec *p, gpointer user_data)
{
  (void) p;
  MusicLibrary *self = MUSIC_LIBRARY (user_data);
  MusicSong    *song = MUSIC_SONG (obj);

  if (self->loading)
    return;

  gboolean fav = music_song_get_favorite (song);
  MusicPlaylist *fp = find_favorites_playlist (self);

  if (fav)
    {
      if (!fp)
        fp = music_library_create_playlist (self, FAVORITES_PLAYLIST_NAME);
      if (fp && !music_playlist_contains (fp, song))
        music_playlist_add_song (fp, song);
    }
  else if (fp)
    {
      GListModel *m = music_playlist_get_songs (fp);
      guint n = g_list_model_get_n_items (m);
      for (guint i = 0; i < n; i++)
        {
          g_autoptr (MusicSong) s = g_list_model_get_item (m, i);
          if (s == song)
            {
              music_playlist_remove_song (fp, i);
              break;
            }
        }
    }

  schedule_save (self);
}

/* ---------- playlists ---------- */

MusicPlaylist *
music_library_create_playlist (MusicLibrary *self, const char *name)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (self), NULL);
  g_return_val_if_fail (name != NULL && *name != '\0', NULL);

  MusicPlaylist *p = music_playlist_new (name);
  g_list_store_append (self->playlists, p);

  /* Save when playlist contents change. */
  g_signal_connect_swapped (music_playlist_get_songs (p), "items-changed",
                            G_CALLBACK (schedule_save), self);
  g_signal_connect_swapped (p, "notify::name",
                            G_CALLBACK (schedule_save), self);

  g_object_unref (p); /* store holds the ref */
  schedule_save (self);
  return p;
}

void
music_library_remove_playlist (MusicLibrary *self, MusicPlaylist *playlist)
{
  g_return_if_fail (MUSIC_IS_LIBRARY (self));
  g_return_if_fail (MUSIC_IS_PLAYLIST (playlist));

  guint n = g_list_model_get_n_items (G_LIST_MODEL (self->playlists));
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicPlaylist) p = g_list_model_get_item (G_LIST_MODEL (self->playlists), i);
      if (p == playlist)
        {
          g_list_store_remove (self->playlists, i);
          schedule_save (self);
          return;
        }
    }
}

/* ---------- persistence ---------- */

static gboolean
on_save_idle (gpointer data)
{
  MusicLibrary *self = MUSIC_LIBRARY (data);
  self->save_idle_id = 0;
  do_save (self);
  return G_SOURCE_REMOVE;
}

static void
schedule_save (MusicLibrary *self)
{
  if (self->loading)
    return;
  if (self->save_idle_id)
    return;
  self->save_idle_id = g_idle_add_full (G_PRIORITY_LOW, on_save_idle, self, NULL);
}

void
music_library_save (MusicLibrary *self)
{
  g_return_if_fail (MUSIC_IS_LIBRARY (self));
  if (self->save_idle_id)
    {
      g_source_remove (self->save_idle_id);
      self->save_idle_id = 0;
    }
  do_save (self);
}

static char *
join_strv (GPtrArray *items)
{
  if (items->len == 0)
    return g_strdup ("");
  GString *s = g_string_new (NULL);
  for (guint i = 0; i < items->len; i++)
    {
      if (i > 0) g_string_append_c (s, ';');
      g_string_append (s, (const char *) g_ptr_array_index (items, i));
    }
  return g_string_free (s, FALSE);
}

static void
do_save (MusicLibrary *self)
{
  g_autoptr (GKeyFile) kf = g_key_file_new ();

  /* directories */
  {
    g_autoptr (GPtrArray) arr = g_ptr_array_new ();
    for (guint i = 0; i < self->directories->len; i++)
      g_ptr_array_add (arr, g_ptr_array_index (self->directories, i));
    g_autofree char *joined = join_strv (arr);
    g_key_file_set_string (kf, "Library", "Directories", joined);
  }

  /* known songs with metadata + favorites */
  {
    GHashTableIter it;
    gpointer k, v;
    g_hash_table_iter_init (&it, self->songs_by_uri);
    g_autoptr (GPtrArray) fav_uris = g_ptr_array_new ();
    while (g_hash_table_iter_next (&it, &k, &v))
      {
        MusicSong *s = MUSIC_SONG (v);
        const char *uri = music_song_get_uri (s);
        if (music_song_get_has_metadata (s))
          {
            g_key_file_set_string (kf, uri, "title",    music_song_get_title  (s) ?: "");
            g_key_file_set_string (kf, uri, "artist",   music_song_get_artist (s) ?: "");
            g_key_file_set_string (kf, uri, "album",    music_song_get_album  (s) ?: "");
            g_key_file_set_int64  (kf, uri, "duration", music_song_get_duration (s));
            g_key_file_set_int64  (kf, uri, "mtime",    music_song_get_mtime    (s));
          }
        if (music_song_get_favorite (s))
          g_ptr_array_add (fav_uris, (gpointer) uri);
      }
    g_autofree char *joined_fav = join_strv (fav_uris);
    g_key_file_set_string (kf, "Favorites", "URIs", joined_fav);
  }

  /* playlists */
  {
    guint n = g_list_model_get_n_items (G_LIST_MODEL (self->playlists));
    g_autoptr (GPtrArray) names = g_ptr_array_new ();
    for (guint i = 0; i < n; i++)
      {
        g_autoptr (MusicPlaylist) p = g_list_model_get_item (G_LIST_MODEL (self->playlists), i);
        g_ptr_array_add (names, (gpointer) music_playlist_get_name (p));
      }
    g_autofree char *joined_names = join_strv (names);
    g_key_file_set_string (kf, "Playlists", "Names", joined_names);

    for (guint i = 0; i < n; i++)
      {
        g_autoptr (MusicPlaylist) p = g_list_model_get_item (G_LIST_MODEL (self->playlists), i);
        g_autofree char *group = g_strconcat ("Playlist:", music_playlist_get_name (p), NULL);
        GListModel *sm = music_playlist_get_songs (p);
        guint sn = g_list_model_get_n_items (sm);
        g_autoptr (GPtrArray) uris = g_ptr_array_new ();
        for (guint j = 0; j < sn; j++)
          {
            g_autoptr (MusicSong) s = g_list_model_get_item (sm, j);
            g_ptr_array_add (uris, (gpointer) music_song_get_uri (s));
          }
        g_autofree char *joined = join_strv (uris);
        g_key_file_set_string (kf, group, "URIs", joined);
      }
  }

  /* write atomically */
  g_autofree char *parent = g_path_get_dirname (self->config_path);
  g_mkdir_with_parents (parent, 0700);

  GError *err = NULL;
  if (!g_key_file_save_to_file (kf, self->config_path, &err))
    {
      g_warning ("Could not save library config: %s", err ? err->message : "(unknown)");
      g_clear_error (&err);
    }
}

static char **
parse_list (GKeyFile *kf, const char *group, const char *key, gsize *out_n)
{
  *out_n = 0;
  if (!g_key_file_has_key (kf, group, key, NULL))
    return NULL;
  g_autofree char *raw = g_key_file_get_string (kf, group, key, NULL);
  if (!raw || !*raw)
    return NULL;
  char **parts = g_strsplit (raw, ";", -1);
  *out_n = g_strv_length (parts);
  return parts;
}

static void
load_from_disk (MusicLibrary *self)
{
  self->loading = TRUE;

  g_autoptr (GKeyFile) kf = g_key_file_new ();
  if (!g_key_file_load_from_file (kf, self->config_path, G_KEY_FILE_NONE, NULL))
    {
      self->loading = FALSE;
      return;
    }

  /* directories */
  {
    gsize n;
    g_auto (GStrv) dirs = parse_list (kf, "Library", "Directories", &n);
    for (gsize i = 0; i < n; i++)
      if (dirs[i] && *dirs[i])
        g_ptr_array_add (self->directories, g_strdup (dirs[i]));
  }

  /* favorites set */
  g_autoptr (GHashTable) fav_set =
      g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);
  {
    gsize n;
    g_auto (GStrv) fav = parse_list (kf, "Favorites", "URIs", &n);
    for (gsize i = 0; i < n; i++)
      if (fav[i] && *fav[i])
        g_hash_table_add (fav_set, g_strdup (fav[i]));
  }

  /* song metadata cache: every group that looks like a URI */
  g_auto (GStrv) groups = g_key_file_get_groups (kf, NULL);
  if (groups)
    {
      for (gsize i = 0; groups[i]; i++)
        {
          const char *g = groups[i];
          if (!g_str_has_prefix (g, "file://"))
            continue;
          MusicSong *s = music_library_ensure_song_for_uri (self, g);
          g_autofree char *title  = g_key_file_get_string (kf, g, "title",  NULL);
          g_autofree char *artist = g_key_file_get_string (kf, g, "artist", NULL);
          g_autofree char *album  = g_key_file_get_string (kf, g, "album",  NULL);
          gint64 duration = g_key_file_get_int64 (kf, g, "duration", NULL);
          gint64 mtime    = g_key_file_get_int64 (kf, g, "mtime",    NULL);
          if (title)  music_song_set_title  (s, title);
          if (artist) music_song_set_artist (s, artist);
          if (album)  music_song_set_album  (s, album);
          music_song_set_duration (s, duration);
          music_song_set_mtime    (s, mtime);
          music_song_set_has_metadata (s, TRUE);

          if (g_hash_table_contains (fav_set, g))
            music_song_set_favorite (s, TRUE);
        }
    }

  /* playlists */
  {
    gsize n;
    g_auto (GStrv) names = parse_list (kf, "Playlists", "Names", &n);
    for (gsize i = 0; i < n; i++)
      {
        const char *name = names[i];
        if (!name || !*name)
          continue;
        MusicPlaylist *p = music_library_create_playlist (self, name);
        g_autofree char *group = g_strconcat ("Playlist:", name, NULL);
        gsize sn;
        g_auto (GStrv) uris = parse_list (kf, group, "URIs", &sn);
        for (gsize j = 0; j < sn; j++)
          {
            if (!uris[j] || !*uris[j])
              continue;
            MusicSong *s = music_library_ensure_song_for_uri (self, uris[j]);
            music_playlist_add_song (p, s);
          }
      }
  }

  self->loading = FALSE;
}
