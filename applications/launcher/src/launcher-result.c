#include "launcher-result.h"

struct _LauncherResult
{
  GObject parent_instance;

  LauncherResultKind kind;
  char              *title;
  char              *subtitle;
  GAppInfo          *app;     /* APP only — owned ref      */
  char              *payload; /* CALC: result text; GOOGLE: query */
};

G_DEFINE_FINAL_TYPE (LauncherResult, launcher_result, G_TYPE_OBJECT)

static void
launcher_result_finalize (GObject *object)
{
  LauncherResult *self = LAUNCHER_RESULT (object);

  g_clear_pointer (&self->title, g_free);
  g_clear_pointer (&self->subtitle, g_free);
  g_clear_pointer (&self->payload, g_free);
  g_clear_object (&self->app);

  G_OBJECT_CLASS (launcher_result_parent_class)->finalize (object);
}

static void
launcher_result_class_init (LauncherResultClass *klass)
{
  G_OBJECT_CLASS (klass)->finalize = launcher_result_finalize;
}

static void
launcher_result_init (LauncherResult *self)
{
  (void) self;
}

/* ---------- constructors ---------- */

LauncherResult *
launcher_result_new_app (GAppInfo *info, const char *title, const char *subtitle)
{
  LauncherResult *self = g_object_new (LAUNCHER_TYPE_RESULT, NULL);
  self->kind     = LAUNCHER_RESULT_APP;
  self->app      = g_object_ref (info);
  self->title    = g_strdup (title);
  self->subtitle = g_strdup (subtitle ? subtitle : "");
  return self;
}

LauncherResult *
launcher_result_new_calc (const char *result_text, const char *expression)
{
  LauncherResult *self = g_object_new (LAUNCHER_TYPE_RESULT, NULL);
  self->kind     = LAUNCHER_RESULT_CALC;
  self->title    = g_strconcat ("= ", result_text, NULL);
  self->subtitle = g_strdup (expression);
  self->payload  = g_strdup (result_text);
  return self;
}

LauncherResult *
launcher_result_new_google (const char *query)
{
  LauncherResult *self = g_object_new (LAUNCHER_TYPE_RESULT, NULL);
  self->kind     = LAUNCHER_RESULT_GOOGLE;
  self->title    = g_strdup_printf ("Search Google for \"%s\"", query);
  self->subtitle = g_strdup ("Open in browser");
  self->payload  = g_strdup (query);
  return self;
}

/* ---------- accessors ---------- */

LauncherResultKind launcher_result_get_kind     (LauncherResult *self) { return self->kind; }
const char        *launcher_result_get_title    (LauncherResult *self) { return self->title; }
const char        *launcher_result_get_subtitle (LauncherResult *self) { return self->subtitle; }
GAppInfo          *launcher_result_get_app_info  (LauncherResult *self) { return self->app; }

/* ---------- activation ---------- */

/* Mirrors the Quickshell launcher, which shells out to `wl-copy`. We prefer it
 * too: GTK's own clipboard loses its contents the moment this short-lived
 * process exits (GNOME has no clipboard manager that takes ownership), whereas
 * wl-copy forks a tiny daemon that keeps serving the selection. Fall back to
 * the GTK clipboard if wl-copy isn't installed. */
static void
copy_to_clipboard (GtkWidget *widget, const char *text)
{
  g_autofree char *wl_copy = g_find_program_in_path ("wl-copy");
  if (wl_copy != NULL)
    {
      const char *argv[] = { wl_copy, "--", text, NULL };
      g_autoptr (GError) error = NULL;
      g_autoptr (GSubprocess) proc =
        g_subprocess_newv (argv, G_SUBPROCESS_FLAGS_NONE, &error);
      if (proc != NULL)
        return;
      g_warning ("wl-copy failed: %s", error->message);
    }

  GdkClipboard *clipboard = gtk_widget_get_clipboard (widget);
  gdk_clipboard_set_text (clipboard, text);
}

void
launcher_result_activate (LauncherResult *self, GtkWidget *widget)
{
  g_autoptr (GError) error = NULL;

  switch (self->kind)
    {
    case LAUNCHER_RESULT_APP:
      {
        GdkDisplay *display = gtk_widget_get_display (widget);
        g_autoptr (GdkAppLaunchContext) ctx =
          gdk_display_get_app_launch_context (display);
        if (!g_app_info_launch (self->app, NULL, G_APP_LAUNCH_CONTEXT (ctx), &error))
          g_warning ("Failed to launch %s: %s",
                     launcher_result_get_title (self), error->message);
        break;
      }

    case LAUNCHER_RESULT_CALC:
      copy_to_clipboard (widget, self->payload);
      break;

    case LAUNCHER_RESULT_GOOGLE:
      {
        g_autofree char *escaped = g_uri_escape_string (self->payload, NULL, FALSE);
        g_autofree char *url =
          g_strconcat ("https://www.google.com/search?q=", escaped, NULL);
        if (!g_app_info_launch_default_for_uri (url, NULL, &error))
          g_warning ("Failed to open %s: %s", url, error->message);
        break;
      }

    default:
      g_assert_not_reached ();
    }
}
