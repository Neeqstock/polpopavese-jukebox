# Community Jukebox Project Plan

## Project Overview
Build a networked jukebox that allows people to queue songs via a web interface on their phones/laptops. Users can add songs from YouTube (and optionally Spotify). The jukebox plays queued songs through speakers attached to an old Linux machine (Zorin OS Lite).

---

## Architecture

### Components

**1. Frontend (Web Interface)**
- Simple, mobile-friendly web page
- Search bar to find songs on YouTube
- "Add to Queue" button
- Live queue display (what's playing, what's next)
- Skip button (optional: for admin only)
- Accessible via `http://jukebox-ip:5000` on local network

**2. Backend (Python Flask Server)**
- REST API endpoints:
  - `POST /api/search` - Search YouTube
  - `POST /api/queue` - Add song to queue
  - `GET /api/queue` - Get current queue
  - `GET /api/now_playing` - Get currently playing song
  - `POST /api/skip` - Skip to next song (optional)
- Queue management (FIFO)
- Audio playback control

**3. Playback Engine**
- Use `yt-dlp` to fetch audio from YouTube
- Use `mpv` or `ffplay` to play audio to system speakers
- Run playback in a separate thread/subprocess

**4. Hardware**
- Zorin OS Lite (already have)
- Speakers (already connected)
- WiFi network (so people can connect)

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Backend | Python 3 + Flask | Lightweight, easy to learn, runs great on old hardware |
| Playback | yt-dlp + mpv | Reliable YouTube extraction + audio playback |
| Frontend | HTML + CSS + vanilla JS | No build step, works on any browser |
| Queue | In-memory Python list | Simple for MVP; can add database later |

---

## Setup Steps

### Step 1: Install Dependencies on Zorin OS Lite

```bash
sudo apt update
sudo apt install -y python3 python3-pip mpv ffmpeg
pip3 install flask flask-cors yt-dlp
```

### Step 2: Create Project Structure

```
/home/user/jukebox/
├── app.py                 # Flask backend
├── templates/
│   └── index.html         # Web interface
├── static/
│   └── style.css          # Styling
└── queue.txt              # Optional: persist queue
```

### Step 3: Implement Backend (app.py)

**Core features:**
- Initialize Flask app with CORS enabled (so phones can connect)
- Queue data structure (Python list)
- Playback thread (plays songs in background)
- API endpoints (search, queue, now_playing, skip)
- Error handling (bad URLs, network issues, etc.)

**Search endpoint:**
- Accept search query from frontend
- Use `yt-dlp` to search YouTube
- Return list of results (title, duration, video ID)

**Queue endpoint:**
- Accept video ID
- Add to queue
- Return updated queue

**Playback:**
- Monitor queue
- When song ends, automatically play next
- Handle pause/skip requests

### Step 4: Implement Frontend (index.html + style.css)

**Layout:**
- Header: "Community Jukebox"
- Search bar + "Add to Queue" button
- "Now Playing" section (current song, time elapsed, progress bar)
- Queue list (next 10 songs, clickable to remove)
- Simple, mobile-responsive design
- Real-time updates (poll backend every 2 seconds for queue/now_playing)

**Interactions:**
- Type song name → autocomplete suggestions (search as you type)
- Click result → add to queue → instant feedback
- Queue updates in real-time
- Show who's playing next

### Step 5: Deploy & Run

**Start the server:**
```bash
python3 app.py
```

**Access from phone/laptop:**
Open browser → `http://<jukebox-ip>:5000`

**Find jukebox IP:**
```bash
hostname -I
```

---

## Implementation Details

### Backend Architecture (Pseudocode)

```python
from flask import Flask, request, jsonify
from yt_dlp import YoutubeDL
import subprocess
import threading
import time

app = Flask(__name__)
queue = []  # [{id, title, duration}, ...]
now_playing = None
playback_thread = None

@app.route('/api/search', methods=['POST'])
def search():
    query = request.json['query']
    # Use yt-dlp to search YouTube
    results = search_youtube(query)
    return jsonify(results)

@app.route('/api/queue', methods=['POST'])
def add_to_queue():
    video_id = request.json['video_id']
    title = request.json['title']
    queue.append({'id': video_id, 'title': title})
    return jsonify({'queue': queue})

@app.route('/api/queue', methods=['GET'])
def get_queue():
    return jsonify({'now_playing': now_playing, 'queue': queue})

def playback_worker():
    # Runs in background
    # Monitor queue, play songs one by one
    while True:
        if queue and not now_playing:
            song = queue.pop(0)
            play_song(song)
        time.sleep(0.5)

def play_song(song):
    # Use yt-dlp to get audio URL
    # Pipe to mpv
    # Block until song ends
    pass

if __name__ == '__main__':
    playback_thread = threading.Thread(target=playback_worker, daemon=True)
    playback_thread.start()
    app.run(host='0.0.0.0', port=5000)
```

