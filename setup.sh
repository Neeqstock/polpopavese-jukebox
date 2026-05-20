#!/usr/bin/env bash
# PolpoJukebox — setup script
# Installs system deps, creates a Python venv, and sets up a systemd service.
# Run as your normal user (no sudo prefix needed — the script calls sudo itself).
#
#   bash setup.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/jukebox"
VENV="$HOME/jukebox-env"
SERVICE="jukebox"
PORT="${PORT:-5000}"

echo "=== PolpoJukebox Setup ==="
echo "  App directory : $APP_DIR"
echo "  Python venv   : $VENV"
echo "  Service port  : $PORT"
echo ""
echo "Spotify (optional — leave blank to skip):"
read -rp "  SPOTIFY_CLIENT_ID     : " SPOTIFY_CLIENT_ID
read -rp "  SPOTIFY_CLIENT_SECRET : " SPOTIFY_CLIENT_SECRET
echo ""

# ── 1. System packages ────────────────────────────────────────────────────────
echo "[1/4] Installing system packages (mpv, ffmpeg, python3-venv)…"
sudo apt-get update -q
sudo apt-get install -y -q python3 python3-venv mpv ffmpeg

# ── 2. Python virtual environment ─────────────────────────────────────────────
echo "[2/4] Creating Python venv at $VENV…"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip --quiet
"$VENV/bin/pip" install flask flask-cors yt-dlp spotipy --quiet
echo "      Python packages installed."

# ── 3. Systemd service ────────────────────────────────────────────────────────
echo "[3/4] Installing systemd service ($SERVICE)…"

SERVICE_FILE="/tmp/${SERVICE}.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=PolpoJukebox (Flask + yt-dlp + mpv)
After=network.target sound.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${APP_DIR}
ExecStart=${VENV}/bin/python app.py
Restart=always
RestartSec=5
Environment=PORT=${PORT}
Environment=SPOTIFY_CLIENT_ID=${SPOTIFY_CLIENT_ID}
Environment=SPOTIFY_CLIENT_SECRET=${SPOTIFY_CLIENT_SECRET}

[Install]
WantedBy=multi-user.target
EOF

sudo cp "$SERVICE_FILE" "/etc/systemd/system/${SERVICE}.service"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE"

# ── 4. Start ──────────────────────────────────────────────────────────────────
echo "[4/4] Starting jukebox service…"
sudo systemctl restart "$SERVICE" || true

# Wait a moment and check
sleep 3
if sudo systemctl is-active --quiet "$SERVICE"; then
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo ""
    echo "✓ Jukebox is running!"
    echo ""
    echo "  Open on this machine : http://localhost:${PORT}"
    echo "  Open on the network  : http://${IP}:${PORT}"
    echo ""
    echo "  Logs   : sudo journalctl -u ${SERVICE} -f"
    echo "  Stop   : sudo systemctl stop ${SERVICE}"
    echo "  Restart: sudo systemctl restart ${SERVICE}"
else
    echo ""
    echo "✗ Service did not start. Check logs:"
    echo "  sudo journalctl -u ${SERVICE} -n 50"
    exit 1
fi
