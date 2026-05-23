#include "music-playlists-view.h"

#include "music-song-row.h"

struct _MusicPlaylistsView
{
  AdwBin             parent_instance;

  MusicLibrary      *library;
  MusicPlayer       *player;

  AdwNavigationView *nav;
  GtkListBox        *list_box;
  GtkWidget         *empty_page;     /* AdwStatusPage */
  GtkWidget         *list_scrolled;  /* container that hides when empty */
};

G_DEFINE_FINAL_TYPE (MusicPlaylistsView, music_playlists_view, ADW_TYPE_BIN)

/* ---------- detail context ---------- */

typedef struct {
  MusicPlayer   *player;
  MusicPlaylist *playlist;
} DetailContext;

static void
detail_ctx_free (gpointer p)
{
  DetailContext *ctx = p;
  g_clear_object (&ctx->player);
  g_clear_object (&ctx->playlist);
  g_free (ctx);
}

static void
play_song_in_queue (MusicPlayer *player, GListModel *queue, MusicSong *song)
{
  guint n = g_list_model_get_n_items (queue);
  for (guint i = 0; i < n; i++)
    {
      g_autoptr (MusicSong) s = g_list_model_get_item (queue, i);
      if (s == song)
        {
          music_player_play_in_queue (player, queue, i);
          return;
        }
    }
}

/* ---------- factory (shared with all-songs row visuals) ---------- */

static void
detail_factory_setup (GtkSignalListItemFactory *f, GtkListItem *li, gpointer ud)
{
  (void) f; (void) ud;
  GtkWidget *row = music_song_row_new ();
  gtk_list_item_set_child (li, row);
}

static void
detail_row_play (GtkWidget *row, gpointer user_data)
{
  DetailContext *ctx = user_data;
  MusicSong *s = music_song_row_get_song (MUSIC_SONG_ROW (row));
  if (!s)
    return;
  GListModel *m = music_playlist_get_songs (ctx->playlist);
  play_song_in_queue (ctx->player, m, s);
}

static void
detail_factory_bind (GtkSignalListItemFactory *f, GtkListItem *li, gpointer user_data)
{
  (void) f;
  GtkWidget *row = gtk_list_item_get_child (li);
  MusicSong *song = MUSIC_SONG (gtk_list_item_get_item (li));
  music_song_row_set_song (MUSIC_SONG_ROW (row), song);
  g_signal_connect (row, "play-requested",
                    G_CALLBACK (detail_row_play), user_data);
}

static void
detail_factory_unbind (GtkSignalListItemFactory *f, GtkListItem *li, gpointer user_data)
{
  (void) f;
  GtkWidget *row = gtk_list_item_get_child (li);
  g_signal_handlers_disconnect_by_data (row, user_data);
  music_song_row_set_song (MUSIC_SONG_ROW (row), NULL);
}

static void
detail_list_activate (GtkListView *lv, guint pos, gpointer user_data)
{
  (void) lv;
  DetailContext *ctx = user_data;
  music_player_play_in_queue (ctx->player,
                              music_playlist_get_songs (ctx->playlist), pos);
}

static void
detail_play_all (GtkButton *b, gpointer user_data)
{
  (void) b;
  DetailContext *ctx = user_data;
  GListModel *m = music_playlist_get_songs (ctx->playlist);
  if (g_list_model_get_n_items (m) == 0)
    return;
  music_player_play_in_queue (ctx->player, m, 0);
}

/* ---------- subtitle updating ---------- */

static void
update_detail_subtitle (GtkLabel *label, MusicPlaylist *pl)
{
  guint n = music_playlist_get_n_songs (pl);
  g_autofree char *txt = g_strdup_printf ("%u %s", n, n == 1 ? "Song" : "Songs");
  gtk_label_set_text (label, txt);
}

