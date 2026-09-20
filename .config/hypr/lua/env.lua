-- ─── env ───
local env_vars = {
    -- cursor
    XCURSOR_THEME                       = "Vanilla-DMZ",
    XCURSOR_SIZE                        = "12",
    HYPRCURSOR_SIZE                     = "1",

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

    -- SDL / Electron
    SDL_VIDEODRIVER                     = "wayland,x11",
    ELECTRON_OZONE_PLATFORM_HINT        = "auto",

    -- clutter / gtk
    CLUTTER_BACKEND                     = "wayland",
    GTK_THEME                           = "Adwaita:dark",
    NO_AT_BRIDGE                        = "1",
    __GL_VRR_ALLOWED                    = "1",
    WLR_RENDERER_ALLOW_SOFTWARE         = "0",
}

for k, v in pairs(env_vars) do
    hl.env(k, v)
end
