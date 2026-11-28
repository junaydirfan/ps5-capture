function ps5-fg --description 'ps5 with lsfg-vk frame generation for 30 fps games, evenly paced (adds input lag)'
    # lsfg-vk shows real + generated frames on back-to-back refreshes, so it only paces evenly when
    # 30 x multiplier = refresh rate (2x at 60 Hz, 8x at 240 Hz). Pick it from PS5_SCREEN's refresh
    # rather than dropping the screen to 60 Hz, which waits up to 16.7 ms per frame for vsync.
    set -l mult 2
    if test -n "$PS5_SCREEN"; and command -q kscreen-doctor; and command -q jq
        set -l hz (kscreen-doctor -j | jq -r --arg n $PS5_SCREEN '.outputs[] | select(.name == $n)
            | . as $o | $o.modes[] | select(.id == $o.currentModeId) | .refreshRate | round')
        test -n "$hz"; and test $hz -ge 60; and set mult (math "round($hz / 30)")
    end
    # the card captures 60 fps, so a 30 fps game arrives with every frame twice; mpdecimate drops
    # the repeats (max=1: never two in a row) so lsfg-vk interpolates between real frames
    # LSFGVK_ENV=1 is required, otherwise lsfg-vk ignores the other LSFGVK_* variables
    # ps5-catchup.lua drops the frame backlog that frame gen otherwise never drains (0.6 s+ of lag)
    set -l catchup (path dirname (path resolve (functions --details ps5-fg)))/../scripts/ps5-catchup.lua
    LSFGVK_ENV=1 LSFGVK_MULTIPLIER=$mult LSFGVK_PACING_MODE=vsync ps5 --vf=mpdecimate=max=1 \
        --demuxer-lavf-o-append=ts=abs --demuxer-readahead-secs=2 --cache=yes --script=$catchup $argv
end
