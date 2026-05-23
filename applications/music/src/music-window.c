#include "music-window.h"

#include "music-library.h"
#include "music-player.h"
#include "music-player-bar.h"
#include "music-all-songs-view.h"
#include "music-playlists-view.h"
#include "music-preferences.h"

struct _MusicWindow
{
  AdwApplicationWindow parent_instance;

  MusicLibrary *library;
  MusicPlayer  *player;

  AdwViewStack *stack;
  GtkWidget    *all_songs_view;
  GtkWidget    *playlists_view;
};

G_DEFINE_FINAL_TYPE (MusicWindow, music_window, ADW_TYPE_APPLICATION_WINDOW)

/* ---------- actions ---------- */

static void
on_folder_chosen (GObject *source, GAsyncResult *res, gpointer user_data)
{
  MusicWindow *self = MUSIC_WINDOW (user_data);
  GtkFileDialog *dlg = GTK_FILE_DIALOG (source);
  g_autoptr (GError) err = NULL;
  g_autoptr (GFile) folder = gtk_file_dialog_select_folder_finish (dlg, res, &err);
  if (!folder)
    return;
  g_autofree char *path = g_file_get_path (folder);
  if (path)
    music_library_add_directory (self->library, path);
}

static void
on_action_add_folder (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicWindow *self = MUSIC_WINDOW (user_data);

  GtkFileDialog *dlg = gtk_file_dialog_new ();
  gtk_file_dialog_set_title (dlg, "Add Music Folder");
  gtk_file_dialog_set_modal (dlg, TRUE);
  g_autoptr (GFile) home = g_file_new_for_path (g_get_home_dir ());
  gtk_file_dialog_set_initial_folder (dlg, home);
  gtk_file_dialog_select_folder (dlg, GTK_WINDOW (self), NULL,
                                 on_folder_chosen, self);
  g_object_unref (dlg);
}

static void
on_action_preferences (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicWindow *self = MUSIC_WINDOW (user_data);
  AdwDialog *dlg = music_preferences_new (self->library);
  adw_dialog_present (dlg, GTK_WIDGET (self));
}

static void
on_action_about (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicWindow *self = MUSIC_WINDOW (user_data);

  AdwDialog *dlg = adw_about_dialog_new ();
  adw_about_dialog_set_application_name (ADW_ABOUT_DIALOG (dlg), "Music");
  adw_about_dialog_set_application_icon (ADW_ABOUT_DIALOG (dlg), APP_ID);
  adw_about_dialog_set_version          (ADW_ABOUT_DIALOG (dlg), APP_VERSION);
  adw_about_dialog_set_developer_name   (ADW_ABOUT_DIALOG (dlg), "Sandip");
  adw_about_dialog_set_license_type     (ADW_ABOUT_DIALOG (dlg), GTK_LICENSE_GPL_3_0);
  adw_about_dialog_set_comments         (ADW_ABOUT_DIALOG (dlg),
      "A minimal GTK4 + libadwaita music player.");
  adw_dialog_present (dlg, GTK_WIDGET (self));
}

static void
on_action_search (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  MusicWindow *self = MUSIC_WINDOW (user_data);
  adw_view_stack_set_visible_child_name (self->stack, "all-songs");
  music_all_songs_view_toggle_search (MUSIC_ALL_SONGS_VIEW (self->all_songs_view));
}

static const GActionEntry win_actions[] = {
  { "add-folder",  on_action_add_folder,  NULL, NULL, NULL, { 0, 0, 0 } },
  { "preferences", on_action_preferences, NULL, NULL, NULL, { 0, 0, 0 } },
  { "about",       on_action_about,       NULL, NULL, NULL, { 0, 0, 0 } },
  { "search",      on_action_search,      NULL, NULL, NULL, { 0, 0, 0 } },
};

/* ---------- lifecycle ---------- */

static void
music_window_dispose (GObject *obj)
{
  MusicWindow *self = MUSIC_WINDOW (obj);
  if (self->library)
    music_library_save (self->library);
  g_clear_object (&self->player);
  g_clear_object (&self->library);
  G_OBJECT_CLASS (music_window_parent_class)->dispose (obj);
}

static void
music_window_class_init (MusicWindowClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose = music_window_dispose;
}

