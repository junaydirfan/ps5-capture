-- ps5-fg: with frame generation mpv presents no faster than frames arrive, so frames that pile up
-- while it starts (or after a hitch) never drain: measured 0.6 s of lag, growing. When the frames
-- being shown get older than max_age, drop mpv's buffered frames and jump to the newest one.
-- Needs ts=abs (wall-clock frame timestamps) and demuxer readahead, so the backlog sits in mpv
-- (where it can be dropped) instead of the capture card's kernel queue.
local max_age = 0.1
local f = io.popen("date +%s.%N"); local off = tonumber(f:read("*l")) - mp.get_time(); f:close()
local late, last = 0, 0
mp.observe_property("time-pos", "number", function(_, pos)
    if not pos or pos < 1e9 then return end
    local now = mp.get_time() + off
    if now - pos > max_age then late = late + 1 else late = 0 end
    if late >= 3 and now - last > 1 then -- 3 late frames in a row, at most once a second
        last = now; late = 0
        mp.command("drop-buffers")
    end
end)
