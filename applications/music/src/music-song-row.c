#include "music-song-row.h"

#include <adwaita.h>
#include "music-library.h"
#include "music-playlist.h"

struct _MusicSongRow
{
  GtkBox parent_instance;

  GtkButton       *play_btn;
  GtkImage        *play_icon;
  GtkLabel        *title_label;
  GtkLabel        *artist_label;
  GtkLabel        *album_label;
  GtkLabel        *duration_label;
  GtkButton       *favorite_btn;
  GtkImage        *favorite_icon;
  GtkMenuButton   *menu_btn;

  MusicSong       *song;
  GPtrArray       *bindings;
};

G_DEFINE_FINAL_TYPE (MusicSongRow, music_song_row, GTK_TYPE_BOX)

enum {
  SIG_PLAY_REQUESTED,
  N_SIGNALS,
};
static guint signals[N_SIGNALS];

/* ---------- helpers ---------- */

static void
free_binding (gpointer data)
{
  GBinding *b = data;
  g_binding_unbind (b);
  g_object_unref (b);
}

static gboolean
xform_duration (GBinding *b, const GValue *src, GValue *dst, gpointer ud)
{
  (void) b; (void) ud;
  gint64 secs = g_value_get_int64 (src);
  if (secs <= 0)
    {
      g_value_set_string (dst, "—");
    }
  else
    {
      char *s = g_strdup_printf ("%" G_GINT64_FORMAT ":%02" G_GINT64_FORMAT,
                                 secs / 60, secs % 60);
      g_value_take_string (dst, s);
    }
  return TRUE;
}

static gboolean
xform_favorite (GBinding *b, const GValue *src, GValue *dst, gpointer ud)
{
  (void) b; (void) ud;
  g_value_set_string (dst,
      g_value_get_boolean (src) ? "starred-symbolic" : "non-starred-symbolic");
  return TRUE;
}

static gboolean
xform_artist_text (GBinding *b, const GValue *src, GValue *dst, gpointer ud)
{
  (void) b; (void) ud;
  const char *raw = g_value_get_string (src);
  g_value_set_string (dst, (raw && *raw) ? raw : "Unknown Artist");
  return TRUE;
}

static gboolean
xform_album_text (GBinding *b, const GValue *src, GValue *dst, gpointer ud)
{
  (void) b; (void) ud;
  const char *raw = g_value_get_string (src);
  g_value_set_string (dst, (raw && *raw) ? raw : "Unknown Album");
  return TRUE;
}

/* ---------- signals ---------- */

static void
on_play_clicked (GtkButton *btn, gpointer user_data)
{
  (void) btn;
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  g_signal_emit (self, signals[SIG_PLAY_REQUESTED], 0);
}

static void
on_favorite_clicked (GtkButton *btn, gpointer user_data)
{
  (void) btn;
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  if (!self->song)
    return;
  music_song_set_favorite (self->song, !music_song_get_favorite (self->song));
}

/* ---------- menu actions ---------- */

static void
action_toggle_favorite (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  if (!self->song)
    return;
  music_song_set_favorite (self->song, !music_song_get_favorite (self->song));
}

static void
action_add_to_playlist (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a;
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  if (!self->song || !p)
    return;
  const char *name = g_variant_get_string (p, NULL);
  if (!name)
    return;

  MusicLibrary *lib = music_library_get_default ();
  GListModel *pls = music_library_get_playlists (lib);
  guint n = g_list_model_get_n_items (pls);
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicPlaylist) pl = g_list_model_get_item (pls, i);
      if (g_strcmp0 (music_playlist_get_name (pl), name) == 0)
        {
          music_playlist_add_song (pl, self->song);
          return;
        }
    }
}

typedef struct {
  MusicSong *song;
  GtkEntry  *entry;
} NewPlaylistCtx;

static void
on_new_playlist_response (AdwAlertDialog *dlg, const char *response, gpointer user_data)
{
  (void) dlg;
  NewPlaylistCtx *ctx = user_data;
  if (g_strcmp0 (response, "create") == 0)
    {
      const char *name = gtk_editable_get_text (GTK_EDITABLE (ctx->entry));
      if (name && *name)
        {
          MusicLibrary *lib = music_library_get_default ();
          MusicPlaylist *pl = music_library_create_playlist (lib, name);
          if (pl)
            music_playlist_add_song (pl, ctx->song);
        }
    }
  g_clear_object (&ctx->song);
  g_free (ctx);
}

