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

*None yet — the vendored tree is a pristine upstream snapshot. Add one section
per feature below as patches land.*

## Build / install

- Day to day: `./rebuild-nautilus.sh` (as your user) builds the fork from
  [applications/nautilus-fork/](../applications/nautilus-fork/) with `makepkg` and installs
  it with `pacman -U`. Each run builds from scratch in a temp dir (~a few
  minutes).
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
