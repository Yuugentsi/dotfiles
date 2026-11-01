-- ─── utils ───
local mainMod = "SUPER"

-- ─── utils.sh ───
hl.on("hyprland.start", function()
    hl.exec_cmd("bash ~/.config/hypr/scripts/utils.sh spotify-listener")
end)

hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("~/.config/hypr/scripts/utils.sh record"), { dont_inhibit = true, allow_input_capture = true })

local vol_mute = "~/.config/hypr/scripts/utils.sh volume mute"
local vol_down = "~/.config/hypr/scripts/utils.sh volume down"
local vol_up   = "~/.config/hypr/scripts/utils.sh volume up"

-- hl.bind("F6",               hl.dsp.exec_cmd(vol_mute),                                         { repeating = true })
-- hl.bind("F7",               hl.dsp.exec_cmd(vol_down),                                         { repeating = true })
-- hl.bind("F8",               hl.dsp.exec_cmd(vol_up),                                           { repeating = true })
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd(vol_mute),                                         { repeating = true })

local brightness_down = "~/.config/hypr/scripts/utils.sh brightness down"
local brightness_up   = "~/.config/hypr/scripts/utils.sh brightness up"

hl.bind("F2", hl.dsp.exec_cmd(brightness_down), { repeating = true })
hl.bind("F3", hl.dsp.exec_cmd(brightness_up),   { repeating = true })

local sunset_down = "~/.config/hypr/scripts/utils.sh sunset down"
local sunset_up   = "~/.config/hypr/scripts/utils.sh sunset up"

hl.bind("ALT + F2", hl.dsp.exec_cmd(sunset_down), { repeating = true })
hl.bind("ALT + F3", hl.dsp.exec_cmd(sunset_up),   { repeating = true })

local toggle_cmd = "~/.config/hypr/scripts/utils.sh toggle"
hl.bind("F9", hl.dsp.exec_cmd(toggle_cmd))

hl.bind(mainMod .. " + T", hl.dsp.workspace.toggle_special("thunar"))
hl.on("workspace.active", function()
    local special = hl.get_active_special_workspace()
    if special and (special.name == "special:thunar" or special.name == "special:kitty" or special.name == "special:telegram") then
        hl.dispatch(hl.dsp.workspace.toggle_special(special.name:sub(9)))
    end
end)
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh video"))
hl.bind("ALT + Q",         hl.dsp.workspace.toggle_special("kitty"))
hl.bind(mainMod .. " + W", function()
    local active_ws = hl.get_active_workspace()
    local sp = hl.get_active_special_workspace()
    local is_special_open = sp and (sp.name == "special:mpv" or sp.id == "special:mpv")

    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.name == "special:mpv" and w.class ~= "mpv" then
            hl.dispatch(hl.dsp.window.move({
                workspace = tostring(active_ws and active_ws.id or 1),
                window = "address:" .. w.address,
                follow = false,
            }))
        end
    end

    if is_special_open then
        hl.dispatch(hl.dsp.workspace.toggle_special("mpv"))
        return
    end

    local mpv_win = nil
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "mpv" then
            mpv_win = w
            break
        end
    end

    if mpv_win then
        local active_ws = hl.get_active_workspace()
        local is_on_active = mpv_win.workspace and (
            (active_ws and mpv_win.workspace.id == active_ws.id) or
            (active_ws and mpv_win.workspace.name == active_ws.name)
        )

        if is_on_active then
            hl.dispatch(hl.dsp.window.move({
                workspace = "special:mpv",
                window = "address:" .. mpv_win.address,
                follow = false,
            }))
        else
            if mpv_win.workspace and mpv_win.workspace.name ~= "special:mpv" then
                hl.dispatch(hl.dsp.window.move({
                    workspace = "special:mpv",
                    window = "address:" .. mpv_win.address,
                    follow = false,
                }))
            end
            hl.dispatch(hl.dsp.workspace.toggle_special("mpv"))
        end
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("mpv"))
    end
