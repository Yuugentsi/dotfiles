-- ─── windowrules ───
-- -------------------- workspace rules --------------------
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

hl.workspace_rule({ workspace = "1", on_created_empty = "librewolf" })
hl.workspace_rule({ workspace = "2", on_created_empty = "kitty" })
hl.workspace_rule({ workspace = "3", on_created_empty = "Telegram" })
hl.workspace_rule({
    workspace = "8",
    on_created_empty =
    "bash -c 'cd ~/.config && zeditor aria2 gallery-dl kitty rofi swayimg mpv swaync fish yt-dlp zathura hypr waybar wofi quickshell'"
})
hl.workspace_rule({ workspace = "5", on_created_empty = "thunar" })
hl.workspace_rule({ workspace = "9", on_created_empty = "spotify" })

hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ name = "no-gaps-f1", match = { float = false, workspace = "f[1]" }, border_size = 0, rounding = 0 })

-- -------------------- gestures --------------------
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = "1", mode = "live" })
hl.gesture({ fingers = 3, direction = "swipe", action = "scroll_move" })

-- -------------------- app --------------------
-- ----- spotify -----
hl.window_rule({ name = "spotify-workspace", match = { class = "Spotify" }, workspace = "9 silent" })
hl.window_rule({ name = "spotify-fullscreen", match = { class = "spotify" }, fullscreen = true })

-- ----- rofi -----
hl.window_rule({ name = "rofi-animation", match = { class = "rofi" }, animation = "popin" })

-- -------------------- opacity --------------------
hl.window_rule({ name = "zed-opacity", match = { class = "dev.zed.Zed" }, opacity = "0.90 0.88" })
hl.window_rule({ name = "firefox-opacity", match = { class = "firefox" }, opacity = "0.82 0.62" })
hl.window_rule({ name = "brave-opacity", match = { class = "brave" }, opacity = "0.82 0.62" })
hl.window_rule({ name = "zen-opacity", match = { class = "zen" }, opacity = "0.70 0.70" })
hl.window_rule({ name = "spotify-opacity", match = { class = "Spotify" }, opacity = "0.85 0.75" })
hl.window_rule({ name = "thunar-opacity", match = { class = "(?i)thunar" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "code-oss-opacity", match = { class = "code-oss" }, opacity = "0.88 0.82" })
hl.window_rule({ name = "bitwarden-opacity", match = { class = "Bitwarden" }, opacity = "0.60 0.70" })
hl.window_rule({ name = "telegram-opacity", match = { class = "org.telegram.desktop" }, opacity = "0.80 0.95" })
hl.window_rule({ name = "kitty-opacity", match = { class = "kitty" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "zathura-opacity", match = { class = "(zathura|org\\.pwmt\\.zathura)" }, opacity = "0.88 0.80" })

-- -------------------- floating apps --------------------
-- ----- mpv -----
hl.window_rule({
    name = "mpv-float",
    match = { class = "mpv" },
    workspace = "7 silent",
    fullscreen = true
})

-- ----- thunar -----
hl.window_rule({
    name = "thunar-float",
    match = { class = "(?i)thunar" },
    float = true,
    size = "900 600",
    center = true,
    border_size = 0
})

-- ----- telegram file dialogs -----
hl.window_rule({
    name        = "telegram-file-chooser",
    match       = { class = "org.telegram.desktop", title = "Save|Choose|Open" },
    float       = true,
    center      = true,
    size        = "(monitor_w*0.32) (monitor_h*0.35)",
    opacity     = "1.0 override 1.0 override",
    border_size = 0,
})

-- ----- telegram -----
hl.window_rule({
    name = "telegram-float",
    match = { class = "org.telegram.desktop" },
    workspace = "3 silent",
    float = true,
    size = "1050 650",
    center = true,
    border_size = 0
})

-- ----- swayimg -----
hl.window_rule({
    name        = "swayimg-float",
    match       = { class = "swayimg" },
    float       = true,
    center      = true,
    size        = "(monitor_w*0.45) (monitor_h*0.55)",
    border_size = 0,
})

-- ----- clipboard-copy -----
hl.window_rule({
    name        = "clipboard-copy-float",
    match       = { class = "clipboard-copy" },
    float       = true,
    center      = true,
    size        = "(monitor_w*0.55) (monitor_h*0.65)",
    border_size = 0,
})

-- ----- browser-pip -----
hl.window_rule({
    name    = "browser-pip",
    match   = { class = "(librewolf|firefox|zen)", title = "(Picture-in-Picture|Picture-in-picture)" },
    float   = true,
    pin     = true,
    opacity = "1.0 1.0",
    size    = "245 136",
    move    = "865 103",
})

hl.window_rule({
    name    = "brave-pip",
    match   = { title = "Picture in picture" },
    float   = true,
    pin     = true,
    opacity = "1.0 1.0",
    size    = "245 136",
    move    = "865 103",
})

-- ----- kitty-float -----
hl.window_rule({
    name    = "kitty-float",
    match   = { class = "kitty-float" },
    float   = true,
    center  = true,
    size    = "(monitor_w*0.55) (monitor_h*0.60)",
    opacity = "0.88 0.80",
})

-- ----- zathura -----
hl.window_rule({
    name   = "zathura-viewer",
    match  = { class = "(zathura|org\\.pwmt\\.zathura)" },
    float  = true,
    center = true,
    size   = "(monitor_w*0.65) (monitor_h*0.75)",
})

-- -------------------- dialogs --------------------
-- ----- browser save dialog -----
hl.window_rule({
    name        = "browser-save-dialog",
    match       = { class = "firefox|brave-origin-beta|xdg-desktop-portal-gtk", title = ".*Save.*|.*Opening.*" },
    float       = true,
    center      = true,
    size        = "875 621",
    opacity     = "0.92 override 0.92 override",
    border_size = 0,
})

-- ----- telegram-media-viewer -----
hl.window_rule({
    name        = "telegram-media-viewer",
    match       = { class = "org.telegram.desktop", title = "Media viewer" },
    float       = true,
    center      = true,
    opacity     = "1.0 1.0",
    size        = "720 540",
    border_size = 0,
})

-- ----- thunar -----
hl.window_rule({
    name    = "thunar-dialogs",
    match   = { class = "(?i)thunar", title = "(?i)(Rename|Create|Delete|Properties|Bulk).*" },
    float   = true,
    size    = "(monitor_w*0.35) (monitor_h*0.3)",
    center  = true,
    opacity = "0.92 override 0.92 override",
})

-- ----- zed -----
hl.window_rule({
    name = "zed",
    match = { class = "dev.zed.Zed" },
    -- float = true,
    size = "960 580",
    center = true,
    border_size = 0
})

-- -------------------- layer rules --------------------
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "waybar" }, blur = true })

-- -------------------- system behavior --------------------
-- ----- suppress maximize -----
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- ----- fix xwayland drags -----
hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ----- hyprland run -----
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})
