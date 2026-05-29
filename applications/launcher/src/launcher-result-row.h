#pragma once

#include <gtk/gtk.h>

#include "launcher-result.h"

G_BEGIN_DECLS

#define LAUNCHER_TYPE_RESULT_ROW (launcher_result_row_get_type ())

G_DECLARE_FINAL_TYPE (LauncherResultRow, launcher_result_row, LAUNCHER, RESULT_ROW, GtkBox)

GtkWidget *launcher_result_row_new (LauncherResult *result);

G_END_DECLS
