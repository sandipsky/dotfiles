#include "music-player-bar.h"

struct _MusicPlayerBar
{
  GtkBox parent_instance;

  MusicPlayer    *player;

  GtkImage       *art;
  GtkLabel       *title_label;
  GtkLabel       *artist_label;
  GtkButton      *prev_btn;
  GtkButton      *play_btn;
  GtkImage       *play_icon;
  GtkButton      *next_btn;
  GtkScale       *seek_scale;
  GtkAdjustment  *seek_adj;
  GtkLabel       *position_label;
  GtkLabel       *duration_label;

  GtkButton      *volume_btn;
  GtkScale       *volume_scale;
  GtkAdjustment  *volume_adj;
  double          volume_before_mute;

  GtkToggleButton *shuffle_btn;
  GtkButton      *repeat_btn;
  GtkImage       *repeat_icon;

  MusicSong      *bound_song;
  GBinding       *title_b;
  GBinding       *artist_b;

  gboolean        updating_scale;
  gboolean        updating_volume;
};

G_DEFINE_FINAL_TYPE (MusicPlayerBar, music_player_bar, GTK_TYPE_BOX)

/* ---------- formatting ---------- */

static char *
fmt_time (gint64 secs)
{
  if (secs < 0) secs = 0;
  return g_strdup_printf ("%" G_GINT64_FORMAT ":%02" G_GINT64_FORMAT,
                          secs / 60, secs % 60);
}

/* ---------- helpers ---------- */

static void
set_play_icon (MusicPlayerBar *self, gboolean playing)
{
  gtk_image_set_from_icon_name (self->play_icon,
      playing ? "media-playback-pause-symbolic"
              : "media-playback-start-symbolic");
}

static void
set_repeat_icon (MusicPlayerBar *self, MusicRepeatMode m)
{
  const char *name;
  switch (m)
    {
    case MUSIC_REPEAT_ALL: name = "media-playlist-repeat-symbolic";       break;
    case MUSIC_REPEAT_ONE: name = "media-playlist-repeat-song-symbolic";  break;
    default:               name = "media-playlist-consecutive-symbolic";  break;
    }
  gtk_image_set_from_icon_name (self->repeat_icon, name);

  if (m == MUSIC_REPEAT_NONE)
    gtk_widget_remove_css_class (GTK_WIDGET (self->repeat_btn), "accent");
  else
    gtk_widget_add_css_class    (GTK_WIDGET (self->repeat_btn), "accent");
}

static void
clear_song_bindings (MusicPlayerBar *self)
{
  if (self->title_b)  { g_binding_unbind (self->title_b);  g_clear_object (&self->title_b); }
  if (self->artist_b) { g_binding_unbind (self->artist_b); g_clear_object (&self->artist_b); }
}

static gboolean
xform_artist_text (GBinding *b, const GValue *src, GValue *dst, gpointer ud)
{
  (void) b; (void) ud;
  const char *raw = g_value_get_string (src);
  g_value_set_string (dst, (raw && *raw) ? raw : "Unknown Artist");
  return TRUE;
}

/* ---------- player signal handlers ---------- */

static void
on_current_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  MusicSong *cur = music_player_get_current (self->player);
  g_set_object (&self->bound_song, cur);

  clear_song_bindings (self);
  if (cur)
    {
      self->title_b = g_object_ref (g_object_bind_property (
          cur, "title", self->title_label, "label", G_BINDING_SYNC_CREATE));
      self->artist_b = g_object_ref (g_object_bind_property_full (
          cur, "artist", self->artist_label, "label", G_BINDING_SYNC_CREATE,
          xform_artist_text, NULL, NULL, NULL));
    }
  else
    {
      gtk_label_set_text (self->title_label,  "");
      gtk_label_set_text (self->artist_label, "");
    }
}

static void
on_playing_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  set_play_icon (self, music_player_is_playing (self->player));
}

