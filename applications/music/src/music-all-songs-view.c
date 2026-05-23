#include "music-all-songs-view.h"

#include "music-song-row.h"
#include <string.h>

struct _MusicAllSongsView
{
  GtkBox parent_instance;

  MusicLibrary       *library;
  MusicPlayer        *player;

  GtkLabel           *subtitle_label;
  GtkSearchBar       *search_bar;
  GtkSearchEntry     *search_entry;
  GtkListView        *list_view;
  GtkCustomFilter    *filter;
  GtkFilterListModel *filter_model;

  char               *search_text;
};

G_DEFINE_FINAL_TYPE (MusicAllSongsView, music_all_songs_view, GTK_TYPE_BOX)

/* ---------- filter ---------- */

static gboolean
match_song (gpointer item, gpointer user_data)
{
  MusicAllSongsView *self = user_data;
  if (!self->search_text || !*self->search_text)
    return TRUE;

  MusicSong *s = item;
  g_autofree char *needle = g_utf8_strdown (self->search_text, -1);

  const char *fields[3] = {
    music_song_get_title  (s),
    music_song_get_artist (s),
    music_song_get_album  (s),
  };
  for (int i = 0; i < 3; i++)
    {
      if (!fields[i])
        continue;
      g_autofree char *down = g_utf8_strdown (fields[i], -1);
      if (strstr (down, needle))
        return TRUE;
    }
  return FALSE;
}

/* ---------- callbacks ---------- */

static void
update_subtitle (MusicAllSongsView *self)
{
  guint n = g_list_model_get_n_items (G_LIST_MODEL (self->filter_model));
  g_autofree char *txt = g_strdup_printf ("%u %s", n, n == 1 ? "Song" : "Songs");
  gtk_label_set_text (self->subtitle_label, txt);
}

static void
on_items_changed (GListModel *m, guint p, guint r, guint a, gpointer user_data)
{
  (void) m; (void) p; (void) r; (void) a;
  update_subtitle (MUSIC_ALL_SONGS_VIEW (user_data));
}

static void
on_search_changed (GtkSearchEntry *e, gpointer user_data)
{
  MusicAllSongsView *self = MUSIC_ALL_SONGS_VIEW (user_data);
  g_clear_pointer (&self->search_text, g_free);
  self->search_text = g_strdup (gtk_editable_get_text (GTK_EDITABLE (e)));
  gtk_filter_changed (GTK_FILTER (self->filter), GTK_FILTER_CHANGE_DIFFERENT);
}

static void
on_row_play_requested (GtkWidget *row, gpointer user_data)
{
  MusicAllSongsView *self = MUSIC_ALL_SONGS_VIEW (user_data);
  MusicSong *song = music_song_row_get_song (MUSIC_SONG_ROW (row));
  if (!song)
    return;

  GListModel *m = G_LIST_MODEL (self->filter_model);
  guint n = g_list_model_get_n_items (m);
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicSong) s = g_list_model_get_item (m, i);
      if (s == song)
        {
          music_player_play_in_queue (self->player, m, i);
          return;
        }
    }
}

static void
on_factory_setup (GtkSignalListItemFactory *f, GtkListItem *li, gpointer ud)
{
  (void) f; (void) ud;
  GtkWidget *row = music_song_row_new ();
  gtk_list_item_set_child (li, row);
}

static void
on_factory_bind (GtkSignalListItemFactory *f, GtkListItem *li, gpointer ud)
{
  (void) f;
  GtkWidget *row = gtk_list_item_get_child (li);
  MusicSong *song = MUSIC_SONG (gtk_list_item_get_item (li));
  music_song_row_set_song (MUSIC_SONG_ROW (row), song);
  g_signal_connect (row, "play-requested",
                    G_CALLBACK (on_row_play_requested), ud);
}

static void
on_factory_unbind (GtkSignalListItemFactory *f, GtkListItem *li, gpointer ud)
{
  (void) f;
  GtkWidget *row = gtk_list_item_get_child (li);
  g_signal_handlers_disconnect_by_data (row, ud);
  music_song_row_set_song (MUSIC_SONG_ROW (row), NULL);
}

static void
on_list_activate (GtkListView *lv, guint pos, gpointer ud)
{
  (void) lv;
  MusicAllSongsView *self = MUSIC_ALL_SONGS_VIEW (ud);
  music_player_play_in_queue (self->player,
                              G_LIST_MODEL (self->filter_model), pos);
}

static void
on_play_all (GtkButton *b, gpointer ud)
{
  (void) b;
  MusicAllSongsView *self = MUSIC_ALL_SONGS_VIEW (ud);
  if (g_list_model_get_n_items (G_LIST_MODEL (self->filter_model)) == 0)
    return;
  music_player_play_in_queue (self->player,
                              G_LIST_MODEL (self->filter_model), 0);
}

/* ---------- lifecycle ---------- */

static void
music_all_songs_view_dispose (GObject *obj)
{
  MusicAllSongsView *self = MUSIC_ALL_SONGS_VIEW (obj);
  g_clear_object  (&self->library);
  g_clear_object  (&self->player);
  g_clear_pointer (&self->search_text, g_free);
  G_OBJECT_CLASS (music_all_songs_view_parent_class)->dispose (obj);
}

