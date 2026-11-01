local mainMod = "SUPER"

local terminal    = "kitty"
local browser     = "librewolf"
local menu        = "rofi -show drun -show-icons"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty", { float = true, size = { 850, 500 }, center = true }))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("pkill -x zed-editor 2>/dev/null; zeditor"))
hl.bind(mainMod .. " + F",         hl.dsp.exec_cmd(browser))
hl.bind("ALT + F",         hl.dsp.exec_cmd(browser .. " --private-window"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + apostrophe", hl.dsp.exec_cmd(browser .. " https://x.com"), { description = "Open X" })

hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind("ALT + C",         hl.dsp.window.kill())
hl.bind(mainMod .. " + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind("F11",             hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + B",   hl.dsp.window.center())

hl.bind("F10", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600 }))
    hl.dispatch(hl.dsp.window.center())
end)

hl.bind("ALT + down", hl.dsp.window.close())
hl.bind("ALT + up",   hl.dsp.group.toggle())

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + up",          hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",        hl.dsp.focus({ direction = "down" }))
hl.bind("CTRL + apostrophe",        hl.dsp.focus({ workspace = "m+1" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + V", hl.dsp.layout("fit visible"))
hl.bind(mainMod .. " + left",           hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + right",          hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + period",         hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + comma",          hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.layout("swapcol l"))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock --config ~/.config/hypr/conf/hyprlock.conf"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

local shot_region = "hyprshot -m region -z -t 500 -o ~/0/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"
local shot_output = "hyprshot -m output -m active -z -t 500 -o ~/0/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"

hl.bind("Print",       hl.dsp.exec_cmd(shot_region))
hl.bind("ALT + Print", hl.dsp.exec_cmd(shot_output))