static void
on_detail_songs_changed (GListModel *m, guint p, guint r, guint a, gpointer ud)
{
  (void) m; (void) p; (void) r; (void) a;
  GtkLabel *lbl = ud;
  MusicPlaylist *pl = g_object_get_data (G_OBJECT (lbl), "playlist");
  if (pl)
    update_detail_subtitle (lbl, pl);
}

/* ---------- new playlist dialog ---------- */

typedef struct {
  MusicPlaylistsView *view;
  GtkEntry           *entry;
} NewPlaylistCtx;

static void
on_new_response (AdwAlertDialog *dlg, const char *response, gpointer ud)
{
  NewPlaylistCtx *ctx = ud;
  if (g_strcmp0 (response, "create") == 0)
    {
      const char *name = gtk_editable_get_text (GTK_EDITABLE (ctx->entry));
      if (name && *name)
        music_library_create_playlist (ctx->view->library, name);
    }
  g_free (ctx);
  (void) dlg;
}

static void
on_new_clicked (GtkButton *b, gpointer ud)
{
  (void) b;
  MusicPlaylistsView *self = ud;

  AdwDialog *dlg = adw_alert_dialog_new ("New Playlist", "Enter a name:");
  GtkWidget *entry = gtk_entry_new ();
  gtk_entry_set_placeholder_text (GTK_ENTRY (entry), "Playlist name");
  adw_alert_dialog_set_extra_child (ADW_ALERT_DIALOG (dlg), entry);

  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "cancel", "Cancel");
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "create", "Create");
  adw_alert_dialog_set_response_appearance (ADW_ALERT_DIALOG (dlg), "create",
                                            ADW_RESPONSE_SUGGESTED);
  adw_alert_dialog_set_default_response (ADW_ALERT_DIALOG (dlg), "create");
  adw_alert_dialog_set_close_response   (ADW_ALERT_DIALOG (dlg), "cancel");

  NewPlaylistCtx *ctx = g_new0 (NewPlaylistCtx, 1);
  ctx->view  = self;
  ctx->entry = GTK_ENTRY (entry);
  g_signal_connect (dlg, "response", G_CALLBACK (on_new_response), ctx);

  adw_dialog_present (dlg, GTK_WIDGET (self));
}

/* ---------- rename / delete ---------- */

typedef struct {
  MusicPlaylist *playlist;
  GtkEntry      *entry;
} RenameCtx;

static void
on_rename_response (AdwAlertDialog *dlg, const char *response, gpointer ud)
{
  RenameCtx *ctx = ud;
  if (g_strcmp0 (response, "ok") == 0)
    {
      const char *new_name = gtk_editable_get_text (GTK_EDITABLE (ctx->entry));
      if (new_name && *new_name)
        music_playlist_set_name (ctx->playlist, new_name);
    }
  g_clear_object (&ctx->playlist);
  g_free (ctx);
  (void) dlg;
}

static void
on_rename_clicked (GtkButton *b, gpointer ud)
{
  DetailContext *dctx = ud;

  AdwDialog *dlg = adw_alert_dialog_new ("Rename Playlist", NULL);
  GtkWidget *entry = gtk_entry_new ();
  gtk_editable_set_text (GTK_EDITABLE (entry), music_playlist_get_name (dctx->playlist));
  adw_alert_dialog_set_extra_child (ADW_ALERT_DIALOG (dlg), entry);

  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "cancel", "Cancel");
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "ok",     "Rename");
  adw_alert_dialog_set_response_appearance (ADW_ALERT_DIALOG (dlg), "ok",
                                            ADW_RESPONSE_SUGGESTED);
  adw_alert_dialog_set_default_response (ADW_ALERT_DIALOG (dlg), "ok");
  adw_alert_dialog_set_close_response   (ADW_ALERT_DIALOG (dlg), "cancel");

  RenameCtx *r = g_new0 (RenameCtx, 1);
  r->playlist = g_object_ref (dctx->playlist);
  r->entry    = GTK_ENTRY (entry);
  g_signal_connect (dlg, "response", G_CALLBACK (on_rename_response), r);

  adw_dialog_present (dlg, GTK_WIDGET (b));
}

