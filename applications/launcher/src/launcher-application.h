#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define LAUNCHER_TYPE_APPLICATION (launcher_application_get_type ())

G_DECLARE_FINAL_TYPE (LauncherApplication, launcher_application, LAUNCHER, APPLICATION, AdwApplication)

LauncherApplication *launcher_application_new (void);

G_END_DECLS
