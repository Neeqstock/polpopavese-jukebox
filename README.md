# PolpoJukebox — Complete Wireless Audio Streaming System

A **unified, easy-to-deploy music streaming and audio system** for any room. Stream from phones, computers, browsers, and music apps to a shared speaker.

**[→ For non-technical users, see USER_GUIDE.md](USER_GUIDE.md)**

---

## Quick Start

**On a fresh Ubuntu 24.04 LTS or Debian 12 machine:**

```bash
cd /path/to/PolpoJukebox
sudo bash jukebox-setup.sh
```

The script will ask for:
- Hostname (e.g., `jukebox`)
- Audio output device (optional; auto-detected)
- Optional music service credentials (Spotify, SoundCloud)

**Total time:** ~15 minutes (includes all downloads and installations)

After setup:
1. Set a **static IP on your router** (DHCP reservation for the machine's MAC address) — optional but recommended
2. Guests visit `http://jukebox` to queue music
3. iOS/macOS: select `jukebox AirPlay` from their AirPlay menu
4. Android: Bluetooth pair with `jukebox`, or use DLNA app cast
5. Windows: Install Scream driver, reboot, set as default audio
6. Linux: `export PULSE_SERVER=tcp:jukebox:4713` then use normally

---

## Features

| Feature | Type | Devices |
|---------|------|---------|
| **Web Player (Iris)** | Browser | Any device (phone, laptop, tablet) |
| **YouTube Streaming** | Built-in | Any device via web |
| **AirPlay** | Wireless | iOS, macOS |
| **Bluetooth** | Wireless | Any phone or device |
| **DLNA/UPnP Casting** | App-based | Android apps (YouTube, Spotify, etc.) |
| **Kodi Media Center** | Advanced | Optional, fullscreen or web |
| **Windows Scream** | Network | Windows PCs (system audio) |
| **Linux PulseAudio TCP** | Network | Linux PCs (system or mic audio) |

---

## What Gets Installed

| Component | Purpose | Auto-Start |
|---|---|---|
| **Mopidy** | Music server with extensible API | ✓ |
| **Iris** | Modern web player for Mopidy | ✓ (port 80) |
| **Muse** | Minimal web interface | ✓ (default) |
| **YouTube Source** | Stream any YouTube video/audio | ✓ |
| **Kodi** | Full media center (optional manual launch) | ✗ (installed, user-launched) |
| **Shairport Sync** | AirPlay receiver | ✓ |
| **gmrender-resurrect** | DLNA/UPnP receiver | ✓ |
| **Bluetooth Stack** | Auto-discoverable audio input | ✓ |
| **Scream Receiver** | Windows UDP audio streaming | ✓ |
| **PipeWire** | Audio mixing & routing | ✓ |
| **Nginx** | Reverse proxy (port 80) | ✓ |
| **Avahi mDNS** | `.local` hostname discovery | ✓ |

---

## System Requirements

- **OS:** Ubuntu 24.04 LTS or Debian 12+
- **Hardware:** Any modern PC or laptop (Pentium-era or better)
- **RAM:** 1GB minimum, 2GB+ recommended
- **Storage:** 500MB free (before music library)
- **Audio:** 3.5mm output, USB audio, or internal speakers
- **Network:** WiFi or Ethernet

---

## How It Works

```
┌─────────────────────────────────────┐
│    Guests & Users (Any Device)      │
└─────────────────────────────────────┘
        ↓ AirPlay
        ↓ Bluetooth
        ↓ HTTP/Web
        ↓ DLNA/UPnP
        ↓ Scream/UDP
        ↓ PulseAudio TCP
        ↓
┌─────────────────────────────────────┐
│  PipeWire Audio Mixer               │
│  (mixes all sources simultaneously) │
└─────────────────────────────────────┘
        ↓
┌─────────────────────────────────────┐
│    Audio Output (Speakers)          │
└─────────────────────────────────────┘
```

### HTTP/Web Stack
```
Browser (http://jukebox)
    ↓
Nginx (reverse proxy, port 80)
    ↓
Mopidy (music server, port 6680)
    ├→ YouTube / SoundCloud / Spotify / Bandcamp / Local files
    ├→ Iris (full-featured UI)
    └→ Muse (minimal UI)
```

---

## Network Access

### Hostname Discovery

The jukebox is discoverable as:

| Name | Protocol | Devices | Works |
|------|----------|---------|-------|
| `jukebox` | DHCP DNS | Router must support | ✓ (if router has DHCP DNS) |
| `jukebox.local` | Avahi mDNS | Any | ✓ (Linux/macOS always, Windows+iTunes usually) |
| `192.168.1.X` | IP address | Any | ✓ (check router for assigned IP) |

**Best practice:** Set a DHCP reservation on your router so `jukebox` always gets the same IP.

### Firewall Ports

If you have UFW enabled, the script automatically opens:

| Port | Service | Protocol |
|------|---------|----------|
| 80 | HTTP (web UI) | TCP |
| 5353 | Avahi mDNS | UDP |
| 3689 | AirPlay mDNS | TCP |
| 4713 | PulseAudio TCP | TCP |
| 4010 | Scream UDP | UDP |

---

## Usage Examples

### Web Browser (Any Device)
```
Open: http://jukebox
→ Search for song
→ Click play
→ Audio streams to speakers
```

### iPhone/iPad (AirPlay)
```
Music app → Play song → AirPlay icon → Select "jukebox AirPlay"
→ or →
Control Center → Long-press volume → AirPlay → "jukebox AirPlay"
```

### Android Phone (Bluetooth)
```
Settings → Bluetooth → Find & pair "jukebox"
→ Open music app → Play (may auto-route to jukebox)
```

### Android with YouTube/Spotify (DLNA)
```
Open app → Cast button → Select "jukebox DLNA"
→ Playback controls remain in app
```

### Android with NewPipe (Kodi)
```
Find video in NewPipe → Share → "Play with Kodi"
→ Enter: jukebox or jukebox.local
→ Video plays fullscreen on jukebox (if Kodi is running)
```

### Windows PC (Scream Driver)
```
1. Install: https://github.com/duncanthrax/scream/releases
2. Reboot Windows
3. Sound settings → Set "Scream" as default device
4. Play anything → streams to jukebox UDP receiver
```

### Linux PC (PulseAudio TCP)
```bash
export PULSE_SERVER=tcp:jukebox:4713
spotify  # or vlc, youtube-dl, etc.
# Audio streams over network to jukebox

# Stream microphone:
parec --device=@DEFAULT_SOURCE@ | \
  PULSE_SERVER=tcp:jukebox:4713 paplay --raw --rate=44100 --channels=2 --format=s16le
```

---

## Music Sources

| Source | Setup | Quality | Notes |
|--------|-------|---------|-------|
| **YouTube** | Built-in | 128kbps (auto) | No auth needed |
| **Local Files** | Built-in | Original | Place in `~/Music/` |
| **Spotify** | Optional | Up to 320kbps (Premium) | Requires Client ID/Secret |
| **SoundCloud** | Optional | 128kbps | Requires OAuth token |

### Enable Spotify
1. Create app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Get Client ID & Secret
3. Edit `/etc/mopidy/mopidy.conf` and add credentials
4. Restart: `sudo systemctl restart mopidy`

---

## Interfaces

### Iris (Full-Featured)
- Search, queue, playlists
- Settings, visualizer, lyrics
- Album art
- Full keyboard shortcuts

Access: `http://jukebox` or `http://jukebox/iris/`

### Muse (Minimal)
- Search and queue
- Clean, fast design
- Mobile-optimized

Access: `http://jukebox/muse/` (fallback to main UI)

### Kodi (Media Center)
- Advanced library management
- Video playback support
- Addon ecosystem
- Mobile control via Kore app

Access:
- Web: `http://jukebox:8080`
- Fullscreen: Manual launch on jukebox machine
- Remote: Install Kore app (iOS/Android)

---

## Troubleshooting

### Services Not Running
```bash
# Check status
sudo systemctl status mopidy shairport-sync gmediarender scream-receiver

# Restart all
sudo systemctl restart mopidy shairport-sync gmediarender scream-receiver

# Check logs
sudo journalctl -u mopidy -n 50
```

### Web UI Not Accessible
```bash
# Test Mopidy directly
curl http://localhost:6680

# Test Nginx
sudo systemctl status nginx
sudo tail -20 /var/log/nginx/error.log
```

### No Audio Output
```bash
# Check audio devices
pactl list short sinks

# Check Mopidy logs for GStreamer errors
sudo journalctl -u mopidy -n 100 | grep -i "audio\|gstreamer\|pulse"
```

### AirPlay Not Discovered
```bash
# Verify Shairport Sync
sudo systemctl status shairport-sync

# Check Avahi
sudo systemctl status avahi-daemon
avahi-browse -a
```

### DLNA Not Found
```bash
# Verify gmediarender
sudo systemctl status gmediarender
ss -tlnp | grep gmediarender
```

---

## Advanced Configuration

### Change Default Audio Device
```bash
# List devices
pactl list short sinks

# Set default
pactl set-default-sink alsa_output.pci-0000_00_09.2.analog-stereo

# Make persistent (edit /etc/mopidy/mopidy.conf)
[audio]
output = pulsesink  # Can specify device here
```

### Kodi Fullscreen Display
Edit `~/.config/autostart/kodi.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=Kodi
Exec=kodi
Icon=kodi
# Change to empty to auto-launch:
AutostartCondition=
```

Then Kodi will launch fullscreen on login, showing album art + now-playing.

### Disable Services
```bash
# Disable AirPlay
sudo systemctl disable shairport-sync

# Disable DLNA
sudo systemctl disable gmediarender

# Disable Bluetooth
sudo systemctl disable bt-agent
```

### Enable Scream TCP Mode (Alternative to UDP)
Edit `/etc/systemd/system/scream-receiver.service`:
```ini
ExecStart=/usr/local/bin/scream-receiver -t -p 4010
```

Then: `sudo systemctl daemon-reload && sudo systemctl restart scream-receiver`

---

## Maintenance

### Update Packages
```bash
sudo apt-get update && sudo apt-get upgrade
```

### View All Logs
```bash
for svc in mopidy nginx shairport-sync gmediarender scream-receiver bluetooth bt-agent; do
  echo "=== $svc ==="
  sudo journalctl -u $svc -n 5 --no-pager
done
```

### Backup Configuration
```bash
sudo cp -r /etc/mopidy /etc/mopidy.backup
sudo cp -r ~/.config/kodi ~/.config/kodi.backup
```

### Factory Reset (Keep Audio, Reset Queue)
```bash
sudo systemctl stop mopidy
sudo rm -rf /var/cache/mopidy/*
sudo systemctl start mopidy
```

---

## Uninstall

```bash
sudo systemctl stop mopidy shairport-sync gmediarender scream-receiver
sudo systemctl disable mopidy shairport-sync gmediarender scream-receiver

sudo apt-get remove --purge mopidy shairport-sync kodi nginx avahi-daemon
sudo apt-get autoremove

sudo rm -rf /etc/mopidy /etc/nginx/sites-available/jukebox \
           /etc/systemd/system/gmediarender.service \
           /etc/systemd/system/scream-receiver.service \
           /etc/systemd/system/bt-agent.service \
           /etc/systemd/system/mopidy.service.d
```

---

## Performance

- **CPU:** All services run efficiently; Kodi is heavier if fullscreen
- **Memory:** ~200MB idle, ~500MB with Kodi fullscreen
- **Network:** Minimal bandwidth; no transcoding by default
- **Audio:** <10ms local latency, 50-100ms over network

---

## Architecture Notes

### Audio Pipeline
```
Source (web queue / AirPlay / Bluetooth / DLNA / etc.)
    ↓
GStreamer
    ↓
PipeWire (mixes all inputs)
    ↓
PulseAudio (compatibility layer)
    ↓
ALSA
    ↓
Speaker
```

### Why PipeWire?
- Natively mixes multiple audio sources
- No complex PulseAudio routing needed
- Supports all casting protocols out-of-the-box
- Modern, actively maintained

---

## Future Enhancements

Possible additions:
- Snapcast for multi-room audio
- Music visualization on display
- Playlist export/import
- Discord audio streaming
- MPRIS support for desktop integration
- Home automation integration (start playlist at specific time, etc.)

---

## Known Limitations

- **YouTube quality:** Limited to what yt-dlp can extract (usually 128kbps audio, sometimes higher)
- **SoundCloud/other sources:** APIs change frequently; functionality may break
- **Android system audio:** No universal system-wide audio casting (DLNA is app-specific)
- **Kodi:** Requires manual launch (not auto-starting by default for resource conservation)

---

## Support

**For non-technical users:** See [USER_GUIDE.md](USER_GUIDE.md)

**For setup issues:**
```bash
# Check all service status
sudo systemctl status mopidy nginx shairport-sync gmediarender scream-receiver

# Full debug logs
sudo journalctl -xe | tail -100
```

**For Mopidy-specific issues:**
```bash
GST_DEBUG=2 mopidyctl status
```

---

## What's Next?

- **Parties:** Create a signup sheet at `http://jukebox` and invite guests
- **Display:** Enable Kodi fullscreen to show album art
- **Remotes:** Install Kore app for advanced Kodi control
- **Automation:** Use Mopidy's JSON-RPC API for custom integrations

---

## License

[Add your license here]

---

**Created:** 2026  
**Last Updated:** May 19, 2026  
**Tested On:** Ubuntu 24.04 LTS, Lubuntu 24.04, Debian 12  
**Platforms:** Linux (x86_64, ARM), any system with modern Linux

---

**Questions?** Check [USER_GUIDE.md](USER_GUIDE.md) for guest usage or run `journalctl` for troubleshooting.
