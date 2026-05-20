#!/bin/bash
set -e

# =============================================================================
# PolpoJukebox — Final Setup Script
# Tested on: Ubuntu 24.04 / Zorin OS 18 (x86_64)
# Installs:  Mopidy 4.0.0a4 + Iris + Spotify 5.0.0a4 + YouTube + Bandcamp
#            DLNA (gmrender-resurrect) + Bluetooth auto-pair
#            nginx (port 80 proxy) + dnsmasq (LAN hostname) + avahi (mDNS)
# Usage:     sudo bash jukebox-setup-final.sh
# =============================================================================

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash jukebox-setup-final.sh"
  exit 1
fi

JUKEBOX_USER="${SUDO_USER:-$USER}"
if [[ "$JUKEBOX_USER" == "root" ]]; then
  echo "ERROR: Do not run directly as root. Use: sudo bash jukebox-setup-final.sh"
  exit 1
fi
JUKEBOX_UID=$(id -u "$JUKEBOX_USER")

# =============================================================================
# PROMPTS
# =============================================================================

echo "=== PolpoJukebox Setup ==="
echo "Installing for user: $JUKEBOX_USER (uid=$JUKEBOX_UID)"
echo ""

read -rp "Hostname for this jukebox [default: polpo-jukebox]: " INPUT_HOSTNAME
JUKEBOX_HOSTNAME="${INPUT_HOSTNAME:-polpo-jukebox}"

echo ""
echo "Spotify Premium credentials (from https://www.mopidy.com/authenticate)"
read -rp "  Spotify client_id: " SPOTIFY_CLIENT_ID
read -rp "  Spotify client_secret: " SPOTIFY_CLIENT_SECRET

echo ""
echo "Configuration:"
echo "  Hostname : $JUKEBOX_HOSTNAME"
echo "  User     : $JUKEBOX_USER"
echo "  Spotify  : $([ -z "$SPOTIFY_CLIENT_ID" ] && echo 'disabled (no credentials)' || echo 'enabled')"
echo ""
read -rp "Proceed? [y/N] " -n 1 REPLY
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# =============================================================================
# STEP 1 — Hostname
# =============================================================================

echo ""
echo "[1/15] Setting hostname to '$JUKEBOX_HOSTNAME'..."

hostnamectl set-hostname "$JUKEBOX_HOSTNAME"

# Rewrite /etc/hosts cleanly
{
  echo "127.0.0.1 localhost"
  echo "::1       localhost"
  echo "127.0.1.1 $JUKEBOX_HOSTNAME $JUKEBOX_HOSTNAME.local"
} > /etc/hosts

# =============================================================================
# STEP 2 — System packages
# =============================================================================

echo "[2/15] Installing system packages..."

apt-get update -q

apt-get install -y \
  python3 python3-pip python3-dev python3-setuptools python3-wheel \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly gstreamer1.0-libav \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libglib2.0-dev libupnp-dev autoconf automake libtool \
  ffmpeg qrencode \
  bluez bluez-tools \
  avahi-daemon avahi-utils \
  alsa-utils \
  curl wget git \
  build-essential pkg-config \
  libssl-dev libffi-dev libopenjp2-7

# =============================================================================
# STEP 3 — Mopidy apt repo + install (provides systemd unit + conf.d)
# =============================================================================

echo "[3/15] Adding Mopidy apt repo and installing base package..."

mkdir -p /etc/apt/keyrings
# Remove any conflicting Mopidy source files
rm -f /etc/apt/sources.list.d/mopidy.sources

wget -q -O - https://apt.mopidy.com/mopidy.gpg \
  | tee /etc/apt/keyrings/mopidy.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mopidy.gpg] https://apt.mopidy.com/ bookworm main" \
  > /etc/apt/sources.list.d/mopidy.list

apt-get update -q
apt-get install -y mopidy   # installs 3.x from apt — we override binary via pip below

# =============================================================================
# STEP 4 — Mopidy 4.0.0a4 stack via pip
# =============================================================================

echo "[4/15] Installing Mopidy 4.0.0a4 stack via pip..."