static void
on_position_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  gint64 pos = music_player_get_position (self->player);

  self->updating_scale = TRUE;
  gtk_adjustment_set_value (self->seek_adj, (double) pos);
  self->updating_scale = FALSE;

  g_autofree char *s = fmt_time (pos);
  gtk_label_set_text (self->position_label, s);
}

static void
on_duration_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  gint64 dur = music_player_get_duration (self->player);
  gtk_adjustment_set_upper (self->seek_adj, dur > 0 ? (double) dur : 1.0);
  g_autofree char *s = fmt_time (dur);
  gtk_label_set_text (self->duration_label, s);
  gtk_widget_set_sensitive (GTK_WIDGET (self->seek_scale), dur > 0);
}

static void
on_shuffle_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  gboolean v = music_player_get_shuffle (self->player);
  if (gtk_toggle_button_get_active (self->shuffle_btn) != v)
    gtk_toggle_button_set_active (self->shuffle_btn, v);
}

static void
on_repeat_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  set_repeat_icon (self, music_player_get_repeat (self->player));
}

/* ---------- user input ---------- */

static void
on_prev_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  music_player_previous (MUSIC_PLAYER_BAR (ud)->player);
}

static void
on_play_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  music_player_toggle (MUSIC_PLAYER_BAR (ud)->player);
}

static void
on_next_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  music_player_next (MUSIC_PLAYER_BAR (ud)->player);
}

static void
on_shuffle_toggled (GtkToggleButton *t, gpointer ud)
{
  music_player_set_shuffle (MUSIC_PLAYER_BAR (ud)->player,
                            gtk_toggle_button_get_active (t));
}

static void
on_repeat_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  MusicRepeatMode m = music_player_get_repeat (self->player);
  m = (m + 1) % 3;
  music_player_set_repeat (self->player, m);
}

static void
on_seek_value_changed (GtkAdjustment *adj, gpointer ud)
{
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  if (self->updating_scale)
    return;
  gint64 v = (gint64) gtk_adjustment_get_value (adj);
  music_player_seek (self->player, v);
}

static const char *
volume_icon_name (double v)
{
  if (v <= 0.0)      return "audio-volume-muted-symbolic";
  if (v < 0.33)      return "audio-volume-low-symbolic";
  if (v < 0.66)      return "audio-volume-medium-symbolic";
  return                    "audio-volume-high-symbolic";
}

static void
on_volume_changed (GObject *o, GParamSpec *p, gpointer ud)
{
  (void) o; (void) p;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  double v = music_player_get_volume (self->player);

  gtk_button_set_icon_name (self->volume_btn, volume_icon_name (v));

  if (!self->updating_volume)
    {
      self->updating_volume = TRUE;
      gtk_adjustment_set_value (self->volume_adj, v);
      self->updating_volume = FALSE;
    }
}

static void
on_volume_value_changed (GtkAdjustment *adj, gpointer ud)
{
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  if (self->updating_volume)
    return;
  music_player_set_volume (self->player, gtk_adjustment_get_value (adj));
}

static void
on_volume_btn_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (ud);
  double v = music_player_get_volume (self->player);
  if (v > 0.0)
    {
      self->volume_before_mute = v;
      music_player_set_volume (self->player, 0.0);
    }
  else
    {
      double r = self->volume_before_mute > 0.0 ? self->volume_before_mute : 1.0;
      music_player_set_volume (self->player, r);
    }
}

/* ---------- lifecycle ---------- */

static void
music_player_bar_dispose (GObject *obj)
{
  MusicPlayerBar *self = MUSIC_PLAYER_BAR (obj);
  clear_song_bindings (self);
  g_clear_object (&self->bound_song);
  g_clear_object (&self->player);
  G_OBJECT_CLASS (music_player_bar_parent_class)->dispose (obj);
}

static void
music_player_bar_class_init (MusicPlayerBarClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose = music_player_bar_dispose;
}

