#include "music-song.h"

#include <string.h>

struct _MusicSong
{
  GObject  parent_instance;
  char    *uri;
  char    *title;
  char    *artist;
  char    *album;
  gint64   duration;       /* seconds */
  gint64   mtime;          /* seconds since epoch */
  gboolean favorite;
  gboolean has_metadata;
};

G_DEFINE_FINAL_TYPE (MusicSong, music_song, G_TYPE_OBJECT)

enum {
  PROP_0,
  PROP_URI,
  PROP_TITLE,
  PROP_ARTIST,
  PROP_ALBUM,
  PROP_DURATION,
  PROP_MTIME,
  PROP_FAVORITE,
  PROP_HAS_METADATA,
  N_PROPS,
};
static GParamSpec *props[N_PROPS];

static void
music_song_finalize (GObject *obj)
{
  MusicSong *self = MUSIC_SONG (obj);
  g_clear_pointer (&self->uri,    g_free);
  g_clear_pointer (&self->title,  g_free);
  g_clear_pointer (&self->artist, g_free);
  g_clear_pointer (&self->album,  g_free);
  G_OBJECT_CLASS (music_song_parent_class)->finalize (obj);
}

static void
music_song_get_property (GObject *obj, guint prop_id, GValue *value, GParamSpec *pspec)
{
  MusicSong *self = MUSIC_SONG (obj);
  switch (prop_id)
    {
    case PROP_URI:           g_value_set_string  (value, self->uri);           break;
    case PROP_TITLE:         g_value_set_string  (value, self->title);         break;
    case PROP_ARTIST:        g_value_set_string  (value, self->artist);        break;
    case PROP_ALBUM:         g_value_set_string  (value, self->album);         break;
    case PROP_DURATION:      g_value_set_int64   (value, self->duration);      break;
    case PROP_MTIME:         g_value_set_int64   (value, self->mtime);         break;
    case PROP_FAVORITE:      g_value_set_boolean (value, self->favorite);      break;
    case PROP_HAS_METADATA:  g_value_set_boolean (value, self->has_metadata);  break;
    default: G_OBJECT_WARN_INVALID_PROPERTY_ID (obj, prop_id, pspec);
    }
}

static void
music_song_set_property (GObject *obj, guint prop_id, const GValue *value, GParamSpec *pspec)
{
  MusicSong *self = MUSIC_SONG (obj);
  switch (prop_id)
    {
    case PROP_URI:
      g_clear_pointer (&self->uri, g_free);
      self->uri = g_value_dup_string (value);
      break;
    case PROP_TITLE:        music_song_set_title        (self, g_value_get_string  (value)); break;
    case PROP_ARTIST:       music_song_set_artist       (self, g_value_get_string  (value)); break;
    case PROP_ALBUM:        music_song_set_album        (self, g_value_get_string  (value)); break;
    case PROP_DURATION:     music_song_set_duration     (self, g_value_get_int64   (value)); break;
    case PROP_MTIME:        music_song_set_mtime        (self, g_value_get_int64   (value)); break;
    case PROP_FAVORITE:     music_song_set_favorite     (self, g_value_get_boolean (value)); break;
    case PROP_HAS_METADATA: music_song_set_has_metadata (self, g_value_get_boolean (value)); break;
    default: G_OBJECT_WARN_INVALID_PROPERTY_ID (obj, prop_id, pspec);
    }
}

static void
music_song_class_init (MusicSongClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->finalize     = music_song_finalize;
  oc->get_property = music_song_get_property;
  oc->set_property = music_song_set_property;

  props[PROP_URI] = g_param_spec_string (
      "uri", NULL, NULL, NULL,
      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);
  props[PROP_TITLE]        = g_param_spec_string  ("title",  NULL, NULL, NULL,  G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_ARTIST]       = g_param_spec_string  ("artist", NULL, NULL, NULL,  G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_ALBUM]        = g_param_spec_string  ("album",  NULL, NULL, NULL,  G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_DURATION]     = g_param_spec_int64   ("duration", NULL, NULL, 0, G_MAXINT64, 0, G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_MTIME]        = g_param_spec_int64   ("mtime",  NULL, NULL, 0, G_MAXINT64, 0, G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_FAVORITE]     = g_param_spec_boolean ("favorite", NULL, NULL, FALSE, G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  props[PROP_HAS_METADATA] = g_param_spec_boolean ("has-metadata", NULL, NULL, FALSE, G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

  g_object_class_install_properties (oc, N_PROPS, props);
}

static void
music_song_init (MusicSong *self)
{
  self->title  = g_strdup ("");
  self->artist = g_strdup ("");
  self->album  = g_strdup ("");
}

MusicSong *
music_song_new (const char *uri)
{
  return g_object_new (MUSIC_TYPE_SONG, "uri", uri, NULL);
}

MusicSong *
music_song_new_from_path (const char *path)
{
  g_autofree char *uri = g_filename_to_uri (path, NULL, NULL);
  if (!uri)
    return NULL;
  MusicSong *s = music_song_new (uri);

  g_autofree char *base = g_path_get_basename (path);
  char *dot = strrchr (base, '.');
  if (dot)
    *dot = '\0';
  music_song_set_title (s, base);
  return s;
}

#define GETTER(field, type, defv)                              \
  type music_song_get_##field (MusicSong *self) {              \
    g_return_val_if_fail (MUSIC_IS_SONG (self), defv);         \
    return self->field;                                        \
  }
GETTER (uri,          const char *, NULL)
GETTER (title,        const char *, NULL)
GETTER (artist,       const char *, NULL)
GETTER (album,        const char *, NULL)
GETTER (duration,     gint64,       0)
GETTER (mtime,        gint64,       0)
GETTER (favorite,     gboolean,     FALSE)
GETTER (has_metadata, gboolean,     FALSE)

#define SETTER_STR(field, prop_enum)                                                  \
  void music_song_set_##field (MusicSong *self, const char *v) {                      \
    g_return_if_fail (MUSIC_IS_SONG (self));                                          \
    if (g_strcmp0 (self->field, v) == 0)                                              \
      return;                                                                         \
    g_free (self->field);                                                             \
    self->field = g_strdup (v ? v : "");                                              \
    g_object_notify_by_pspec (G_OBJECT (self), props[prop_enum]);                     \
  }
SETTER_STR (title,  PROP_TITLE)
SETTER_STR (artist, PROP_ARTIST)
SETTER_STR (album,  PROP_ALBUM)

void
music_song_set_duration (MusicSong *self, gint64 v)
{
  g_return_if_fail (MUSIC_IS_SONG (self));
  if (self->duration == v) return;
  self->duration = v;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_DURATION]);
}

void
music_song_set_mtime (MusicSong *self, gint64 v)
{
  g_return_if_fail (MUSIC_IS_SONG (self));
  if (self->mtime == v) return;
  self->mtime = v;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_MTIME]);
}

void
music_song_set_favorite (MusicSong *self, gboolean v)
{
  g_return_if_fail (MUSIC_IS_SONG (self));
  if (self->favorite == v) return;
  self->favorite = v;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_FAVORITE]);
}

void
music_song_set_has_metadata (MusicSong *self, gboolean v)
{
  g_return_if_fail (MUSIC_IS_SONG (self));
  if (self->has_metadata == v) return;
  self->has_metadata = v;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_HAS_METADATA]);
}
