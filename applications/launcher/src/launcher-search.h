#pragma once

#include <gio/gio.h>

G_BEGIN_DECLS

/* Build the ordered result list for `query`: an optional calculator row, up to
 * six matching applications, and a trailing "Search Google" fallback. Returns a
 * GListStore of LauncherResult*; empty when `query` is blank. */
GListStore *launcher_search_query (const char *query);

/* Evaluate `text` as an arithmetic expression. Returns TRUE and stores the
 * (FP-noise-trimmed) value in `out` only when the whole string is a valid
 * expression containing at least one operator. */
gboolean    launcher_search_try_calculate (const char *text, double *out);

G_END_DECLS