static void
action_new_playlist (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  if (!self->song)
    return;

  AdwDialog *dlg = adw_alert_dialog_new ("New Playlist", "Enter a name:");
  GtkWidget *entry = gtk_entry_new ();
  gtk_entry_set_placeholder_text (GTK_ENTRY (entry), "Playlist name");
  adw_alert_dialog_set_extra_child (ADW_ALERT_DIALOG (dlg), entry);
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "cancel", "Cancel");
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "create", "Create");
  adw_alert_dialog_set_response_appearance (ADW_ALERT_DIALOG (dlg), "create",
                                            ADW_RESPONSE_SUGGESTED);
  adw_alert_dialog_set_default_response (ADW_ALERT_DIALOG (dlg), "create");
  adw_alert_dialog_set_close_response   (ADW_ALERT_DIALOG (dlg), "cancel");

  NewPlaylistCtx *ctx = g_new0 (NewPlaylistCtx, 1);
  ctx->song  = g_object_ref (self->song);
  ctx->entry = GTK_ENTRY (entry);
  g_signal_connect (dlg, "response", G_CALLBACK (on_new_playlist_response), ctx);

  adw_dialog_present (dlg, GTK_WIDGET (self));
}

static const GActionEntry row_actions[] = {
  { "toggle-favorite", action_toggle_favorite, NULL, NULL, NULL, { 0, 0, 0 } },
  { "add-to-playlist", action_add_to_playlist, "s",  NULL, NULL, { 0, 0, 0 } },
  { "new-playlist",    action_new_playlist,    NULL, NULL, NULL, { 0, 0, 0 } },
};

static void
build_row_menu (GtkMenuButton *btn, gpointer user_data)
{
  MusicSongRow *self = MUSIC_SONG_ROW (user_data);
  if (!self->song)
    {
      gtk_menu_button_set_menu_model (btn, NULL);
      return;
    }

  gboolean fav = music_song_get_favorite (self->song);

  GMenu *menu = g_menu_new ();

  /* Favorite section */
  {
    GMenu *sec = g_menu_new ();
    g_menu_append (sec,
                   fav ? "Remove from Favorites" : "Add to Favorites",
                   "row.toggle-favorite");
    g_menu_append_section (menu, NULL, G_MENU_MODEL (sec));
    g_object_unref (sec);
  }

  /* Existing playlists section */
  MusicLibrary *lib = music_library_get_default ();
  GListModel *pls = music_library_get_playlists (lib);
  guint n = g_list_model_get_n_items (pls);
  if (n > 0)
    {
      GMenu *sec = g_menu_new ();
      for (guint i = 0; i < n; i++)
        {
          g_autoptr (MusicPlaylist) pl = g_list_model_get_item (pls, i);
          const char *name = music_playlist_get_name (pl);
          GMenuItem *item = g_menu_item_new (name, NULL);
          g_menu_item_set_action_and_target_value (item,
              "row.add-to-playlist", g_variant_new_string (name));
          g_menu_append_item (sec, item);
          g_object_unref (item);
        }
      g_menu_append_section (menu, "Add to Playlist", G_MENU_MODEL (sec));
      g_object_unref (sec);
    }

  /* New playlist section */
  {
    GMenu *sec = g_menu_new ();
    g_menu_append (sec, "New Playlist…", "row.new-playlist");
    g_menu_append_section (menu, NULL, G_MENU_MODEL (sec));
    g_object_unref (sec);
  }

  gtk_menu_button_set_menu_model (btn, G_MENU_MODEL (menu));
  g_object_unref (menu);
}

/* ---------- lifecycle ---------- */

static void
music_song_row_dispose (GObject *obj)
{
  MusicSongRow *self = MUSIC_SONG_ROW (obj);
  if (self->bindings)
    g_ptr_array_set_size (self->bindings, 0);
  g_clear_object (&self->song);
  G_OBJECT_CLASS (music_song_row_parent_class)->dispose (obj);
}

