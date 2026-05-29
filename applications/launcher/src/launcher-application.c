#include "launcher-application.h"

#include "launcher-window.h"

struct _LauncherApplication
{
  AdwApplication parent_instance;
  gboolean       held; /* g_application_hold() called once */
};

G_DEFINE_FINAL_TYPE (LauncherApplication, launcher_application, ADW_TYPE_APPLICATION)

/* ---------- helpers ---------- */

static LauncherWindow *
ensure_window (LauncherApplication *self)
{
  /* The window is created hidden and kept alive for the life of the process,
   * so toggling it is instant. get_active_window() is NULL while it's hidden,
   * hence we look at the full window list. */
  GList *windows = gtk_application_get_windows (GTK_APPLICATION (self));
  if (windows != NULL)
    return LAUNCHER_WINDOW (windows->data);
  return LAUNCHER_WINDOW (launcher_window_new (GTK_APPLICATION (self)));
}

/* ---------- vfuncs ---------- */

static void
load_css (void)
{
  g_autoptr (GtkCssProvider) provider = gtk_css_provider_new ();
  gtk_css_provider_load_from_resource (provider, "/dev/sandip/Launcher/style.css");
  gtk_style_context_add_provider_for_display (gdk_display_get_default (),
                                              GTK_STYLE_PROVIDER (provider),
                                              GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

static void
launcher_application_startup (GApplication *app)
{
  G_APPLICATION_CLASS (launcher_application_parent_class)->startup (app);

  /* Dark-only, like the shell this mimics. */
  adw_style_manager_set_color_scheme (adw_style_manager_get_default (),
                                       ADW_COLOR_SCHEME_FORCE_DARK);
  load_css ();
}

/* All invocations are routed here. The first one to run becomes the resident
 * primary instance; every later `launcher` invocation is forwarded over D-Bus
 * to it (GApplication single-instance), so the keybind toggles the already-warm
 * window instead of spawning a new process.
 *
 *   launcher --service   -> set up + stay hidden (used by the systemd unit)
 *   launcher [--toggle]   -> show if hidden, hide if shown (the keybind)
 */
static int
launcher_application_command_line (GApplication            *app,
                                   GApplicationCommandLine *cmdline)
{
  LauncherApplication *self = LAUNCHER_APPLICATION (app);

  int    argc = 0;
  char **argv = g_application_command_line_get_arguments (cmdline, &argc);
  gboolean service_mode = FALSE;
  for (int i = 1; i < argc; i++)
    if (g_strcmp0 (argv[i], "--service") == 0 || g_strcmp0 (argv[i], "-s") == 0)
      service_mode = TRUE;
  g_strfreev (argv);

  /* Keep the process resident even while the window is hidden. */
  if (!self->held)
    {
      g_application_hold (app);
      self->held = TRUE;
    }

  LauncherWindow *window = ensure_window (self);
  if (service_mode)
    launcher_window_hide (window);
  else
    launcher_window_toggle (window);

  return 0;
}

/* ---------- lifecycle ---------- */

static void
launcher_application_class_init (LauncherApplicationClass *klass)
{
  GApplicationClass *gac = G_APPLICATION_CLASS (klass);
  gac->startup      = launcher_application_startup;
  gac->command_line = launcher_application_command_line;
}

static void
launcher_application_init (LauncherApplication *self)
{
  self->held = FALSE;
}

LauncherApplication *
launcher_application_new (void)
{
  return g_object_new (LAUNCHER_TYPE_APPLICATION,
                       "application-id", APP_ID,
                       "flags", G_APPLICATION_HANDLES_COMMAND_LINE,
                       NULL);
}