pip3 install --break-system-packages --upgrade \
  "mopidy==4.0.0a4" \
  "mopidy-iris" \
  "mopidy-spotify==5.0.0a4" \
  "mopidy-youtube" \
  "mopidy-bandcamp" \
  "mopidy-party" \
  "mopidy-muse" \
  "yt-dlp"

# =============================================================================
# STEP 5 — Iris core.py patch (Mopidy 4.x removed mopidy.models.serialize)
# =============================================================================

echo "[5/15] Applying Iris compatibility patch for Mopidy 4.x..."

IRIS_CORE=$(python3 -c \
  "import mopidy_iris; print(mopidy_iris.__file__.replace('__init__.py','core.py'))" \
  2>/dev/null || true)

if [ -z "$IRIS_CORE" ] || [ ! -f "$IRIS_CORE" ]; then
  echo "WARNING: Could not locate mopidy_iris/core.py — patch skipped."
else
  if grep -q "from mopidy.models.serialize import ModelJSONEncoder" "$IRIS_CORE"; then
    sed -i \
      's|^from mopidy.models.serialize import ModelJSONEncoder|import json as _json\nclass ModelJSONEncoder(_json.JSONEncoder):\n    def default(self, obj):\n        if hasattr(obj, "model_dump_json"):\n            return _json.loads(obj.model_dump_json())\n        return super().default(obj)|' \
      "$IRIS_CORE"
    echo "  Patch applied to: $IRIS_CORE"
  else
    echo "  Already patched or import not found — skipping."
  fi
fi

# =============================================================================
# STEP 6 — GStreamer Spotify plugin v0.15.0-alpha.1
# =============================================================================

echo "[6/15] Installing GStreamer Spotify plugin v0.15.0-alpha.1..."

ARCH=$(dpkg --print-architecture)
GST_VERSION="0.15.0-alpha.1"
GST_URL="https://github.com/mopidy/gst-plugins-rs-build/releases/download/v${GST_VERSION}/gst-plugin-spotify_${GST_VERSION}_${ARCH}.deb"

if gst-inspect-1.0 spotify 2>/dev/null | grep -q "Version.*${GST_VERSION}"; then
  echo "  Already installed (v${GST_VERSION}) — skipping."
else
  echo "  Downloading from: $GST_URL"
  if wget -q -O /tmp/gst-plugin-spotify.deb "$GST_URL"; then
    apt-get install -y /tmp/gst-plugin-spotify.deb
    rm -f /tmp/gst-plugin-spotify.deb
    echo "  GStreamer Spotify plugin installed."
  else
    echo "  WARNING: Download failed for arch '$ARCH'. Spotify playback will not work."
    echo "  Manually install from: https://github.com/mopidy/gst-plugins-rs-build/releases/tag/v${GST_VERSION}"
  fi
fi

# =============================================================================
# STEP 7 — Mopidy configuration
# =============================================================================

echo "[7/15] Writing /etc/mopidy/mopidy.conf..."

mkdir -p /etc/mopidy

SPOTIFY_ENABLED="false"
if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
  SPOTIFY_ENABLED="true"
fi

cat > /etc/mopidy/mopidy.conf <<EOF
[core]
cache_dir = /var/cache/mopidy
config_dir = /etc/mopidy
data_dir = /var/lib/mopidy

[logging]
console_format = %(levelname)-8s %(asctime)s [%(name)s] %(message)s
color = true

[http]
enabled = true
hostname = 0.0.0.0
port = 6680
csrf_protection = false
allowed_origins = $JUKEBOX_HOSTNAME, $JUKEBOX_HOSTNAME.local, localhost

[audio]
mixer = software
; alsasink bypasses PulseAudio/PipeWire socket — required when mopidy runs as a
; system service even with the user drop-in, because the socket path can vary.
output = alsasink

[local]
enabled = true
media_dir = ~/Music

[youtube]
enabled = true
youtube_dl_package = yt_dlp

[bandcamp]
enabled = true

[party]
enabled = true

[muse]
enabled = true

[iris]
enabled = true

[spotify]
enabled = $SPOTIFY_ENABLED
client_id = $SPOTIFY_CLIENT_ID
client_secret = $SPOTIFY_CLIENT_SECRET
bitrate = 320

