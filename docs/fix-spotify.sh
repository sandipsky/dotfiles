#!/usr/bin/env sh
# Reapply the Spotify-network fix.
#
# Two unrelated misconfigurations stop Spotify from logging in and show the
# misleading "your firewall may be blocking Spotify" message:
#
#   1. /etc/hosts blackholes legitimate Spotify infrastructure:
#        0.0.0.0 weblb-wg.gslb.spotify.com   (CNAME target of ap-*.spotify.com)
#        0.0.0.0 prod.b.ssl.us-eu.fastlylb.net (Fastly edge for Spotify content)
#      Leftover from an old "block ads via /etc/hosts" trick.
#
#   2. /etc/resolv.conf lists a dead first nameserver (110.44.112.200) that
#      pings fine but doesn't answer on port 53. Every DNS lookup eats a 5s
#      timeout before falling through, which trips Spotify's access-point
#      handshake timeout and produces "AccessPoint:34".
#
# Re-run after any /etc/resolv.conf rewrite (NetworkManager dhcp, etc).

set -eu

HOSTS=/etc/hosts
RESOLV=/etc/resolv.conf
DEAD_NS='110.44.112.200'
BAD_HOSTS_PATTERN='spotify\.com\|fastlylb\.net'

need_sudo() {
    [ "$(id -u)" -eq 0 ] && return 0
    if ! sudo -v; then
        echo "  sudo is required — aborting." >&2
        exit 1
    fi
    SUDO=sudo
}

with_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

echo "==> Checking /etc/hosts"
if grep -qE "$BAD_HOSTS_PATTERN" "$HOSTS"; then
    need_sudo
    with_sudo cp "$HOSTS" "$HOSTS.bak.$(date +%s)"
    with_sudo sed -i "/$BAD_HOSTS_PATTERN/d" "$HOSTS"
    echo "    removed blackhole entries"
else
    echo "    already clean"
fi

echo "==> Checking /etc/resolv.conf"
if grep -qE "^nameserver $DEAD_NS\$" "$RESOLV"; then
    need_sudo
    with_sudo cp "$RESOLV" "$RESOLV.bak.$(date +%s)"
    with_sudo sed -i "/^nameserver $DEAD_NS\$/d" "$RESOLV"
    echo "    removed dead nameserver $DEAD_NS"
else
    echo "    already clean"
fi

echo "==> Verifying connectivity"
ok=0
for h in ap-gew1.spotify.com ap-gew4.spotify.com; do
    if timeout 4 sh -c "</dev/tcp/$h/4070" 2>/dev/null; then
        echo "    OK   $h:4070"
        ok=$((ok + 1))
    else
        echo "    FAIL $h:4070"
    fi
done

if [ "$ok" -eq 0 ]; then
    echo
    echo "Spotify access points still unreachable. Possible causes:" >&2
    echo "  - ISP is blocking outbound TCP/4070 to Spotify" >&2
    echo "  - resolv.conf was rewritten again (re-run this script)" >&2
    echo "  - new entries appeared in /etc/hosts" >&2
    exit 1
fi

echo
echo "Done. Launch Spotify via:"
echo "  env LD_PRELOAD=/usr/lib/spotify-adblock.so spotify &"
echo "or just use the 'Spotify (adblock)' desktop entry."
