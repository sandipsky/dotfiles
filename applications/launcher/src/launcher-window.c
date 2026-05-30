#include "launcher-window.h"

#include "launcher-result.h"
#include "launcher-result-row.h"
#include "launcher-search.h"

#ifdef HAVE_LAYER_SHELL
#include <gtk4-layer-shell.h>
#endif

struct _LauncherWindow
{
  AdwApplicationWindow parent_instance;

  GtkWidget  *card;       /* floats inside the full-screen overlay at 20% top */
  GtkWidget  *entry;
  GtkWidget  *separator;
  GtkWidget  *scroller;
  GtkWidget  *list;
  GListStore *results;
  gboolean    was_active; /* became active at least once (focus-out dismiss) */
};

G_DEFINE_FINAL_TYPE (LauncherWindow, launcher_window, ADW_TYPE_APPLICATION_WINDOW)

static void refresh_results (LauncherWindow *self);

/* ---------- selection helpers ---------- */

static int
selected_index (LauncherWindow *self)
{
  GtkListBoxRow *row = gtk_list_box_get_selected_row (GTK_LIST_BOX (self->list));
  return row != NULL ? gtk_list_box_row_get_index (row) : -1;
}

/* Scroll the capped results area so the given row is fully visible. We adjust
 * the scroller's vadjustment by hand because the row never grabs real focus
 * (that stays on the entry so typing keeps working), so the ScrolledWindow's
 * automatic focus-follows scrolling never kicks in. */
static void
scroll_row_into_view (LauncherWindow *self, GtkWidget *row)
{
  GtkAdjustment *vadj =
    gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (self->scroller));
  if (vadj == NULL)
    return;

  graphene_rect_t bounds;
  if (!gtk_widget_compute_bounds (row, self->list, &bounds))
    return; /* not allocated yet — nothing to scroll to */

  double top    = bounds.origin.y;
  double bottom = top + bounds.size.height;
  double value  = gtk_adjustment_get_value (vadj);
  double page   = gtk_adjustment_get_page_size (vadj);

  if (top < value)
    gtk_adjustment_set_value (vadj, top);
  else if (bottom > value + page)
    gtk_adjustment_set_value (vadj, bottom - page);
}

static void
select_index (LauncherWindow *self, int index)
{
  GtkListBoxRow *row = gtk_list_box_get_row_at_index (GTK_LIST_BOX (self->list), index);
  if (row != NULL)
    {
      gtk_list_box_select_row (GTK_LIST_BOX (self->list), row);
      /* Keep the highlighted row scrolled into view without stealing focus
       * from the entry (so typing keeps working). */
      gtk_widget_set_focus_child (self->list, GTK_WIDGET (row));
      scroll_row_into_view (self, GTK_WIDGET (row));
    }
}

static void
move_selection (LauncherWindow *self, int delta)
{
  guint n = g_list_model_get_n_items (G_LIST_MODEL (self->results));
  if (n == 0)
    return;
  int cur = selected_index (self);
  if (cur < 0)
    cur = 0;
  int next = (((cur + delta) % (int) n) + (int) n) % (int) n;
  select_index (self, next);
}

static void
activate_index (LauncherWindow *self, int index)
{
  if (index < 0)
    return;
  g_autoptr (LauncherResult) result =
    g_list_model_get_item (G_LIST_MODEL (self->results), index);
  if (result == NULL)
    return;
  launcher_result_activate (result, GTK_WIDGET (self));
  launcher_window_hide (self);
}

/* ---------- show / hide / toggle ---------- */

/* The window is maximized, so its final height is only known once the
 * compositor has allocated it. Offset the card to 20% of that height as soon
 * as the allocation lands (retry on the next idle until it does). */
static gboolean
position_card_idle (gpointer data)
{
  LauncherWindow *self = LAUNCHER_WINDOW (data);
  int h = gtk_widget_get_height (GTK_WIDGET (self));
  if (h <= 1)
    return G_SOURCE_CONTINUE; /* not allocated yet */
  gtk_widget_set_margin_top (self->card, (int) (h * 0.20));
  return G_SOURCE_REMOVE;
}

