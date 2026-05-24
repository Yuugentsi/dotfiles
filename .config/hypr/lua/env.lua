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
}

for k, v in pairs(env_vars) do
    hl.env(k, v)
end

-- ─── theme ───
local themes = {
    ["org.gnome.desktop.interface gtk-theme"]  = "adw-gtk3-dark",
    ["org.gnome.desktop.interface icon-theme"] = "breeze-dark",
}

for key, val in pairs(themes) do
    hl.exec_cmd("gsettings set " .. key .. " '" .. val .. "'")
end