typedef struct {
  MusicPlaylistsView *view;
  MusicPlaylist      *playlist;
} DeleteCtx;

static void
on_delete_response (AdwAlertDialog *dlg, const char *response, gpointer ud)
{
  DeleteCtx *ctx = ud;
  if (g_strcmp0 (response, "delete") == 0)
    {
      music_library_remove_playlist (ctx->view->library, ctx->playlist);
      adw_navigation_view_pop (ctx->view->nav);
    }
  g_clear_object (&ctx->playlist);
  g_free (ctx);
  (void) dlg;
}

static void
on_delete_clicked (GtkButton *b, gpointer ud)
{
  DetailContext *dctx = ud;

  AdwDialog *dlg = adw_alert_dialog_new (
      "Delete Playlist?",
      "This will permanently remove the playlist. Songs remain in your library.");
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "cancel", "Cancel");
  adw_alert_dialog_add_response (ADW_ALERT_DIALOG (dlg), "delete", "Delete");
  adw_alert_dialog_set_response_appearance (ADW_ALERT_DIALOG (dlg), "delete",
                                            ADW_RESPONSE_DESTRUCTIVE);
  adw_alert_dialog_set_default_response (ADW_ALERT_DIALOG (dlg), "cancel");
  adw_alert_dialog_set_close_response   (ADW_ALERT_DIALOG (dlg), "cancel");

  /* Find the enclosing view via widget hierarchy. */
  MusicPlaylistsView *view = NULL;
  for (GtkWidget *w = gtk_widget_get_parent (GTK_WIDGET (b)); w; w = gtk_widget_get_parent (w))
    {
      if (MUSIC_IS_PLAYLISTS_VIEW (w))
        {
          view = MUSIC_PLAYLISTS_VIEW (w);
          break;
        }
    }
  if (!view)
    {
      adw_dialog_force_close (dlg);
      return;
    }

  DeleteCtx *ctx = g_new0 (DeleteCtx, 1);
  ctx->view     = view;
  ctx->playlist = g_object_ref (dctx->playlist);
  g_signal_connect (dlg, "response", G_CALLBACK (on_delete_response), ctx);

  adw_dialog_present (dlg, GTK_WIDGET (b));
}

/* ---------- build detail page ---------- */

