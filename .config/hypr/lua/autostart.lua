-- ─── autostart ───
-- waybar hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("waybar")
    -- exec("hyprsunset -t 2000")
    exec("swaync")
    -- exec("spotify")
    exec("zen-browser")

    -- ----- xdg desktop portal -----

    -- ----- spotify-mpv -----
    hl.timer(function()
        local status = io.popen("playerctl -p spotify status 2>/dev/null"):read("*l")
        if status == "Playing" then
            exec("pkill -x mpv")
        end
    end, { timeout = 2000, type = "repeat" })

    -- ----- spotify -----
    hl.timer(function()
        local status = io.popen("playerctl -p spotify status 2>/dev/null"):read("*l")
        if status == "Paused" then
            exec("playerctl -p spotify play")
        end
    end, { timeout = 1000, type = "repeat" })

    -- ----- mpv -----
    hl.timer(function()
        local mpvs = tonumber(io.popen("pgrep -x mpv 2>/dev/null | wc -l"):read("*a")) or 0
        if mpvs > 1 then
            exec("pkill -x -o mpv")
        end
    end, { timeout = 1000, type = "repeat" })

    -- ----- zathura -----
    hl.timer(function()
        local zaths = tonumber(io.popen("pgrep -x zathura 2>/dev/null | wc -l"):read("*a")) or 0
        if zaths > 1 then
            exec("pkill -x -o zathura")
        end
    end, { timeout = 1000, type = "repeat" })

end)

-- ----- shutdown cleanup -----
hl.on("hyprland.shutdown", function()
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    exec("pkill -x hypridle")
    exec("pkill -x hyprpaper")
    exec("pkill -x swaync")
    exec("pkill -x waybar")
end)