static void
window_show (LauncherWindow *self)
{
  /* Start fresh each time, like the QML launcher's onOpenChanged reset. */
  self->was_active = FALSE;
  gtk_editable_set_text (GTK_EDITABLE (self->entry), "");
  refresh_results (self); /* empty query -> results hidden */
  gtk_widget_set_visible (GTK_WIDGET (self), TRUE);
  gtk_window_present (GTK_WINDOW (self));
  gtk_widget_grab_focus (self->entry);
  g_idle_add (position_card_idle, self);
}

void
launcher_window_hide (LauncherWindow *self)
{
  self->was_active = FALSE;
  gtk_widget_set_visible (GTK_WIDGET (self), FALSE);
}

void
launcher_window_toggle (LauncherWindow *self)
{
  if (gtk_widget_get_visible (GTK_WIDGET (self)))
    launcher_window_hide (self);
  else
    window_show (self);
}

/* ---------- results model ---------- */

static GtkWidget *
create_row (gpointer item, gpointer user_data)
{
  (void) user_data;
  return launcher_result_row_new (LAUNCHER_RESULT (item));
}

static void
refresh_results (LauncherWindow *self)
{
  const char *query = gtk_editable_get_text (GTK_EDITABLE (self->entry));
  g_autoptr (GListStore) fresh = launcher_search_query (query);

  g_list_store_remove_all (self->results);
  guint n = g_list_model_get_n_items (G_LIST_MODEL (fresh));
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (LauncherResult) r = g_list_model_get_item (G_LIST_MODEL (fresh), i);
      g_list_store_append (self->results, r);
    }

  gboolean has_results = n > 0;
  gtk_widget_set_visible (self->separator, has_results);
  gtk_widget_set_visible (self->scroller, has_results);
  if (has_results)
    select_index (self, 0);
}

/* ---------- signal handlers ---------- */

static void
on_entry_changed (GtkEditable *editable, gpointer user_data)
{
  (void) editable;
  refresh_results (LAUNCHER_WINDOW (user_data));
}

static void
on_entry_activate (GtkEntry *entry, gpointer user_data)
{
  (void) entry;
  LauncherWindow *self = LAUNCHER_WINDOW (user_data);
  int index = selected_index (self);
  activate_index (self, index >= 0 ? index : 0);
}

static void
on_row_activated (GtkListBox *box, GtkListBoxRow *row, gpointer user_data)
{
  (void) box;
  activate_index (LAUNCHER_WINDOW (user_data), gtk_list_box_row_get_index (row));
}

static gboolean
on_key_pressed (GtkEventControllerKey *controller, guint keyval, guint keycode,
                GdkModifierType state, gpointer user_data)
{
  (void) controller; (void) keycode; (void) state;
  LauncherWindow *self = LAUNCHER_WINDOW (user_data);

  switch (keyval)
    {
    case GDK_KEY_Escape:
      launcher_window_hide (self);
      return TRUE;
    case GDK_KEY_Up:
      move_selection (self, -1);
      return TRUE;
    case GDK_KEY_Down:
      move_selection (self, +1);
      return TRUE;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
      {
        int index = selected_index (self);
        activate_index (self, index >= 0 ? index : 0);
        return TRUE;
      }
    default:
      return FALSE; /* let the entry handle ordinary typing */
    }
}

static void
on_backdrop_pressed (GtkGestureClick *gesture, int n_press, double x, double y,
                     gpointer user_data)
{
  (void) gesture; (void) n_press; (void) x; (void) y;
  /* Click landed on the empty area around the card -> dismiss. Clicks on the
   * card itself are consumed by the card's own widgets and never reach here. */
  launcher_window_hide (LAUNCHER_WINDOW (user_data));
}