static AdwNavigationPage *
build_detail_page (MusicPlaylistsView *self, MusicPlaylist *playlist)
{
  DetailContext *ctx = g_new0 (DetailContext, 1);
  ctx->player   = g_object_ref (self->player);
  ctx->playlist = g_object_ref (playlist);

  AdwToolbarView *tv = ADW_TOOLBAR_VIEW (adw_toolbar_view_new ());

  AdwHeaderBar *hb = ADW_HEADER_BAR (adw_header_bar_new ());
  GtkWidget *rename_btn = gtk_button_new_from_icon_name ("document-edit-symbolic");
  gtk_widget_set_tooltip_text (rename_btn, "Rename");
  g_signal_connect (rename_btn, "clicked", G_CALLBACK (on_rename_clicked), ctx);

  GtkWidget *delete_btn = gtk_button_new_from_icon_name ("user-trash-symbolic");
  gtk_widget_set_tooltip_text (delete_btn, "Delete");
  g_signal_connect (delete_btn, "clicked", G_CALLBACK (on_delete_clicked), ctx);

  adw_header_bar_pack_end (hb, delete_btn);
  adw_header_bar_pack_end (hb, rename_btn);

  adw_toolbar_view_add_top_bar (tv, GTK_WIDGET (hb));

  /* Content */
  GtkWidget *content = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);

  GtkWidget *header_box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 4);
  gtk_widget_set_margin_top    (header_box, 24);
  gtk_widget_set_margin_start  (header_box, 24);
  gtk_widget_set_margin_end    (header_box, 24);
  gtk_widget_set_margin_bottom (header_box, 12);

  GtkWidget *title_label = gtk_label_new (music_playlist_get_name (playlist));
  gtk_label_set_xalign     (GTK_LABEL (title_label), 0);
  gtk_widget_add_css_class (title_label, "title-1");
  g_object_bind_property   (playlist, "name", title_label, "label", G_BINDING_SYNC_CREATE);
  gtk_box_append (GTK_BOX (header_box), title_label);

  GtkWidget *subtitle_label = gtk_label_new ("");
  gtk_label_set_xalign     (GTK_LABEL (subtitle_label), 0);
  gtk_widget_add_css_class (subtitle_label, "dim-label");
  g_object_set_data_full   (G_OBJECT (subtitle_label), "playlist",
                            g_object_ref (playlist), g_object_unref);
  update_detail_subtitle   (GTK_LABEL (subtitle_label), playlist);
  g_signal_connect_object  (music_playlist_get_songs (playlist),
                            "items-changed",
                            G_CALLBACK (on_detail_songs_changed),
                            subtitle_label, 0);
  gtk_box_append (GTK_BOX (header_box), subtitle_label);

  GtkWidget *action_row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);
  gtk_widget_set_margin_top (action_row, 8);
  GtkWidget *play_all = gtk_button_new_from_icon_name ("media-playback-start-symbolic");
  gtk_widget_add_css_class (play_all, "circular");
  gtk_widget_add_css_class (play_all, "suggested-action");
  gtk_widget_set_size_request (play_all, 44, 44);
  g_signal_connect (play_all, "clicked", G_CALLBACK (detail_play_all), ctx);
  gtk_box_append (GTK_BOX (action_row), play_all);
  gtk_box_append (GTK_BOX (header_box), action_row);

  gtk_box_append (GTK_BOX (content), header_box);

  /* Song list */
  GtkListItemFactory *factory = gtk_signal_list_item_factory_new ();
  g_signal_connect (factory, "setup",  G_CALLBACK (detail_factory_setup),  NULL);
  g_signal_connect (factory, "bind",   G_CALLBACK (detail_factory_bind),   ctx);
  g_signal_connect (factory, "unbind", G_CALLBACK (detail_factory_unbind), ctx);

  GListModel *songs = music_playlist_get_songs (playlist);
  GtkSelectionModel *sel =
      GTK_SELECTION_MODEL (gtk_no_selection_new (g_object_ref (songs)));
  GtkListView *lv = GTK_LIST_VIEW (gtk_list_view_new (sel, factory));
  gtk_list_view_set_show_separators (lv, TRUE);
  g_signal_connect (lv, "activate", G_CALLBACK (detail_list_activate), ctx);

  GtkWidget *scrolled = gtk_scrolled_window_new ();
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled),
                                  GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_scrolled_window_set_child (GTK_SCROLLED_WINDOW (scrolled), GTK_WIDGET (lv));
  gtk_widget_set_vexpand (scrolled, TRUE);
  gtk_widget_set_margin_start  (scrolled, 12);
  gtk_widget_set_margin_end    (scrolled, 12);
  gtk_widget_set_margin_bottom (scrolled, 12);
  gtk_box_append (GTK_BOX (content), scrolled);

  adw_toolbar_view_set_content (tv, content);

  AdwNavigationPage *page =
      adw_navigation_page_new (GTK_WIDGET (tv), music_playlist_get_name (playlist));
  g_object_bind_property (playlist, "name", page, "title", G_BINDING_SYNC_CREATE);

  /* Tie context lifetime to the page. */
  g_object_set_data_full (G_OBJECT (page), "ctx", ctx, detail_ctx_free);

  return page;
}

/* ---------- list row ---------- */

