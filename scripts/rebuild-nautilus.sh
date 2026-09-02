#!/bin/bash
set -e

if [[ $EUID -eq 0 ]]; then
    echo "Run rebuild-nautilus.sh as your normal user, not with sudo." >&2
    exit 1
fi

# The script lives in scripts/ — the repo root is one level up.
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# The fork has "Open in Terminal" / "Open in Code" built in — remove the
# third-party extensions so the menu items don't show up twice. (-R without
# --cascade never removes dependent packages; it just fails if any exist.)
if pacman -Qq nautilus-open-any-terminal >/dev/null 2>&1; then
    sudo pacman -R --noconfirm nautilus-open-any-terminal
fi
rm -f "$HOME/.local/share/nautilus-python/extensions/code-nautilus.py"

UPSTREAM_URL="https://gitlab.gnome.org/GNOME/nautilus.git"
# Upstream tag the vendored fork tree was cut from
# (see docs/nautilus-patches.md → Baseline).
BASELINE_TAG=50.2.2

# Target tag: $1 if given, else the latest stable upstream release tag.
if [[ -n "$1" ]]; then
    TARGET_TAG="$1"
else
    TARGET_TAG=$(git ls-remote --tags --refs --sort=-v:refname "$UPSTREAM_URL" \
        | awk -F/ '{print $NF}' \
        | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' \
        | head -1)
fi
[[ -n "$TARGET_TAG" ]] || { echo "Could not determine target upstream tag." >&2; exit 1; }
echo "Building nautilus $TARGET_TAG with local fork patches (baseline $BASELINE_TAG)."

WORK=$(mktemp -d)

# 1. Diff the vendored fork against a pristine baseline checkout, so the
#    local patches float free of any specific upstream version.
git clone --depth 1 --branch "$BASELINE_TAG" "$UPSTREAM_URL" "$WORK/a"
rm -rf "$WORK/a/.git"
mkdir "$WORK/b"
cp -a "$REPO_DIR/applications/nautilus-fork/nautilus/." "$WORK/b/"
(cd "$WORK" && diff -urN a b > fork.patch) || true  # non-zero when diffs exist

# 2. Fetch the target upstream tag and replay the fork's patch onto it.
#    If the patch doesn't apply cleanly, patch(1) exits non-zero → set -e
#    aborts and leaves $WORK in place for inspection.
git clone --depth 1 --branch "$TARGET_TAG" "$UPSTREAM_URL" "$WORK/nautilus"
rm -rf "$WORK/nautilus/.git"
patch -d "$WORK/nautilus" -p1 --no-backup-if-mismatch < "$WORK/fork.patch"

# 3. Build with the shared PKGBUILD, overriding pkgver at the target tag.
BUILD=$WORK/build
mkdir "$BUILD"
cp "$REPO_DIR/applications/nautilus-fork/PKGBUILD" "$BUILD/PKGBUILD"
sed -i "s/^pkgver=.*/pkgver=$TARGET_TAG/" "$BUILD/PKGBUILD"
mv "$WORK/nautilus" "$BUILD/nautilus"
(cd "$BUILD" && makepkg -s --noconfirm)

# Deliberately NOT --noconfirm: if pacman ever proposes removing conflicting
# packages here, it must be shown and explicitly confirmed, never auto-agreed.
sudo pacman -U "$BUILD"/nautilus-*.pkg.tar.zst "$BUILD"/libnautilus-extension-*.pkg.tar.zst
rm -rf "$WORK"

# Keep pacman -Syu from replacing the fork with the repo package.
if ! grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*nautilus' /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a IgnorePkg = nautilus libnautilus-extension' /etc/pacman.conf
fi

# Quit any running instance so the next launch uses the new binary. Safe on
# GNOME too: nautilus hasn't drawn the desktop since 3.28 and is D-Bus
# activated, so it simply restarts on next use.
nautilus -q >/dev/null 2>&1 || true

echo "Nautilus fork installed: $(pacman -Q nautilus)"