static void
music_window_init (MusicWindow *self)
{
  self->library = g_object_ref (music_library_get_default ());
  self->player  = music_player_new ();

  gtk_window_set_title (GTK_WINDOW (self), "Music");
  gtk_window_set_default_size (GTK_WINDOW (self), 1100, 720);

  g_action_map_add_action_entries (G_ACTION_MAP (self),
                                   win_actions, G_N_ELEMENTS (win_actions), self);

  AdwToolbarView *tv = ADW_TOOLBAR_VIEW (adw_toolbar_view_new ());

  /* ---- header bar ---- */
  AdwHeaderBar *hb = ADW_HEADER_BAR (adw_header_bar_new ());

  GtkWidget *search = gtk_button_new_from_icon_name ("system-search-symbolic");
  gtk_widget_set_tooltip_text (search, "Search (Ctrl+F)");
  gtk_actionable_set_action_name (GTK_ACTIONABLE (search), "win.search");
  adw_header_bar_pack_start (hb, search);

  /* ---- content stack with two pages ---- */
  self->stack = ADW_VIEW_STACK (adw_view_stack_new ());

  self->all_songs_view = music_all_songs_view_new (self->library, self->player);
  adw_view_stack_add_titled_with_icon (self->stack, self->all_songs_view,
                                       "all-songs", "All Songs",
                                       "audio-x-generic-symbolic");

  self->playlists_view = music_playlists_view_new (self->library, self->player);
  adw_view_stack_add_titled_with_icon (self->stack, self->playlists_view,
                                       "playlists", "Playlists",
                                       "view-list-symbolic");

  AdwViewSwitcher *switcher = ADW_VIEW_SWITCHER (adw_view_switcher_new ());
  adw_view_switcher_set_stack  (switcher, self->stack);
  adw_view_switcher_set_policy (switcher, ADW_VIEW_SWITCHER_POLICY_WIDE);
  adw_header_bar_set_title_widget (hb, GTK_WIDGET (switcher));

  /* ---- menu ---- */
  GMenu *menu = g_menu_new ();
  g_menu_append (menu, "Add Folder…", "win.add-folder");
  g_menu_append (menu, "Preferences", "win.preferences");
  g_menu_append (menu, "About Music", "win.about");

  GtkMenuButton *mb = GTK_MENU_BUTTON (gtk_menu_button_new ());
  gtk_menu_button_set_icon_name  (mb, "open-menu-symbolic");
  gtk_menu_button_set_menu_model (mb, G_MENU_MODEL (menu));
  g_object_unref (menu);
  adw_header_bar_pack_end (hb, GTK_WIDGET (mb));

  adw_toolbar_view_add_top_bar (tv, GTK_WIDGET (hb));
  adw_toolbar_view_set_content (tv, GTK_WIDGET (self->stack));

  /* ---- bottom: player bar ---- */
  GtkWidget *bar = music_player_bar_new (self->player);
  adw_toolbar_view_add_bottom_bar (tv, bar);

  adw_application_window_set_content (ADW_APPLICATION_WINDOW (self), GTK_WIDGET (tv));

  /* Kick off scan once the window is on screen. */
  music_library_scan (self->library);
}

/* ---------- public ---------- */

MusicWindow *
music_window_new (GtkApplication *app)
{
  return g_object_new (MUSIC_TYPE_WINDOW, "application", app, NULL);
}

void
music_window_open_files (MusicWindow *self, GFile **files, int n)
{
  g_return_if_fail (MUSIC_IS_WINDOW (self));
  if (!files || n <= 0)
    return;

  g_autoptr (GListStore) store = g_list_store_new (MUSIC_TYPE_SONG);
  for (int i = 0; i < n; i++)
    {
      if (!files[i])
        continue;
      g_autofree char *uri = g_file_get_uri (files[i]);
      if (!uri)
        continue;
      MusicSong *s = music_library_ensure_song_for_uri (self->library, uri);
      if (!s)
        continue;
      g_list_store_append (store, s);
      if (!music_song_get_has_metadata (s))
        music_library_queue_metadata (self->library, s);
    }

  if (g_list_model_get_n_items (G_LIST_MODEL (store)) > 0)
    music_player_play_in_queue (self->player, G_LIST_MODEL (store), 0);
}
