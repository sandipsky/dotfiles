# Music

A minimal GTK4 + libadwaita music player. Two tabs in the header (All Songs and
Playlists), no sidebar, scans `~/Music` by default, registers as a handler for
audio files so it shows up in the file manager's "Open With" menu.

## Dependencies

Already on this Arch system: `gtk4`, `libadwaita`, `gstreamer`,
`gst-plugins-base/good/bad`, `gst-libav`, `gcc`, `pkgconf`.

Still needed (install once):

```
sudo pacman -S meson ninja
```

## Build

```
cd /home/sandip/Projects/music
meson setup build --prefix="$HOME/.local"
meson compile -C build
```

The binary lands at `build/src/music`. To launch:

```
./build/src/music
```

## Install (also wires up "Open With" in file managers)

```
meson install -C build
```

This installs:

- `~/.local/bin/music` — the executable
- `~/.local/share/applications/dev.sandip.Music.desktop` — the desktop entry
  declaring MIME types for mp3, m4a, flac, ogg, opus, wav, aac, wma, aiff, ape.

After install, refresh the desktop database so the file manager picks it up:

```
update-desktop-database ~/.local/share/applications/
```

Right-click any audio file in Files/Nautilus/Nemo/Thunar → **Open With** →
**Music** should now appear. Or set Music as the default:

```
xdg-mime default dev.sandip.Music.desktop audio/mpeg audio/flac audio/ogg \
    audio/mp4 audio/x-m4a audio/opus audio/wav audio/aac
```

## Where things live

- Config + library cache: `~/.config/music/music.ini`
  - `[Library] Directories=` — folders to scan (`~/Music` is the default)
  - `[Favorites] URIs=` — starred tracks
  - `[Playlist:<name>] URIs=` — one section per playlist
  - One section per cached song with metadata (`title`, `artist`, `album`,
    `duration`, `mtime`) — speeds up subsequent launches.

## Layout map

```
src/
├── main.c                       # entry point
├── music-application.{c,h}      # AdwApplication: activate / open hooks
├── music-window.{c,h}           # header bar + view switcher + player bar
├── music-song.{c,h}             # MusicSong GObject (uri/title/artist/...)
├── music-playlist.{c,h}         # MusicPlaylist (name + GListStore<Song>)
├── music-library.{c,h}          # scan, GstDiscoverer metadata, GKeyFile persistence
├── music-player.{c,h}           # GStreamer playbin wrapper + queue + shuffle/repeat
├── music-song-row.{c,h}         # row widget bound to a MusicSong
├── music-player-bar.{c,h}       # bottom transport bar bound to MusicPlayer
├── music-all-songs-view.{c,h}   # "All Songs" tab (search, sort, play)
├── music-playlists-view.{c,h}   # "Playlists" tab (create/rename/delete)
└── music-preferences.{c,h}      # Folder list (add/remove)
```

## Keybindings

- **Ctrl+F** — toggle search on All Songs
- **Ctrl+Q** — quit
- **Space** (when focused on row) — activate / play
