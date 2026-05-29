#include "launcher-search.h"
#include "launcher-result.h"

#include <gio/gdesktopappinfo.h>
#include <math.h>
#include <string.h>

#define MAX_APP_RESULTS 6

/* ===================================================================== *
 *  Calculator — a tiny recursive-descent evaluator.                     *
 *                                                                       *
 *  Grammar (precedence low -> high):                                    *
 *    expr   := term   (('+' | '-') term)*                               *
 *    term   := unary  (('*' | '/' | '%') unary)*                        *
 *    unary  := ('+' | '-') unary | power                                *
 *    power  := primary ('^' unary)?      (right-associative)            *
 *    primary:= number | '(' expr ')'                                    *
 * ===================================================================== */

typedef struct
{
  const char *p;
  gboolean    ok;
} Parser;

static double parse_expr (Parser *ps);

static void
skip_ws (Parser *ps)
{
  while (*ps->p == ' ' || *ps->p == '\t')
    ps->p++;
}

static double
parse_primary (Parser *ps)
{
  skip_ws (ps);

  if (*ps->p == '(')
    {
      ps->p++;
      double v = parse_expr (ps);
      skip_ws (ps);
      if (*ps->p == ')')
        ps->p++;
      else
        ps->ok = FALSE;
      return v;
    }

  char  *end = NULL;
  double v = g_ascii_strtod (ps->p, &end);
  if (end == ps->p)
    {
      ps->ok = FALSE;
      return 0;
    }
  ps->p = end;
  return v;
}

static double parse_unary (Parser *ps);

static double
parse_power (Parser *ps)
{
  double base = parse_primary (ps);
  skip_ws (ps);
  if (*ps->p == '^')
    {
      ps->p++;
      double exp = parse_unary (ps);
      return pow (base, exp);
    }
  return base;
}

static double
parse_unary (Parser *ps)
{
  skip_ws (ps);
  if (*ps->p == '+')
    {
      ps->p++;
      return parse_unary (ps);
    }
  if (*ps->p == '-')
    {
      ps->p++;
      return -parse_unary (ps);
    }
  return parse_power (ps);
}

static double
parse_term (Parser *ps)
{
  double v = parse_unary (ps);
  for (;;)
    {
      skip_ws (ps);
      char c = *ps->p;
      if (c == '*')      { ps->p++; v *= parse_unary (ps); }
      else if (c == '/') { ps->p++; v /= parse_unary (ps); }
      else if (c == '%') { ps->p++; v = fmod (v, parse_unary (ps)); }
      else break;
    }
  return v;
}

static double
parse_expr (Parser *ps)
{
  double v = parse_term (ps);
  for (;;)
    {
      skip_ws (ps);
      char c = *ps->p;
      if (c == '+')      { ps->p++; v += parse_term (ps); }
      else if (c == '-') { ps->p++; v -= parse_term (ps); }
      else break;
    }
  return v;
}

gboolean
launcher_search_try_calculate (const char *text, double *out)
{
  g_autofree char *t = g_strdup (text);
  g_strstrip (t);
  if (*t == '\0')
    return FALSE;

  /* Only treat input that looks like arithmetic as a calculation — and only
   * when it actually contains an operator (so "42" alone isn't a "result"). */
  for (const char *c = t; *c != '\0'; c++)
    if (!g_ascii_isdigit (*c) && strchr (" \t+-*/().%^", *c) == NULL)
      return FALSE;
  if (strpbrk (t, "+-*/%^") == NULL)
    return FALSE;

  Parser ps = { .p = t, .ok = TRUE };
  double v = parse_expr (&ps);
  skip_ws (&ps);
  if (!ps.ok || *ps.p != '\0' || !isfinite (v))
    return FALSE;

  /* Trim floating-point noise the way the QML version does. */
  v = round (v * 1e10) / 1e10;
  if (out != NULL)
    *out = v;
  return TRUE;
}

/* ===================================================================== *
 *  Application matching.                                                *
 * ===================================================================== */

