-- ─── utils (all scripts & autostart workspace) ───
local mainMod = "SUPER"

-- ─── utils.sh ───
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh thunar"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh video"))
hl.bind("ALT + Q",         hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh kitty"))
hl.bind("ALT + W",         hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh mpv"))
hl.bind("ALT + T",         hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh toggle"))
hl.bind("ALT + E",         hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/utils.sh switcher"))

-- ─── clipboard ───
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"), { locked = true })
hl.bind("ALT + V",         hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh images"), { locked = true })

-- ─── websites ───
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("~/.config/hypr/scripts/websites.sh"))

-- ─── music ───
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/music.py"),      { locked = true })
hl.bind(mainMod .. " + G",  hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/music.py menu"), { locked = true })
hl.bind("ALT + F1",         hl.dsp.exec_cmd("python3 -B ~/.config/hypr/scripts/music.py stop"), { locked = true })

-- ─── cycle non-empty workspaces (SUPER release) ───
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

-- ─── workspace  ───
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
}

hl.on("workspace.active", function(ws)
    local msg = ws_icons[ws.id] or ("󰣇  " .. tostring(ws.name or ws.id))
    local w = hl.get_active_window()
    if w and w.class and w.class ~= "" then
        local raw = string.lower(w.class)
        local cls = class_names[raw] or raw
        msg = msg .. "  ·  " .. cls
    end
    for _, n in ipairs(hl.notification.get()) do
        n:dismiss()
    end
    hl.notification.create({
        text = "fontsize:16 " .. msg,
        timeout = 1800,
        color = "rgb(cba6f7)",
        icon = "info",
    })
end)
