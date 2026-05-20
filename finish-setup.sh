#!/bin/bash
set -e

HOSTNAME="jukebox"
JUKEBOX_USER="polpopavese"
JUKEBOX_UID=$(id -u "$JUKEBOX_USER")
AUDIO_DEVICE="@DEFAULT_SINK@"

echo "[5/9] Installing gmrender-resurrect (DLNA)..."
apt-get install -y \
  git build-essential automake autoconf libtool pkg-config \
  libupnp-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-pulseaudio gstreamer1.0-alsa
GMRENDER_SRC=$(mktemp -d)
git clone --depth=1 https://github.com/hzeller/gmrender-resurrect.git "$GMRENDER_SRC"
cd "$GMRENDER_SRC"
./autogen.sh && ./configure && make -j"$(nproc)" && make install
cd / && rm -rf "$GMRENDER_SRC"
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

echo "[7/9] Setting up Bluetooth..."
apt-get install -y bluez bluez-tools libspa-0.2-bluetooth
cat > /etc/bluetooth/main.conf <<'BTCONF'
[General]
Class = 0x200414
DiscoverableTimeout = 0
PairableTimeout = 0
AutoEnable = true
BTCONF
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
systemctl enable bluetooth bt-agent
systemctl restart bluetooth
sleep 2
bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl pairable on
systemctl restart bt-agent

echo "[8/9] Installing Scream (Windows audio)..."
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

echo "[9/9] Configuring Nginx..."
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
nginx -t && systemctl restart nginx

echo "[10/10] Finalizing..."
systemctl enable avahi-daemon
systemctl restart avahi-daemon
qrencode -o /home/$JUKEBOX_USER/jukebox-qr.png "http://$HOSTNAME.local"
chown $JUKEBOX_USER:$JUKEBOX_USER /home/$JUKEBOX_USER/jukebox-qr.png
