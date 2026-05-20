#!/usr/bin/env bash
# PolpoJukebox cleanup script
# Removes all jukebox-related packages, services, and configs from this machine
# Run as: sudo bash jukebox-clean.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use: sudo bash jukebox-clean.sh)"
  exit 1
fi

echo "=== PolpoJukebox Cleanup ==="
echo "This will remove:"
echo "  • Mopidy and all extensions"
echo "  • Shairport Sync, gmrender-resurrect, Snapcast"
echo "  • nginx, dnsmasq"
echo "  • Spotify/YouTube/Bandcamp config from mopidy.conf"
echo "  • Systemd services and override files"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

echo "[1/5] Stopping services…"
systemctl stop mopidy snapserver shairport-sync gmrender-resurrect nginx dnsmasq avahi-daemon 2>/dev/null || true

echo "[2/5] Disabling services…"
systemctl disable mopidy snapserver shairport-sync gmrender-resurrect nginx dnsmasq avahi-daemon 2>/dev/null || true
systemctl disable avahi-daemon.socket 2>/dev/null || true

echo "[3/5] Removing packages…"
apt-get remove -y \
  mopidy mopidy-iris mopidy-spotify mopidy-youtube mopidy-local mopidy-party mopidy-bandcamp \
  shairport-sync gmrender-resurrect snapserver snapclient \
  nginx dnsmasq \
  2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

echo "[4/5] Removing config files…"
rm -rf /etc/mopidy /etc/nginx /etc/dnsmasq.conf /etc/dnsmasq.d/* 2>/dev/null || true
rm -rf /etc/systemd/system/mopidy.service.d /etc/systemd/system/jukebox-qr.service 2>/dev/null || true
rm -f /usr/local/bin/jukebox-qr.sh 2>/dev/null || true

echo "[5/5] Reloading systemd…"
systemctl daemon-reload

echo ""
echo "✓ Cleanup complete."
echo ""
echo "Now run:"
echo "  cd ~/PolpoJukebox"
echo "  sudo bash jukebox-setup.sh"