static void
music_all_songs_view_class_init (MusicAllSongsViewClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose = music_all_songs_view_dispose;
}

static void
music_all_songs_view_init (MusicAllSongsView *self)
{
  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_VERTICAL);
  gtk_widget_set_hexpand (GTK_WIDGET (self), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self), TRUE);
}

/* ---------- public ---------- */

GtkWidget *
music_all_songs_view_new (MusicLibrary *library, MusicPlayer *player)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (library), NULL);
  g_return_val_if_fail (MUSIC_IS_PLAYER  (player),  NULL);

  MusicAllSongsView *self = g_object_new (MUSIC_TYPE_ALL_SONGS_VIEW, NULL);
  self->library = g_object_ref (library);
  self->player  = g_object_ref (player);

  /* --- Header section --- */
  {
    GtkWidget *header = gtk_box_new (GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_margin_top    (header, 24);
    gtk_widget_set_margin_start  (header, 24);
    gtk_widget_set_margin_end    (header, 24);
    gtk_widget_set_margin_bottom (header, 12);

    GtkWidget *title = gtk_label_new ("All Songs");
    gtk_label_set_xalign (GTK_LABEL (title), 0);
    gtk_widget_add_css_class (title, "title-1");
    gtk_box_append (GTK_BOX (header), title);

    self->subtitle_label = GTK_LABEL (gtk_label_new ("0 Songs"));
    gtk_label_set_xalign (self->subtitle_label, 0);
    gtk_widget_add_css_class (GTK_WIDGET (self->subtitle_label), "dim-label");
    gtk_box_append (GTK_BOX (header), GTK_WIDGET (self->subtitle_label));

    /* Play-all row */
    GtkWidget *action_row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_widget_set_margin_top (action_row, 8);

    GtkWidget *play_all = gtk_button_new_from_icon_name ("media-playback-start-symbolic");
    gtk_widget_add_css_class (play_all, "circular");
    gtk_widget_set_size_request (play_all, 44, 44);
    g_signal_connect (play_all, "clicked", G_CALLBACK (on_play_all), self);
    gtk_box_append (GTK_BOX (action_row), play_all);

    gtk_box_append (GTK_BOX (header), action_row);
    gtk_box_append (GTK_BOX (self), header);
  }

  /* --- Search bar --- */
  self->search_entry = GTK_SEARCH_ENTRY (gtk_search_entry_new ());
  gtk_widget_set_hexpand (GTK_WIDGET (self->search_entry), TRUE);
  g_signal_connect (self->search_entry, "search-changed",
                    G_CALLBACK (on_search_changed), self);

  self->search_bar = GTK_SEARCH_BAR (gtk_search_bar_new ());
  gtk_search_bar_set_child (self->search_bar, GTK_WIDGET (self->search_entry));
  gtk_search_bar_connect_entry (self->search_bar, GTK_EDITABLE (self->search_entry));
  gtk_search_bar_set_key_capture_widget (self->search_bar, GTK_WIDGET (self));
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->search_bar));

  /* --- Filter + sort over library songs --- */
  GListModel *songs = music_library_get_songs (library);

  self->filter = gtk_custom_filter_new (match_song, self, NULL);
  self->filter_model = gtk_filter_list_model_new (g_object_ref (songs),
                                                  GTK_FILTER (self->filter));
  /* `filter` ref'd by the model now */

  g_signal_connect (self->filter_model, "items-changed",
                    G_CALLBACK (on_items_changed), self);

  /* --- List view --- */
  GtkSelectionModel *sel =
      GTK_SELECTION_MODEL (gtk_no_selection_new (G_LIST_MODEL (self->filter_model)));

  GtkListItemFactory *factory = gtk_signal_list_item_factory_new ();
  g_signal_connect (factory, "setup",   G_CALLBACK (on_factory_setup),   self);
  g_signal_connect (factory, "bind",    G_CALLBACK (on_factory_bind),    self);
  g_signal_connect (factory, "unbind",  G_CALLBACK (on_factory_unbind),  self);

  self->list_view = GTK_LIST_VIEW (gtk_list_view_new (sel, factory));
  gtk_list_view_set_show_separators (self->list_view, TRUE);
  g_signal_connect (self->list_view, "activate",
                    G_CALLBACK (on_list_activate), self);

  GtkWidget *scrolled = gtk_scrolled_window_new ();
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled),
                                  GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_scrolled_window_set_child (GTK_SCROLLED_WINDOW (scrolled), GTK_WIDGET (self->list_view));
  gtk_widget_set_vexpand (scrolled, TRUE);
  gtk_widget_set_margin_start  (scrolled, 12);
  gtk_widget_set_margin_end    (scrolled, 12);
  gtk_widget_set_margin_bottom (scrolled, 12);
  gtk_box_append (GTK_BOX (self), scrolled);

  update_subtitle (self);
  return GTK_WIDGET (self);
}

void
music_all_songs_view_toggle_search (MusicAllSongsView *self)
{
  g_return_if_fail (MUSIC_IS_ALL_SONGS_VIEW (self));
  gboolean active = gtk_search_bar_get_search_mode (self->search_bar);
  gtk_search_bar_set_search_mode (self->search_bar, !active);
  if (!active)
    gtk_widget_grab_focus (GTK_WIDGET (self->search_entry));
}
