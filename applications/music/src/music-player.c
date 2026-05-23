#include "music-player.h"

#include <gst/gst.h>

struct _MusicPlayer
{
  GObject parent_instance;

  GstElement     *playbin;
  GstBus         *bus;
  guint           bus_watch_id;

  MusicSong      *current;
  GListModel     *queue;
  guint           queue_index;

  gint64          position;
  gint64          duration;
  double          volume;
  gboolean        playing;
  gboolean        shuffle;
  MusicRepeatMode repeat;

  guint           position_timer_id;
  GRand          *rand;
};

G_DEFINE_FINAL_TYPE (MusicPlayer, music_player, G_TYPE_OBJECT)

enum {
  PROP_0,
  PROP_CURRENT,
  PROP_PLAYING,
  PROP_POSITION,
  PROP_DURATION,
  PROP_VOLUME,
  PROP_SHUFFLE,
  PROP_REPEAT,
  N_PROPS,
};
static GParamSpec *props[N_PROPS];

enum {
  SIG_EOS,
  N_SIGNALS,
};
static guint signals[N_SIGNALS];

/* ---------- forward ---------- */
static gboolean on_bus_message (GstBus *bus, GstMessage *msg, gpointer user_data);
static gboolean on_position_tick (gpointer data);
static void     play_index (MusicPlayer *self, guint idx);

/* ---------- lifecycle ---------- */

static void
music_player_dispose (GObject *obj)
{
  MusicPlayer *self = MUSIC_PLAYER (obj);

  if (self->position_timer_id)
    {
      g_source_remove (self->position_timer_id);
      self->position_timer_id = 0;
    }
  if (self->bus_watch_id)
    {
      g_source_remove (self->bus_watch_id);
      self->bus_watch_id = 0;
    }
  if (self->playbin)
    {
      gst_element_set_state (self->playbin, GST_STATE_NULL);
      gst_object_unref (self->playbin);
      self->playbin = NULL;
    }
  g_clear_object (&self->current);
  g_clear_object (&self->queue);
  g_clear_pointer (&self->bus, gst_object_unref);

  G_OBJECT_CLASS (music_player_parent_class)->dispose (obj);
}

static void
music_player_finalize (GObject *obj)
{
  MusicPlayer *self = MUSIC_PLAYER (obj);
  g_clear_pointer (&self->rand, g_rand_free);
  G_OBJECT_CLASS (music_player_parent_class)->finalize (obj);
}

static void
music_player_get_property (GObject *o, guint id, GValue *v, GParamSpec *p)
{
  MusicPlayer *s = MUSIC_PLAYER (o);
  switch (id)
    {
    case PROP_CURRENT:  g_value_set_object  (v, s->current);  break;
    case PROP_PLAYING:  g_value_set_boolean (v, s->playing);  break;
    case PROP_POSITION: g_value_set_int64   (v, s->position); break;
    case PROP_DURATION: g_value_set_int64   (v, s->duration); break;
    case PROP_VOLUME:   g_value_set_double  (v, s->volume);   break;
    case PROP_SHUFFLE:  g_value_set_boolean (v, s->shuffle);  break;
    case PROP_REPEAT:   g_value_set_int     (v, s->repeat);   break;
    default: G_OBJECT_WARN_INVALID_PROPERTY_ID (o, id, p);
    }
}

static void
music_player_class_init (MusicPlayerClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose      = music_player_dispose;
  oc->finalize     = music_player_finalize;
  oc->get_property = music_player_get_property;

  props[PROP_CURRENT]  = g_param_spec_object  ("current",  NULL, NULL, MUSIC_TYPE_SONG, G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_PLAYING]  = g_param_spec_boolean ("playing",  NULL, NULL, FALSE,           G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_POSITION] = g_param_spec_int64   ("position", NULL, NULL, 0, G_MAXINT64, 0, G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_DURATION] = g_param_spec_int64   ("duration", NULL, NULL, 0, G_MAXINT64, 0, G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_VOLUME]   = g_param_spec_double  ("volume",   NULL, NULL, 0.0, 1.0, 1.0,    G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_SHUFFLE]  = g_param_spec_boolean ("shuffle",  NULL, NULL, FALSE,            G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  props[PROP_REPEAT]   = g_param_spec_int     ("repeat",   NULL, NULL,
                            MUSIC_REPEAT_NONE, MUSIC_REPEAT_ONE, MUSIC_REPEAT_NONE,
                            G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_properties (oc, N_PROPS, props);

  signals[SIG_EOS] = g_signal_new ("end-of-stream",
      G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST, 0,
      NULL, NULL, NULL, G_TYPE_NONE, 0);
}

static void
music_player_init (MusicPlayer *self)
{
  if (!gst_is_initialized ())
    gst_init (NULL, NULL);

  self->playbin = gst_element_factory_make ("playbin3", "music-playbin");
  if (!self->playbin)
    self->playbin = gst_element_factory_make ("playbin", "music-playbin");
  if (!self->playbin)
    {
      g_warning ("Could not create GStreamer playbin element");
      return;
    }

  self->volume = 1.0;
  g_object_set (self->playbin, "volume", 1.0, NULL);

  self->bus = gst_element_get_bus (self->playbin);
  self->bus_watch_id = gst_bus_add_watch (self->bus, on_bus_message, self);

  self->rand = g_rand_new ();
}

MusicPlayer *
music_player_new (void)
{
  return g_object_new (MUSIC_TYPE_PLAYER, NULL);
}

/* ---------- accessors ---------- */

MusicSong       *music_player_get_current  (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), NULL);  return s->current; }
gboolean         music_player_is_playing   (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), FALSE); return s->playing; }
gint64           music_player_get_position (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), 0);     return s->position; }
gint64           music_player_get_duration (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), 0);     return s->duration; }
double           music_player_get_volume   (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), 1.0);   return s->volume; }
gboolean         music_player_get_shuffle  (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), FALSE); return s->shuffle; }
MusicRepeatMode  music_player_get_repeat   (MusicPlayer *s) { g_return_val_if_fail (MUSIC_IS_PLAYER (s), MUSIC_REPEAT_NONE); return s->repeat; }