### Frontend Logic (JavaScript)

```javascript
// Poll for queue/now_playing every 2 seconds
setInterval(() => {
    fetch('/api/queue')
        .then(r => r.json())
        .then(data => {
            updateNowPlaying(data.now_playing);
            updateQueueDisplay(data.queue);
        });
}, 2000);

// Search + Add to Queue
document.getElementById('search-btn').addEventListener('click', () => {
    const query = document.getElementById('search-input').value;
    fetch('/api/search', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({query})
    })
    .then(r => r.json())
    .then(results => displaySearchResults(results));
});

function addToQueue(videoId, title) {
    fetch('/api/queue', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({video_id: videoId, title})
    })
    .then(() => {
        document.getElementById('search-input').value = '';
        document.getElementById('search-results').innerHTML = '';
    });
}
```

---

## Phased Implementation

### Phase 1: MVP (Get It Working)
- ✅ Search YouTube
- ✅ Add to queue
- ✅ Play songs in order
- ✅ Basic web UI
- ✅ No admin controls (anyone can skip/remove)

**Estimated time: 2-3 hours with Claude Code**

### Phase 2: Polish (Nice to Have)
- Admin controls (password-protected skip/remove)
- Persistent queue (save to file, survive restarts)
- Now-playing progress bar
- Song duration display
- Better search (show thumbnails, duration)
- Remove from queue feature

### Phase 3: Advanced (Stretch Goals)
- Spotify integration (requires Premium + API key)
- Bluetooth audio passthrough
- Volume control
- Voting to skip (democratic jukebox)
- Stats/history (top played songs)

---

## Known Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| **YouTube extraction fails** | yt-dlp updates frequently; run `pip install --upgrade yt-dlp` monthly |
| **Slow on old hardware** | Keep queue small, use lightweight frontend, no fancy animations |
| **Network latency** | Poll every 2 seconds; real-time updates via WebSocket (Phase 2) |
| **Multiple people adding songs simultaneously** | Queue is thread-safe in Python; Flask handles concurrent requests |
| **Someone queues 100 songs** | Add queue limit (e.g., max 50 songs, or max 10 per person) |
| **Song unavailable (copyright strikes)** | Gracefully skip to next; log errors |
| **Speakers fail/disconnect** | Detect playback errors; retry or notify via web UI |

---

## Testing Checklist

- [ ] Search returns YouTube results
- [ ] Add song to queue works
- [ ] Now Playing updates
- [ ] Song actually plays through speakers
- [ ] Queue advances after song ends
- [ ] Multiple phones can connect simultaneously
- [ ] Mobile UI works on small screens
- [ ] No crashes after 1 hour of operation
- [ ] Graceful error handling (bad video ID, network down, etc.)

---

## Deployment Checklist

- [ ] All dependencies installed (`python3`, `flask`, `yt-dlp`, `mpv`)
- [ ] Backend runs without errors: `python3 app.py`
- [ ] Web UI accessible from phone on local network
- [ ] Speakers work: test with `speaker-test` command
- [ ] Set up auto-start (optional: systemd service or crontab)

### Auto-Start on Boot (Optional)

Create `/etc/systemd/system/jukebox.service`:
```ini
[Unit]
Description=Community Jukebox
After=network.target

[Service]
Type=simple
User=<your-username>
WorkingDirectory=/home/<your-username>/jukebox
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable jukebox
sudo systemctl start jukebox
```

---

## Next Steps

1. **Review this plan** with your team
2. **Use Claude Code** to implement `app.py` (backend)
3. **Use Claude Code** to implement `templates/index.html` + `static/style.css` (frontend)
4. **Test locally** on the Zorin box
5. **Iterate** based on feedback (Phase 2 enhancements)

---

## Questions to Answer Before Starting

1. **What's the Zorin box's IP on your network?** (You'll need this for access)
2. **Do you want Spotify support, or is YouTube enough?** (Spotify adds complexity)
3. **Should there be admin controls?** (Password to skip/clear queue?)
4. **Queue limit?** (Should one person be able to add infinite songs?)
5. **Music source?** (YouTube only, or also local files?)

---

## Resources

- **yt-dlp docs:** https://github.com/yt-dlp/yt-dlp
- **Flask docs:** https://flask.palletsprojects.com/
- **mpv docs:** https://mpv.io/
- **CSS responsive design:** https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design
