#!/usr/bin/env bash
# fix-dns.sh — one-time DNS fix that works on any network
#
# Original diagnosis (2026-07-12): the "GLX" Wi-Fi router hands out three DNS
# servers via DHCP, and the FIRST one (110.44.112.200) is dead — it never
# answers. glibc tries nameservers in order with a 5 s timeout, and with no
# local DNS cache running, every hostname lookup stalled for 5 s. Any other
# router with a dead/slow DHCP DNS server causes the same symptom.
#
# What this script does (system-wide, network-independent):
#   1. Gives systemd-resolved a global DNS config (Cloudflare, v4+v6) with
#      Domains=~. so it is preferred over whatever DNS any network's DHCP
#      hands out — dead router DNS servers are simply never consulted.
#   2. Enables systemd-resolved — a local DNS cache that also auto-skips
#      unresponsive servers — and points /etc/resolv.conf at its stub.
#   3. Removes the old per-connection DNS pin on "GLX" (from the previous
#      version of this fix) since the global config supersedes it.
#   4. Restarts NetworkManager, waits for reconnect, then verifies that
#      lookups take milliseconds.
#
# Trade-off: with Domains=~. the router's DNS is not used for lookups, so
# LAN hostnames that only the router can resolve (e.g. printer.local names
# served by router DNS) won't resolve. mDNS/.local via Avahi is unaffected.
#
# To undo everything:
#   sudo rm /etc/systemd/resolved.conf.d/10-global-dns.conf
#   sudo systemctl disable --now systemd-resolved.service
#   sudo rm /etc/resolv.conf && sudo systemctl restart NetworkManager
#   (NetworkManager regenerates /etc/resolv.conf; a backup of the old file
#    is also saved next to it as /etc/resolv.conf.backup-<timestamp>)
#
# Run with:  sudo ./fix-dns.sh

set -euo pipefail

DROPIN=/etc/systemd/resolved.conf.d/10-global-dns.conf

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "please run as root:  sudo $0"

msg "1/4  Writing global DNS config for systemd-resolved ($DROPIN)"
mkdir -p /etc/systemd/resolved.conf.d
cat > "$DROPIN" <<'EOF'
# Prefer these resolvers on every network (Domains=~. outranks per-link
# DHCP-provided DNS), so dead router DNS servers are never consulted.
[Resolve]
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
Domains=~.
EOF

msg "2/4  Enabling systemd-resolved (DNS cache + dead-server failover)"
systemctl enable --now systemd-resolved.service
systemctl restart systemd-resolved.service
# Point /etc/resolv.conf at resolved's stub so every app, including browsers
# that read resolv.conf directly (Chromium), goes through the cache.
if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
    cp /etc/resolv.conf "/etc/resolv.conf.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Drop the old per-connection pin from the previous GLX-only fix, if present;
# the global config above covers every network including GLX.
if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq GLX; then
    msg "     Removing old per-connection DNS pin on 'GLX'"
    nmcli connection modify GLX \
        ipv4.ignore-auto-dns no ipv4.dns "" \
        ipv6.ignore-auto-dns no ipv6.dns ""
fi

msg "3/4  Restarting NetworkManager (network will drop for a few seconds)"
systemctl restart NetworkManager.service

printf 'waiting for the network to reconnect '
connected=0
for _ in $(seq 1 30); do
    if nmcli -t -f STATE general 2>/dev/null | grep -q '^connected'; then
        connected=1
        break
    fi
    printf '.'
    sleep 1
done
echo
[[ $connected -eq 1 ]] || die "network did not reconnect within 30 s — check 'nmcli device' manually"
sleep 2

msg "4/4  Verifying DNS speed"
echo "DNS servers now in use:"
resolvectl dns 2>/dev/null | sed 's/^/  /' || true
echo
echo "Lookup times (last one repeats the first host to show the cache working):"
for h in www.python.org www.rust-lang.org www.python.org; do
    t0=$(date +%s%N)
    if getent ahosts "$h" > /dev/null; then
        t1=$(date +%s%N)
        awk -v ms=$(( (t1 - t0) / 1000000 )) -v h="$h" \
            'BEGIN { printf "  %-22s %5d ms%s\n", h, ms, (ms > 2000 ? "   <-- still slow!" : "") }'
    else
        echo "  $h: lookup FAILED"
    fi
done
echo
if t=$(curl -o /dev/null -sS -m 15 -w '%{time_total}' https://www.wikipedia.org); then
    echo "  full HTTPS fetch of wikipedia.org: ${t}s (was ~5.4 s before the fix)"
else
    echo "  HTTPS test fetch failed — check connectivity with: nmcli device"
fi

msg "Done. This is a one-time fix — it applies to every network, current and future."
echo "Undo instructions are in the comment header of this script."
