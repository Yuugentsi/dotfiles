-- ─── autostart ───
-- waybar hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("waybar")
    exec("hyprsunset -t 2000")
    exec("swaync")
    exec("spotify")
    exec("hyprctl dispatch exec [workspace 1] firefox")

    -- ----- spotify-mpv -----
    local spotify_monitor =
    "bash -c 'while true; do if playerctl -p spotify status 2>/dev/null | grep -qx Playing; then pkill -x mpv; fi; sleep 2; done'"
    exec(spotify_monitor)

    -- ----- spotify -----
    local spotify_resume =
    "bash -c 'while true; do if playerctl -p spotify status 2>/dev/null | grep -qx Paused; then playerctl -p spotify play; fi; sleep 1; done'"
    exec(spotify_resume)

    -- ----- mpv -----
    local mpv_dedup =
    "bash -c 'while true; do if [ \"$(pgrep -x mpv | wc -l)\" -gt 1 ]; then pkill -x -o mpv; fi; sleep 1; done'"
    exec(mpv_dedup)

    -- ----- zathura -----
    local zathura_dedup =
    "bash -c 'while true; do if [ \"$(pgrep -x zathura | wc -l)\" -gt 1 ]; then pkill -x -o zathura; fi; sleep 1; done'"
    exec(zathura_dedup)
end)
