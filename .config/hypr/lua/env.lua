-- ─── env ───
local env_vars = {
    -- cursor
    XCURSOR_THEME                       = "Oxygen_Zion",
    XCURSOR_SIZE                        = "5",
    HYPRCURSOR_SIZE                     = "11",

    -- session
    XDG_CURRENT_DESKTOP                 = "Hyprland",
    XDG_SESSION_TYPE                    = "wayland",
    XDG_SESSION_DESKTOP                 = "Hyprland",

    -- toolkit
    GDK_BACKEND                         = "wayland,x11,*",
    QT_QPA_PLATFORM                     = "wayland;xcb",
    QT_AUTO_SCREEN_SCALE_FACTOR         = "1",
    QT_QPA_PLATFORMTHEME                = "qt6ct",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",

    -- browser
    MOZ_ENABLE_WAYLAND                  = "1",
    BROWSER                             = "brave-origin",

    -- SDL / Electron
    SDL_VIDEODRIVER                     = "wayland,x11",
    ELECTRON_OZONE_PLATFORM_HINT        = "auto",
}

for k, v in pairs(env_vars) do
    hl.env(k, v)
end

-- ─── theme ───
local themes = {
    ["org.gnome.desktop.interface gtk-theme"]  = "Pop-dark",
    ["org.gnome.desktop.interface icon-theme"] = "bloom",
}

for key, val in pairs(themes) do
    hl.exec_cmd("GSETTINGS_BACKEND=dconf gsettings set " .. key .. " '" .. val .. "'")
end