end)
hl.bind("ALT + W", function()
    local sp = hl.get_active_special_workspace()
    local is_special_open = sp and (sp.name == "special:mpv" or sp.id == "special:mpv")

    local mpv_win = nil
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "mpv" then
            mpv_win = w
            break
        end
    end

    if mpv_win then
        if mpv_win.workspace and mpv_win.workspace.name == "special:mpv" and not is_special_open then
            hl.dispatch(hl.dsp.workspace.toggle_special("mpv"))
        end
        hl.dispatch(hl.dsp.window.fullscreen({
            window = "address:" .. mpv_win.address,
            action = "toggle",
        }))
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("mpv"))
    end
end)
hl.bind("ALT + T",         hl.dsp.workspace.toggle_special("telegram"))
-- hl.bind(mainMod .. " + F", function()
--     local ff_win = nil
--     for _, w in ipairs(hl.get_windows()) do
--         if w.class and string.lower(w.class) == "firefox" and not (w.title and string.find(string.lower(w.title), "picture%-in%-picture")) then
--             ff_win = w
--             break
--         end
--     end
--     if ff_win then
--         hl.dispatch(hl.dsp.focus({ window = "address:" .. ff_win.address }))
--     else
--         hl.dispatch(hl.dsp.exec_cmd("firefox"))
--     end
-- end)

-- ─── clipboard.sh ───
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"), { locked = true })
hl.bind("ALT + V",         hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh images"), { locked = true })

-- ─── websites.sh ───
local useIntegratedMangaReader = true
local mangaAction = useIntegratedMangaReader and "manga-reader" or "manga"

hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("~/.config/hypr/scripts/websites.sh"))
hl.bind("ALT + M",         hl.dsp.exec_cmd("~/.config/hypr/scripts/websites.sh " .. mangaAction))