/* ---------- core play helpers ---------- */

static void
set_current_song (MusicPlayer *self, MusicSong *song)
{
  if (self->current == song)
    return;
  g_set_object (&self->current, song);
  self->position = 0;
  self->duration = song ? music_song_get_duration (song) : 0;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_CURRENT]);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_POSITION]);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_DURATION]);
}

static void
set_playing (MusicPlayer *self, gboolean playing)
{
  if (self->playing == playing)
    return;
  self->playing = playing;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_PLAYING]);

  if (playing)
    {
      if (!self->position_timer_id)
        self->position_timer_id = g_timeout_add (250, on_position_tick, self);
    }
  else
    {
      if (self->position_timer_id)
        {
          g_source_remove (self->position_timer_id);
          self->position_timer_id = 0;
        }
    }
}

static void
play_song_internal (MusicPlayer *self, MusicSong *song)
{
  if (!self->playbin || !song)
    return;
  set_current_song (self, song);

  gst_element_set_state (self->playbin, GST_STATE_NULL);
  g_object_set (self->playbin, "uri", music_song_get_uri (song), NULL);
  gst_element_set_state (self->playbin, GST_STATE_PLAYING);
}

static void
play_index (MusicPlayer *self, guint idx)
{
  if (!self->queue)
    return;
  guint n = g_list_model_get_n_items (self->queue);
  if (n == 0)
    return;
  if (idx >= n)
    idx = 0;
  self->queue_index = idx;
  g_autoptr (MusicSong) s = g_list_model_get_item (self->queue, idx);
  if (s)
    play_song_internal (self, s);
}

void
music_player_play_song (MusicPlayer *self, MusicSong *song)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  g_return_if_fail (MUSIC_IS_SONG (song));

  /* Single-song "queue" so next/prev behave consistently. */
  g_autoptr (GListStore) ls = g_list_store_new (MUSIC_TYPE_SONG);
  g_list_store_append (ls, song);
  g_set_object (&self->queue, G_LIST_MODEL (ls));
  self->queue_index = 0;
  play_song_internal (self, song);
}

void
music_player_play_in_queue (MusicPlayer *self, GListModel *queue, guint start_index)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  g_return_if_fail (G_IS_LIST_MODEL (queue));

  g_set_object (&self->queue, queue);
  play_index (self, start_index);
}

/* ---------- playback control ---------- */

void
music_player_toggle (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->playbin) return;
  if (!self->current && self->queue)
    {
      play_index (self, 0);
      return;
    }
  if (self->playing)
    music_player_pause (self);
  else
    music_player_play (self);
}

void
music_player_play (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->playbin) return;
  if (!self->current && self->queue && g_list_model_get_n_items (self->queue) > 0)
    {
      play_index (self, self->queue_index);
      return;
    }
  gst_element_set_state (self->playbin, GST_STATE_PLAYING);
}

void
music_player_pause (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->playbin) return;
  gst_element_set_state (self->playbin, GST_STATE_PAUSED);
}

void
music_player_stop (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->playbin) return;
  gst_element_set_state (self->playbin, GST_STATE_NULL);
  set_playing (self, FALSE);
}