static void
on_active_changed (GObject *object, GParamSpec *pspec, gpointer user_data)
{
  (void) pspec; (void) user_data;
  LauncherWindow *self = LAUNCHER_WINDOW (object);
  if (gtk_window_is_active (GTK_WINDOW (self)))
    self->was_active = TRUE;
  else if (self->was_active)
    launcher_window_hide (self); /* dismiss on focus loss, like the overlay */
}

/* ---------- lifecycle ---------- */

static void
launcher_window_dispose (GObject *object)
{
  LauncherWindow *self = LAUNCHER_WINDOW (object);
  g_clear_object (&self->results);
  G_OBJECT_CLASS (launcher_window_parent_class)->dispose (object);
}

static void
launcher_window_class_init (LauncherWindowClass *klass)
{
  G_OBJECT_CLASS (klass)->dispose = launcher_window_dispose;
}

static void
launcher_window_init (LauncherWindow *self)
{
  GtkWindow *window = GTK_WINDOW (self);

  gtk_window_set_decorated (window, FALSE);
  /* Resizable so it can be maximized to cover the monitor (see below); the
   * card inside still hugs its content. */
  gtk_window_set_resizable (window, TRUE);
  gtk_widget_add_css_class (GTK_WIDGET (self), "launcher");

  /* The rounded, bordered surface. The toplevel itself is transparent (see
   * style.css) so these corners aren't clipped to a square.
   *
   * Width is fixed on the card; height is left to its content, so the card is
   * a slim Spotlight-style bar at rest and grows downward as results appear.
   * It's parented into a full-screen overlay below (not set as the window's
   * content directly) so it can float at 20% from the top, centered. */
  GtkWidget *card = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
  gtk_widget_add_css_class (card, "card");
  gtk_widget_set_size_request (card, 720, -1);
  gtk_widget_set_halign (card, GTK_ALIGN_CENTER);
  gtk_widget_set_valign (card, GTK_ALIGN_START);

  /* Search row: magnifier glyph + frameless entry. */
  GtkWidget *row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 14);
  gtk_widget_add_css_class (row, "search-row");

  GtkWidget *icon = gtk_image_new_from_resource ("/dev/sandip/Launcher/icons/search.svg");
  gtk_image_set_pixel_size (GTK_IMAGE (icon), 22);
  gtk_box_append (GTK_BOX (row), icon);

  self->entry = gtk_entry_new ();
  gtk_entry_set_has_frame (GTK_ENTRY (self->entry), FALSE);
  gtk_entry_set_placeholder_text (GTK_ENTRY (self->entry), "Search...");
  gtk_widget_add_css_class (self->entry, "search-entry");
  gtk_widget_set_hexpand (self->entry, TRUE);
  gtk_widget_set_valign (self->entry, GTK_ALIGN_CENTER);
  gtk_box_append (GTK_BOX (row), self->entry);

  gtk_box_append (GTK_BOX (card), row);

  /* Separator — only shown once there are results. */
  self->separator = gtk_separator_new (GTK_ORIENTATION_HORIZONTAL);
  gtk_widget_set_visible (self->separator, FALSE);
  gtk_box_append (GTK_BOX (card), self->separator);

  /* Results list inside a height-capped scroller (auto-grow, then scroll). */
  self->results = g_list_store_new (LAUNCHER_TYPE_RESULT);

  self->list = gtk_list_box_new ();
  gtk_list_box_set_selection_mode (GTK_LIST_BOX (self->list), GTK_SELECTION_SINGLE);
  gtk_widget_add_css_class (self->list, "results");
  gtk_list_box_bind_model (GTK_LIST_BOX (self->list),
                           G_LIST_MODEL (self->results),
                           create_row, NULL, NULL);

  self->scroller = gtk_scrolled_window_new ();
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (self->scroller),
                                  GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_scrolled_window_set_propagate_natural_height (GTK_SCROLLED_WINDOW (self->scroller), TRUE);
  gtk_scrolled_window_set_max_content_height (GTK_SCROLLED_WINDOW (self->scroller), 400);
  gtk_scrolled_window_set_child (GTK_SCROLLED_WINDOW (self->scroller), self->list);
  gtk_widget_set_visible (self->scroller, FALSE);
  gtk_box_append (GTK_BOX (card), self->scroller);

  /* Screen-covering transparent overlay: the card floats inside at 20% from
   * the top (like the QML launcher), and the empty area around it is a
   * backdrop that dismisses the launcher when clicked — click-outside-to-close.
   * Two ways to cover the screen, chosen at runtime below. */
  GtkWidget *overlay = gtk_overlay_new ();

  GtkWidget *backdrop = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
  gtk_overlay_set_child (GTK_OVERLAY (overlay), backdrop);

  GtkGesture *backdrop_click = gtk_gesture_click_new ();
  g_signal_connect (backdrop_click, "pressed",
                    G_CALLBACK (on_backdrop_pressed), self);
  gtk_widget_add_controller (backdrop, GTK_EVENT_CONTROLLER (backdrop_click));

  gtk_overlay_add_overlay (GTK_OVERLAY (overlay), card);
  adw_application_window_set_content (ADW_APPLICATION_WINDOW (self), overlay);

  self->card = card;

  /* On a wlroots compositor (Hyprland, sway, ...) become a real layer-shell
   * overlay anchored to all four edges — full-output, above everything, with
   * exclusive keyboard focus, exactly like the QML PanelWindow. Elsewhere
   * (GNOME, which has no layer-shell) fall back to maximizing: a fullscreen
   * surface gets unredirected by mutter, dropping the window's alpha and
   * painting the transparent area solid black on software-rendered VMs, while
   * a maximized window stays composited so the desktop shows through. Either
   * way the card is offset to 20% of the window height in position_card_idle. */
  gboolean layered = FALSE;
