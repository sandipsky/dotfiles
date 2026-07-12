#!/usr/bin/env bash
# fix-dns.sh — fix the 5-second-per-lookup DNS stalls on this Arch machine
#
# Diagnosis (2026-07-12): the "GLX" Wi-Fi router hands out three DNS servers
# via DHCP, and the FIRST one (110.44.112.200) is dead — it never answers.
# glibc tries nameservers in order with a 5 s timeout, and with no local DNS
# cache running (systemd-resolved was disabled), every hostname lookup on the
# system stalled for 5 s before failing over. That is why websites crawl here
# but feel fine on Windows (Windows caches DNS and sidelines dead servers).
#
# What this script does:
#   1. Tells NetworkManager to ignore the router's DNS on connection "GLX"
#      and use 1.1.1.1 + 110.44.113.245 (the ISP server that works) instead.
#   2. Enables systemd-resolved — a local DNS cache that also auto-skips
#      unresponsive servers — and points /etc/resolv.conf at its stub.
#   3. Restarts NetworkManager, waits for Wi-Fi to reconnect, then verifies
#      that lookups now take milliseconds.
#
# To undo everything:
#   sudo nmcli connection modify GLX ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no ipv4.dns "" ipv6.dns ""
#   sudo systemctl disable --now systemd-resolved.service
#   sudo rm /etc/resolv.conf && sudo systemctl restart NetworkManager
#   (NetworkManager regenerates /etc/resolv.conf; a backup of the old file
#    is also saved next to it as /etc/resolv.conf.backup-<timestamp>)
#
# Run with:  sudo ./fix-dns.sh

set -euo pipefail

CON="GLX"
DNS4="1.1.1.1 110.44.113.245"
DNS6="2606:4700:4700::1111 2606:4700:4700::1001"

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "please run as root:  sudo $0"

nmcli -t -f NAME connection show | grep -Fxq "$CON" \
    || die "connection '$CON' not found. Available: $(nmcli -t -f NAME connection show | tr '\n' ' ')"

msg "1/4  Setting DNS on '$CON' (ignore router DNS, use: $DNS4)"
nmcli connection modify "$CON" \
    ipv4.ignore-auto-dns yes ipv4.dns "$DNS4" \
    ipv6.ignore-auto-dns yes ipv6.dns "$DNS6"

msg "2/4  Enabling systemd-resolved (DNS cache + dead-server failover)"
systemctl enable --now systemd-resolved.service
# Point /etc/resolv.conf at resolved's stub so every app, including browsers
# that read resolv.conf directly (Chromium), goes through the cache.
if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
    cp /etc/resolv.conf "/etc/resolv.conf.backup-$(date +%Y%m%d-%H%M%S)"
fi
ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

msg "3/4  Restarting NetworkManager (Wi-Fi will drop for a few seconds)"
systemctl restart NetworkManager.service

printf 'waiting for %s to reconnect ' "$CON"
connected=0
for _ in $(seq 1 30); do
    if nmcli -t -f NAME connection show --active 2>/dev/null | grep -Fxq "$CON"; then
        connected=1
        break
    fi
    printf '.'
    sleep 1
done
echo
[[ $connected -eq 1 ]] || die "'$CON' did not reconnect within 30 s — check 'nmcli device' manually"
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

msg "Done. Lookups should be a few hundred ms at most (cached ones ~0 ms)."
echo "Undo instructions are in the comment header of this script."
