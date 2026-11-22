function ps5-fg --description 'ps5 with lsfg-vk 2x frame generation (smoother, adds input lag)'
    # LSFGVK_ENV=1 is required, otherwise lsfg-vk ignores the other LSFGVK_* variables
    LSFGVK_ENV=1 LSFGVK_MULTIPLIER=2 LSFGVK_PACING_MODE=vsync ps5 $argv
end
