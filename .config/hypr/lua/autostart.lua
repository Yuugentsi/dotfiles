-- ─── autostart ───
-- waybar hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("waybar")
    exec("hyprsunset -t 3000")
    exec("swaync")
    exec("hypridle")
    exec("spotify")
    exec("wl-clip-persist --clipboard regular")
    exec("setsid -f wl-paste --type text --watch cliphist store")
    exec("setsid -f wl-paste --type image --watch cliphist store")
    exec("GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme 'Obsidian' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface cursor-theme 'Vanilla-DMZ' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

    -- ----- spotify-mpv event listener (async / no polling) -----
    exec("bash -c 'while true; do playerctl -i mpv --follow status 2>/dev/null | while read -r s; do [ \"$s\" = \"Playing\" ] && pkill -x mpv 2>/dev/null; done; sleep 2; done &'")
end)

-- ----- single instance apps (mpv & zathura) -----
local single_instance_classes = {
    ["mpv"] = "mpv",
    ["zathura"] = "zathura",
    ["org.pwmt.zathura"] = "zathura",
}

hl.on("window.open", function(opened_win)
    local target = single_instance_classes[opened_win.class]
    if not target then return end

    local wins = {}
    for _, w in ipairs(hl.get_windows()) do
        if single_instance_classes[w.class] == target then
            table.insert(wins, w)
        end
    end

    if #wins > 1 then
        for _, w in ipairs(wins) do
            if w.address ~= opened_win.address then
                hl.dispatch(hl.dsp.window.close({ window = w }))
            end
        end
    end
end)

-- ----- shutdown cleanup -----
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("pkill -x 'kitty|firefox|zen-browser|librewolf|brave-origin|hypridle|hyprpaper|swaync|waybar'")
end)
