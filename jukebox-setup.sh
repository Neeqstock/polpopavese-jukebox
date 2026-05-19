#!/bin/bash
set -e

# PolpoJukebox Setup — Clean single-room implementation
# Ubuntu 24.04 / Debian 12
# Usage: sudo bash jukebox-setup.sh

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use: sudo bash jukebox-setup.sh)"
  exit 1
fi

# Detect the actual login user (the one who ran sudo)
JUKEBOX_USER=${SUDO_USER:-$USER}
JUKEBOX_UID=$(id -u "$JUKEBOX_USER")

if [[ "$JUKEBOX_USER" == "root" ]]; then
  echo "ERROR: Do not run this as root directly. Use: sudo bash jukebox-setup.sh"
  exit 1
fi

echo "=== PolpoJukebox Setup ==="
echo "This will install Mopidy, Shairport Sync, DLNA receiver, nginx, and PipeWire audio."
echo ""
read -p "Hostname for this jukebox (default: jukebox): " HOSTNAME
HOSTNAME=${HOSTNAME:-jukebox}

read -p "Audio output device (run 'pactl list short sinks' to find; default: @DEFAULT_SINK@): " AUDIO_DEVICE
AUDIO_DEVICE=${AUDIO_DEVICE:-@DEFAULT_SINK@}

read -p "SoundCloud OAuth token (optional, leave blank to skip): " SOUNDCLOUD_API_TOKEN
read -p "Spotify Premium client ID (optional, leave blank to skip): " SPOTIFY_CLIENT_ID
read -p "Spotify Premium client secret (optional, leave blank to skip): " SPOTIFY_CLIENT_SECRET

# Non-interactive confirmations
echo ""
echo "Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Audio device: $AUDIO_DEVICE"
echo "  SoundCloud: $([ -z "$SOUNDCLOUD_API_TOKEN" ] && echo "disabled" || echo "enabled")"
echo "  Spotify: $([ -z "$SPOTIFY_CLIENT_ID" ] && echo "disabled" || echo "enabled")
echo ""
read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================

echo "[1/9] Setting hostname to '$HOSTNAME'..."
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

# ============================================================================
# DEPENDENCIES
# ============================================================================

echo "[2/9] Installing system dependencies..."
apt-get update
apt-get install -y \
  python3 python3-pip python3-venv python3-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav libxml2 libxslt1.1 \
  ffmpeg qrencode \
  nginx \
  avahi-daemon avahi-utils \
  alsa-utils pulseaudio-utils \
  curl wget git \
  build-essential pkg-config \
  libssl-dev libffi-dev libopenjp2-7

# Install latest yt-dlp via pip (distro package is often very outdated)
pip3 install --upgrade --break-system-packages yt-dlp

# ============================================================================
# PIPEWIRE SETUP
# ============================================================================

echo "[3/9] Configuring PipeWire for audio mixing..."

# PipeWire should already be installed on Ubuntu 24.04.
# Enable PulseAudio-compatible TCP listener so other Linux machines on the
# network can stream their audio directly to this jukebox (port 4713).
PIPEWIRE_CONF_DIR="/home/$JUKEBOX_USER/.config/pipewire/pipewire-pulse.conf.d"
mkdir -p "$PIPEWIRE_CONF_DIR"
cat > "$PIPEWIRE_CONF_DIR/99-tcp.conf" <<'EOF'
pulse.properties = {
    server.address = [
        "unix:native"
        "tcp:4713"
    ]
}
EOF
chown -R "$JUKEBOX_USER:$JUKEBOX_USER" "/home/$JUKEBOX_USER/.config/pipewire"

# Open port 4713 if ufw is active
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
  ufw allow 4713/tcp
fi

# ============================================================================
# MOPIDY
# ============================================================================

echo "[4/9] Installing Mopidy and extensions..."

# Install Mopidy from official repo
apt-get install -y mopidy

# Install Mopidy extensions via pip
pip3 install --upgrade --break-system-packages \
  Mopidy-Muse \
  Mopidy-Iris \
  Mopidy-YouTube \
  Mopidy-Local \
  Mopidy-SoundCloud

# Optional: Spotify
if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
  pip3 install --upgrade --break-system-packages Mopidy-Spotify
fi

# Configure Mopidy
# Note: allowed_origins must list every hostname clients will use
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
zeroconf = Mopidy HTTP server
allowed_origins = $HOSTNAME, $HOSTNAME.local, localhost

[audio]
mixer = software
output = pulsesink
visualizer =

[local]
enabled = true
media_dir = ~/Music
scan_timeout = 1000
scan_flush_threshold = 100

[youtube]
enabled = true
youtube_api_key =

[ytmusic]
enabled = false


[soundcloud]
enabled = false
auth_token =

[spotify]
enabled = false
client_id =
client_secret =
bitrate = 320

[muse]
enabled = true

[iris]
enabled = true
EOF

