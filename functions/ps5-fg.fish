function ps5-fg --description 'ps5 with lsfg-vk frame generation for 30 fps games, evenly paced (adds input lag)'
    # lsfg-vk shows real + generated frames on back-to-back refreshes, so it only paces evenly when
    # 30 x multiplier = refresh rate (2x at 60 Hz, 8x at 240 Hz). Pick it from PS5_SCREEN's refresh
    # rather than dropping the screen to 60 Hz, which waits up to 16.7 ms per frame for vsync.
    set -l mult 2
    set -l mode_back
    if test -n "$PS5_SCREEN"; and command -q kscreen-doctor; and command -q jq
        set -l out (kscreen-doctor -j | jq -c --arg n $PS5_SCREEN '.outputs[] | select(.name == $n)')
        set -l hz (echo $out | jq -r '. as $o | $o.modes[] | select(.id == $o.currentModeId) | .refreshRate | round')
        test -n "$hz"; and test $hz -ge 60; and set mult (math "round($hz / 30)")
        # run the screen at the capture size while playing: at 240 fps, every frame lsfg-vk makes (and,
        # on hybrid laptops, copies to the iGPU) is 56% smaller at 1080p than 1600p. At 1600p the iGPU
        # heat-soaked after ~1 min and fell to ~60 fps, so real frames dropped to 8/s and lag piled up.
        set -l size (string split x (set -q PS5_SIZE; and echo $PS5_SIZE; or echo 1920x1080))
        set -l m (echo $out | jq -r --argjson w $size[1] --argjson h $size[2] --argjson hz $hz '. as $o
            | [$o.modes[] | select(.size.width == $w and .size.height == $h and (.refreshRate | round) == $hz)][0].id // empty')
        set -l cur (echo $out | jq -r .currentModeId)
        if test -n "$m" -a "$m" != "$cur"
            kscreen-doctor output.$PS5_SCREEN.mode.$m >/dev/null 2>&1; and set mode_back $cur
        end
    end
    # performance profile = more fan and power headroom; the 240 fps pipeline throttled on balanced
    set -l profile_back
    if command -q powerprofilesctl
        set profile_back (powerprofilesctl get)
        test "$profile_back" != performance; and powerprofilesctl set performance; or set profile_back
    end
    # put the screen mode and profile back once mpv is gone, even if this function is cut short
    # (Ctrl+C, closed terminal): a detached watcher, since the end of the function may never run
    set -l restore
    test -n "$profile_back"; and set -a restore "powerprofilesctl set $profile_back"
    test -n "$mode_back"; and set -a restore "kscreen-doctor output.$PS5_SCREEN.mode.$mode_back"
    if set -q restore[1]
        setsid fish -c "for i in (seq 60); pgrep -f '[m]pv av://v4l2' >/dev/null; and break; sleep 0.5; end
            while pgrep -f '[m]pv av://v4l2' >/dev/null; sleep 1; end
            "(string join '; ' $restore) >/dev/null 2>&1 &
        disown
    end
    # the card captures 60 fps, so a 30 fps game arrives with every frame twice; mpdecimate drops
    # the repeats (max=1: never two in a row) so lsfg-vk interpolates between real frames
    # ps5-catchup.lua drops the frame backlog that frame gen otherwise never drains (0.6 s+ of lag)
    set -l catchup (path dirname (path resolve (functions --details ps5-fg)))/../scripts/ps5-catchup.lua
    # LSFGVK_ENV=1 is required, otherwise lsfg-vk ignores the other LSFGVK_* variables
    LSFGVK_ENV=1 LSFGVK_MULTIPLIER=$mult LSFGVK_PACING_MODE=vsync ps5 --vf=mpdecimate=max=1 \
        --demuxer-lavf-o-append=ts=abs --demuxer-readahead-secs=2 --cache=yes --script=$catchup $argv
end
