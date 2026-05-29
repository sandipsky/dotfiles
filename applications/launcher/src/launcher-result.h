#pragma once

#include <gtk/gtk.h>
#include <gio/gio.h>

G_BEGIN_DECLS

typedef enum
{
  LAUNCHER_RESULT_APP,    /* launch a GAppInfo                         */
  LAUNCHER_RESULT_CALC,   /* copy the computed value to the clipboard  */
  LAUNCHER_RESULT_GOOGLE, /* open a Google search in the browser       */
} LauncherResultKind;

#define LAUNCHER_TYPE_RESULT (launcher_result_get_type ())

G_DECLARE_FINAL_TYPE (LauncherResult, launcher_result, LAUNCHER, RESULT, GObject)

LauncherResult *launcher_result_new_app    (GAppInfo   *info,
                                            const char *title,
                                            const char *subtitle);
LauncherResult *launcher_result_new_calc   (const char *result_text,
                                            const char *expression);
LauncherResult *launcher_result_new_google (const char *query);

LauncherResultKind  launcher_result_get_kind     (LauncherResult *self);
const char         *launcher_result_get_title    (LauncherResult *self);
const char         *launcher_result_get_subtitle (LauncherResult *self);
GAppInfo           *launcher_result_get_app_info (LauncherResult *self);

/* Perform the result's action. `widget` is any realized widget — used to
 * derive the display (launch context) and clipboard. */
void                launcher_result_activate     (LauncherResult *self,
                                                  GtkWidget      *widget);

G_END_DECLS