# Inject user credentials if provided
if [ -n "$SOUNDCLOUD_API_TOKEN" ]; then
  sed -i "/\[soundcloud\]/,/auth_token/{s/enabled = false/enabled = true/}" /etc/mopidy/mopidy.conf
  sed -i "s/auth_token =/auth_token = $SOUNDCLOUD_API_TOKEN/" /etc/mopidy/mopidy.conf
fi

if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
  sed -i "/\[spotify\]/,/client_secret/{s/enabled = false/enabled = true/}" /etc/mopidy/mopidy.conf
  sed -i "s/client_id =/client_id = $SPOTIFY_CLIENT_ID/" /etc/mopidy/mopidy.conf
  sed -i "s/client_secret =/client_secret = $SPOTIFY_CLIENT_SECRET/" /etc/mopidy/mopidy.conf
fi



# Create data directories owned by the login user
# (Mopidy runs as the login user so it can access PipeWire audio)
mkdir -p /var/cache/mopidy /var/lib/mopidy
chown -R "$JUKEBOX_USER:$JUKEBOX_USER" /var/cache/mopidy /var/lib/mopidy

# Create systemd drop-in so Mopidy runs as the login user with PipeWire access
# (The system mopidy service runs as 'mopidy' user by default, which can't reach
#  the user's PipeWire/PulseAudio socket — this override fixes that.)
# Enable user session at boot (required for PipeWire socket to exist without login)
loginctl enable-linger "$JUKEBOX_USER"

mkdir -p /etc/systemd/system/mopidy.service.d
cat > /etc/systemd/system/mopidy.service.d/user.conf <<EOF
[Unit]
After=user@${JUKEBOX_UID}.service sound.target

[Service]
User=$JUKEBOX_USER
Group=$JUKEBOX_USER
Environment=XDG_RUNTIME_DIR=/run/user/$JUKEBOX_UID
Environment=PULSE_SERVER=unix:/run/user/$JUKEBOX_UID/pulse/native
Restart=on-failure
RestartSec=5
EOF

# Start Mopidy
systemctl daemon-reload
systemctl enable mopidy
systemctl restart mopidy

echo "Waiting for Mopidy to start..."
sleep 3

# ============================================================================
# SHAIRPORT SYNC (AirPlay)
# ============================================================================

echo "[5/9] Installing Shairport Sync (AirPlay receiver)..."

apt-get install -y shairport-sync

cat > /etc/shairport-sync.conf <<EOF
general = {
  name = "$HOSTNAME AirPlay";
  log_verbosity = 1;
  drift_tolerance_in_seconds = 0.002;
  resync_threshold_in_seconds = 0.050;
};

audio = {
  output_backend = "pa";
  output_device = "$AUDIO_DEVICE";
};

sessioncontrol = {
  wait_for_output = yes;
  dacp_server_port = 3689;
};
EOF

systemctl enable shairport-sync
systemctl restart shairport-sync

# ============================================================================
# GMRENDER-RESURRECT (DLNA/UPnP for Android)
# ============================================================================

echo "[6/9] Installing gmrender-resurrect (DLNA receiver for Android)..."

# Build from source (not in Ubuntu 24.04 repos)
apt-get install -y \
  git build-essential automake autoconf libtool pkg-config \
  libupnp-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-pulseaudio gstreamer1.0-alsa

GMRENDER_SRC=$(mktemp -d)
git clone --depth=1 https://github.com/hzeller/gmrender-resurrect.git "$GMRENDER_SRC"
cd "$GMRENDER_SRC"
./autogen.sh
./configure
make -j"$(nproc)"
make install
cd /
rm -rf "$GMRENDER_SRC"

cat > /etc/systemd/system/gmediarender.service <<EOF
[Unit]
Description=GMediaRender UPnP/DLNA Renderer
After=network-online.target user@${JUKEBOX_UID}.service sound.target
Wants=network-online.target

[Service]
Type=simple
User=$JUKEBOX_USER
Group=$JUKEBOX_USER
Environment=XDG_RUNTIME_DIR=/run/user/$JUKEBOX_UID
Environment=PULSE_SERVER=unix:/run/user/$JUKEBOX_UID/pulse/native
ExecStart=/usr/local/bin/gmediarender -f "$HOSTNAME DLNA" --gstout-audiosink=pulsesink
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gmediarender
systemctl restart gmediarender

# ============================================================================
# BLUETOOTH RECEIVER
# ============================================================================

echo "[7/9] Setting up Bluetooth audio receiver..."

apt-get install -y bluez bluez-tools libspa-0.2-bluetooth

# Configure Bluetooth: always discoverable, speaker device class
cat > /etc/bluetooth/main.conf <<'BTCONF'
[General]
Class = 0x200414
DiscoverableTimeout = 0
PairableTimeout = 0
AutoEnable = true
BTCONF