[soundcloud]
enabled = false

[ytmusic]
enabled = false
EOF

chown "$JUKEBOX_USER:$JUKEBOX_USER" /etc/mopidy/mopidy.conf
chmod 600 /etc/mopidy/mopidy.conf

# =============================================================================
# STEP 8 — Systemd drop-in (run mopidy as login user, use pip binary)
# =============================================================================

echo "[8/15] Creating mopidy systemd drop-in..."

mkdir -p /etc/systemd/system/mopidy.service.d

cat > /etc/systemd/system/mopidy.service.d/user.conf <<EOF
[Unit]
; Wait for the user session (needed for audio socket access)
After=user@${JUKEBOX_UID}.service sound.target

[Service]
User=$JUKEBOX_USER
Group=$JUKEBOX_USER
Environment=XDG_RUNTIME_DIR=/run/user/$JUKEBOX_UID
Environment=PULSE_SERVER=unix:/run/user/$JUKEBOX_UID/pulse/native
Restart=on-failure
RestartSec=5

; Clear the base unit's ExecStartPre that chowns to the system 'mopidy' user
ExecStartPre=
ExecStartPre=/bin/mkdir -p /var/cache/mopidy/spotify
ExecStartPre=/bin/chown -R $JUKEBOX_USER:$JUKEBOX_USER /var/cache/mopidy

; Use pip-installed mopidy 4.x, not the apt stub at /usr/bin/mopidy
ExecStart=
ExecStart=/usr/local/bin/mopidy --config /usr/share/mopidy/conf.d:/etc/mopidy/mopidy.conf
EOF

# =============================================================================
# STEP 9 — Permissions + linger
# =============================================================================

echo "[9/15] Fixing permissions and enabling linger..."

mkdir -p /var/cache/mopidy/spotify /var/lib/mopidy
chown -R "$JUKEBOX_USER:$JUKEBOX_USER" /var/cache/mopidy /var/lib/mopidy
chown -R "$JUKEBOX_USER:$JUKEBOX_USER" /etc/mopidy

# Enable linger so the user session (and audio) exists at boot without graphical login
loginctl enable-linger "$JUKEBOX_USER"

systemctl daemon-reload
systemctl enable mopidy

# =============================================================================
# STEP 10 — DLNA renderer (gmrender-resurrect, built from source)
# =============================================================================

echo "[10/15] Building gmrender-resurrect (DLNA renderer)..."

if command -v gmediarender >/dev/null 2>&1; then
  echo "  Already installed — skipping build."
else
  cd /tmp
  rm -rf gmrender-resurrect
  git clone --depth=1 https://github.com/hzeller/gmrender-resurrect.git
  cd gmrender-resurrect
  ./autogen.sh
  ./configure
  make -j"$(nproc)"
  make install
  cd /tmp
  rm -rf gmrender-resurrect
fi

DLNA_UUID=$(cat /proc/sys/kernel/random/uuid)

cat > /etc/systemd/system/gmediarender.service <<EOF
[Unit]
Description=UPnP/DLNA Media Renderer
After=network-online.target user@${JUKEBOX_UID}.service sound.target

[Service]
User=$JUKEBOX_USER
Group=$JUKEBOX_USER
Environment=XDG_RUNTIME_DIR=/run/user/$JUKEBOX_UID
Environment=PULSE_SERVER=unix:/run/user/$JUKEBOX_UID/pulse/native
ExecStart=/usr/local/bin/gmediarender \
  --port 49494 \
  --uuid $DLNA_UUID \
  --friendly-name "$JUKEBOX_HOSTNAME DLNA"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gmediarender
systemctl restart gmediarender

# =============================================================================
# STEP 11 — Bluetooth auto-pair
# =============================================================================

echo "[11/15] Configuring Bluetooth auto-pair..."

cat > /etc/bluetooth/main.conf <<'BTCONF'
[General]
Class = 0x200414
DiscoverableTimeout = 0
PairableTimeout = 0
AutoEnable = true
BTCONF