#ifdef HAVE_LAYER_SHELL
  if (gtk_layer_is_supported ())
    {
      gtk_layer_init_for_window (window);
      gtk_layer_set_namespace (window, "launcher");
      gtk_layer_set_layer (window, GTK_LAYER_SHELL_LAYER_OVERLAY);
      gtk_layer_set_keyboard_mode (window, GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE);
      gtk_layer_set_anchor (window, GTK_LAYER_SHELL_EDGE_TOP,    TRUE);
      gtk_layer_set_anchor (window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
      gtk_layer_set_anchor (window, GTK_LAYER_SHELL_EDGE_LEFT,   TRUE);
      gtk_layer_set_anchor (window, GTK_LAYER_SHELL_EDGE_RIGHT,  TRUE);
      layered = TRUE;
    }
#endif
  if (!layered)
    gtk_window_maximize (window);

  /* Wiring. */
  g_signal_connect (self->entry, "changed", G_CALLBACK (on_entry_changed), self);
  g_signal_connect (self->entry, "activate", G_CALLBACK (on_entry_activate), self);
  g_signal_connect (self->list, "row-activated", G_CALLBACK (on_row_activated), self);

  /* Capture-phase key controller so Up/Down/Enter/Escape work while the entry
   * holds focus; everything else falls through to the entry for typing. */
  GtkEventController *keys = gtk_event_controller_key_new ();
  gtk_event_controller_set_propagation_phase (keys, GTK_PHASE_CAPTURE);
  g_signal_connect (keys, "key-pressed", G_CALLBACK (on_key_pressed), self);
  gtk_widget_add_controller (GTK_WIDGET (self), keys);

  g_signal_connect (self, "notify::is-active", G_CALLBACK (on_active_changed), NULL);

  gtk_widget_grab_focus (self->entry);
}

GtkWidget *
launcher_window_new (GtkApplication *app)
{
  return g_object_new (LAUNCHER_TYPE_WINDOW, "application", app, NULL);
}
