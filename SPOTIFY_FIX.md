# Spotify Playback Fix — Mopidy 4.x + Mopidy-Spotify 5.x on Ubuntu 24.04

## Symptoms

- Spotify **search works** (Iris UI returns results, playlists load)
- Spotify **playback does not work** (tracks silently fail or show "not playable")
- `core.playback.get_state` returns `"stopped"` immediately after calling `play`

## Root Causes (in order of discovery)

### 1. Missing GStreamer Spotify plugin

Mopidy-Spotify 5.x uses a **Rust-based GStreamer plugin** (`libgstspotify.so`) to handle
`spotify://` URIs. Without it, GStreamer has no URI handler for Spotify and playback fails
silently or with:

```
GStreamer error: No URI handler implemented for 'spotify'
WARNING mopidy.core.tracklist Track is not playable: spotify:track:...
```

This plugin is **not in the Ubuntu apt repositories**. It must be installed manually from
the Mopidy project's pre-built releases:

```
https://github.com/mopidy/gst-plugins-rs-build/releases
```

The correct version for Mopidy-Spotify 5.x is **`0.15.0-alpha.1`** (not `0.14.0`, which
is missing the `spotifyaudiosrc` element).

**Install:**
```bash
wget https://github.com/mopidy/gst-plugins-rs-build/releases/download/v0.15.0-alpha.1/gst-plugin-spotify_0.15.0-alpha.1_amd64.deb -O /tmp/gst-plugin-spotify.deb
sudo apt-get install /tmp/gst-plugin-spotify.deb
```

**Verify:**
```bash
gst-inspect-1.0 spotify
# Should list: spotifyaudiosrc, spotifylyricssrc
```

---

### 2. Wrong audio sink (`pulsesink` → `alsasink`)

With the default `pulsesink`, Mopidy running as a system service (user `mopidy`) cannot
reach the login user's PulseAudio/PipeWire socket:

```
GStreamer error: Failed to connect: Connection refused
```

**Fix in `/etc/mopidy/mopidy.conf`:**
```ini
[audio]
output = alsasink
```

`alsasink` writes directly to ALSA with no daemon dependency, which is reliable for a
dedicated jukebox where only one process plays audio at a time.

---

### 3. Mopidy service running as system `mopidy` user (not login user)

The default `mopidy.service` runs as the system user `mopidy` (uid 123). After reboot,
the systemd drop-in that overrides this was missing, so mopidy ran as `mopidy` again.

Running as `mopidy` causes two problems:
- Cannot read `/etc/mopidy/mopidy.conf` → Spotify credentials missing → extension disabled
- Cannot access `~/Music` or user-owned directories

**Fix — create `/etc/systemd/system/mopidy.service.d/user.conf`:**
```ini
[Unit]
After=user@1000.service sound.target

[Service]
User=YOUR_LOGIN_USER
Group=YOUR_LOGIN_USER
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native
Restart=on-failure
RestartSec=5
```

Replace `1000` with the actual UID (`id -u YOUR_LOGIN_USER`) and `YOUR_LOGIN_USER` with
the actual username.

Also enable linger so the user session exists at boot even without a graphical login:
```bash
sudo loginctl enable-linger YOUR_LOGIN_USER
```

---

### 4. Config file unreadable by the login user

Even after running mopidy as the login user, `/etc/mopidy/mopidy.conf` was owned by
system user `mopidy` with mode `640` and group `root`. The login user is not in `root`
group and cannot read it — so Spotify (and SoundCloud) credentials are silently dropped.

**Fix:**
```bash
sudo chown YOUR_LOGIN_USER:YOUR_LOGIN_USER /etc/mopidy/mopidy.conf
sudo chmod 600 /etc/mopidy/mopidy.conf
```

---

## Checklist for a fresh install

1. Install `gst-plugin-spotify` v0.15.0-alpha.1 from the Mopidy GitHub releases
2. Set `output = alsasink` in `/etc/mopidy/mopidy.conf`
3. Create the systemd drop-in to run mopidy as the login user
4. Run `loginctl enable-linger <user>` so the user session exists at boot
5. Set ownership of `/etc/mopidy/mopidy.conf` to the login user
6. `sudo systemctl daemon-reload && sudo systemctl enable mopidy && sudo systemctl restart mopidy`

## Verification

```bash
# Plugin present
gst-inspect-1.0 spotify | grep -c "Factory\|Element"

# Mopidy running as correct user
ps aux | grep mopidy | grep -v grep

# Spotify loaded and authenticated
journalctl -u mopidy | grep -E "Spotify|spotify"
# Should show: "Logged into Spotify Web API as ..."

# Playback test (Mr. Brightside)
curl -s -X POST http://localhost:6680/mopidy/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"core.tracklist.clear"}'

curl -s -X POST http://localhost:6680/mopidy/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"core.tracklist.add","params":{"uris":["spotify:track:3n3Ppam7vgaVa1iaRUc9Lp"]}}'

curl -s -X POST http://localhost:6680/mopidy/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"core.playback.play"}'

sleep 3

curl -s -X POST http://localhost:6680/mopidy/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":4,"method":"core.playback.get_state"}'
# Expected: {"result": "playing", ...}
```
