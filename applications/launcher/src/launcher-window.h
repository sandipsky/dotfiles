#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define LAUNCHER_TYPE_WINDOW (launcher_window_get_type ())

G_DECLARE_FINAL_TYPE (LauncherWindow, launcher_window, LAUNCHER, WINDOW, AdwApplicationWindow)

GtkWidget *launcher_window_new    (GtkApplication *app);

/* The window is never destroyed — it's hidden and re-shown so the resident
 * process can toggle it instantly. */
void       launcher_window_toggle (LauncherWindow *self);
void       launcher_window_hide   (LauncherWindow *self);

G_END_DECLS
