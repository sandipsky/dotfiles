# Nautilus fork — local patch reference

This file documents every local change carried on top of the vendored upstream
snapshot at [applications/nautilus-fork/nautilus/](../applications/nautilus-fork/nautilus/),
described **by behavior** rather than by diff, so the same customizations can be
re-applied when bumping to a newer upstream release. Keep it updated when
patching the fork (same convention as [noctalia-patches.md](noctalia-patches.md)).

- **Baseline:** upstream Nautilus 50.2.2
  (gitlab.gnome.org/GNOME/nautilus tag `50.2.2`,
  commit `c6592e9c7fce37ad685d0ba24720893955b7835d`), matching the Arch
  package `nautilus 50.2.2-1` it replaces.
- **Raw diff of everything below:**
  `git diff <baseline-commit>..HEAD -- applications/nautilus-fork/nautilus`
  (where `<baseline-commit>` is the dotfiles commit that vendored the snapshot).

## Local patches

Summary of features (each detailed below):

1. Tab bar above the toolbar, always visible, with a permanent “+” new-tab button
2. Up (parent-folder) button next to back/forward
3. Always-visible search box replacing the search toggle button
4. Sidebar width adjustable by dragging its edge (persisted)
5. Context menu: “New ▸ File / Document (txt)” submenu above New Folder
6. Context menu: “Open as Root” (admin:// via GVfs/polkit)
7. Context menu: built-in “Open in Terminal” (alacritty, falls back to kitty)
8. Context menu: built-in “Open in Code” (VS Code)
9. Folder icons preview an image contained in the folder (Win11/Dolphin style)

### 1. Tab bar on top, always visible, compact tabs, “+” after the last tab

Files: `src/resources/ui/nautilus-window.blp`,
`src/resources/ui/nautilus-toolbar.blp`. The top bar of the content
Adw.ToolbarView is a `WindowHandle` (so empty space drags the window) holding
a Box with: the `Adw.TabBar` (`autohide: false`, `expand-tabs: false` for
Win11-style compact tabs, `hexpand: false` so it hugs its tabs), a flat
`win.new-tab` “+” button immediately after the last tab, an expanding spacer,
and `WindowControls { side: end; }` — the window close button lives on this
top row. The `$NautilusToolbar` `[top]` block comes second (toolbar below the
tabs), and its Adw.HeaderBar sets `show-start/end-title-buttons: false` so the
controls aren't duplicated. Tab width: AdwTabBar is designed to fill its
container and divide the width among tabs (no fixed-tab-width API; CSS
min/max-width fights its internal allocator), so the bar sits inside
`NautilusTabBarClamp` (defined in `nautilus-window.c`), a one-off AdwBin whose
measure reports a NATURAL width of n-tabs × 220 px (updated via
`notify::n-pages`) while keeping the tab bar's own small scrollable minimum.
The top-row GtkBox therefore gives tabs their constant 220 px whenever there
is room — the “+” trails the last tab all the way up to the window controls —
and compresses them evenly only when the row is genuinely full. Tune
`TAB_BAR_TAB_WIDTH` there.

### 2. Up button

File: `src/resources/ui/nautilus-history-controls.blp`. A third button after
back/forward using the pre-existing `slot.up` action (also bound to Alt+Up
upstream), icon `go-up-symbolic`.

### 3. Always-visible search box

Files: `src/resources/ui/nautilus-toolbar.blp`, `src/nautilus-toolbar.c`.
Upstream shows the per-slot NautilusQueryEditor only while searching, swapping
it into the title-area stack in place of the path bar. The patch removes the
“search” stack page and the search toggle button, and instead parents the
query editor permanently (`search_container`, width-request 260) to the right
of the path bar. A `GtkEventControllerFocus` on the container sets the slot’s
`search-visible` property when the editor gains focus, which triggers the
stock search machinery (`show_query_editor` connects the changed/cancel
signals). Escape still cancels; the path bar stays visible during search.
`toolbar_update_appearance()` lost its “search” branch and the
`search_button_stack` global-search swapping.

### 4. Resizable sidebar

Files: `src/nautilus-window.c`, `src/nautilus-global-preferences.h`,
`data/org.gnome.nautilus.gschema.xml`. AdwOverlaySplitView has no user resize
handle, so a capture-phase `GtkGestureDrag` on the split view claims drags
starting within 6 px of the sidebar/content boundary and pins
min-sidebar-width = max-sidebar-width to the dragged value (160–600 px range);
a motion controller shows a `col-resize` cursor near the edge. The width
persists in the new `sidebar-width` key (window-state schema, default 240) and
is restored in `nautilus_window_constructed()` via
`nautilus_window_set_up_sidebar_resize()`. Disabled while the split view is
collapsed (narrow-window breakpoint).

### 5–8. Context-menu items (New / Open as Root / Terminal / Code)

Files: `src/nautilus-files-view.c`,
`src/resources/menu/nautilus-files-view-context-menus.ui`. All items use
`hidden-when: action-disabled`, so they vanish (not gray out) when
inapplicable. New view actions (see the “Local patch” blocks in
`view_entries[]`, the handlers after `action_current_dir_open_console()`, and
the enable-state block in `nautilus_files_view_update_actions_state()`):

- `new-empty-file` / `new-text-document` — create “New File” /
  “New Document.txt” via `nautilus_files_view_new_file_with_initial_contents()`
  (same flow as templates, so the file appears selected/renameable). Shown as
  a “Ne_w” submenu above New Folder in the background menu; enabled with the
  same `can_create_files` gate as new-folder.
- `open-as-root` / `current-directory-open-as-root` — build an
  `admin://<path>` URI and open it in a new tab
  (`nautilus_application_open_location_full`). GVfs prompts via polkit.
  Requires a local path; enabled for single selected directories and the
  current directory.
- `open-terminal` / `current-directory-terminal` — label is generic
  (“Open in _Terminal”); launches `alacritty --working-directory <path>` or,
  if alacritty is absent, `kitty --directory <path>`. Program lookup is cached
  with `g_once_init_*`. Replaces the nautilus-open-any-terminal extension.
- `open-in-code` / `current-directory-code` — launches `code` with the
  selected local paths (or the current directory). Replaces the code-nautilus
  extension. The Code/Terminal/Root trio sits in its own section directly
  above Properties in both the background and the selection menu (the same
  spot the old third-party extension items used).

### 9. Folder image previews

Files: `src/nautilus-file.c`, `src/nautilus-file-private.h`. In
`nautilus_file_get_icon()`, native directories (thumbnails enabled per the
existing speed-tradeoff preference, no custom icon) get a preview: the folder
is enumerated asynchronously (batches of 100, max 500 entries, priority LOW)
for the alphabetically-first non-hidden `image/*` child; its thumbnail is
loaded from the cache when GIO reports `thumbnail::is-valid`, otherwise
generated through the stock `nautilus_create_thumbnail_async()` queue. The
resulting texture is cached on the file (`folder_preview_*` fields in
`struct NautilusFilePrivate`, freed in finalize) and composited over the
themed folder icon with a rounded-rect clip (64% × 46% of the icon, aspect
fill). `nautilus_file_changed()` re-renders the cell when the preview arrives,
and the cache invalidates when the folder’s mtime changes.

## Build / install

- Day to day: `./rebuild-nautilus.sh` (as your user) builds the fork from
  [applications/nautilus-fork/](../applications/nautilus-fork/) with `makepkg` and installs
  it with `pacman -U`. Each run builds from scratch in a temp dir (~a few
  minutes). Because the fork keeps the `nautilus` package name at a higher
  pkgrel, this replaces the official package in place — there is no separate
  uninstall step. The script also removes the `nautilus-open-any-terminal`
  package and the code-nautilus extension if present (their features are
  built into the fork).
- Fresh install: [install.sh](../install.sh) does the same after installing the
  repo `nautilus` (which only serves to pull in runtime deps before the fork
  overwrites it).
- The fork is versioned `50.2.2-1.1` (pkgrel bump over the repo's `-1`) and
  both scripts add `IgnorePkg = nautilus libnautilus-extension` to
  `/etc/pacman.conf` so `pacman -Syu` never replaces it. Remove that line to go
  back to stock Nautilus (`sudo pacman -S nautilus libnautilus-extension`).

## Bumping upstream

1. `git clone --depth 1 --branch <tag> https://gitlab.gnome.org/GNOME/nautilus.git`
2. Overlay it onto `applications/nautilus-fork/nautilus/` (full replace, drop `.git`).
3. Review `git diff` to re-apply the local patches listed above.
4. Update `pkgver` in [applications/nautilus-fork/PKGBUILD](../applications/nautilus-fork/PKGBUILD)
   (keep the `.1` pkgrel suffix) and sync its `depends`/`makedepends` with
   Arch's current PKGBUILD
   (gitlab.archlinux.org/archlinux/packaging/packages/nautilus).
5. Update the baseline commit above, then `./rebuild-nautilus.sh`.
