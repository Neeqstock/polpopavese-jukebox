# PolpoJukebox Handoff Status — May 20, 2026

## 🚀 Summary
The Jukebox has been successfully repaired and upgraded to support **Modern Spotify** on Ubuntu 24.04 (Noble) / Zorin OS 18. The "Dependency Hell" regarding `pyspotify` has been resolved by transitioning to Mopidy 4.0 and the Rust-based Spotify extension.

---

## ✅ What's Working
- **Mopidy 4.0.0a4 (Alpha):** The core music server is running.
- **Iris Web UI (Patched):** Accessible at `http://localhost:6680/iris/`.
    - *Surgical Patch Applied:* `/usr/local/lib/python3.12/dist-packages/mopidy_iris/core.py` was patched to replace the removed `mopidy.models.serialize` module with a Pydantic-compatible `ModelJSONEncoder`.
- **Integrated Spotify:** Browsing and searching Spotify inside Iris is **ONLINE** and authorized.
- **Spotify Connect (Raspotify):** Background service is running. Devices can cast directly from the Spotify App.
- **YouTube:** Integrated and working.
- **Bluetooth Audio:** Active and discoverable as `jukebox`.
- **DLNA/UPnP:** Active and visible as `jukebox DLNA`.
- **Discovery:** `avahi-daemon` is running; reachable via `http://jukebox.local`.

---

## ⚠️ Unresolved / Skipped
- **AirPlay (Shairport-Sync):** Service is `failed`. User indicated they do not require this.
- **Scream (Windows Audio):** Installation was attempted but the systemd service file or binary might be missing/misprioritized.
- **Nginx Proxy:** Nginx is active, but there was a conflict with the `jukebox` site config. Currently, Iris is best accessed via port **6680**.
- **Python Environment:** Multiple system-level Python packages were installed via `pip --break-system-packages` to resolve conflicts between Mopidy 4.x and Ubuntu 24.04's default libraries.

---

## 🛠 Technical Details
- **Mopidy Version:** `4.0.0a4` (Installed via `pip`).
- **Mopidy-Spotify:** `5.0.0a4` (Rust-based GStreamer backend).
- **Patch Details:**
    ```python
    # Applied to mopidy_iris/core.py
    class ModelJSONEncoder(json.JSONEncoder):
        def default(self, obj):
            if hasattr(obj, "model_dump_json"):
                return json.loads(obj.model_dump_json())
            return super().default(obj)
    ```
- **Configuration:** Stored in `/etc/mopidy/mopidy.conf`. Contains active Spotify Client ID/Secret.

---

## 📝 Next Steps for the New Agent
1.  **Refine Nginx:** Map port 80 correctly to `http://127.0.0.1:6680` if port 80 is desired as the primary entry point.
2.  **Fix Scream:** Re-run the Scream build/install process if Windows audio streaming is required.
3.  **Local Media:** The `local/media_dir` is currently set to `/home/polpopavese/Music`. Ensure permissions allow the `mopidy` user (or the user running the service) to read it.
4.  **AirPlay:** If the user changes their mind, `shairport-sync` logs suggest it is failing to bind to the audio device or port.

---
*Handed over by Gemini CLI (Agent 1)*
