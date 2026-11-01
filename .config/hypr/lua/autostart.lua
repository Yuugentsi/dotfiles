-- ─── autostart ───
-- quickshell hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP GTK_THEME=Adwaita:dark")
    exec("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR")


    exec("~/.config/hypr/scripts/quickshell.sh start")
    exec("python3 -B ~/.config/quickshell/scripts/wallpapers.py restore")
    exec("hyprsunset -t 2700 -g 100")
    exec("swaync")
    exec("hypridle")
    exec("spotify")
    exec("wl-clip-persist --clipboard regular")
    exec("setsid -f wl-paste --type text --watch cliphist store")
    exec("setsid -f wl-paste --type image --watch cliphist store")
    exec("GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme 'Obsidian' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface cursor-theme 'Vanilla-DMZ' && GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' && command -v xfconf-query >/dev/null 2>&1 && xfconf-query -c xsettings -p /Net/ThemeName -s 'Adwaita:dark' --create -t string")

    exec("thunar -q; GTK_THEME=Adwaita:dark thunar --daemon")

end)

-- ----- mpv & zathura -----
local single_instance_classes = {
    ["mpv"] = "mpv",
    ["zathura"] = "zathura",
    ["org.pwmt.zathura"] = "zathura",
}

hl.on("window.open", function(opened_win)
    if string.lower(opened_win.class or "") == "spotify" then
        hl.exec_cmd("playerctl --player=spotify play")
    end

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

-- past
hl.on("hyprland.start", function()
    hl.exec_cmd([[bash -c '
        bookmarks="$HOME/.config/gtk-3.0/bookmarks"
        if [ ! -e "$bookmarks" ]; then
            mkdir -p "$HOME/.config/gtk-3.0" "$HOME/Downloads" "$HOME/0" \
                "$HOME/0/documents" "$HOME/0/music" "$HOME/0/pictures" "$HOME/0/videos" || exit
            set -o noclobber
            printf "%s\n" "file://$HOME/.config/" "file://$HOME/Downloads/" \
                "file://$HOME/0" "file://$HOME/0/documents" "file://$HOME/0/music" \
                "file://$HOME/0/pictures" "file://$HOME/0/videos" > "$bookmarks"
        fi
    ']])
end)
--