static void
music_song_row_finalize (GObject *obj)
{
  MusicSongRow *self = MUSIC_SONG_ROW (obj);
  g_clear_pointer (&self->bindings, g_ptr_array_unref);
  G_OBJECT_CLASS (music_song_row_parent_class)->finalize (obj);
}

static void
music_song_row_class_init (MusicSongRowClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose  = music_song_row_dispose;
  oc->finalize = music_song_row_finalize;

  signals[SIG_PLAY_REQUESTED] = g_signal_new ("play-requested",
      G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST, 0,
      NULL, NULL, NULL, G_TYPE_NONE, 0);
}

static void
music_song_row_init (MusicSongRow *self)
{
  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_HORIZONTAL);
  gtk_box_set_spacing (GTK_BOX (self), 12);
  gtk_widget_set_margin_top    (GTK_WIDGET (self), 4);
  gtk_widget_set_margin_bottom (GTK_WIDGET (self), 4);
  gtk_widget_set_margin_start  (GTK_WIDGET (self), 8);
  gtk_widget_set_margin_end    (GTK_WIDGET (self), 8);

  self->bindings = g_ptr_array_new_with_free_func (free_binding);

  /* Play button */
  self->play_icon = GTK_IMAGE (gtk_image_new_from_icon_name ("media-playback-start-symbolic"));
  self->play_btn = GTK_BUTTON (gtk_button_new ());
  gtk_button_set_child (self->play_btn, GTK_WIDGET (self->play_icon));
  gtk_widget_add_css_class (GTK_WIDGET (self->play_btn), "flat");
  gtk_widget_add_css_class (GTK_WIDGET (self->play_btn), "circular");
  gtk_widget_set_valign (GTK_WIDGET (self->play_btn), GTK_ALIGN_CENTER);
  g_signal_connect (self->play_btn, "clicked", G_CALLBACK (on_play_clicked), self);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->play_btn));

  /* Title (fixed width, ellipsize if too long) */
  self->title_label = GTK_LABEL (gtk_label_new (""));
  gtk_label_set_xalign          (self->title_label, 0);
  gtk_label_set_ellipsize       (self->title_label, PANGO_ELLIPSIZE_END);
  gtk_label_set_width_chars     (self->title_label, 30);
  gtk_label_set_max_width_chars (self->title_label, 30);
  gtk_widget_add_css_class      (GTK_WIDGET (self->title_label), "heading");
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->title_label));

  /* Artist */
  self->artist_label = GTK_LABEL (gtk_label_new (""));
  gtk_label_set_xalign      (self->artist_label, 0);
  gtk_label_set_ellipsize   (self->artist_label, PANGO_ELLIPSIZE_END);
  gtk_label_set_width_chars (self->artist_label, 16);
  gtk_label_set_max_width_chars (self->artist_label, 22);
  gtk_widget_add_css_class  (GTK_WIDGET (self->artist_label), "dim-label");
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->artist_label));

  /* Album */
  self->album_label = GTK_LABEL (gtk_label_new (""));
  gtk_label_set_xalign      (self->album_label, 0);
  gtk_label_set_ellipsize   (self->album_label, PANGO_ELLIPSIZE_END);
  gtk_label_set_width_chars (self->album_label, 16);
  gtk_label_set_max_width_chars (self->album_label, 22);
  gtk_widget_add_css_class  (GTK_WIDGET (self->album_label), "dim-label");
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->album_label));

  /* Flexible spacer so duration / favorite / menu pack to the right edge */
  {
    GtkWidget *spacer = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_hexpand (spacer, TRUE);
    gtk_box_append (GTK_BOX (self), spacer);
  }

  /* Duration */
  self->duration_label = GTK_LABEL (gtk_label_new ("—"));
  gtk_label_set_xalign      (self->duration_label, 1);
  gtk_label_set_width_chars (self->duration_label, 5);
  gtk_widget_add_css_class  (GTK_WIDGET (self->duration_label), "numeric");
  gtk_widget_add_css_class  (GTK_WIDGET (self->duration_label), "dim-label");
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->duration_label));

  /* Favorite */
  self->favorite_icon = GTK_IMAGE (gtk_image_new_from_icon_name ("non-starred-symbolic"));
  self->favorite_btn  = GTK_BUTTON (gtk_button_new ());
  gtk_button_set_child (self->favorite_btn, GTK_WIDGET (self->favorite_icon));
  gtk_widget_add_css_class (GTK_WIDGET (self->favorite_btn), "flat");
  gtk_widget_add_css_class (GTK_WIDGET (self->favorite_btn), "circular");
  gtk_widget_set_valign    (GTK_WIDGET (self->favorite_btn), GTK_ALIGN_CENTER);
  g_signal_connect (self->favorite_btn, "clicked", G_CALLBACK (on_favorite_clicked), self);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->favorite_btn));

  /* 3-dot menu */
  GSimpleActionGroup *group = g_simple_action_group_new ();
  g_action_map_add_action_entries (G_ACTION_MAP (group),
                                   row_actions, G_N_ELEMENTS (row_actions), self);
  gtk_widget_insert_action_group (GTK_WIDGET (self), "row", G_ACTION_GROUP (group));
  g_object_unref (group);

  self->menu_btn = GTK_MENU_BUTTON (gtk_menu_button_new ());
  gtk_menu_button_set_icon_name (self->menu_btn, "view-more-symbolic");
  gtk_widget_add_css_class (GTK_WIDGET (self->menu_btn), "flat");
  gtk_widget_add_css_class (GTK_WIDGET (self->menu_btn), "circular");
  gtk_widget_set_valign    (GTK_WIDGET (self->menu_btn), GTK_ALIGN_CENTER);
  gtk_menu_button_set_create_popup_func (self->menu_btn, build_row_menu, self, NULL);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->menu_btn));
}

