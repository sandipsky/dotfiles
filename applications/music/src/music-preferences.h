#pragma once

#include <adwaita.h>
#include "music-library.h"

G_BEGIN_DECLS

#define MUSIC_TYPE_PREFERENCES (music_preferences_get_type ())
G_DECLARE_FINAL_TYPE (MusicPreferences, music_preferences, MUSIC, PREFERENCES, AdwPreferencesDialog)

AdwDialog *music_preferences_new (MusicLibrary *library);

G_END_DECLS