static void
on_row_activated (GtkListBox *box, GtkListBoxRow *row, gpointer user_data)
{
  (void) box;
  MusicPlaylistsView *self = MUSIC_PLAYLISTS_VIEW (user_data);
  MusicPlaylist *pl = g_object_get_data (G_OBJECT (row), "playlist");
  if (!pl)
    return;
  AdwNavigationPage *page = build_detail_page (self, pl);
  adw_navigation_view_push (self->nav, page);
}

static void
update_row_subtitle (GtkWidget *row, MusicPlaylist *pl)
{
  guint n = music_playlist_get_n_songs (pl);
  g_autofree char *sub = g_strdup_printf ("%u %s", n, n == 1 ? "Song" : "Songs");
  adw_action_row_set_subtitle (ADW_ACTION_ROW (row), sub);
}

static void
on_row_songs_changed (GListModel *m, guint p, guint r, guint a, gpointer ud)
{
  (void) m; (void) p; (void) r; (void) a;
  GtkWidget *row = ud;
  MusicPlaylist *pl = g_object_get_data (G_OBJECT (row), "playlist");
  if (pl)
    update_row_subtitle (row, pl);
}

static GtkWidget *
create_playlist_row (gpointer item, gpointer user_data)
{
  (void) user_data;
  MusicPlaylist *pl = MUSIC_PLAYLIST (item);

  GtkWidget *row = adw_action_row_new ();
  g_object_bind_property (pl, "name", row, "title", G_BINDING_SYNC_CREATE);
  gtk_list_box_row_set_activatable (GTK_LIST_BOX_ROW (row), TRUE);

  GtkWidget *icon = gtk_image_new_from_icon_name ("view-list-symbolic");
  adw_action_row_add_prefix (ADW_ACTION_ROW (row), icon);

  GtkWidget *chevron = gtk_image_new_from_icon_name ("go-next-symbolic");
  gtk_widget_add_css_class (chevron, "dim-label");
  adw_action_row_add_suffix (ADW_ACTION_ROW (row), chevron);

  g_object_set_data_full (G_OBJECT (row), "playlist", g_object_ref (pl), g_object_unref);
  update_row_subtitle (row, pl);

  g_signal_connect_object (music_playlist_get_songs (pl), "items-changed",
                           G_CALLBACK (on_row_songs_changed), row, 0);

  return row;
}

/* ---------- empty state ---------- */

static void
update_empty_state (MusicPlaylistsView *self)
{
  guint n = g_list_model_get_n_items (music_library_get_playlists (self->library));
  gtk_widget_set_visible (self->empty_page,    n == 0);
  gtk_widget_set_visible (self->list_scrolled, n != 0);
}

static void
on_playlists_changed (GListModel *m, guint p, guint r, guint a, gpointer ud)
{
  (void) m; (void) p; (void) r; (void) a;
  update_empty_state (MUSIC_PLAYLISTS_VIEW (ud));
}

/* ---------- lifecycle ---------- */

static void
music_playlists_view_dispose (GObject *obj)
{
  MusicPlaylistsView *self = MUSIC_PLAYLISTS_VIEW (obj);
  g_clear_object (&self->library);
  g_clear_object (&self->player);
  G_OBJECT_CLASS (music_playlists_view_parent_class)->dispose (obj);
}

static void
music_playlists_view_class_init (MusicPlaylistsViewClass *klass)
{
  GObjectClass *oc = G_OBJECT_CLASS (klass);
  oc->dispose = music_playlists_view_dispose;
}

static void
music_playlists_view_init (MusicPlaylistsView *self)
{
}