# Auto-accept all pairing requests (no PIN) so any phone can connect
cat > /etc/systemd/system/bt-agent.service <<'BTSVC'
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
systemctl enable bluetooth
systemctl enable bt-agent
systemctl restart bluetooth
sleep 2
bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl pairable on
systemctl restart bt-agent

# ============================================================================
# SCREAM RECEIVER (Windows audio streaming)
# ============================================================================

echo "[8/10] Installing Scream receiver (Windows audio streaming)..."

apt-get install -y libpulse-dev cmake

SCREAM_SRC=$(mktemp -d)
git clone --depth=1 https://github.com/duncanthrax/scream.git "$SCREAM_SRC"
cmake -DPULSEAUDIO_ENABLE=ON -B "$SCREAM_SRC/build" "$SCREAM_SRC/Receivers/unix"
cmake --build "$SCREAM_SRC/build"
cp "$SCREAM_SRC/build/scream" /usr/local/bin/scream-receiver
rm -rf "$SCREAM_SRC"

cat > /etc/systemd/system/scream-receiver.service <<EOF
[Unit]
Description=Scream Audio Receiver (Windows network audio)
After=network-online.target user@${JUKEBOX_UID}.service
Wants=network-online.target

[Service]
Type=simple
User=$JUKEBOX_USER
Group=$JUKEBOX_USER
Environment=XDG_RUNTIME_DIR=/run/user/$JUKEBOX_UID
Environment=PULSE_SERVER=unix:/run/user/$JUKEBOX_UID/pulse/native
ExecStart=/usr/local/bin/scream-receiver -u -p 4010
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable scream-receiver
systemctl restart scream-receiver

# ============================================================================
# NGINX (Reverse Proxy)
# ============================================================================

echo "[9/10] Configuring nginx..."

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

# ============================================================================
# AVAHI (mDNS for .local hostname)
# ============================================================================

echo "[10/10] Enabling avahi (mDNS)..."

systemctl enable avahi-daemon
systemctl restart avahi-daemon

# ============================================================================
# QR CODE GENERATION
# ============================================================================

echo "Generating QR code..."

# Create QR code pointing to hostname (will resolve via router DNS or avahi)
QR_CONTENT="http://$HOSTNAME"
QR_FILE="$HOME/jukebox-qr.png"

qrencode -o "$QR_FILE" "$QR_CONTENT"

if [ -f "$QR_FILE" ]; then
  echo "QR code saved to: $QR_FILE"
  echo "Points to: $QR_CONTENT"
else
  echo "Warning: QR code generation failed"
fi

# ============================================================================
# FINAL STATUS
# ============================================================================

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Hostname: $HOSTNAME"
echo \"Web UI: http://$HOSTNAME\"
echo \"mDNS fallback: http://$HOSTNAME.local\"
echo \"\"
echo \"Available interfaces:\"
echo \"  • Iris (full-featured) — http://$HOSTNAME or http://$HOSTNAME.local\"
echo \"  • Muse (minimal) — http://$HOSTNAME/muse/\"
echo \"\"
echo \"Casting support:\"
echo \"  • AirPlay — iOS/macOS (shows as '$HOSTNAME AirPlay')\"
echo \"  • DLNA/UPnP — Android app casting (shows as '$HOSTNAME DLNA')\"
echo \"  • Bluetooth — any phone (shows as '$HOSTNAME' in Bluetooth settings)\"
echo \"  • PulseAudio TCP — Linux machines on the same network (port 4713)\"
echo \"  • Scream — Windows machines (set Scream as default audio device, port 4010 UDP)\"
echo \"\"
echo \"Music sources:\"
echo \"  • YouTube\"
echo \"  • Local files (~/Music)\"
echo \"  • SoundCloud $([ -z \"$SOUNDCLOUD_API_TOKEN\" ] && echo \"(not configured)\" || echo \"(configured)\")\"
echo \"  • Spotify $([ -z \"$SPOTIFY_CLIENT_ID\" ] && echo \"(not configured)\" || echo \"(configured)\")\"
echo \"\"
echo \"Service status:\"
for svc in mopidy nginx shairport-sync avahi-daemon gmediarender bluetooth bt-agent scream-receiver; do
  status=$(systemctl is-active \"$svc\" 2>/dev/null || echo \"N/A\")
  echo \"  $svc: $status\"
done
echo \"\"
echo \"Next steps:\"
echo \"  1. Set a static/reserved IP on your router for this machine (recommended)\"
echo \"  2. Scan the QR code (at $QR_FILE) or visit http://$HOSTNAME from any device\"
echo \"  3. For AirPlay (iOS/macOS): check Settings → Sound/AirPlay for '$HOSTNAME AirPlay'\"
echo \"  4. For DLNA (Android): use a DLNA/UPnP app to find '$HOSTNAME DLNA'\"
echo \"  5. For NewPipe (Android): NewPipe doesn't support Kodi yet (use DLNA or web UI instead)\"
echo \"\"
