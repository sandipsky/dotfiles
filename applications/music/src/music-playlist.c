#include "music-playlist.h"

struct _MusicPlaylist
{
  GObject     parent_instance;
  char       *name;
  GListStore *songs;
};

G_DEFINE_FINAL_TYPE (MusicPlaylist, music_playlist, G_TYPE_OBJECT)

enum {
  PROP_0,
  PROP_NAME,
  PROP_N_SONGS,
  N_PROPS,
};
static GParamSpec *props[N_PROPS];

static void
on_items_changed (GListModel *m, guint p, guint r, guint a, gpointer user_data)
{
  (void) m; (void) p; (void) r; (void) a;
  g_object_notify_by_pspec (G_OBJECT (user_data), props[PROP_N_SONGS]);
}

static void
music_playlist_init (MusicPlaylist *self)
{
  self->name  = g_strdup ("");
  self->songs = g_list_store_new (MUSIC_TYPE_SONG);
  g_signal_connect (self->songs, "items-changed",
                    G_CALLBACK (on_items_changed), self);
}

static void
music_playlist_finalize (GObject *obj)
{
  MusicPlaylist *self = MUSIC_PLAYLIST (obj);
  g_clear_pointer (&self->name, g_free);
  g_clear_object  (&self->songs);
  G_OBJECT_CLASS (music_playlist_parent_class)->finalize (obj);
}

static void
music_playlist_get_property (GObject *o, guint id, GValue *v, GParamSpec *p)
{
  MusicPlaylist *s = MUSIC_PLAYLIST (o);
  switch (id)
    {
    case PROP_NAME:    g_value_set_string (v, s->name); break;
    case PROP_N_SONGS: g_value_set_uint   (v, g_list_model_get_n_items (G_LIST_MODEL (s->songs))); break;
    default: G_OBJECT_WARN_INVALID_PROPERTY_ID (o, id, p);
    }
}

static void
music_playlist_set_property (GObject *o, guint id, const GValue *v, GParamSpec *p)
{
  MusicPlaylist *s = MUSIC_PLAYLIST (o);
  switch (id)
    {
    case PROP_NAME: music_playlist_set_name (s, g_value_get_string (v)); break;
    default: G_OBJECT_WARN_INVALID_PROPERTY_ID (o, id, p);
    }
}

static void
music_playlist_class_init (MusicPlaylistClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->finalize     = music_playlist_finalize;
  oc->get_property = music_playlist_get_property;
  oc->set_property = music_playlist_set_property;

  props[PROP_NAME]    = g_param_spec_string ("name", NULL, NULL, "",
                          G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_N_SONGS] = g_param_spec_uint   ("n-songs", NULL, NULL,
                          0, G_MAXUINT, 0,
                          G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_properties (oc, N_PROPS, props);
}

MusicPlaylist *
music_playlist_new (const char *name)
{
  MusicPlaylist *p = g_object_new (MUSIC_TYPE_PLAYLIST, NULL);
  music_playlist_set_name (p, name);
  return p;
}

const char *
music_playlist_get_name (MusicPlaylist *self)
{
  g_return_val_if_fail (MUSIC_IS_PLAYLIST (self), NULL);
  return self->name;
}

void
music_playlist_set_name (MusicPlaylist *self, const char *name)
{
  g_return_if_fail (MUSIC_IS_PLAYLIST (self));
  if (g_strcmp0 (self->name, name) == 0)
    return;
  g_free (self->name);
  self->name = g_strdup (name ? name : "");
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_NAME]);
}

GListModel *
music_playlist_get_songs (MusicPlaylist *self)
{
  g_return_val_if_fail (MUSIC_IS_PLAYLIST (self), NULL);
  return G_LIST_MODEL (self->songs);
}

guint
music_playlist_get_n_songs (MusicPlaylist *self)
{
  g_return_val_if_fail (MUSIC_IS_PLAYLIST (self), 0);
  return g_list_model_get_n_items (G_LIST_MODEL (self->songs));
}

void
music_playlist_add_song (MusicPlaylist *self, MusicSong *song)
{
  g_return_if_fail (MUSIC_IS_PLAYLIST (self));
  g_return_if_fail (MUSIC_IS_SONG (song));
  if (music_playlist_contains (self, song))
    return;
  g_list_store_append (self->songs, song);
}

void
music_playlist_remove_song (MusicPlaylist *self, guint position)
{
  g_return_if_fail (MUSIC_IS_PLAYLIST (self));
  if (position >= g_list_model_get_n_items (G_LIST_MODEL (self->songs)))
    return;
  g_list_store_remove (self->songs, position);
}

gboolean
music_playlist_contains (MusicPlaylist *self, MusicSong *song)
{
  g_return_val_if_fail (MUSIC_IS_PLAYLIST (self), FALSE);
  g_return_val_if_fail (MUSIC_IS_SONG (song), FALSE);

  guint n = g_list_model_get_n_items (G_LIST_MODEL (self->songs));
  const char *want = music_song_get_uri (song);
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicSong) s = g_list_model_get_item (G_LIST_MODEL (self->songs), i);
      if (g_strcmp0 (music_song_get_uri (s), want) == 0)
        return TRUE;
    }
  return FALSE;
}
