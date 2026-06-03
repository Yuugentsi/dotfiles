-- ─── windowrules ───
-- -------------------- workspace rules --------------------
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

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
hl.window_rule({ name = "spotify-opacity", match = { class = "Spotify" }, opacity = "0.85 0.75" })
hl.window_rule({ name = "thunar-opacity", match = { class = "thunar" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "code-oss-opacity", match = { class = "code-oss" }, opacity = "0.88 0.82" })
hl.window_rule({ name = "bitwarden-opacity", match = { class = "Bitwarden" }, opacity = "0.60 0.70" })
hl.window_rule({ name = "telegram-opacity", match = { class = "org.telegram.desktop" }, opacity = "0.88 0.80" })
hl.window_rule({ name = "kitty-opacity", match = { class = "kitty" }, opacity = "0.88 0.80" })

-- -------------------- floating apps --------------------
-- ----- mpv -----
hl.window_rule({ name = "mpv-float", match = { class = "mpv" }, float = true, size = "370 208" })

-- ----- thunar -----
hl.window_rule({ name = "thunar-float", match = { class = "thunar" }, float = true, size = "800 600", center = true, border_size = 0 })

-- ----- zed -----
hl.window_rule({ name = "zed-float", match = { class = "dev.zed.Zed" }, float = true, size = "800 600", center = true, border_size = 0 })

-- ----- telegram -----
hl.window_rule({ name = "telegram-float", match = { class = "org.telegram.desktop" }, float = true, size = "800 600", center = true, border_size = 0 })

-- ----- viewnior -----
hl.window_rule({
    name  = "viewnior-float",
    match = { class = "viewnior" },
    float = true,
    size  = "(monitor_w*0.6) (monitor_h*0.7)",
    move  = "(monitor_w*0.2) (monitor_h*0.15)",
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
    move    = "(monitor_w-245) 0",
})

hl.window_rule({
    name    = "brave-pip",
    match   = { title = "Picture in picture" },
    float   = true,
    pin     = true,
    opacity = "1.0 1.0",
    size    = "245 136",
    move    = "(monitor_w-245) 0",
})

-- ----- feh -----
hl.window_rule({
    name    = "feh-viewer",
    match   = { class = "feh" },
    float   = true,
    center  = true,
    size    = "570 508",
    opacity = "0.92 override 0.92 override",
})

-- ----- kitty-float -----
hl.window_rule({
    name   = "kitty-float",
    match  = { class = "kitty-float" },
    float  = true,
    center = true,
    size   = "(monitor_w*0.42) (monitor_h*0.48)",
})

-- ----- zathura -----
hl.window_rule({
    name   = "zathura-viewer",
    match  = { class = "(zathura|org\\.pwmt\\.zathura)" },
    float  = true,
    center = true,
    size   = "(monitor_w*0.52) (monitor_h*0.68)",
})

-- -------------------- dialogs --------------------
-- ----- thunar -----
hl.window_rule({
    name    = "thunar-dialogs",
    match   = { class = "thunar", title = "(Rename|Create|Delete|Properties).*" },
    float   = true,
    size    = "600 250",
    center  = true,
    opacity = "0.92 override 0.92 override",
})

-- ----- firefox -----
hl.window_rule({
    name    = "firefox-save-dialog",
    match   = { class = "firefox|xdg-desktop-portal-gtk|brave-origin-beta|xdg-desktop-portal-gtk", title = ".*Save.*|.*Opening.*" },
    float   = true,
    center  = true,
    size    = "800 500",
    opacity = "0.92 override 0.92 override",
})

-- ----- telegram -----
hl.window_rule({
    name        = "telegram-file-chooser",
    match       = { class = "org.telegram.desktop", title = "(Choose an image|Choose Files|Choose download path|Save Audio File|Save voice message|Save Video|Save File|Save Image)" },
    float       = true,
    center      = true,
    size        = "780 560",
    opacity     = "1.0 override 1.0 override",
    border_size = 0,
})

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
--
--hello
