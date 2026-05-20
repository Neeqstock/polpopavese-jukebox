import os
import re
import subprocess
import threading
import time
import uuid
import logging
from pathlib import Path

# ─── Load .env if present (keeps secrets out of systemd unit / shell history) ─
_env_file = Path(__file__).parent / ".env"
if _env_file.exists():
    for _line in _env_file.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _k, _v = _line.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from yt_dlp import YoutubeDL

# ─── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# ─── Constants ───────────────────────────────────────────────────────────────
YOUTUBE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
SPOTIFY_ID_RE  = re.compile(r"^[A-Za-z0-9]{22}$")
MAX_QUEUE_SIZE = 50
MAX_SEARCH_RESULTS = 5
MAX_QUERY_LEN = 200

# ─── Shared state ─────────────────────────────────────────────────────────────
_lock = threading.Lock()
_queue: list = []       # [{id, video_id, title, duration}, ...]
_now_playing = None     # same dict shape, or None
_proc = None            # current mpv subprocess, or None

# ─── Spotify helpers ────────────────────────────────────────────────────────

def _spotify_client():
    """Return an authenticated spotipy client, or None if not configured."""
    cid    = os.environ.get("SPOTIFY_CLIENT_ID", "").strip()
    secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "").strip()
    if not cid or not secret:
        return None
    try:
        import spotipy
        from spotipy.oauth2 import SpotifyClientCredentials
        return spotipy.Spotify(
            auth_manager=SpotifyClientCredentials(
                client_id=cid,
                client_secret=secret,
            )
        )
    except ImportError:
        log.warning("spotipy not installed; Spotify search unavailable")
        return None


def spotify_search(query: str) -> list:
    sp = _spotify_client()
    if sp is None:
        raise RuntimeError("Spotify not configured")
    results = sp.search(q=query, type="track", limit=MAX_SEARCH_RESULTS)
    tracks = (results or {}).get("tracks", {}).get("items", [])
    out = []
    for t in tracks:
        artists = ", ".join(a["name"] for a in t.get("artists", []))
        images  = (t.get("album") or {}).get("images") or []
        # pick the smallest thumbnail (last entry) if available
        image_url = images[-1].get("url", "") if images else ""
        out.append({
            "spotify_id": t["id"],
            "title":      f"{artists} — {t['name']}",
            "duration":   (t.get("duration_ms") or 0) // 1000,
            "image":      image_url,
        })
    return out


# ─── YouTube helpers ──────────────────────────────────────────────────────────

def yt_search(query: str) -> list:
    opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(
            f"ytsearch{MAX_SEARCH_RESULTS}:{query}", download=False
        )
        if not info or "entries" not in info:
            return []
        results = []
        for entry in info["entries"]:
            if not entry:
                continue
            results.append({
                "video_id": entry.get("id", ""),
                "title": entry.get("title", "Unknown"),
                "duration": entry.get("duration") or 0,
            })
        return results


def yt_search_first(query: str) -> str | None:
    """Return the YouTube video_id of the top result for a search query."""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(f"ytsearch1:{query}", download=False)
        entries = (info or {}).get("entries") or []
        if entries and entries[0]:
            return entries[0].get("id")
    return None


def yt_audio_url(video_id: str) -> str:
    """Resolve a YouTube video ID to a direct audio stream URL."""
    url = f"https://www.youtube.com/watch?v={video_id}"
    opts = {
        "quiet": True,
        "no_warnings": True,
        "format": "bestaudio/best",
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        # Flat dict — has a top-level 'url'
        if info.get("url"):
            return info["url"]
        # Format list — pick the first with a URL
        for fmt in reversed(info.get("formats", [])):
            if fmt.get("url"):
                return fmt["url"]
    raise RuntimeError(f"No audio URL found for video_id={video_id}")


# ─── Playback worker ──────────────────────────────────────────────────────────

def _playback_worker() -> None:
    global _now_playing, _proc

    while True:
        song = None
        with _lock:
            if _queue and _now_playing is None:
                song = _queue.pop(0)
                _now_playing = song

        if song is None:
            time.sleep(0.5)
            continue

        log.info("Playing: %s", song["title"])
        try:
            audio_url = yt_audio_url(song["video_id"])
            proc = subprocess.Popen(
                ["mpv", "--no-video", "--quiet", audio_url],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            with _lock:
                _proc = proc
            proc.wait()
            log.info("Finished: %s", song["title"])
        except Exception:
            log.exception("Playback error for '%s'", song.get("title"))
        finally:
            with _lock:
                _now_playing = None
                _proc = None


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/search", methods=["POST"])
def search():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON body"}), 400

    query = str(data.get("query", "")).strip()
    if not query:
        return jsonify({"error": "Empty query"}), 400
    if len(query) > MAX_QUERY_LEN:
        return jsonify({"error": "Query too long"}), 400

    try:
        results = yt_search(query)
        return jsonify(results)
    except Exception:
        log.exception("Search error")
        return jsonify({"error": "Search failed"}), 500


@app.route("/api/queue", methods=["GET"])
def get_queue():
    with _lock:
        return jsonify({
            "now_playing": _now_playing,
            "queue": list(_queue),
        })


@app.route("/api/spotify/status", methods=["GET"])
def spotify_status():
    enabled = _spotify_client() is not None
    return jsonify({"enabled": enabled})


@app.route("/api/spotify/search", methods=["POST"])
def spotify_search_endpoint():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON body"}), 400
    query = str(data.get("query", "")).strip()
    if not query:
        return jsonify({"error": "Empty query"}), 400
    if len(query) > MAX_QUERY_LEN:
        return jsonify({"error": "Query too long"}), 400
    try:
        return jsonify(spotify_search(query))
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 503
    except Exception:
        log.exception("Spotify search error")
        return jsonify({"error": "Spotify search failed"}), 500


@app.route("/api/queue", methods=["POST"])
def add_to_queue():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON body"}), 400

    source = str(data.get("source", "youtube"))

    if source == "spotify":
        spotify_id = str(data.get("spotify_id", "")).strip()
        if not SPOTIFY_ID_RE.match(spotify_id):
            return jsonify({"error": "Invalid Spotify ID"}), 400
        title    = str(data.get("title", "Unknown"))[:200].strip() or "Unknown"
        duration = int(data.get("duration") or 0)
        # Resolve to a YouTube video for playback
        video_id = yt_search_first(title)
        if not video_id:
            return jsonify({"error": "Could not find this track on YouTube"}), 502
    else:
        video_id = str(data.get("video_id", "")).strip()
        if not YOUTUBE_ID_RE.match(video_id):
            return jsonify({"error": "Invalid video ID"}), 400
        title    = str(data.get("title", "Unknown"))[:200].strip() or "Unknown"
        duration = int(data.get("duration") or 0)

    song = {
        "id": str(uuid.uuid4()),
        "video_id": video_id,
        "title": title,
        "duration": duration,
    }

    with _lock:
        if len(_queue) >= MAX_QUEUE_SIZE:
            return jsonify({"error": "Queue is full (max 50 songs)"}), 429
        _queue.append(song)
        queue_snapshot = list(_queue)

    return jsonify({"queue": queue_snapshot})


@app.route("/api/skip", methods=["POST"])
def skip():
    with _lock:
        proc = _proc
    if proc:
        proc.terminate()
        return jsonify({"status": "skipping"})
    return jsonify({"status": "nothing playing"})


# ─── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    worker = threading.Thread(target=_playback_worker, daemon=True)
    worker.start()

    port = int(os.environ.get("PORT", 5000))
    log.info("PolpoJukebox starting on http://0.0.0.0:%d", port)
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
