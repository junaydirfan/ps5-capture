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
| `ps5-fg` | 2× frame generation with lsfg-vk (30 → 60 fps). Smoother, but adds input lag |
| `ps5-fg --hud` | Frame gen with an overlay that shows the real (generated) FPS |
| `ps5 --untimed=no` | Perfectly even frame pacing, for up to one extra frame of lag |

Any other arguments are passed to `mpv` (e.g. `ps5 --no-fs`). Press `q` to quit.

## Requirements

- fish, `mpv`, `v4l-utils`, PipeWire (`pw-loopback`, `pactl`)
- A capture card that does **MJPEG** at your resolution (YUYV is usually too slow at 1080p)
- Optional: `mangohud` for `--hud`
- Optional: `lsfg-vk` 2.x and Lossless Scaling (Steam) for `ps5-fg`. See below.

On Arch/CachyOS: `sudo pacman -S mpv v4l-utils mangohud lsfg-vk`

## Install

```fish
git clone <this repo> ~/ps5-capture
ln -s ~/ps5-capture/functions/*.fish ~/.config/fish/functions/
```

## Configure

Set these once as universal variables. Only `PS5_CARD` is required.

```fish
# Part of your capture card's name, as shown by `ls /dev/v4l/by-id/`
set -Ux PS5_CARD UGREEN_15389

# Optional: capture mode (defaults 1920x1080 and 30). Check yours with:
#   v4l2-ctl -d /dev/v4l/by-id/<your card>-video-index0 --list-formats-ext
set -Ux PS5_SIZE 1920x1080
set -Ux PS5_FPS 30

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
  120 Hz). lsfg-vk 2.0 has only two pacing modes: `vsync` and `none`.

## Latency vs smoothness (measured)

These numbers are from one setup (RTX 4080 laptop, 240 Hz panel), measured with MangoHud
logs and `v4l2-ctl`. Treat them as a guide.

- The capture card delivered a rock-steady 30.00 fps (±0.5 ms between frames).
- **`ps5` (default):** each frame is shown as soon as it's decoded. Lowest lag, with about
  ±5 ms of jitter between frames.
- **`ps5 --untimed=no`:** frames are scheduled from the card's timestamps, ±0.1–0.4 ms
  jitter, at the cost of buffering one frame (~33 ms). `--demuxer-readahead-secs=0` is
  essential here. Without it mpv buffers about 0.5 s.
- **Frame gen:** the generation itself is cheap (~1 ms/frame on an RTX 4080), but
  interpolation has to hold back a real frame. 2× and 4× felt too laggy for an action game.
  It's nice for slower games or just watching.

## License

MIT
