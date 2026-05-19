# Polpopavese Jukebox — setup handoff

## Goal
Build a democratic WiFi jukebox on a Linux machine (non-Pi, x86_64 desktop).
Anyone on the local network can open a web UI, search for music, and add songs to a shared queue.
Access via a custom hostname and QR code — no app install required.

## Target URL
`http://polpopavesejukebox` — resolves via dnsmasq on the local network.
Fallback: `http://polpopavesejukebox.local` via avahi mDNS, and direct IP `http://192.168.178.76`.

## Machine details
- Hostname: `polpo-jukebox`
- User: `polpopavese`
- OS: Debian 12 Bookworm (x86_64, not Raspberry Pi)
- Network interface: `wlp2s0` (WiFi)
- Local IP: `192.168.178.76` (dynamic, no static IP — router is a Vodafone Station 6 with limited admin UI)
- Python: 3.12

## Stack
| Component | Role |
|---|---|
| **Mopidy** | Music server. Manages queue, playback, sources. Exposes HTTP/WebSocket API on port 6680. |
| **Iris** | Web UI for Mopidy. Guests open this in their browser to search and queue songs. |
| **Mopidy-YouTube + yt-dlp** | Streams from YouTube (no Spotify account available). |
| **Mopidy-Local** | Plays local files from `~/Music`. |
| **Mopidy-Party** | Vote-based queue sorting (most upvoted plays next). |
| **Mopidy-Bandcamp** | Streams from Bandcamp. |
| **Snapcast** | Multi-room synced audio output. Mopidy writes to a named pipe `/tmp/snapfifo`, Snapcast reads it. Web client on port 1780. |
| **nginx** | Reverse proxy. Exposes Mopidy on port 80 at the custom hostname. |
| **dnsmasq** | Resolves `polpopavesejukebox` to the machine regardless of its current IP (`address=/polpopavesejukebox/0.0.0.0`). |
| **avahi** | mDNS — makes `polpopavesejukebox.local` work on iOS/macOS/Windows. |
| **qrencode** | Generates a QR code PNG pointing to `http://polpopavesejukebox`. Regenerated on boot. |

## Key file locations
| File | Purpose |
|---|---|
| `/etc/mopidy/mopidy.conf` | Main Mopidy config |
| `/opt/mopidy-env/` | Python venv containing Mopidy and all extensions |
| `/etc/systemd/system/mopidy.service.d/venv.conf` | Overrides Mopidy's systemd unit to use the venv binary |
| `/etc/nginx/sites-available/jukebox` | nginx reverse proxy config |
| `/etc/dnsmasq.conf` | dnsmasq config with custom hostname |
| `/etc/systemd/resolved.conf` | `DNSStubListener=no` set to free port 53 for dnsmasq |
| `/usr/local/bin/jukebox-qr.sh` | Boot script that regenerates the QR code PNG |
| `/etc/systemd/system/jukebox-qr.service` | Systemd unit for the QR boot script |
| `~/jukebox-qr.png` | The QR code image |
| `~/Music/` | Local music library |

## Mopidy config summary (`/etc/mopidy/mopidy.conf`)
```ini
[http]
enabled = true
hostname = 0.0.0.0
port = 6680
csrf_protection = false

[audio]
output = audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=/tmp/snapfifo

[local]
enabled = true
media_dir = /home/polpopavese/Music

[youtube]
enabled = true
youtube_dl_package = yt_dlp

[bandcamp]
enabled = true

[party]
enabled = true
```

Spotify is NOT configured (no account available at time of setup).
To add it later: install `Mopidy-Spotify` in the venv and add `[spotify]` credentials to the config.

## Service status at handoff
| Service | Status |
|---|---|
| nginx | ✅ running |
| dnsmasq | ✅ running |
| avahi-daemon | ✅ running |
| snapserver | ✅ installed |
| **mopidy** | ❌ failing — see current issue below |

## Current issue — Mopidy not starting
Mopidy crashes immediately on start with:
```
ModuleNotFoundError: No module named 'pkg_resources'
```

`pkg_resources` is part of `setuptools`. Despite `setuptools 82.0.1` being present in the venv,
`/opt/mopidy-env/bin/python -c "import pkg_resources"` still fails.
This is a known Python 3.12 issue where `pkg_resources` can be present in setuptools
but not importable in certain venv configurations.

### What has been tried
- `sudo /opt/mopidy-env/bin/pip install setuptools` → already satisfied, no change
- `sudo /opt/mopidy-env/bin/pip install --upgrade setuptools wheel` → installed wheel, still fails
- `sudo /opt/mopidy-env/bin/pip install --force-reinstall setuptools` → in progress at handoff

### Suggested next steps
1. Force reinstall setuptools and test:
   ```bash
   sudo /opt/mopidy-env/bin/pip install --force-reinstall setuptools
   sudo /opt/mopidy-env/bin/python -c "import pkg_resources; print('ok')"
   ```
2. If still failing, force reinstall mopidy itself:
   ```bash
   sudo /opt/mopidy-env/bin/pip install --force-reinstall mopidy
   sudo systemctl restart mopidy
   ```
3. If still failing, rebuild the venv entirely:
   ```bash
   sudo rm -rf /opt/mopidy-env
   sudo python3 -m venv /opt/mopidy-env
   sudo /opt/mopidy-env/bin/pip install --upgrade pip setuptools wheel
   sudo /opt/mopidy-env/bin/pip install Mopidy-Iris Mopidy-YouTube Mopidy-Local Mopidy-Party Mopidy-Bandcamp yt-dlp
   sudo systemctl restart mopidy
   ```
4. Alternative: skip the venv entirely and install Mopidy system-wide using
   `--break-system-packages` since this is a dedicated single-purpose machine:
   ```bash
   sudo pip3 install --break-system-packages mopidy mopidy-iris mopidy-youtube mopidy-local mopidy-party mopidy-bandcamp yt-dlp
   # Then remove the venv override so systemd uses the system mopidy:
   sudo rm /etc/systemd/system/mopidy.service.d/venv.conf
   sudo systemctl daemon-reload
   sudo systemctl restart mopidy
   ```

## Other issues encountered and resolved
- **Duplicate Mopidy apt source**: both `mopidy.list` and `mopidy.sources` existed → removed `mopidy.list`
- **`sudo: unable to resolve host polpo-jukebox`**: hostname not in `/etc/hosts` → added `127.0.1.1 polpo-jukebox`
- **Broken nodejs/npm packages blocking apt**: removed with `apt remove --purge nodejs npm`
- **`externally-managed-environment` pip error**: solved by using a Python venv at `/opt/mopidy-env`
- **dnsmasq port 53 conflict with systemd-resolved**: set `DNSStubListener=no` in `/etc/systemd/resolved.conf`
- **No static IP / router inaccessible**: Vodafone Station 6 hides DHCP reservation. Solved with dnsmasq `address=/polpopavesejukebox/0.0.0.0` (resolves to current IP dynamically) + avahi mDNS as fallback

## Once Mopidy is running — final verification checklist
```bash
# Mopidy listening on port 6680?
ss -tlnp | grep 6680

# Open in browser on the same WiFi network:
# http://polpopavesejukebox      (via dnsmasq)
# http://polpopavesejukebox.local  (via avahi, iOS/macOS/Windows)
# http://192.168.178.76          (direct IP, Android fallback)
# http://192.168.178.76:1780     (Snapcast web client)

# Scan local music library after adding files to ~/Music:
sudo mopidyctl local scan
```
