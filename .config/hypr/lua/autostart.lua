-- ─── autostart ───
-- waybar hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    exec("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    exec("waybar")
    exec("hyprsunset -t 3000")
    exec("swaync")
    exec("hypridle")
    exec("spotify")
    exec("wl-clip-persist --clipboard regular")
    exec("setsid -f wl-paste --type text --watch cliphist store")
    exec("setsid -f wl-paste --type image --watch cliphist store")
    exec("GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme 'Obsidian' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface cursor-theme 'Vanilla-DMZ' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' && command -v xfconf-query >/dev/null 2>&1 && xfconf-query -c xsettings -p /Net/ThemeName -s 'Adwaita:dark' --create -t string")

    exec("bash ~/.config/hypr/scripts/utils.sh spotify-listener")
end)

-- ----- mpv & zathura -----
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

-- ----- shutdown -----
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("pkill -x 'kitty|firefox|zen-browser|librewolf|brave-origin|hypridle|hyprpaper|swaync|waybar'; pkill -f 'utils.sh spotify-listener'")
end)
