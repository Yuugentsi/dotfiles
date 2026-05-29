-- ─── autostart ───
-- waybar hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("waybar")
    exec("hyprsunset -t 2200")
    exec("swaync")

    -- ----- spotify-mpv -----
    local spotify_monitor =
    "bash -c 'while true; do if playerctl -p spotify status 2>/dev/null | grep -qx Playing; then pkill -x mpv; fi; sleep 2; done'"
    exec(spotify_monitor)

    -- ----- mpv -----
    local mpv_dedup =
    "bash -c 'while true; do if [ \"$(pgrep -x mpv | wc -l)\" -gt 1 ]; then pkill -x -o mpv; fi; sleep 1; done'"
    exec(mpv_dedup)
end)