GtkWidget *
music_song_row_new (void)
{
  return g_object_new (MUSIC_TYPE_SONG_ROW, NULL);
}

MusicSong *
music_song_row_get_song (MusicSongRow *self)
{
  g_return_val_if_fail (MUSIC_IS_SONG_ROW (self), NULL);
  return self->song;
}

void
music_song_row_set_song (MusicSongRow *self, MusicSong *song)
{
  g_return_if_fail (MUSIC_IS_SONG_ROW (self));

  if (self->song == song)
    return;

  g_ptr_array_set_size (self->bindings, 0);
  g_set_object (&self->song, song);

  if (!song)
    {
      gtk_label_set_text (self->title_label,    "");
      gtk_label_set_text (self->artist_label,   "");
      gtk_label_set_text (self->album_label,    "");
      gtk_label_set_text (self->duration_label, "—");
      gtk_image_set_from_icon_name (self->favorite_icon, "non-starred-symbolic");
      return;
    }

#define ADD_BIND(b) g_ptr_array_add (self->bindings, g_object_ref (b))

  ADD_BIND (g_object_bind_property (song, "title",
                                    self->title_label, "label",
                                    G_BINDING_SYNC_CREATE));
  ADD_BIND (g_object_bind_property_full (song, "artist",
                                         self->artist_label, "label",
                                         G_BINDING_SYNC_CREATE,
                                         xform_artist_text, NULL, NULL, NULL));
  ADD_BIND (g_object_bind_property_full (song, "album",
                                         self->album_label, "label",
                                         G_BINDING_SYNC_CREATE,
                                         xform_album_text, NULL, NULL, NULL));
  ADD_BIND (g_object_bind_property_full (song, "duration",
                                         self->duration_label, "label",
                                         G_BINDING_SYNC_CREATE,
                                         xform_duration, NULL, NULL, NULL));
  ADD_BIND (g_object_bind_property_full (song, "favorite",
                                         self->favorite_icon, "icon-name",
                                         G_BINDING_SYNC_CREATE,
                                         xform_favorite, NULL, NULL, NULL));

#undef ADD_BIND
}

void
music_song_row_set_playing (MusicSongRow *self, gboolean playing)
{
  g_return_if_fail (MUSIC_IS_SONG_ROW (self));
  gtk_image_set_from_icon_name (self->play_icon,
      playing ? "media-playback-pause-symbolic"
              : "media-playback-start-symbolic");
}