static void
music_player_bar_init (MusicPlayerBar *self)
{
  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_HORIZONTAL);
  gtk_box_set_spacing (GTK_BOX (self), 12);
  gtk_widget_set_margin_top    (GTK_WIDGET (self), 6);
  gtk_widget_set_margin_bottom (GTK_WIDGET (self), 6);
  gtk_widget_set_margin_start  (GTK_WIDGET (self), 12);
  gtk_widget_set_margin_end    (GTK_WIDGET (self), 12);
  gtk_widget_add_css_class (GTK_WIDGET (self), "toolbar");

  /* Album art placeholder */
  self->art = GTK_IMAGE (gtk_image_new_from_icon_name ("audio-x-generic-symbolic"));
  gtk_image_set_pixel_size (self->art, 48);
  gtk_widget_add_css_class    (GTK_WIDGET (self->art), "card");
  gtk_widget_set_size_request (GTK_WIDGET (self->art), 48, 48);
  gtk_widget_set_margin_start (GTK_WIDGET (self->art), 6);
  gtk_widget_set_margin_end   (GTK_WIDGET (self->art), 12);
  gtk_widget_set_margin_top   (GTK_WIDGET (self->art), 4);
  gtk_widget_set_margin_bottom(GTK_WIDGET (self->art), 4);
  gtk_widget_set_valign       (GTK_WIDGET (self->art), GTK_ALIGN_CENTER);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->art));

  /* Title / artist column — fixed width so the center seekbar stays put
   * as songs change. Long titles ellipsize. */
  {
    GtkWidget *col = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_valign  (col, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand (col, FALSE);

    self->title_label = GTK_LABEL (gtk_label_new (""));
    gtk_label_set_xalign          (self->title_label, 0);
    gtk_label_set_ellipsize       (self->title_label, PANGO_ELLIPSIZE_END);
    gtk_label_set_width_chars     (self->title_label, 28);
    gtk_label_set_max_width_chars (self->title_label, 28);
    gtk_widget_add_css_class      (GTK_WIDGET (self->title_label), "heading");
    gtk_box_append (GTK_BOX (col), GTK_WIDGET (self->title_label));

    self->artist_label = GTK_LABEL (gtk_label_new (""));
    gtk_label_set_xalign          (self->artist_label, 0);
    gtk_label_set_ellipsize       (self->artist_label, PANGO_ELLIPSIZE_END);
    gtk_label_set_width_chars     (self->artist_label, 28);
    gtk_label_set_max_width_chars (self->artist_label, 28);
    gtk_widget_add_css_class      (GTK_WIDGET (self->artist_label), "dim-label");
    gtk_box_append (GTK_BOX (col), GTK_WIDGET (self->artist_label));

    gtk_box_append (GTK_BOX (self), col);
  }

  /* Center column: transport row stacked above the seek row. */
  {
    GtkWidget *center = gtk_box_new (GTK_ORIENTATION_VERTICAL, 2);
    gtk_widget_set_valign  (center, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand (center, TRUE);

    /* Row 1: transport controls (centered) */
    GtkWidget *transport = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_widget_set_halign (transport, GTK_ALIGN_CENTER);

    self->prev_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("media-skip-backward-symbolic"));
    gtk_widget_add_css_class (GTK_WIDGET (self->prev_btn), "flat");
    gtk_widget_add_css_class (GTK_WIDGET (self->prev_btn), "circular");
    g_signal_connect (self->prev_btn, "clicked", G_CALLBACK (on_prev_clicked), self);

    self->play_icon = GTK_IMAGE (gtk_image_new_from_icon_name ("media-playback-start-symbolic"));
    gtk_image_set_pixel_size (self->play_icon, 20);
    self->play_btn = GTK_BUTTON (gtk_button_new ());
    gtk_button_set_child (self->play_btn, GTK_WIDGET (self->play_icon));
    gtk_widget_add_css_class (GTK_WIDGET (self->play_btn), "circular");
    gtk_widget_set_size_request (GTK_WIDGET (self->play_btn), 36, 36);
    g_signal_connect (self->play_btn, "clicked", G_CALLBACK (on_play_clicked), self);

    self->next_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("media-skip-forward-symbolic"));
    gtk_widget_add_css_class (GTK_WIDGET (self->next_btn), "flat");
    gtk_widget_add_css_class (GTK_WIDGET (self->next_btn), "circular");
    g_signal_connect (self->next_btn, "clicked", G_CALLBACK (on_next_clicked), self);

    gtk_box_append (GTK_BOX (transport), GTK_WIDGET (self->prev_btn));
    gtk_box_append (GTK_BOX (transport), GTK_WIDGET (self->play_btn));
    gtk_box_append (GTK_BOX (transport), GTK_WIDGET (self->next_btn));
    gtk_box_append (GTK_BOX (center), transport);

    /* Row 2: position, seek, duration */
    GtkWidget *seek_row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);

    self->position_label = GTK_LABEL (gtk_label_new ("0:00"));
    gtk_widget_add_css_class  (GTK_WIDGET (self->position_label), "numeric");
    gtk_widget_add_css_class  (GTK_WIDGET (self->position_label), "dim-label");
    gtk_label_set_width_chars (self->position_label, 5);
    gtk_label_set_xalign      (self->position_label, 1);

    self->seek_adj = GTK_ADJUSTMENT (gtk_adjustment_new (0, 0, 1, 1, 10, 0));
    self->seek_scale = GTK_SCALE (gtk_scale_new (GTK_ORIENTATION_HORIZONTAL, self->seek_adj));
    gtk_scale_set_draw_value (self->seek_scale, FALSE);
    gtk_widget_set_hexpand   (GTK_WIDGET (self->seek_scale), TRUE);
    gtk_widget_set_valign    (GTK_WIDGET (self->seek_scale), GTK_ALIGN_CENTER);
    gtk_widget_set_sensitive (GTK_WIDGET (self->seek_scale), FALSE);
    g_signal_connect (self->seek_adj, "value-changed",
                      G_CALLBACK (on_seek_value_changed), self);

    self->duration_label = GTK_LABEL (gtk_label_new ("0:00"));
    gtk_widget_add_css_class  (GTK_WIDGET (self->duration_label), "numeric");
    gtk_widget_add_css_class  (GTK_WIDGET (self->duration_label), "dim-label");
    gtk_label_set_width_chars (self->duration_label, 5);
    gtk_label_set_xalign      (self->duration_label, 0);

    gtk_box_append (GTK_BOX (seek_row), GTK_WIDGET (self->position_label));
    gtk_box_append (GTK_BOX (seek_row), GTK_WIDGET (self->seek_scale));
    gtk_box_append (GTK_BOX (seek_row), GTK_WIDGET (self->duration_label));
    gtk_box_append (GTK_BOX (center), seek_row);

    gtk_box_append (GTK_BOX (self), center);
  }

  /* Volume: icon button (mute toggle) + small slider */
  {
    GtkWidget *vol_row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 4);
    gtk_widget_set_valign (vol_row, GTK_ALIGN_CENTER);

    self->volume_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("audio-volume-high-symbolic"));
    gtk_widget_add_css_class (GTK_WIDGET (self->volume_btn), "flat");
    gtk_widget_add_css_class (GTK_WIDGET (self->volume_btn), "circular");
    gtk_widget_set_tooltip_text (GTK_WIDGET (self->volume_btn), "Mute / unmute");
    g_signal_connect (self->volume_btn, "clicked", G_CALLBACK (on_volume_btn_clicked), self);

    self->volume_adj = GTK_ADJUSTMENT (gtk_adjustment_new (1.0, 0.0, 1.0, 0.05, 0.1, 0));
    self->volume_scale = GTK_SCALE (gtk_scale_new (GTK_ORIENTATION_HORIZONTAL, self->volume_adj));
    gtk_scale_set_draw_value (self->volume_scale, FALSE);
    gtk_widget_set_size_request (GTK_WIDGET (self->volume_scale), 80, -1);
    gtk_widget_set_valign       (GTK_WIDGET (self->volume_scale), GTK_ALIGN_CENTER);
    g_signal_connect (self->volume_adj, "value-changed",
                      G_CALLBACK (on_volume_value_changed), self);

    gtk_box_append (GTK_BOX (vol_row), GTK_WIDGET (self->volume_btn));
    gtk_box_append (GTK_BOX (vol_row), GTK_WIDGET (self->volume_scale));
    gtk_box_append (GTK_BOX (self), vol_row);
  }

  self->volume_before_mute = 1.0;

  /* Shuffle + repeat — vertically centered so their hover/press hit-area
   * lines up with the rest of the bar instead of stretching full height. */
  {
    self->shuffle_btn = GTK_TOGGLE_BUTTON (gtk_toggle_button_new ());
    gtk_button_set_icon_name (GTK_BUTTON (self->shuffle_btn), "media-playlist-shuffle-symbolic");
    gtk_widget_add_css_class (GTK_WIDGET (self->shuffle_btn), "flat");
    gtk_widget_add_css_class (GTK_WIDGET (self->shuffle_btn), "circular");
    gtk_widget_set_valign    (GTK_WIDGET (self->shuffle_btn), GTK_ALIGN_CENTER);
    g_signal_connect (self->shuffle_btn, "toggled", G_CALLBACK (on_shuffle_toggled), self);

    self->repeat_icon = GTK_IMAGE (gtk_image_new_from_icon_name ("media-playlist-consecutive-symbolic"));
    self->repeat_btn  = GTK_BUTTON (gtk_button_new ());
    gtk_button_set_child (self->repeat_btn, GTK_WIDGET (self->repeat_icon));
    gtk_widget_add_css_class (GTK_WIDGET (self->repeat_btn), "flat");
    gtk_widget_add_css_class (GTK_WIDGET (self->repeat_btn), "circular");
    gtk_widget_set_valign    (GTK_WIDGET (self->repeat_btn), GTK_ALIGN_CENTER);
    g_signal_connect (self->repeat_btn, "clicked", G_CALLBACK (on_repeat_clicked), self);

    gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->shuffle_btn));
    gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->repeat_btn));
  }
}

