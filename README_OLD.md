# PolpoJukebox — Clean Single-Room Setup

A **Democratic WiFi Jukebox** running on Debian 12. Anyone on your local network can open a web page and queue music — no app or static IP required.

## Quick Start

**On a fresh Debian 12 machine:**

```bash
sudo bash jukebox-setup.sh
```

The script will ask for:
- Hostname (e.g., `jukebox`)
- Audio output device (optional; auto-detected)
- Spotify credentials (optional)
- SoundCloud token (optional)

Then:
1. Set a **static IP on your router** (DHCP reservation for the machine's MAC address)
2. Guests visit `http://jukebox` to queue music
3. iOS/macOS users: select `jukebox AirPlay` from their AirPlay menu
4. Android users: open a DLNA app and find `jukebox DLNA`

---

## How It Works

### For Guests

| Device | Method | Access |
|--------|--------|--------|
| Phone/Laptop (any OS) | Browser QR code | `http://jukebox` |
| iPhone/iPad/Mac | AirPlay | Appears as `jukebox AirPlay` |
| Android + DLNA app | DLNA receiver | Appears as `jukebox DLNA` |

### Hostname Resolution

The machine announces its hostname (`jukebox`) on the network via:
1. **Router DHCP DNS** — Most modern home routers register the hostname automatically
2. **Avahi (mDNS)** — Falls back to `jukebox.local` for iOS/macOS/Windows if router doesn't help
3. **Fixed IP** — Set via DHCP reservation on your router, so `http://jukebox` resolves to the same IP forever

**No Bitly, no dnsmasq, no dynamic IP tracking needed.**

---

## Architecture

```
Phone/Laptop (any OS)
    ↓ (HTTP port 80)
  nginx (reverse proxy)
    ↓ (HTTP port 6680)
  Mopidy (music server)
    ├─→ YouTube / YTMusic / Bandcamp / SoundCloud / Spotify / Local files
    └─→ /tmp/snapfifo → PipeWire → Audio output
    
iPhone/iPad/Mac
    ↓ (AirPlay protocol)
  Shairport Sync
    ↓ 
  PipeWire (mixes Mopidy + AirPlay audio)
    ↓
  System speakers

Android (with DLNA app)
    ↓ (DLNA/UPnP protocol)
  gmrender-resurrect (DLNA receiver)
    ↓
  PipeWire
    ↓
  System speakers
```

### Services

All services start automatically on boot (systemd).

| Service | Role |
|---------|------|
| `mopidy` | Music server — queue, search, playback |
| `nginx` | HTTP reverse proxy on port 80 |
| `shairport-sync` | AirPlay receiver |
| `gmrender-resurrect` | DLNA/UPnP receiver |
| `avahi-daemon` | mDNS for `.local` hostname |

Check all:
```bash
systemctl status mopidy nginx shairport-sync gmrender-resurrect avahi-daemon
```

---

## Music Sources

| Source | Setup | Notes |
|--------|-------|-------|
| **YouTube / YTMusic** | Built-in | No auth needed |
| **Local files** | Built-in | Add MP3s to `~/Music/` |
| **SoundCloud** | Optional | Requires API token |
| **Spotify** | Optional | Requires Premium + Client ID/Secret |

### Adding Spotify

If you have a Spotify Premium account:

1. Create a Spotify Developer application at https://developer.spotify.com/dashboard
2. Get your Client ID and Client Secret
3. Re-run setup with your credentials when prompted

### Adding SoundCloud

1. Get an auth token (search "SoundCloud API token")
2. Pass it when prompted during setup

### Local Music Library

Place MP3 files in `~/Music/`. They'll be scanned on boot and available to queue.

---

## Web Interfaces

### Muse (Default)

Clean, minimal, modern interface. Opens by default at `http://jukebox`.

- Search and queue songs
- View upcoming queue
- Simple, fast

### Iris (Full-Featured)

More options. Visit `http://jukebox/iris/` if you want deeper controls (playlists, settings, etc.).

---

## AirPlay (iOS/macOS)

Any iPhone, iPad, or Mac on the network can stream to the jukebox.

1. Open Control Center (iOS) or AirPlay menu (macOS)
2. Look for `jukebox AirPlay`
3. Select it — audio will play through the jukebox speakers

The jukebox **mixes** AirPlay audio with queued music (both play simultaneously if needed).

---

## DLNA/UPnP (Android & Others)

Android devices and many smart devices can use DLNA to send audio to the jukebox.

1. Install a DLNA/UPnP app (e.g., BubbleUPnP, Kodi, etc.)
2. Scan for devices — you'll see `jukebox DLNA`
3. Select it and play audio

Like AirPlay, the jukebox mixes DLNA audio with the web queue.

---

## Audio Stack

The jukebox uses **PipeWire** (modern Linux audio system) which natively mixes multiple sources:
- Web queue playback (Mopidy)
- AirPlay stream (Shairport Sync)
- DLNA stream (gmrender-resurrect)

All play together without complex configuration.

---

## Network Setup (Important)

### Option 1: Router DHCP Reservation (Recommended)

Most home routers let you bind a fixed IP to a MAC address. This is the cleanest approach:

1. Find the jukebox's MAC address:
   ```bash
   ip link show | grep ether
   ```
2. Log into your router (e.g., `192.168.1.1` for Fritz!Box)
3. Find the DHCP reservation section (varies by router brand)
4. Bind the jukebox's MAC to a fixed IP (e.g., `192.168.1.100`)
5. Reboot the jukebox

Result: `http://jukebox` will always resolve to that IP.

### Option 2: Avahi (mDNS) Fallback

If your router doesn't support hostname DNS, the jukebox still works via:
- `http://jukebox.local` (works on iOS, macOS, Windows, modern Android)

This is automatic and requires no setup.

---

## Troubleshooting

### "http://jukebox not found" on Android phone

**Root cause:** Android's browser sometimes doesn't resolve the router-advertised hostname.

**Solutions:**
- Use `http://jukebox.local` instead (if avahi is working)
- Ask your router admin for the machine's IP and use that directly
- Use a DLNA app instead

### No music playing after queuing

Check Mopidy status:
```bash
systemctl status mopidy
systemctl restart mopidy
```

Check PipeWire audio levels:
```bash
pactl list short sinks
pactl set-sink-volume @DEFAULT_SINK@ 100%
```

### AirPlay not showing up on iPhone

1. Confirm the iPhone is on the same WiFi network
2. Check Shairport Sync is running:
   ```bash
   systemctl status shairport-sync
   systemctl restart shairport-sync
   ```
3. Look in iPhone Settings → AirPlay & Bluetooth or Control Center

### DLNA not showing on Android

Check gmrender-resurrect:
```bash
systemctl status gmrender-resurrect
systemctl restart gmrender-resurrect
```

If still not showing, try a different DLNA app (BubbleUPnP is most reliable).

---

## File Locations

| Path | Purpose |
|------|---------|
| `/etc/mopidy/mopidy.conf` | Mopidy configuration |
| `/etc/shairport-sync.conf` | AirPlay settings |
| `/etc/default/gmrender-resurrect` | DLNA device name |
| `/etc/nginx/sites-available/jukebox` | Web proxy config |
| `~/Music/` | Local music library |
| `~/jukebox-qr.png` | QR code image |

---

## System Requirements

- **OS:** Debian 12 Bookworm (tested)
- **Hardware:** x86_64 or ARM (any machine with audio output)
- **Network:** WiFi or Ethernet connected to your local network
- **Audio:** Any audio output (headphone jack, HDMI, USB, etc.)

---

## What Changed from the Old Setup

The previous setup used:
- ❌ Bitly short links (external dependency, broke easily)
- ❌ `update_jukebox.py` (tracked IP changes constantly)
- ❌ dnsmasq (redundant with modern router DHCP-DNS)
- ❌ Snapcast (only needed for multi-room; dropped for simplicity)

The new setup:
- ✅ DHCP reservation on router (permanent)
- ✅ Avahi mDNS fallback (works on all modern OSes)
- ✅ PipeWire audio (native mixing, no complex plumbing)
- ✅ Single machine, single room (simpler)
- ✅ Static QR code

---

## License

This is a personal project. Do what you want with it.
