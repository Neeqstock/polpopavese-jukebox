#!/bin/bash
set -e

# =============================================================================
# PolpoJukebox — Clean / Reset Script
# Stops and disables all jukebox services, removes all configs and unit files.
# Does NOT uninstall apt packages (nginx, dnsmasq, avahi, bluez stay installed).
# Usage: sudo bash jukebox-clean-final.sh
# =============================================================================

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash jukebox-clean-final.sh"
  exit 1
fi

JUKEBOX_USER="${SUDO_USER:-$USER}"
if [[ "$JUKEBOX_USER" == "root" ]]; then
  echo "ERROR: Do not run directly as root. Use: sudo bash jukebox-clean-final.sh"
  exit 1
fi

echo "=== PolpoJukebox Clean Reset ==="
echo "This will stop all jukebox services and remove all configs."
echo "apt packages are left installed. Mopidy pip packages will be removed."
echo ""
read -rp "Type 'yes' to proceed: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""

# =============================================================================
# STEP 1 — Stop and disable all jukebox services
# =============================================================================

echo "[1/6] Stopping and disabling services..."

SERVICES=(mopidy gmediarender bt-agent bluetooth avahi-daemon dnsmasq nginx)

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo "  Stopping $svc..."
    systemctl stop "$svc" 2>/dev/null || true
  fi
  if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    echo "  Disabling $svc..."
    systemctl disable "$svc" 2>/dev/null || true
  fi
done

# =============================================================================
# STEP 2 — Remove custom systemd unit files
# =============================================================================

echo "[2/6] Removing systemd unit files and drop-ins..."

rm -rf /etc/systemd/system/mopidy.service.d/
rm -f  /etc/systemd/system/gmediarender.service
rm -f  /etc/systemd/system/bt-agent.service

systemctl daemon-reload

# =============================================================================
# STEP 3 — Uninstall pip mopidy packages
# =============================================================================

echo "[3/6] Uninstalling Mopidy pip packages..."

pip3 uninstall -y \
  mopidy \
  mopidy-iris \
  mopidy-spotify \
  mopidy-youtube \
  mopidy-bandcamp \
  mopidy-party \
  mopidy-muse \
  2>/dev/null || true

# =============================================================================
# STEP 4 — Remove config files and data dirs
# =============================================================================

echo "[4/6] Removing config files and data directories..."

# Mopidy config
rm -f /etc/mopidy/mopidy.conf

# Mopidy data/cache (owned by the user — safe to remove)
rm -rf /var/cache/mopidy
rm -rf /var/lib/mopidy

# Bluetooth config (restores to distro default on next bluez install/restart)
rm -f /etc/bluetooth/main.conf

# =============================================================================
# STEP 5 — Revert nginx to default
# =============================================================================

echo "[5/6] Reverting nginx to default..."

rm -f /etc/nginx/sites-enabled/jukebox
rm -f /etc/nginx/sites-available/jukebox

# Restore the default nginx site if it exists
if [ -f /etc/nginx/sites-available/default ]; then
  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  systemctl start nginx 2>/dev/null || true
  echo "  nginx default site restored."
else
  echo "  No default nginx site found — nginx left stopped."
fi

# =============================================================================
# STEP 6 — Revert dnsmasq and re-enable systemd-resolved DNS stub
# =============================================================================

echo "[6/6] Reverting dnsmasq and restoring systemd-resolved..."

rm -f /etc/dnsmasq.conf

# Re-enable systemd-resolved DNS stub listener (we disabled it for dnsmasq)
if [ -f /etc/systemd/resolved.conf ]; then
  sed -i \
    's|^DNSStubListener=no|DNSStubListener=yes|' \
    /etc/systemd/resolved.conf
  systemctl restart systemd-resolved 2>/dev/null || true
  echo "  systemd-resolved DNS stub re-enabled."
fi

# Disable user linger (was enabled so mopidy could start at boot without login)
loginctl disable-linger "$JUKEBOX_USER" 2>/dev/null || true

echo ""
echo "=== Clean Complete ==="
echo ""
echo "Removed:"
echo "  - All jukebox systemd services (stopped + disabled)"
echo "  - Mopidy + Iris + Spotify pip packages"
echo "  - /etc/mopidy/mopidy.conf"
echo "  - /etc/systemd/system/mopidy.service.d/"
echo "  - /etc/systemd/system/gmediarender.service"
echo "  - /etc/systemd/system/bt-agent.service"
echo "  - /etc/bluetooth/main.conf"
echo "  - /etc/nginx/sites-available/jukebox"
echo "  - /etc/dnsmasq.conf"
echo "  - /var/cache/mopidy, /var/lib/mopidy"
echo ""
echo "Kept (apt packages not removed):"
echo "  - nginx, dnsmasq, avahi-daemon, bluez, ffmpeg, gstreamer, python3"
echo ""
echo "To reinstall: sudo bash jukebox-setup-final.sh"
echo ""
