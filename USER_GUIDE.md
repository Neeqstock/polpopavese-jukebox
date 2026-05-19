# PolpoJukebox — User Guide for Non-Technical Users

**Everything you need to know to use the jukebox as a guest or owner.**

---

## What Is It?

A **wireless speaker system** that plays music from your phone, computer, or web browser. Anyone on your WiFi network can add songs to a shared playlist.

Think of it as a **friendly jukebox** — no coins, no setup, just connect and play.

---

## Quick Start (2 Minutes)

1. Make sure your phone is on the **same WiFi network** as the jukebox
2. Open a web browser and go to: `http://jukebox` (or `http://jukebox.local` if that doesn't work)
3. You should see a music player interface
4. Search for a song and click the play button
5. **Audio plays through the jukebox speaker**

---

## Ways to Use the Jukebox

### Method 1: Web Browser (Works on Any Device)

**Easiest for non-phone users or people with laptops.**

1. On your phone, tablet, or laptop, open any web browser
2. Type: `http://jukebox` or `http://jukebox.local`
3. You'll see a search box
4. Type the name of a song, artist, or video
5. Click on a result — it plays immediately
6. **Control the volume** with the volume slider on the page
7. **Queue songs** by clicking "Add to Queue"

**Works on:**
- ✓ iPhone (Safari browser)
- ✓ Android (Chrome browser)
- ✓ Windows (any browser)
- ✓ macOS (any browser)
- ✓ Tablets (any browser)

---

### Method 2: iPhone, iPad, or Mac (AirPlay)

**Ideal for Apple users — works even if you're not on the same WiFi.**

#### Play Music App

1. Open your Music app (Apple Music, Spotify, YouTube Music, etc.)
2. Start playing a song
3. Look for the **AirPlay icon** (looks like a speaker with WiFi waves)
4. Tap it
5. Select **"jukebox AirPlay"**
6. Your music now plays through the jukebox speaker
7. To stop: tap the AirPlay icon again and select "iPhone"

#### From Your Phone Directly

1. **Swipe down** from the top-right corner (iPhone) or top-left (iPad) to open Control Center
2. **Long-press** the music/volume widget (hold down, don't just tap)
3. Look for **AirPlay** button
4. Tap it and select **"jukebox AirPlay"**
5. Now **any sound** on your phone plays through the jukebox (calls, videos, games, everything)

**What You Can Play:**
- Spotify
- Apple Music
- YouTube
- Netflix
- Podcasts
- Anything with audio

---

### Method 3: Android Phone (Bluetooth)

**Works wirelessly from up to 30 feet away.**

#### Step 1: Pair Once
1. On your **Android phone**, open Settings
2. Go to **Bluetooth**
3. Look for a device called **"jukebox"** (or similar)
4. Tap it
5. Your phone will ask to pair — **tap "Pair"**
6. Done! (You only do this once)

#### Step 2: Connect & Play
1. Open your music app (Spotify, YouTube, etc.)
2. Start playing a song
3. Open **Settings → Sound & Vibration → Volume → Media volume** and scroll down
4. Look for an **audio output selector** (or just play music, it might auto-connect)
5. Select **"jukebox"** as the output device
6. Music now plays through the jukebox

**If you can't find the selector:**
- Just play music — if the jukebox is paired and on, it might auto-connect
- Try opening Bluetooth settings and tapping the jukebox again

---

### Method 4: Android Phone (App Casting — YouTube, Spotify)

**For apps that have a "Cast" button.**

This works if the app supports casting (YouTube, Spotify, YouTube Music, etc.):

1. Open your music app (YouTube, Spotify, etc.)
2. Find a **Cast button** (usually a speaker icon with WiFi waves in the corner)
3. Tap it
4. Select **"jukebox DLNA"** or just **"jukebox"**
5. The app will now play through the jukebox speaker
6. You can still control playback from your phone

**Which apps support this?**
- ✓ YouTube
- ✓ Spotify
- ✓ YouTube Music
- ✓ Many others with a "Cast" button

---

### Method 5: Windows PC (System Audio)

**Stream ANY audio from your Windows computer to the jukebox.**

#### One-Time Setup
1. Download **Scream** audio driver from: https://github.com/duncanthrax/scream/releases
2. Find the file ending in `.exe` or `.msi` — download it
3. Run the installer
4. **Reboot your computer** (required for the driver to work)

#### Using It
After reboot:
1. Open your **Volume settings** (click speaker icon in taskbar)
2. Look for **"Scream"** in the device list
3. Click it to set as default
4. Now any audio on your PC plays through the jukebox speaker

**Works with:**
- Music apps (Spotify, YouTube, VLC)
- Web browsers (Netflix, YouTube, etc.)
- Games
- Videos
- Everything on your PC

---

### Method 6: Linux PC (PulseAudio — Advanced)

**For Linux users who want to stream audio over WiFi.**

```bash
export PULSE_SERVER=tcp:jukebox:4713
# Now run any audio app normally
spotify  # or youtube-dl, vlc, anything
unset PULSE_SERVER  # When you're done
```

**Streaming your microphone:**
```bash
parec --device=@DEFAULT_SOURCE@ | \
  PULSE_SERVER=tcp:jukebox:4713 paplay --raw --rate=44100 --channels=2 --format=s16le
```

---

### Method 7: Kodi (Advanced Media Center)

**For power users who want a full jukebox experience.**

#### Via Android (NewPipe)
If you use the **NewPipe** app on Android:
1. Find a YouTube video you want to play
2. Tap the **share** button (arrow)
3. Select **"Play with Kodi"**
4. It will prompt for the jukebox IP (use `jukebox` or `jukebox.local`)
5. The video plays through Kodi on the jukebox

#### Via Web Browser
1. On any computer, open: `http://jukebox:8080`
2. You'll see the Kodi web interface
3. Search for music or video and start playback
4. Audio/video plays on the jukebox

---

## Shared Playlist (Queue)

When multiple people use the web browser interface, **everyone sees the same queue**.

### Adding Songs
1. Search for a song
2. Click **"Add to Queue"** (or just press play)
3. The song is added to the end of the playlist

### Controlling the Queue
- **Skip forward:** Click the next/skip button
- **Go back:** Click the previous button
- **Remove a song:** Hover over it in the queue and click the X
- **Pause:** Click the pause button
- **Change volume:** Use the volume slider

### How It Works
When you add a song, it gets added to a **shared playlist**. Everyone in the room can see what's queued and what's currently playing.

---

## Finding the Jukebox

### If "http://jukebox" Doesn't Work

Try one of these:

1. **"http://jukebox.local"** — Works on most networks
2. **Ask the owner** — They can give you the IP address, e.g., "192.168.1.50"
3. **Look at your WiFi devices** — On your phone's network settings, you might see it listed

### On Different Networks

- If you're on a **different WiFi network** than the jukebox, you won't be able to reach it
- You need to be on the **same WiFi network** (or the owner needs to set up remote access — ask them!)

---

## Troubleshooting

### "I can't find the jukebox"
- ✓ Make sure you're on the **same WiFi network**
- ✓ Try `http://jukebox.local` instead of `http://jukebox`
- ✓ Ask the owner for the IP address
- ✓ Make sure the jukebox machine is turned on

### "No sound is coming out"
- ✓ Check the **volume** on both your phone AND the jukebox machine itself
- ✓ Try unplugging speakers and plugging them back in
- ✓ Try a different audio output method (Bluetooth instead of AirPlay, etc.)
- ✓ Make sure nothing else is playing on the jukebox

### "The web page won't load"
- ✓ Refresh the page (press F5 or swipe down)
- ✓ Try `http://jukebox.local` instead of `http://jukebox`
- ✓ Make sure you're connected to WiFi

### "AirPlay isn't appearing"
- ✓ Make sure your iPhone/Mac and the jukebox are on the **same WiFi**
- ✓ Try turning AirPlay off and on again (kill and restart the Music app)
- ✓ Restart your iPhone/Mac

### "Bluetooth won't connect"
- ✓ Make sure Bluetooth is turned on
- ✓ Forget the device and pair again (Settings → Bluetooth → forget "jukebox")
- ✓ Make sure the jukebox is in Bluetooth discoverable mode (ask owner)

### "Scream doesn't work"
- ✓ Did you **reboot Windows** after installing? (Required!)
- ✓ Is Scream set as the default audio device?
- ✓ Try unplugging USB audio devices and using the built-in audio jack

---

## Tips & Tricks

### Keep the Web Page Open
Leave the browser tab open on your laptop — it looks nice and shows now-playing info!

### Cast Full Concert Videos
Search for "artist name + live concert" on YouTube, then cast it to the jukebox to watch + listen.

### Multiple People Adding Songs
Everyone can search and queue songs at the same time. The queue will keep growing!

### Playing From Your PC
Don't want to install Scream? Just open the browser interface on your PC and use that instead.

### AirPlay + Web Browser
You can play from both your iPhone (AirPlay) and the web browser at the same time. Both will come through the speaker.

---

## What To Play

### Search By
- **Song name:** "Bohemian Rhapsody"
- **Artist:** "The Beatles"
- **Album:** "Abbey Road"
- **Mood:** "relaxing music", "workout songs", "sleep music"
- **YouTube keywords:** "lo-fi hip hop", "jazz vinyl"

### YouTube Limitations
- Most songs on YouTube are **user-uploaded**, so quality varies
- Some artist channels have **official uploads** (usually better quality)
- Live recordings are often available
- Covers and remixes are mixed in with originals

---

## Etiquette

### At a Party
- Add songs you like, but don't skip everyone else's music immediately
- Let each song play through unless it's really bad
- If the host wants to change the music, respect that

### Shared Spaces
- Ask others before changing the volume significantly
- Don't queue a huge list of 50 songs — give others a turn
- If someone queued something, let it play (they chose it for a reason!)

---

## For the Owner/Admin

### Starting/Stopping
- The jukebox **auto-starts on boot**
- To restart services: `sudo systemctl restart mopidy nginx shairport-sync`
- To shut down: Normal shutdown procedure

### Logs
If something breaks, check the logs:
```bash
sudo journalctl -u mopidy -n 20
```

### Changing Settings
Edit `/etc/mopidy/mopidy.conf` to enable Spotify, change output device, etc.

### Guests Can't Reach It?
Make sure port 80 is open on your firewall, and that all services are running.

---

## Questions?

**Most common issue:** Can't reach the jukebox. Make sure you're on the same WiFi network!

**For technical issues:** Ask the owner or check the main README.md for setup details.

---

**Enjoy the music! 🎵**