-- ─── media.py ───
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/media.py"),      { locked = true })
hl.bind(mainMod .. " + G",  hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/media.py music"), { locked = true })
hl.bind("ALT + F1",         hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/media.py stop"), { locked = true })
hl.bind("ALT + G",          hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/media.py video"))

hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

hl.bind("F1",              hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/player-next.py"), { locked = true })
hl.bind("ALT + K",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("ALT + J",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("ALT + H",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ─── cycle   ───
hl.bind(mainMod .. " + SUPER_L", function()
    local active_ws = hl.get_active_workspace()
    local active_id = active_ws and active_ws.id or 1
    local valid = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 and ws.windows > 0 then
            table.insert(valid, ws.id)
        end
    end
    table.sort(valid)
    if #valid <= 1 then return end
    local next_ws = valid[1]
    for i, id in ipairs(valid) do
        if id == active_id then
            next_ws = valid[(i % #valid) + 1]
            break
        end
    end
    hl.dispatch(hl.dsp.focus({ workspace = next_ws }))
end, { release = true })

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell.sh ipc panels toggle"), { description = "Open Hub" })

hl.bind("F6", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell.sh volume mute"), { repeating = true })
hl.bind("F7", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell.sh volume down"), { repeating = true })
hl.bind("F8", hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell.sh volume up"), { repeating = true })

hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -C && ~/.config/hypr/scripts/quickshell.sh notify -1 2000 0 '🔔 Notifications cleared'"))
hl.bind(mainMod .. " + U", function()
    hl.exec_cmd("~/.config/hypr/scripts/quickshell.sh notify 0 2000 'rgb(cba6f7)' '󰔟 Timer started (waiting 2s)...'")
    hl.timer(function()
        hl.exec_cmd("~/.config/hypr/scripts/quickshell.sh notify 5 3000 'rgb(80ff80)' '󰄬 Timer completed (2s elapsed)!'")
    end, { timeout = 2000, type = "oneshot" })
end)

local switcherHeld = false
hl.bind("ALT + Escape", function()
    switcherHeld = true
    hl.exec_cmd("~/.config/hypr/scripts/quickshell.sh ipc windowSwitcher next")
end, { repeating = true, description = "Window switcher: next window" })
hl.bind("ALT_L", function()
    if switcherHeld then
        switcherHeld = false
        hl.exec_cmd("~/.config/hypr/scripts/quickshell.sh ipc windowSwitcher acceptHeld")
    end
end, { release = true, non_consuming = true, ignore_mods = true, description = "Window switcher: confirm on Alt release" })

-- ───  workspace notify  ───
local ws_icons = { [1] = "➊", [2] = "➋", [3] = "➌", [4] = "➍", [5] = "➎", [6] = "➏", [7] = "➐", [8] = "➑", [9] = "➒", [10] = "➓" }
local class_names = {
    ["org.telegram.desktop"] = "telegram",
    ["dev.zed.zed"] = "zed",
    ["org.pwmt.zathura"] = "zathura",
    ["zathura"] = "zathura",
    ["brave-browser"] = "brave",
    ["code-oss"] = "code",
    ["kitty"] = "kitty",
    ["kitty-float"] = "kitty",
    ["firefox"] = "firefox",
    ["librewolf"] = "firefox",
    ["zen"] = "zen",
    ["zen-browser"] = "zen",
    ["thunar"] = "thunar",
    ["mpv"] = "mpv",
    ["spotify"] = "spotify",
}

local class_icons = {
    ["kitty"] = "󰄛",
    ["firefox"] = "󰈹",
    ["librewolf"] = "󰈹",
    ["zen"] = "󰈹",
    ["brave"] = "󰖟",
    ["telegram"] = "󰅣",
    ["code"] = "󰨞",
    ["zed"] = "󰞷",
    ["thunar"] = "󰉋",
    ["mpv"] = "󰕼",
    ["zathura"] = "󰈦",
    ["spotify"] = "󰓇",
}

local function get_proc_mem(pid)
    if not pid or pid <= 0 then return nil end
    local f = io.open("/proc/" .. pid .. "/status", "r")
    if not f then return nil end
    local rss = nil
    for line in f:lines() do
        local val = line:match("^VmRSS:%s+(%d+)%s+kB")
        if val then
            rss = tonumber(val)
            break
        end
    end
    f:close()
    if not rss then return nil end
    local mb = rss / 1024
    if mb >= 1024 then
        return string.format("%.2f GB", mb / 1024)
    end
    return string.format("%.0f MB", mb)
end

local show_workspace_notify = true
local show_workspace_mem    = false

hl.on("workspace.active", function(ws)
    if not show_workspace_notify then return end

    local ws_label = ws_icons[ws.id] or ("󰣇  " .. tostring(ws.name or ws.id))
    local text = ws_label
    local heading = ws_label
    local app_class = ""
    local w = hl.get_active_window()
    if w and w.class and w.class ~= "" then
        local raw = string.lower(w.class)
        local cls = class_names[raw] or raw
        app_class = w.class
        heading = ws_label .. "  " .. cls
        local icon = class_icons[cls] or class_icons[raw] or ""
        text = ws_label .. " " .. icon .. "  " .. cls
        if show_workspace_mem then
            local mem = get_proc_mem(w.pid)
            if mem then
                text = text .. "\n󰘚  " .. mem
            end
        end
    end
    text = text .. "\n" .. os.date("%H:%M:%S")
    local quoted_text = "'" .. text:gsub("'", "'\\''") .. "'"
    local quoted_class = "'" .. app_class:gsub("'", "'\\''") .. "'"
    local quoted_heading = "'" .. heading:gsub("'", "'\\''") .. "'"
    hl.exec_cmd("~/.config/hypr/scripts/quickshell.sh workspace " .. quoted_text .. " " .. quoted_class .. " " .. quoted_heading)
end)