GtkWidget *
music_playlists_view_new (MusicLibrary *library, MusicPlayer *player)
{
  g_return_val_if_fail (MUSIC_IS_LIBRARY (library), NULL);
  g_return_val_if_fail (MUSIC_IS_PLAYER  (player),  NULL);

  MusicPlaylistsView *self = g_object_new (MUSIC_TYPE_PLAYLISTS_VIEW, NULL);
  self->library = g_object_ref (library);
  self->player  = g_object_ref (player);

  self->nav = ADW_NAVIGATION_VIEW (adw_navigation_view_new ());
  adw_bin_set_child (ADW_BIN (self), GTK_WIDGET (self->nav));

  /* List page */
  AdwToolbarView *list_tv = ADW_TOOLBAR_VIEW (adw_toolbar_view_new ());

  GtkWidget *outer = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);

  /* Header — title on the left, New Playlist on the right, same row. */
  GtkWidget *header_box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 12);
  gtk_widget_set_margin_top    (header_box, 24);
  gtk_widget_set_margin_start  (header_box, 24);
  gtk_widget_set_margin_end    (header_box, 24);
  gtk_widget_set_margin_bottom (header_box, 12);
  gtk_widget_set_valign        (header_box, GTK_ALIGN_CENTER);
  {
    GtkWidget *t = gtk_label_new ("Playlists");
    gtk_label_set_xalign (GTK_LABEL (t), 0);
    gtk_widget_add_css_class (t, "title-1");
    gtk_widget_set_hexpand (t, TRUE);
    gtk_box_append (GTK_BOX (header_box), t);

    GtkWidget *new_btn = gtk_button_new_with_label ("New Playlist");
    gtk_widget_set_valign (new_btn, GTK_ALIGN_CENTER);
    g_signal_connect (new_btn, "clicked", G_CALLBACK (on_new_clicked), self);
    gtk_box_append (GTK_BOX (header_box), new_btn);
  }
  gtk_box_append (GTK_BOX (outer), header_box);

  /* Empty state */
  self->empty_page = adw_status_page_new ();
  adw_status_page_set_icon_name (ADW_STATUS_PAGE (self->empty_page), "view-list-symbolic");
  adw_status_page_set_title       (ADW_STATUS_PAGE (self->empty_page), "No Playlists");
  adw_status_page_set_description (ADW_STATUS_PAGE (self->empty_page),
                                   "Create one to group your favorite songs.");
  gtk_widget_set_vexpand (self->empty_page, TRUE);
  gtk_box_append (GTK_BOX (outer), self->empty_page);

  /* List */
  self->list_box = GTK_LIST_BOX (gtk_list_box_new ());
  gtk_list_box_set_selection_mode (self->list_box, GTK_SELECTION_NONE);
  gtk_widget_add_css_class (GTK_WIDGET (self->list_box), "boxed-list");
  gtk_list_box_bind_model (self->list_box,
                           music_library_get_playlists (library),
                           create_playlist_row, self, NULL);
  g_signal_connect (self->list_box, "row-activated",
                    G_CALLBACK (on_row_activated), self);

  self->list_scrolled = gtk_scrolled_window_new ();
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (self->list_scrolled),
                                  GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  GtkWidget *clamp = adw_clamp_new ();
  adw_clamp_set_maximum_size (ADW_CLAMP (clamp), 700);
  gtk_widget_set_margin_start  (clamp, 12);
  gtk_widget_set_margin_end    (clamp, 12);
  gtk_widget_set_margin_bottom (clamp, 12);
  adw_clamp_set_child (ADW_CLAMP (clamp), GTK_WIDGET (self->list_box));
  gtk_scrolled_window_set_child (GTK_SCROLLED_WINDOW (self->list_scrolled), clamp);
  gtk_widget_set_vexpand (self->list_scrolled, TRUE);
  gtk_box_append (GTK_BOX (outer), self->list_scrolled);

  adw_toolbar_view_set_content (list_tv, outer);

  AdwNavigationPage *list_page = adw_navigation_page_new (GTK_WIDGET (list_tv), "Playlists");
  adw_navigation_page_set_tag (list_page, "list");
  adw_navigation_view_add (self->nav, list_page);

  g_signal_connect (music_library_get_playlists (library), "items-changed",
                    G_CALLBACK (on_playlists_changed), self);
  update_empty_state (self);

  return GTK_WIDGET (self);
}