typedef struct
{
  GAppInfo *info;     /* owned ref */
  char     *title;
  char     *subtitle;
  char     *name_low; /* lowercased name, for prefix ranking + sort */
  int       rank;     /* 0 = name starts with query, 1 = elsewhere  */
} AppMatch;

static void
app_match_free (gpointer data)
{
  AppMatch *m = data;
  g_clear_object (&m->info);
  g_free (m->title);
  g_free (m->subtitle);
  g_free (m->name_low);
  g_free (m);
}

static int
app_match_compare (gconstpointer a, gconstpointer b)
{
  const AppMatch *ma = *(AppMatch *const *) a;
  const AppMatch *mb = *(AppMatch *const *) b;
  if (ma->rank != mb->rank)
    return ma->rank - mb->rank;
  return g_strcmp0 (ma->name_low, mb->name_low);
}

static void
collect_apps (const char *query_low, GListStore *store)
{
  GList     *all     = g_app_info_get_all ();
  GPtrArray *matches = g_ptr_array_new_with_free_func (app_match_free);

  for (GList *l = all; l != NULL; l = l->next)
    {
      GAppInfo *info = l->data;
      if (!g_app_info_should_show (info)) /* respects NoDisplay / OnlyShowIn */
        continue;

      const char *name = g_app_info_get_display_name (info);
      if (name == NULL)
        name = g_app_info_get_name (info);
      if (name == NULL)
        continue;

      const char *generic = NULL;
      const char *comment = g_app_info_get_description (info);
      g_autofree char *keywords = NULL;
      if (G_IS_DESKTOP_APP_INFO (info))
        {
          GDesktopAppInfo *dai = G_DESKTOP_APP_INFO (info);
          generic = g_desktop_app_info_get_generic_name (dai);
          const char *const *kw = g_desktop_app_info_get_keywords (dai);
          if (kw != NULL)
            keywords = g_strjoinv (" ", (char **) kw);
        }

      g_autofree char *haystack =
        g_strdup_printf ("%s %s %s %s", name, generic ? generic : "",
                         comment ? comment : "", keywords ? keywords : "");
      g_autofree char *haystack_low = g_utf8_strdown (haystack, -1);
      if (strstr (haystack_low, query_low) == NULL)
        continue;

      AppMatch *m = g_new0 (AppMatch, 1);
      m->info     = g_object_ref (info);
      m->title    = g_strdup (name);
      m->subtitle = g_strdup (generic ? generic : (comment ? comment : ""));
      m->name_low = g_utf8_strdown (name, -1);
      m->rank     = g_str_has_prefix (m->name_low, query_low) ? 0 : 1;
      g_ptr_array_add (matches, m);
    }

  g_list_free_full (all, g_object_unref);

  g_ptr_array_sort (matches, app_match_compare);

  guint n = MIN (matches->len, MAX_APP_RESULTS);
  for (guint i = 0; i < n; i++)
    {
      AppMatch       *m = g_ptr_array_index (matches, i);
      LauncherResult *r = launcher_result_new_app (m->info, m->title, m->subtitle);
      g_list_store_append (store, r);
      g_object_unref (r);
    }

  g_ptr_array_unref (matches);
}

/* ===================================================================== *
 *  Public entry point.                                                  *
 * ===================================================================== */

GListStore *
launcher_search_query (const char *query)
{
  GListStore *store = g_list_store_new (LAUNCHER_TYPE_RESULT);

  g_autofree char *q = g_strdup (query ? query : "");
  g_strstrip (q);
  if (*q == '\0')
    return store;

  /* 1) Calculator — only when the expression has an operator. */
  double value;
  if (launcher_search_try_calculate (q, &value))
    {
      g_autofree char *result_text = g_strdup_printf ("%.10g", value);
      LauncherResult  *r = launcher_result_new_calc (result_text, q);
      g_list_store_append (store, r);
      g_object_unref (r);
    }

  /* 2) Application matches. */
  g_autofree char *q_low = g_utf8_strdown (q, -1);
  collect_apps (q_low, store);

  /* 3) Google search — always last, as a fallback action. */
  {
    LauncherResult *r = launcher_result_new_google (q);
    g_list_store_append (store, r);
    g_object_unref (r);
  }

  return store;
}