void
music_player_next (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->queue)
    return;
  guint n = g_list_model_get_n_items (self->queue);
  if (n == 0)
    return;

  if (self->repeat == MUSIC_REPEAT_ONE)
    {
      play_index (self, self->queue_index);
      return;
    }

  guint next;
  if (self->shuffle && n > 1)
    {
      do {
        next = (guint) g_rand_int_range (self->rand, 0, (gint32) n);
      } while (next == self->queue_index);
    }
  else
    {
      if (self->queue_index + 1 >= n)
        {
          if (self->repeat == MUSIC_REPEAT_ALL)
            next = 0;
          else
            {
              music_player_stop (self);
              return;
            }
        }
      else
        next = self->queue_index + 1;
    }
  play_index (self, next);
}

void
music_player_previous (MusicPlayer *self)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));

  /* If we're more than 3s into the song, restart it instead of going back. */
  if (self->position > 3)
    {
      music_player_seek (self, 0);
      return;
    }

  if (!self->queue)
    return;
  guint n = g_list_model_get_n_items (self->queue);
  if (n == 0)
    return;

  guint prev;
  if (self->queue_index == 0)
    prev = (self->repeat == MUSIC_REPEAT_ALL) ? n - 1 : 0;
  else
    prev = self->queue_index - 1;
  play_index (self, prev);
}

void
music_player_seek (MusicPlayer *self, gint64 seconds)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (!self->playbin) return;
  if (seconds < 0) seconds = 0;
  gst_element_seek_simple (self->playbin, GST_FORMAT_TIME,
      GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT,
      (gint64) seconds * GST_SECOND);
  self->position = seconds;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_POSITION]);
}

void
music_player_set_volume (MusicPlayer *self, double v)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (v < 0) v = 0;
  if (v > 1) v = 1;
  if (self->volume == v) return;
  self->volume = v;
  if (self->playbin)
    g_object_set (self->playbin, "volume", v, NULL);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_VOLUME]);
}

void
music_player_set_shuffle (MusicPlayer *self, gboolean shuffle)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (self->shuffle == shuffle) return;
  self->shuffle = shuffle;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_SHUFFLE]);
}

void
music_player_set_repeat (MusicPlayer *self, MusicRepeatMode mode)
{
  g_return_if_fail (MUSIC_IS_PLAYER (self));
  if (self->repeat == mode) return;
  self->repeat = mode;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_REPEAT]);
}

/* ---------- bus + timer ---------- */

static gboolean
on_bus_message (GstBus *bus, GstMessage *msg, gpointer user_data)
{
  (void) bus;
  MusicPlayer *self = MUSIC_PLAYER (user_data);

  switch (GST_MESSAGE_TYPE (msg))
    {
    case GST_MESSAGE_EOS:
      g_signal_emit (self, signals[SIG_EOS], 0);
      music_player_next (self);
      break;

    case GST_MESSAGE_ERROR:
      {
        GError *err = NULL;
        gchar *dbg = NULL;
        gst_message_parse_error (msg, &err, &dbg);
        g_warning ("GStreamer error: %s (%s)", err ? err->message : "?", dbg ? dbg : "");
        g_clear_error (&err);
        g_free (dbg);
        music_player_stop (self);
        break;
      }

    case GST_MESSAGE_STATE_CHANGED:
      if (GST_MESSAGE_SRC (msg) == GST_OBJECT (self->playbin))
        {
          GstState old, cur, pend;
          gst_message_parse_state_changed (msg, &old, &cur, &pend);
          set_playing (self, cur == GST_STATE_PLAYING);

          /* Query duration once we have it. */
          gint64 dur_ns = 0;
          if (gst_element_query_duration (self->playbin, GST_FORMAT_TIME, &dur_ns)
              && dur_ns > 0)
            {
              gint64 dur_s = dur_ns / GST_SECOND;
              if (self->duration != dur_s)
                {
                  self->duration = dur_s;
                  if (self->current && music_song_get_duration (self->current) == 0)
                    music_song_set_duration (self->current, dur_s);
                  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_DURATION]);
                }
            }
        }
      break;

    default:
      break;
    }

  return G_SOURCE_CONTINUE;
}

static gboolean
on_position_tick (gpointer data)
{
  MusicPlayer *self = MUSIC_PLAYER (data);
  if (!self->playbin)
    return G_SOURCE_REMOVE;

  gint64 pos_ns = 0;
  if (gst_element_query_position (self->playbin, GST_FORMAT_TIME, &pos_ns) && pos_ns >= 0)
    {
      gint64 pos_s = pos_ns / GST_SECOND;
      if (pos_s != self->position)
        {
          self->position = pos_s;
          g_object_notify_by_pspec (G_OBJECT (self), props[PROP_POSITION]);
        }
    }

  if (self->duration == 0)
    {
      gint64 dur_ns = 0;
      if (gst_element_query_duration (self->playbin, GST_FORMAT_TIME, &dur_ns) && dur_ns > 0)
        {
          self->duration = dur_ns / GST_SECOND;
          g_object_notify_by_pspec (G_OBJECT (self), props[PROP_DURATION]);
        }
    }

  return G_SOURCE_CONTINUE;
}
