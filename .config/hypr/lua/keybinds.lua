-- ─── keybinds ───
local mainMod = "SUPER"

-- ─── programs ───
local terminal    = "kitty"
local browser     = "zen-browser"
local menu        = "rofi -show drun -show-icons"

-- apps
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty", { float = true, size = { 850, 500 }, center = true }))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("pkill -x zed-editor 2>/dev/null; zeditor"))
hl.bind(mainMod .. " + F",         hl.dsp.exec_cmd(browser))
hl.bind("ALT + F",         hl.dsp.exec_cmd(browser .. " --private-window"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(menu))

-- windows
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind("ALT + C",         hl.dsp.window.kill())
-- hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind("F11",             hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + B",   hl.dsp.window.center())

-- float
hl.bind("F10", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600 }))
    hl.dispatch(hl.dsp.window.center())
end)

-- groups
hl.bind("ALT + down", hl.dsp.window.close())
hl.bind("ALT + up",   hl.dsp.group.toggle())

-- workspace
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- focus
hl.bind(mainMod .. " + up",          hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",        hl.dsp.focus({ direction = "down" }))
hl.bind("CTRL + apostrophe",        hl.dsp.focus({ workspace = "m+1" }))

-- mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- scrolling
hl.bind(mainMod .. " + left",           hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + right",          hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + period",         hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + comma",          hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.layout("swapcol l"))
-- hl.bind(mainMod .. " + p",              hl.dsp.layout("promote"))

-- workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- system
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock --config ~/.config/hypr/conf/hyprlock.conf"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -C && hyprctl notify -1 2000 0 '🔔 Notifications cleared'"))
hl.bind(mainMod .. " + U", function()
    hl.notification.create({
        text = "Timer started (waiting 2s)...",
        font_size = 16,
        timeout = 2000,
        color = "rgb(cba6f7)",
        icon = "info",
    })
    hl.timer(function()
        hl.notification.create({
            text = "Timer completed (2s elapsed)!",
            font_size = 16,
            timeout = 3000,
            color = "rgb(80ff80)",
            icon = "ok",
        })
    end, { timeout = 2000, type = "oneshot" })
end)

-- screenshots
local shot_region = "hyprshot -m region -z -t 500 -o ~/0/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"
local shot_output = "hyprshot -m output -m active -z -t 500 -o ~/0/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"

hl.bind("Print",       hl.dsp.exec_cmd(shot_region))
hl.bind("ALT + Print", hl.dsp.exec_cmd(shot_output))

-- audio
local vol_mute = "~/.config/hypr/scripts/utils.sh volume mute"
local vol_down = "~/.config/hypr/scripts/utils.sh volume down"
local vol_up   = "~/.config/hypr/scripts/utils.sh volume up"

hl.bind("F6",               hl.dsp.exec_cmd(vol_mute),                                         { repeating = true })
hl.bind("F7",               hl.dsp.exec_cmd(vol_down),                                         { repeating = true })
hl.bind("F8",               hl.dsp.exec_cmd(vol_up),                                           { repeating = true })
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd(vol_mute),                                         { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

hl.bind("F1",              hl.dsp.exec_cmd("playerctl next"),                           { locked = true })
hl.bind("ALT + K",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("ALT + J",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("ALT + H",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- brightness
local brightness_down = "~/.config/hypr/scripts/utils.sh brightness down"
local brightness_up   = "~/.config/hypr/scripts/utils.sh brightness up"

hl.bind("F2", hl.dsp.exec_cmd(brightness_down), { repeating = true })
hl.bind("F3", hl.dsp.exec_cmd(brightness_up),   { repeating = true })

-- hyprsunset
local sunset_down = "~/.config/hypr/scripts/utils.sh sunset down"
local sunset_up   = "~/.config/hypr/scripts/utils.sh sunset up"

hl.bind("ALT + F2", hl.dsp.exec_cmd(sunset_down), { repeating = true })
hl.bind("ALT + F3", hl.dsp.exec_cmd(sunset_up),   { repeating = true })

-- toggle
local toggle_cmd = "~/.config/hypr/scripts/utils.sh toggle"
hl.bind("F9", hl.dsp.exec_cmd(toggle_cmd))
