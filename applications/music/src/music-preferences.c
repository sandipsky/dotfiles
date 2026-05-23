#include "music-preferences.h"

struct _MusicPreferences
{
  AdwPreferencesDialog parent_instance;

  MusicLibrary       *library;
  AdwPreferencesGroup *dirs_group;
  GPtrArray          *current_rows;   /* GtkWidget* (not refd; cleared en masse) */
};

G_DEFINE_FINAL_TYPE (MusicPreferences, music_preferences, ADW_TYPE_PREFERENCES_DIALOG)

/* ---------- rebuild directory list ---------- */

static void
on_remove_clicked (GtkButton *b, gpointer user_data)
{
  MusicPreferences *self = MUSIC_PREFERENCES (user_data);
  const char *path = g_object_get_data (G_OBJECT (b), "path");
  if (!path)
    return;
  music_library_remove_directory (self->library, path);
}

static void rebuild_dir_rows (MusicPreferences *self);

static void
on_directories_changed (MusicLibrary *lib, gpointer user_data)
{
  (void) lib;
  rebuild_dir_rows (MUSIC_PREFERENCES (user_data));
}

static void
rebuild_dir_rows (MusicPreferences *self)
{
  /* Remove previously-added rows */
  for (guint i = 0; i < self->current_rows->len; i++)
    {
      GtkWidget *row = g_ptr_array_index (self->current_rows, i);
      adw_preferences_group_remove (self->dirs_group, row);
    }
  g_ptr_array_set_size (self->current_rows, 0);

  GPtrArray *dirs = music_library_get_directories (self->library);
  for (guint i = 0; i < dirs->len; i++)
    {
      const char *path = g_ptr_array_index (dirs, i);
      GtkWidget *row = adw_action_row_new ();
      adw_preferences_row_set_title (ADW_PREFERENCES_ROW (row), path);

      GtkWidget *icon = gtk_image_new_from_icon_name ("folder-symbolic");
      adw_action_row_add_prefix (ADW_ACTION_ROW (row), icon);

      GtkWidget *remove = gtk_button_new_from_icon_name ("user-trash-symbolic");
      gtk_widget_add_css_class (remove, "flat");
      gtk_widget_set_valign (remove, GTK_ALIGN_CENTER);
      gtk_widget_set_tooltip_text (remove, "Remove");
      g_object_set_data_full (G_OBJECT (remove), "path", g_strdup (path), g_free);
      g_signal_connect (remove, "clicked", G_CALLBACK (on_remove_clicked), self);
      adw_action_row_add_suffix (ADW_ACTION_ROW (row), remove);

      adw_preferences_group_add (self->dirs_group, row);
      g_ptr_array_add (self->current_rows, row);
    }
}

/* ---------- add folder picker ---------- */

static void
on_folder_chosen (GObject *source, GAsyncResult *res, gpointer user_data)
{
  MusicPreferences *self = MUSIC_PREFERENCES (user_data);
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
on_add_clicked (GtkButton *b, gpointer user_data)
{
  MusicPreferences *self = MUSIC_PREFERENCES (user_data);

  GtkFileDialog *dlg = gtk_file_dialog_new ();
  gtk_file_dialog_set_title (dlg, "Add Music Folder");
  gtk_file_dialog_set_modal (dlg, TRUE);

  /* Initial folder: $HOME */
  g_autoptr (GFile) home = g_file_new_for_path (g_get_home_dir ());
  gtk_file_dialog_set_initial_folder (dlg, home);

  GtkWidget *parent_win = NULL;
  for (GtkWidget *w = GTK_WIDGET (b); w; w = gtk_widget_get_parent (w))
    if (GTK_IS_WINDOW (w))
      {
        parent_win = w;
        break;
      }

  gtk_file_dialog_select_folder (dlg, GTK_WINDOW (parent_win), NULL,
                                 on_folder_chosen, self);
  g_object_unref (dlg);
}

/* ---------- lifecycle ---------- */

static void
music_preferences_dispose (GObject *obj)
{
  MusicPreferences *self = MUSIC_PREFERENCES (obj);
  g_clear_object  (&self->library);
  g_clear_pointer (&self->current_rows, g_ptr_array_unref);
  G_OBJECT_CLASS (music_preferences_parent_class)->dispose (obj);
}

static void
music_preferences_class_init (MusicPreferencesClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose = music_preferences_dispose;
}

static void
music_preferences_init (MusicPreferences *self)
{
  self->current_rows = g_ptr_array_new ();
}

AdwDialog *
music_preferences_new (MusicLibrary *library)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (library), NULL);

  MusicPreferences *self = g_object_new (MUSIC_TYPE_PREFERENCES, NULL);
  self->library = g_object_ref (library);

  AdwPreferencesPage *page = ADW_PREFERENCES_PAGE (adw_preferences_page_new ());
  adw_preferences_page_set_icon_name (page, "folder-music-symbolic");
  adw_preferences_page_set_title     (page, "Library");

  self->dirs_group = ADW_PREFERENCES_GROUP (adw_preferences_group_new ());
  adw_preferences_group_set_title       (self->dirs_group, "Music Folders");
  adw_preferences_group_set_description (self->dirs_group,
      "These folders are scanned for audio files.");

  GtkWidget *add_btn = gtk_button_new_with_label ("Add");
  gtk_widget_add_css_class (add_btn, "flat");
  gtk_widget_set_valign (add_btn, GTK_ALIGN_CENTER);
  g_signal_connect (add_btn, "clicked", G_CALLBACK (on_add_clicked), self);
  adw_preferences_group_set_header_suffix (self->dirs_group, add_btn);

  adw_preferences_page_add (page, self->dirs_group);
  adw_preferences_dialog_add (ADW_PREFERENCES_DIALOG (self), page);

  rebuild_dir_rows (self);
  g_signal_connect_object (library, "directories-changed",
                           G_CALLBACK (on_directories_changed),
                           self, 0);

  return ADW_DIALOG (self);
}
