#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define MUSIC_TYPE_APPLICATION (music_application_get_type ())
G_DECLARE_FINAL_TYPE (MusicApplication, music_application, MUSIC, APPLICATION, AdwApplication)

MusicApplication *music_application_new (void);

G_END_DECLS