GtkWidget *
music_player_bar_new (MusicPlayer *player)
{
  g_return_val_if_fail (MUSIC_IS_PLAYER (player), NULL);

  MusicPlayerBar *self = g_object_new (MUSIC_TYPE_PLAYER_BAR, NULL);
  self->player = g_object_ref (player);

  g_signal_connect_object (player, "notify::current",  G_CALLBACK (on_current_changed),  self, 0);
  g_signal_connect_object (player, "notify::playing",  G_CALLBACK (on_playing_changed),  self, 0);
  g_signal_connect_object (player, "notify::position", G_CALLBACK (on_position_changed), self, 0);
  g_signal_connect_object (player, "notify::duration", G_CALLBACK (on_duration_changed), self, 0);
  g_signal_connect_object (player, "notify::shuffle",  G_CALLBACK (on_shuffle_changed),  self, 0);
  g_signal_connect_object (player, "notify::repeat",   G_CALLBACK (on_repeat_changed),   self, 0);
  g_signal_connect_object (player, "notify::volume",   G_CALLBACK (on_volume_changed),   self, 0);

  /* Sync initial state */
  on_current_changed  (NULL, NULL, self);
  on_playing_changed  (NULL, NULL, self);
  on_duration_changed (NULL, NULL, self);
  on_position_changed (NULL, NULL, self);
  on_shuffle_changed  (NULL, NULL, self);
  on_repeat_changed   (NULL, NULL, self);
  on_volume_changed   (NULL, NULL, self);

  return GTK_WIDGET (self);
}