cat > /etc/systemd/system/bt-agent.service <<BTSVC
[Unit]
Description=Bluetooth Auto-Accept Pairing Agent
After=bluetooth.service
Requires=bluetooth.service

[Service]
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
BTSVC

systemctl daemon-reload
systemctl enable bluetooth bt-agent
systemctl restart bluetooth
sleep 5

bluetoothctl power on       2>/dev/null || true
bluetoothctl discoverable on 2>/dev/null || true
bluetoothctl pairable on    2>/dev/null || true
systemctl restart bt-agent  2>/dev/null || true

# =============================================================================
# STEP 12 — dnsmasq (LAN hostname resolution)
# =============================================================================

echo "[12/15] Configuring dnsmasq..."

apt-get install -y dnsmasq

# Free port 53 from systemd-resolved so dnsmasq can bind
if [ -f /etc/systemd/resolved.conf ]; then
  sed -i \
    's|^#DNSStubListener=yes|DNSStubListener=no|; s|^DNSStubListener=yes|DNSStubListener=no|' \
    /etc/systemd/resolved.conf
  systemctl restart systemd-resolved 2>/dev/null || true
fi

cat > /etc/dnsmasq.conf <<EOF
# PolpoJukebox — dnsmasq config
listen-address=127.0.0.1
bind-interfaces
addn-hosts=/etc/hosts
cache-size=150
EOF

systemctl enable dnsmasq
systemctl restart dnsmasq

# =============================================================================
# STEP 13 — nginx reverse proxy (port 80 → Mopidy :6680)
# =============================================================================

echo "[13/15] Configuring nginx..."

# Purge + reinstall ensures nginx.conf and full directory structure are present
apt-get purge -y nginx nginx-common 2>/dev/null || true
apt-get install -y nginx

cat > /etc/nginx/sites-available/jukebox <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        proxy_pass http://127.0.0.1:6680;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/jukebox /etc/nginx/sites-enabled/jukebox
nginx -t
systemctl enable nginx
systemctl restart nginx

# =============================================================================
# STEP 14 — avahi (mDNS for hostname.local)
# =============================================================================

echo "[14/15] Enabling avahi-daemon..."

systemctl enable avahi-daemon
systemctl restart avahi-daemon

# =============================================================================
# STEP 15 — Start Mopidy + verify
# =============================================================================

echo "[15/15] Starting Mopidy..."

systemctl restart mopidy
sleep 6

echo ""
echo "=== Service Status ==="
for svc in mopidy nginx avahi-daemon dnsmasq gmediarender bluetooth bt-agent; do
  status=$(systemctl is-active "$svc" 2>/dev/null || echo "N/A")
  printf "  %-20s %s\n" "$svc" "$status"
done

echo ""
echo "=== Mopidy Log (last 10 lines) ==="
journalctl -u mopidy --no-pager -n 10

echo ""
echo "=== Setup Complete ==="
echo ""
echo "  Web UI    : http://$JUKEBOX_HOSTNAME/iris/     (Iris)"
echo "  Muse UI   : http://$JUKEBOX_HOSTNAME/muse/"
echo "  mDNS      : http://$JUKEBOX_HOSTNAME.local/iris/"
echo "  Direct    : http://$(hostname -I | awk '{print $1}'):6680/iris/"
echo ""
echo "  Bluetooth : discoverable as '$JUKEBOX_HOSTNAME'"
echo "  DLNA      : visible as '$JUKEBOX_HOSTNAME DLNA'"
echo ""

# QR code for the web UI
QR_FILE="/home/$JUKEBOX_USER/jukebox-qr.png"
if command -v qrencode >/dev/null 2>&1; then
  qrencode -o "$QR_FILE" "http://$JUKEBOX_HOSTNAME/iris/"
  chown "$JUKEBOX_USER:$JUKEBOX_USER" "$QR_FILE"
  echo "  QR code   : $QR_FILE → http://$JUKEBOX_HOSTNAME/iris/"
fi

echo ""
if journalctl -u mopidy --no-pager -n 30 | grep -q "Logged into Spotify"; then
  echo "  Spotify   : AUTHENTICATED ✓"
else
  echo "  Spotify   : check logs → journalctl -u mopidy -n 50"
fi
echo ""
