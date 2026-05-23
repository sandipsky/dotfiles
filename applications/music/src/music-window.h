#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define MUSIC_TYPE_WINDOW (music_window_get_type ())
G_DECLARE_FINAL_TYPE (MusicWindow, music_window, MUSIC, WINDOW, AdwApplicationWindow)

MusicWindow *music_window_new        (GtkApplication *app);
void         music_window_open_files (MusicWindow *self, GFile **files, int n);

G_END_DECLS
