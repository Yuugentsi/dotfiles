-- ─── autostart ───
-- quickshell hyprsunset swaync mpv playerctl
hl.on("hyprland.start", function()
    -- helper
    local function exec(cmd)
        hl.exec_cmd(cmd)
    end
    -- -------------------- exec --------------------
    exec("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    exec("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR")

    exec("hypridle")
    exec("spotify")
    exec("wl-clip-persist --clipboard regular")
    exec("setsid -f wl-paste --type text --watch cliphist store")
    exec("setsid -f wl-paste --type image --watch cliphist store")
    exec([[setsid -f wl-paste --type text --watch sh -c 'u=$(cat | tr -d "\r\n "); case "$u" in *://*wallhaven.cc/w/*) if gallery-dl -d "$HOME/0/pictures/wallpapers" "$u" >/dev/null 2>&1; then hyprctl notify 1 5000 "rgb(88c0d0)" "󰸉 "; else hyprctl notify 3 5000 "rgb(bf616a)" "󰸉 "; fi ;; esac']])
    exec("GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface cursor-theme 'Vanilla-DMZ'")

    exec("thunar -q; thunar --daemon")

end)

-- ----- mpv_zathura -----
hl.on("window.open", function(opened_win)
    local class = string.lower(opened_win.class or "")
    if class == "spotify" then hl.exec_cmd("playerctl --player=spotify play") end
    -- ─── mpv audio ───
    if class == "mpv" then hl.exec_cmd("pkill -f '^/usr/bin/mpv --no-video --audio-display=no' 2>/dev/null || true") end
    local target = class == "mpv" and "mpv" or (class == "zathura" or class == "org.pwmt.zathura") and "zathura"
    if not target then return end
    for _, w in ipairs(hl.get_windows()) do
        local other_class = string.lower(w.class or "")
        if w.address ~= opened_win.address and (other_class == target or (target == "zathura" and other_class == "org.pwmt.zathura")) then
            hl.dispatch(hl.dsp.window.close({ window = w }))
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
