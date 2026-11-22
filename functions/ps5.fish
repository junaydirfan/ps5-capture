function ps5 --description 'Console capture card in mpv with low latency + audio (see ps5-fg, --hud)'
    # Config (set once, e.g. `set -Ux PS5_CARD UGREEN_15389`); see README.
    if test -z "$PS5_CARD"
        echo "ps5: set PS5_CARD to part of your capture card's name. Video devices:" >&2
        command ls -1 /dev/v4l/by-id/ >&2
        return 1
    end
    set -l size 1920x1080; set -q PS5_SIZE; and set size $PS5_SIZE
    set -l fps 30; set -q PS5_FPS; and set fps $PS5_FPS

    # frame gen adds too much input lag for play; only ps5-fg (env profile) turns it on
    set -q LSFGVK_ENV; or set -lx DISABLE_LSFGVK 1
    # render on the GPU wired to your screen (skips a cross-GPU copy); lsfg-vk wants the dGPU
    set -l gpu $PS5_GPU
    set -q LSFGVK_ENV; and set gpu $PS5_FG_GPU
    set -l extra
    test -n "$gpu"; and set -a extra --vulkan-device=$gpu
    test -n "$PS5_SCREEN"; and set -a extra --fs-screen-name=$PS5_SCREEN

    # --hud: MangoHud as an explicit layer sits below lsfg-vk, so it counts generated frames too
    if contains -- --hud $argv
        set argv (string match -v -- --hud $argv)
        set -fx VK_INSTANCE_LAYERS VK_LAYER_MANGOHUD_overlay_x86_64
        set -q MANGOHUD_CONFIG; or set -fx MANGOHUD_CONFIG fps,frametime,frame_timing
    end

    # /dev/videoN and the card's serial can change between boots, so match by name
    set -l vid /dev/v4l/by-id/usb-*$PS5_CARD*-video-index0
    set -l src (pactl list short sources | cut -f2 | string match "alsa_input.usb-*$PS5_CARD*")
    if test -z "$vid[1]"
        echo "ps5: no video device matching '$PS5_CARD'. Video devices:" >&2
        command ls -1 /dev/v4l/by-id/ >&2
        return 1
    end

    # capture-card audio straight to the default output, independent of mpv's clock
    set -l lp
    if test -n "$src[1]"
        pw-loopback -n ps5-audio --capture-props="target.object=$src[1]" --latency=10ms &
        set lp $last_pid
    else
        echo "ps5: no audio source matching '$PS5_CARD', continuing without audio" >&2
    end

    # untimed = show each frame as soon as decoded (lowest lag). `ps5 --untimed=no` = even cadence for +1 frame of lag
    mpv av://v4l2:$vid[1] --profile=low-latency --untimed --demuxer-readahead-secs=0 --cache=no \
        --demuxer-lavf-o=video_size=$size,framerate=$fps,input_format=mjpeg,fflags=+nobuffer \
        --demuxer-lavf-probesize=32 --demuxer-lavf-analyzeduration=0 \
        --video-latency-hacks=yes --interpolation=no \
        --vo=gpu-next --gpu-api=vulkan --hwdec=no --swapchain-depth=1 --fs $extra $argv
    test -n "$lp"; and kill $lp 2>/dev/null
end
