-- ─── keybinds ───
-- -------------------- variables --------------------
local MOD     = "SUPER"
local TERM    = "kitty"
local FM      = "thunar"
local BROWSER = "librewolf || firefox || zen-browser"
local MENU    = "rofi -show drun"
local EDITOR  = "zeditor"

-- helper
local function bind_exec(key, cmd, opts)
    hl.bind(key, hl.dsp.exec_cmd(cmd), opts)
end

-- -------------------- apps --------------------
bind_exec(MOD .. " + Q", TERM)
bind_exec(MOD .. " + T", FM)
bind_exec(MOD .. " + F", BROWSER)
bind_exec("ALT + F", "librewolf --private-window || firefox --private-window || zen-browser --private-window")
bind_exec(MOD .. " + E", MENU)
bind_exec("ALT + E", EDITOR)
-- -------------------- windows --------------------
hl.bind(MOD .. " + C", hl.dsp.window.close())
hl.bind(MOD .. " + M", hl.dsp.exit())
hl.bind(MOD .. " + I", hl.dsp.window.pin())
hl.bind(MOD .. " + P", hl.dsp.window.pseudo())
hl.bind(MOD .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(MOD .. " + Tab", hl.dsp.window.cycle_next())
hl.bind("F11", hl.dsp.window.fullscreen())

-- ----- groups -----
hl.bind("ALT + down", hl.dsp.window.close())
hl.bind("ALT + up", hl.dsp.group.toggle())

-- -------------------- media --------------------
-- ----- audio -----
local vol_mute =
"bash -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; state=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo \"󰖁\" || echo \"\"); hyprctl dismissnotify 1; hyprctl notify -1 2000 \"rgb(ff3333)\" \"fontsize:18 $state\"'"
local vol_down =
"bash -c 'v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk \"{print int(\\$2*100)}\"); [ $v -le 15 ] && v=15 || v=$((v-5)); wpctl set-volume @DEFAULT_AUDIO_SINK@ ${v}%; hyprctl dismissnotify 1; hyprctl notify -1 2000 \"rgb(ffaa00)\" \"fontsize:18  ${v}%\"'"
local vol_up   =
"bash -c 'v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk \"{print int(\\$2*100)}\"); v=$((v+5)); [ $v -gt 80 ] && v=80; wpctl set-volume --limit 0.80 @DEFAULT_AUDIO_SINK@ ${v}%; hyprctl dismissnotify 1; hyprctl notify -1 2000 \"rgb(33ff33)\" \"fontsize:18 󰕾 ${v}%\"'"

bind_exec("F6", vol_mute, { repeating = true })
bind_exec("F7", vol_down, { repeating = true })
bind_exec("F8", vol_up, { repeating = true })

-- ----- playerctl -----
bind_exec("ALT + H", "playerctl previous")
bind_exec("ALT + J", "playerctl play-pause")
bind_exec("ALT + K", "playerctl next")

-- -------------------- brightness --------------------
-- ----- brightnessctl -----
local brightness_down =
"bash -c 'v=$(brightnessctl get); max=$(brightnessctl max); current=$((v * 100 / max)); [ $current -le 30 ] && current=30 || current=$((current-5)); brightnessctl set ${current}%; hyprctl dismissnotify 1; [ $current -le 30 ] && icon=\"󰃞\" || { [ $current -le 70 ] && icon=\"󰃟\" || icon=\"󰃠\"; }; hyprctl notify -1 2000 0 \"fontsize:18 $icon ${current}%\"'"
local brightness_up   =
"bash -c 'v=$(brightnessctl get); max=$(brightnessctl max); current=$((v * 100 / max)); [ $current -ge 90 ] && current=90 || current=$((current+5)); brightnessctl set ${current}%; hyprctl dismissnotify 1; [ $current -le 30 ] && icon=\"󰃞\" || { [ $current -le 70 ] && icon=\"󰃟\" || icon=\"󰃠\"; }; hyprctl notify -1 2000 0 \"fontsize:18 $icon ${current}%\"'"

bind_exec("F2", brightness_down, { repeating = true })
bind_exec("F3", brightness_up, { repeating = true })

-- ----- hyprsunset -----
local sunset_down =
"bash -c 'pgrep -x hyprsunset >/dev/null || hyprsunset & v=$(hyprctl hyprsunset temperature); v=$((v-300)); [ $v -lt 1200 ] && v=1200; hyprctl hyprsunset temperature $v; hyprctl dismissnotify 1; [ $v -le 2000 ] && icon=\"󰃛\" || icon=\"󰃜\"; hyprctl notify -1 2000 0 \"fontsize:18 $icon ${v}K\"'"
local sunset_up   =
"bash -c 'pgrep -x hyprsunset >/dev/null || hyprsunset & v=$(hyprctl hyprsunset temperature); v=$((v+300)); [ $v -gt 2700 ] && v=2700; hyprctl hyprsunset temperature $v; hyprctl dismissnotify 1; [ $v -le 2000 ] && icon=\"󰃛\" || icon=\"󰃜\"; hyprctl notify -1 2000 0 \"fontsize:18 $icon ${v}K\"'"

bind_exec("ALT + F2", sunset_down, { repeating = true })
bind_exec("ALT + F3", sunset_up, { repeating = true })

-- -------------------- system --------------------

-- ----- lock -----
bind_exec(MOD .. " + L", "hyprlock --config $HOME/.config/hypr/conf/hyprlock.conf")

-- ----- reload -----
bind_exec(MOD .. " + SHIFT + R", "hyprctl reload")
bind_exec("ALT + W", "pkill -x waybar || waybar")

-- ----- notifications -----
bind_exec(MOD .. " + N", "swaync-client -t")
bind_exec(MOD .. " + SHIFT + N",
    "swaync-client -C && hyprctl notify -1 2000 0 '🔔 Notifications cleared'")

-- -------------------- screenshots --------------------
local shot_region =
"hyprshot -m region -z -t 500 -o $HOME/media/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"
local shot_output =
"hyprshot -m output -m active -z -t 500 -o $HOME/media/pictures/screenshots -f $(date +'%H-%M-%S_%m-%d-%Y').png"

-- ----- region -----
bind_exec("Print", shot_region)
bind_exec(MOD .. " + F9", shot_region)

-- ----- output -----
bind_exec(MOD .. " + Print", shot_output)
bind_exec("F9", shot_output)

-- -------------------- scrolling layout --------------------
hl.bind(MOD .. " + period", hl.dsp.layout("move +col"))
hl.bind(MOD .. " + comma", hl.dsp.layout("move -col"))
hl.bind(MOD .. " + SHIFT + period", hl.dsp.layout("swapcol r"))
hl.bind(MOD .. " + SHIFT + comma", hl.dsp.layout("swapcol l"))
hl.bind(MOD .. " + p", hl.dsp.layout("promote"))

-- -------------------- scripts --------------------
bind_exec("ALT + T", "bash $HOME/.config/hypr/scripts/toggle.sh")
-- ----- autostart -----
hl.on("hyprland.start", function()
    local function exec(cmd) hl.exec_cmd(cmd) end
    exec("bash $HOME/.config/hypr/scripts/clipboard.sh daemon")
    exec("bash $HOME/.config/hypr/scripts/wallpaper.sh daemon")
    exec("python $HOME/.config/hypr/scripts/utils.py watch")
    exec("python $HOME/.config/hypr/scripts/utils.py anime")
end)

-- ----- media -----
bind_exec("SUPER + G", "bash $HOME/.config/hypr/scripts/music.sh")
bind_exec("ALT + G", "bash $HOME/.config/hypr/scripts/video.sh")

-- ----- utils -----
bind_exec("SUPER + Escape", "bash $HOME/.config/hypr/scripts/websites.sh")
bind_exec("SUPER + V", "bash $HOME/.config/hypr/scripts/clipboard.sh")
bind_exec("ALT + V", "bash $HOME/.config/hypr/scripts/clipboard.sh images")

-- ----- random music (F1) -----
bind_exec("F1", "bash $HOME/.config/hypr/scripts/play.sh")

-- -------------------- workspace navigation --------------------
-- ----- navigation -----
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(MOD .. " + " .. dir, hl.dsp.focus({ direction = dir }))
end

-- ----- mouse -----
hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ----- special workspace -----
hl.bind(MOD .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(MOD .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- ----- workspaces -----
for i = 1, 10 do
    local key = i % 10
    hl.bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
