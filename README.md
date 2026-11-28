# ps5-capture

Play a console (PS5, Switch, Xbox…) on your Linux PC through a USB capture card, with the
lowest latency `mpv` can do, capture-card audio, an optional FPS overlay, and optional
[lsfg-vk](https://github.com/PancakeTAS/lsfg-vk) frame generation (Lossless Scaling on Linux).

Three small fish functions. Tested on CachyOS (KDE Plasma, Wayland) with a UGREEN 15389
capture card, a PS5 at 1080p, and a hybrid Intel + RTX 4080 laptop.

## Commands

| Command | What it does |
|---|---|
| `ps5` | Capture card fullscreen, lowest latency, audio on. **Use this to play.** |
| `ps5 --hud` / `ps5-hud` | Same, with a MangoHud FPS/frametime overlay |
| `ps5-fg` | Frame generation with lsfg-vk for 30 fps games, evenly paced: picks 30 × N = your refresh rate (2× at 60 Hz, 8× at 240 Hz). Very smooth, ~30 ms more lag than `ps5` |
| `ps5-fg --hud` | Frame gen with an overlay that shows the real (generated) FPS |
| `ps5 --untimed=no` | Perfectly even frame pacing, for up to one extra frame of lag |
| `ps5 --discord` | Also creates a `ps5-mic` virtual mic (your mic + game audio) for Discord |

Any other arguments are passed to `mpv` (e.g. `ps5 --no-fs`). Press `q` to quit.

## Requirements

- fish, `mpv`, `v4l-utils`, PipeWire (`pw-loopback`, `pactl`)
- A capture card that does **MJPEG** at your resolution (YUYV is usually too slow at 1080p)
- Optional: `mangohud` for `--hud`
- Optional: `lsfg-vk` 2.x and Lossless Scaling (Steam) for `ps5-fg`, plus `jq` and KDE's `kscreen-doctor` to read your refresh rate (without them it uses 2×). See below.

On Arch/CachyOS: `sudo pacman -S mpv v4l-utils mangohud lsfg-vk`

## Install

```fish
git clone https://github.com/junaydirfan/ps5-capture ~/ps5-capture
ln -s ~/ps5-capture/functions/*.fish ~/.config/fish/functions/
```

## Configure

Set these once as universal variables. Only `PS5_CARD` is required.

```fish
# Part of your capture card's name, as shown by `ls /dev/v4l/by-id/`
set -Ux PS5_CARD UGREEN_15389

# Optional: capture mode (defaults 1920x1080 and 60; many cards only do 30 at 1440p). Check yours with:
#   v4l2-ctl -d /dev/v4l/by-id/<your card>-video-index0 --list-formats-ext
set -Ux PS5_SIZE 1920x1080
set -Ux PS5_FPS 60

# Optional: which screen to go fullscreen on (names from `kscreen-doctor -o` or `xrandr`)
set -Ux PS5_SCREEN eDP-1

# Optional, hybrid laptops: Vulkan device names from `vulkaninfo --summary`
set -Ux PS5_GPU 'Intel(R) Graphics (RPL-S)'               # GPU wired to PS5_SCREEN
set -Ux PS5_FG_GPU 'NVIDIA GeForce RTX 4080 Laptop GPU'   # dGPU for frame generation
```

**Hybrid laptop tip:** the internal screen is often wired to the iGPU. Without frame gen,
render on the GPU that drives your screen (`PS5_GPU`). Otherwise each frame is copied
between GPUs, which adds lag. Decoding runs on the CPU, so the iGPU is plenty. Find out
which GPU drives which screen with:

```fish
for c in /sys/class/drm/card*-*; test (cat $c/status) = connected; and echo (basename $c) (basename (readlink -f $c/../device/driver)); end
```

## Streaming on Discord

The official Discord client on Linux sends **no audio** with a screen share. It only
records your mic. Workaround: `ps5 --discord` creates a virtual mic, **`ps5-mic`**, that
mixes your real mic with the game audio, and removes it when you quit.

1. Run `ps5 --discord` and go live in Discord as usual.
2. In Discord **Settings → Voice & Video**, set **Input Device** to `ps5-mic`.
3. In the same settings, turn off **Noise Suppression** and **Echo Cancellation**, or they
   cut out game sound. With voice activity on, set Input Sensitivity low (or the game
   gets gated). Push-to-talk mutes the game too.

The game audio is sent through the voice channel, so everyone in the call hears it (mono,
voice quality), not only stream viewers. Switch the input back to your mic afterwards.

**Alternative: [Vesktop](https://github.com/Vencord/Vesktop)** (`sudo pacman -S vesktop-bin`).
It can share real stream audio: pick `ps5-audio` in its audio picker. But its voice runs on
Discord's web engine. On some networks, connecting to distant Discord voice servers gets
stuck at "DTLS connecting", while nearby servers work. A voice channel **Region Override**
to a nearby region can help. Vesktop ships Vencord, an unofficial client mod. That's against
Discord's terms, though rarely enforced. If Vesktop hangs on its splash screen after a long
break, rename `~/.config/vesktop/sessionData/vencordFiles` so it downloads a fresh copy.

## Frame generation (lsfg-vk 2.x)

1. Own Lossless Scaling on Steam. In Library, right-click it → **Properties → Betas**, and
   choose the **`lsfg-vk`** branch. lsfg-vk 2.0 needs the `lsfg-vk.dll` from that branch.
2. It's found automatically under `~/.steam/steam/steamapps/common/Lossless Scaling/`. If
   your game library is on another drive, symlink the folder there.
3. Check it with `lsfg-vk-cli benchmark -d "<path>/lsfg-vk.dll" -g "<your dGPU name>"`.

`ps5-fg` doesn't need a profile in `~/.config/lsfg-vk/conf.toml`. It passes its settings
through environment variables.

## What we found (so you don't have to)

- **"The specified shader DLL does not exist"** with lsfg-vk 2.0 means you're on the normal
  Lossless Scaling branch. The old `Lossless.dll` doesn't have the shaders 2.0 needs
  (`Unable to find base shader 'mipmaps'`), so renaming it or pointing `LSFGVK_DLL_PATH` at
  it won't help. Switch to the `lsfg-vk` beta branch.
- **`LSFGVK_*` environment variables are ignored unless `LSFGVK_ENV=1` is also set.**
- **`mangohud mpv …` shows 30 fps even when frame gen works.** The wrapper puts MangoHud
  above lsfg-vk, so it only sees the app's own frames. `--hud` loads MangoHud as an explicit
  layer *below* lsfg-vk, so it counts generated frames too.
- **`lsfg-vk-cli benchmark` defaults to GPU0**, which may be your iGPU (6 fps instead of
  ~1800). Pass `-g`.
- **`/dev/video0`/`/dev/video2` swap between boots**, and a capture card's USB serial can
  change too. That's why the functions match devices by name.
- **Frame gen pacing:** generated and real frames go out on back-to-back refreshes, so 2×
  only looks even at 60 Hz, or with a multiplier that fits the refresh rate (e.g. 4× at
  120 Hz). lsfg-vk 2.0 has only two pacing modes: `vsync` and `none`. So `ps5-fg` picks the multiplier from
  `PS5_SCREEN`'s refresh rate (8× at 240 Hz). Dropping the panel to 60 Hz for 2× also paces
  evenly, but felt much laggier: every frame waits up to 16.7 ms for vsync instead of ~4 ms.
- **Capture at 60 fps even for 30 fps games.** At 60 a 30 fps game arrives with each frame
  twice (measured: ~half the frames are byte-identical), but every new frame lands within
  ~16 ms instead of up to 33 ms, and an unevenly paced game frame isn't missed. `ps5-fg`
  removes the repeats with `mpdecimate=max=1` (measured: 30.3 fps out, 133 of 135 gaps at
  33 ms), so lsfg-vk interpolates between real frames.
- **DLSS can't do this.** DLSS frame generation needs the game's own motion vectors and
  depth, so it only works inside PC games that build it in. It can't run on a video feed
  from a capture card. lsfg-vk (Lossless Scaling) is the tool that works on any image.

## Latency vs smoothness (measured)

These numbers are from one setup (RTX 4080 laptop, 240 Hz panel), measured with MangoHud
logs and `v4l2-ctl`. Treat them as a guide.

- The capture card delivered a rock-steady 30.00 fps (±0.5 ms between frames).
- **`ps5` (default):** each frame is shown as soon as it's decoded. Lowest lag, with about
  ±5 ms of jitter between frames.
- **`ps5 --untimed=no`:** frames are scheduled from the card's timestamps, ±0.1–0.4 ms
  jitter, at the cost of buffering one frame (~33 ms). `--demuxer-readahead-secs=0` is
  essential here. Without it mpv buffers about 0.5 s.
- **Frame gen:** the generation itself is cheap (~1 ms/frame on an RTX 4080), and
  interpolation holds back one real frame (~33 ms at 30 fps).
- **The big frame gen lag was a backlog, not the generation.** With frame gen on, mpv can't
  present faster than frames arrive, so the ~0.5 s of frames that pile up while it starts
  never drained. Measured frame age: 600 ms and growing (it felt like a second). Plain `ps5`
  drains it in ~3 s and sits at ~21 ms. `scripts/ps5-catchup.lua` drops mpv's buffered frames
  whenever the shown frame is over 100 ms old. That needs wall-clock frame timestamps
  (`ts=abs`) and demuxer readahead, so the backlog sits in mpv, not the card's kernel queue.
  `ps5-fg` frame age after the fix: median 49 ms, max 75 ms. `LSFGVK_OVERRIDE_PRESENT_MODE=mailbox`
  and `LSFGVK_PACING_MODE=none` didn't help (none was worse), and 7× froze lsfg-vk at start.

## License

MIT
