#!/bin/bash
set -e

# PolpoJukebox Clean Uninstall
# Removes ALL jukebox components for a fresh start
# Usage: sudo bash jukebox-clean.sh

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use: sudo bash jukebox-clean.sh)"
  exit 1
fi

echo "=== PolpoJukebox Uninstall ==="
echo "This will remove ALL jukebox services and configurations."
echo ""
read -p "Are you sure? Type 'yes' to proceed: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "[1/5] Stopping all services..."

for svc in mopidy nginx shairport-sync gmrender-resurrect snapserver snapclient snapfifo-keeper dnsmasq avahi-daemon; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo "  Stopping $svc..."
    systemctl stop "$svc" || true
  fi
  if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    echo "  Disabling $svc..."
    systemctl disable "$svc" || true
  fi
done

echo ""
echo "[2/5] Removing packages..."

# Remove mopidy and extensions
apt-get remove -y mopidy 2>/dev/null || true
pip3 uninstall -y Mopidy-Muse Mopidy-Iris Mopidy-YouTube Mopidy-YTMusic Mopidy-Local Mopidy-SoundCloud Mopidy-Spotify 2>/dev/null || true

# Remove other services
apt-get remove -y shairport-sync gmrender-resurrect snapserver snapclient dnsmasq avahi-daemon nginx 2>/dev/null || true

# Clean apt cache
apt-get autoremove -y 2>/dev/null || true

echo ""
echo "[3/5] Removing configuration files..."

rm -f /etc/mopidy/mopidy.conf
rm -f /etc/shairport-sync.conf
rm -f /etc/snapserver.conf
rm -f /etc/default/snapclient
rm -f /etc/default/gmrender-resurrect
rm -f /etc/default/shairport-sync
rm -f /etc/dnsmasq.conf
rm -f /etc/nginx/sites-available/jukebox
rm -f /etc/nginx/sites-enabled/jukebox
rm -f /etc/yt-dlp.conf

echo ""
echo "[4/5] Removing systemd service files..."

rm -rf /etc/systemd/system/snapfifo-keeper.service
rm -rf /etc/systemd/system/snapclient.service.d/
rm -rf /etc/systemd/user/pipewire.service.d/

systemctl daemon-reload

echo ""
echo "[5/5] Removing data and runtime files..."

# Clean up data directories
rm -rf /var/lib/mopidy
rm -rf /var/cache/mopidy
rm -f /tmp/snapfifo
rm -f /tmp/airplayfifo
rm -f /usr/local/bin/snapfifo-keeper.py

echo ""
echo "=== Uninstall Complete ==="
echo ""
echo "Old components removed. You're ready to run:"
echo "  sudo bash jukebox-setup.sh"
echo ""
