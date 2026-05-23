#include "music-application.h"

#include "music-window.h"

struct _MusicApplication
{
  AdwApplication parent_instance;
};

G_DEFINE_FINAL_TYPE (MusicApplication, music_application, ADW_TYPE_APPLICATION)

/* ---------- helpers ---------- */

static MusicWindow *
ensure_window (GApplication *app)
{
  GtkWindow *win = gtk_application_get_active_window (GTK_APPLICATION (app));
  if (!win)
    win = GTK_WINDOW (music_window_new (GTK_APPLICATION (app)));
  return MUSIC_WINDOW (win);
}

/* ---------- vfuncs ---------- */

static void
music_application_activate (GApplication *app)
{
  MusicWindow *win = ensure_window (app);
  gtk_window_present (GTK_WINDOW (win));
}

static void
music_application_open (GApplication *app, GFile **files, gint n_files, const gchar *hint)
{
  (void) hint;
  MusicWindow *win = ensure_window (app);
  gtk_window_present (GTK_WINDOW (win));
  music_window_open_files (win, files, (int) n_files);
}

static void
on_action_quit (GSimpleAction *a, GVariant *p, gpointer user_data)
{
  (void) a; (void) p;
  g_application_quit (G_APPLICATION (user_data));
}

static void
music_application_startup (GApplication *app)
{
  G_APPLICATION_CLASS (music_application_parent_class)->startup (app);

  GSimpleAction *quit = g_simple_action_new ("quit", NULL);
  g_signal_connect (quit, "activate", G_CALLBACK (on_action_quit), app);
  g_action_map_add_action (G_ACTION_MAP (app), G_ACTION (quit));
  g_object_unref (quit);

  const char *quit_accels[]   = { "<Control>q", NULL };
  const char *search_accels[] = { "<Control>f", NULL };
  gtk_application_set_accels_for_action (GTK_APPLICATION (app), "app.quit",   quit_accels);
  gtk_application_set_accels_for_action (GTK_APPLICATION (app), "win.search", search_accels);
}

/* ---------- lifecycle ---------- */

static void
music_application_class_init (MusicApplicationClass *klass)
{
  GApplicationClass *gac = G_APPLICATION_CLASS (klass);
  gac->activate = music_application_activate;
  gac->open     = music_application_open;
  gac->startup  = music_application_startup;
}

static void
music_application_init (MusicApplication *self)
{
  (void) self;
}

MusicApplication *
music_application_new (void)
{
  return g_object_new (MUSIC_TYPE_APPLICATION,
                       "application-id", APP_ID,
                       "flags", G_APPLICATION_HANDLES_OPEN,
                       NULL);
}
