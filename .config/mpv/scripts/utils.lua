-- ─────────── osd / general ───────────
mp.set_property("osd-font", "Cartograph CF")
mp.set_property("osd-font-size", "22")
mp.set_property("osd-color", "#ffffff")
mp.set_property("osd-border-color", "#000000")
mp.set_property("osd-border-size", "1.5")
mp.set_property("osd-bold", "yes")

-- ─────────── fast forward ───────────
local fast_on = false
local orig_speed = 1.0

local function handle_fast(table)
    if table.event == "down" then
        if not fast_on then
            orig_speed = mp.get_property_number("speed", 1.0)
            mp.set_property("speed", 3.0)
            fast_on = true
        end
    elseif table.event == "up" then
        if fast_on then
            mp.set_property("speed", orig_speed)
            fast_on = false
        end
    end
end

-- ─────────── eta / time ───────────
local function format_time(seconds)
    if not seconds or seconds < 0 then
        return "00:00"
    end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function show_eta()
    local pos = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")
    local speed = mp.get_property_number("speed", 1.0)
    if not pos or not duration or duration <= 0 then
        return
    end

    local remaining = (duration - pos) / speed
    local end_time = os.date("%H:%M", os.time() + math.floor(remaining))
    local percent = math.floor((pos / duration) * 100)

    local bar_len = 16
    local filled = math.floor((percent / 100) * bar_len)
    local bar = string.rep("■", filled) .. string.rep("□", bar_len - filled)

    local msg = format_time(pos) .. " / " .. format_time(duration) .. "  •  "
        .. percent .. "%\n-"
        .. format_time(remaining) .. "  ⌛ " .. end_time .. "\n"
        .. bar

    mp.osd_message(msg, 2000)
    mp.add_timeout(2, function()
        mp.osd_message("", 0)
    end)
end

-- ─────────── screenshot clipboard ───────────
local ENABLE_CLIPBOARD = true

local function screenshot_clipboard()
    if not ENABLE_CLIPBOARD then
        mp.osd_message("clipboard disabled", 2000)
        return
    end
    local tmp = "/tmp/mpv_clip.jpg"
    mp.commandv("screenshot-to-file", tmp, "video")
    mp.command_native_async({
        name = "subprocess",
        args = { "sh", "-c", "wl-copy -t image/jpeg < " .. tmp },
        playback_only = false,
        detach = true,
    }, function() end)
    mp.osd_message("📋", 300)
    mp.add_timeout(0.3, function()
        mp.osd_message("", 0)
    end)
end

-- ─────────── help ───────────

local function show_help()
    local text = table.concat({
        "SPACE pause",
        "q quit",
        "ENTER fast fwd",
        "[ ] speed",
        "m mute",
        "- = volume",
        "← → seek",
        "↑ ↓ +5s",
        "TAB skip85s",
        ". , frame",
        "i stats",
        "a d prev/next",
        "f fullscreen",
        "b sub",
        "s screenshot",
        "t eta",
        "Ctrl+C clipboard",
        "DEL trash",
    }, "\n")
    mp.osd_message(text, 4000)
    mp.add_timeout(4, function()
        mp.osd_message("", 0)
    end)
end
-- ─────────── bindings ───────────
mp.add_forced_key_binding("ENTER", "press-fast-enter", handle_fast, { complex = true })
mp.add_forced_key_binding("KP_ENTER", "press-fast-kp-enter", handle_fast, { complex = true })
mp.add_forced_key_binding("t", "eta-show", show_eta)
mp.add_forced_key_binding("T", "eta-show-T", show_eta)
mp.add_forced_key_binding("Ctrl+c", "screenshot-clipboard", screenshot_clipboard)
mp.add_forced_key_binding("C", "screenshot-clipboard-C", screenshot_clipboard)
mp.add_forced_key_binding("h", "help-show", show_help)
