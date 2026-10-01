local mp_utils = require "mp.utils"
local assdraw = require "mp.assdraw"

-- ─────────── osd / general ───────────
mp.set_property("osd-font", "Cartograph CF")
mp.set_property("osd-font-size", "22")
mp.set_property("osd-color", "#ffffff")
mp.set_property("osd-border-size", "1.5")
mp.set_property("osd-bold", "yes")

-- ─────────── fast forward ───────────
local fast_on = false
local orig_speed = 1.0

local function handle_fast(table)
    if table.event == "down" then
        if not fast_on then
            orig_speed = mp.get_property_number("speed", 1.0)
            mp.set_property("speed", 1.3)
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

-- ─────────── pasteurl ───────────
local function paste_and_play(fmt)
    mp.command_native_async({
        name = "subprocess",
        args = { "sh", "-c", "timeout 2 wl-paste 2>/dev/null || echo ''" },
        playback_only = false,
        capture_stdout = true,
    }, function(_, res)
        local url = ""
        if res and res.stdout then
            url = res.stdout:gsub("^%s*(.-)%s*$", "%1")
        end
        if url == "" then
            mp.osd_message("empty", 1000)
            return
        end
        mp.set_property("ytdl-format", fmt)
        mp.commandv("loadfile", url, "replace")
    end)
end

local function paste_360() paste_and_play("best[height<=360]") end
local function paste_720() paste_and_play("best[height<=720]") end

local paste_btn = {
    x = 48, y = 48, size = 36,
    visible = false,
}

local function show_paste_button()
    if paste_btn.visible then return end
    local ass = assdraw.ass_new()
    ass:draw_start()
    ass:append("{\\bord0\\shad0\\1c&H222222&\\alpha&H88&}")
    ass:rect_cw(paste_btn.x, paste_btn.y, paste_btn.x + paste_btn.size, paste_btn.y + paste_btn.size)
    ass:draw_stop()
    ass:pos(paste_btn.x + paste_btn.size / 2, paste_btn.y + paste_btn.size / 2)
    ass:append("{\\fnSymbola\\fs18\\bord0\\shad0\\1c&HFFFFFF&}")
    ass:append("\239\157\145")
    mp.set_osd_ass(0, 0, ass.text)
    paste_btn.visible = true
end

local function hide_paste_button()
    if not paste_btn.visible then return end
    mp.set_osd_ass(0, 0, "")
    paste_btn.visible = false
end

-- ─────────── crop ───────────
local crop_timer = nil
local crop_hwdec_backup = nil

local function cleanup_crop()
    if crop_timer then
        crop_timer:kill()
        crop_timer = nil
    end
    mp.command("no-osd vf remove @utils-crop")
    if crop_hwdec_backup then
        mp.set_property("hwdec", crop_hwdec_backup)
        crop_hwdec_backup = nil
    end
end

local function toggle_crop()
    local current_crop = mp.get_property("video-crop")
    if current_crop and current_crop ~= "" then
        mp.command("set file-local-options/video-crop ''")
        mp.osd_message("Crop: off", 1.5)
        return
    end

    if crop_timer then
        return
    end

    local hwdec_current = mp.get_property("hwdec-current", "no")
    if hwdec_current:find("-copy$") == nil and hwdec_current ~= "no" then
        crop_hwdec_backup = mp.get_property("hwdec")
        mp.set_property("hwdec", "no")
    end

    mp.command("no-osd vf pre @utils-crop:cropdetect=limit=24/255:round=2:reset=0")
    mp.osd_message("Detecting crop...", 1)

    crop_timer = mp.add_timeout(0.8, function()
        local meta = mp.get_property_native("vf-metadata/utils-crop")
        cleanup_crop()

        if not meta or not meta["lavfi.cropdetect.w"] or not meta["lavfi.cropdetect.h"] then
            mp.osd_message("Crop: failed", 1.5)
            return
        end

        local w = tonumber(meta["lavfi.cropdetect.w"])
        local h = tonumber(meta["lavfi.cropdetect.h"])
        local x = tonumber(meta["lavfi.cropdetect.x"])
        local y = tonumber(meta["lavfi.cropdetect.y"])
        local orig_w = mp.get_property_number("width", 0)
        local orig_h = mp.get_property_number("height", 0)

        if w and h and orig_w > 0 and orig_h > 0 and (w < orig_w or h < orig_h) then
            mp.command(string.format("set file-local-options/video-crop %dx%d+%d+%d", w, h, x, y))
            mp.osd_message(string.format("Crop: %dx%d", w, h), 2)
        end
    end)
end

-- ─────────── screentime ───────────
local st_state = {
    daily = {},
    videos = {},
}

local session_seconds = 0
local file_session_seconds = 0
local file_session_start = nil
local file_session_path = nil
local file_session_title = nil
local save_counter = 0

local display_timer = nil
local hide_timeout = nil

local weekdays = { [0] = "Sun", [1] = "Mon", [2] = "Tue", [3] = "Wed", [4] = "Thu", [5] = "Fri", [6] = "Sat" }

local function is_video()
    local vid = mp.get_property("vid")
    if not vid or vid == "no" then
        return false
    end
    local is_image = mp.get_property_native("current-tracks/video/image")
    if is_image then
        return false
    end
    return true
end

local function get_state_path()
    local dir = os.getenv("HOME") .. "/.cache/mpv/screentime"
    os.execute("mkdir -p " .. dir)
    return dir .. "/screentime.json"
end

local function is_audio_path(path)
    if not path then return true end
    local ext = path:match("%.([^%.]+)$")
    if not ext then return false end
    ext = ext:lower()
    return ext == "flac" or ext == "mp3" or ext == "wav" or ext == "ogg"
        or ext == "m4a" or ext == "aac" or ext == "opus" or ext == "wma"
end

local function load_screentime_data()
    local path = get_state_path()
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then
            local raw = mp_utils.parse_json(content)
            if type(raw) == "table" then
                local filtered_videos = {}
                if type(raw.videos) == "table" then
                    for _, v in ipairs(raw.videos) do
                        if v.path and not is_audio_path(v.path) then
                            table.insert(filtered_videos, v)
                        end
                    end
                end

                local data = {
                    daily = raw.daily or {},
                    videos = filtered_videos,
                }
                for k, v in pairs(raw) do
                    if type(k) == "string" and k:match("^%d%d%d%d%-%d%d%-%d%d$") then
                        data.daily[k] = v
                    end
                end
                return data
            end
        end
    end
    return {
        daily = {},
        videos = {},
    }
end

local function format_duration(sec)
    sec = math.floor(sec or 0)
    if sec < 60 then
        return string.format("%ds", sec)
    end
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m < 60 then
        return string.format("%dm %02ds", m, s)
    end
    local h = math.floor(m / 60)
    m = m % 60
    return string.format("%dh %02dm %02ds", h, m, s)
end

local function format_clock(sec)
    if not sec or sec < 0 then
        return "00:00"
    end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local function commit_video_session()
    local path = file_session_path
    if file_session_seconds < 60 or not path or path == "" or is_audio_path(path) then
        file_session_seconds = 0
        file_session_start = nil
        file_session_path = nil
        file_session_title = nil
        return
    end

    local title = file_session_title or path
    local target_vid = nil

    for _, v in ipairs(st_state.videos) do
        if v.path == path then
            target_vid = v
            break
        end
    end

    if not target_vid then
        target_vid = {
            title = title,
            path = path,
            total_watched = 0,
            sessions = {},
        }
        table.insert(st_state.videos, target_vid)
    end

    target_vid.total_watched = (target_vid.total_watched or 0) + file_session_seconds
    table.insert(target_vid.sessions, {
        started_at = file_session_start or os.date("%Y-%m-%d %H:%M"),
        duration = format_duration(file_session_seconds),
    })

    while #target_vid.sessions > 30 do
        table.remove(target_vid.sessions, 1)
    end

    while #st_state.videos > 50 do
        table.remove(st_state.videos, 1)
    end

    file_session_seconds = 0
    file_session_start = nil
    file_session_path = nil
    file_session_title = nil
end

local function save_screentime_data()
    local path = get_state_path()
    local f = io.open(path, "w")
    if f then
        f:write(mp_utils.format_json(st_state))
        f:close()
    end
end

st_state = load_screentime_data()

local function render_screentime()
    local now = os.time()
    local total_time = 0
    local day_lines = {}

    for i = 6, 0, -1 do
        local t = now - i * 86400
        local d = os.date("%Y-%m-%d", t)
        local dm = os.date("%d/%m", t)
        local w = tonumber(os.date("%w", t))
        local val = st_state.daily[d] or 0
        if val > 0 then
            total_time = total_time + val
            local label = weekdays[w]
            table.insert(day_lines, string.format("%s (%s)  %s", label, dm, format_duration(val)))
        end
    end

    local lines = {
        format_duration(total_time),
        string.format("SESSION      %s", format_duration(session_seconds)),
    }

    if #day_lines > 0 then
        table.insert(lines, "─────────────────────────")
        for _, dl in ipairs(day_lines) do
            table.insert(lines, dl)
        end
    end

    local pos = mp.get_property_number("time-pos")
    local dur = mp.get_property_number("duration")

    if is_video() and pos and dur and dur > 0 then
        local percent = math.floor((pos / dur) * 100)
        local bar_len = 16
        local filled = math.floor((percent / 100) * bar_len)
        local bar = string.rep("■", filled) .. string.rep("□", bar_len - filled)

        table.insert(lines, "─────────────────────────")
        table.insert(lines, string.format("🎬 %s / %s  •  %d%%\n%s", format_clock(pos), format_clock(dur), percent, bar))
    end

    mp.osd_message(table.concat(lines, "\n"), 1.2)
end

local function hide_screentime()
    if display_timer then
        display_timer:kill()
        display_timer = nil
    end
    if hide_timeout then
        hide_timeout:kill()
        hide_timeout = nil
    end
    mp.osd_message("", 0)
end

local function toggle_screentime()
    if display_timer then
        hide_screentime()
        return
    end

    render_screentime()
    display_timer = mp.add_periodic_timer(0.5, render_screentime)
    hide_timeout = mp.add_timeout(4, hide_screentime)
end

mp.add_periodic_timer(1, function()
    local paused = mp.get_property_bool("pause", true)
    local idle = mp.get_property_bool("idle-active", false)
    if not paused and not idle and is_video() then
        session_seconds = session_seconds + 1
        file_session_seconds = file_session_seconds + 1
        if not file_session_start then
            file_session_start = os.date("%Y-%m-%d %H:%M")
        end
        if not file_session_path then
            file_session_path = mp.get_property("path")
            file_session_title = mp.get_property("media-title") or mp.get_property("filename") or file_session_path
        end

        local today = os.date("%Y-%m-%d")
        st_state.daily[today] = (st_state.daily[today] or 0) + 1

        save_counter = save_counter + 1
        if save_counter >= 30 then
            save_counter = 0
            save_screentime_data()
        end
    end
end)

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
        "Ctrl+S clipboard",
        "x crop",
        "c clip",
        "G screentime",
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
mp.add_forced_key_binding("Ctrl+s", "screenshot-clipboard-ctrl-s", screenshot_clipboard)
mp.add_forced_key_binding("x", "toggle-crop", toggle_crop)
mp.add_forced_key_binding("h", "help-show", show_help)
mp.add_forced_key_binding("G", "toggle-screentime-G", toggle_screentime)
mp.add_forced_key_binding("g", "toggle-screentime-g", toggle_screentime)
mp.add_forced_key_binding("k", "paste-360", paste_360)
mp.add_forced_key_binding("Ctrl+k", "paste-720", paste_720)

mp.add_key_binding("u", "toggle-paste-button", function()
    if paste_btn.visible then hide_paste_button() else show_paste_button() end
end)

mp.add_key_binding("mouse_btn0", "pasteurl-click", function()
    if not paste_btn.visible then return end
    local cp = mp.get_property_native("cursor-position")
    if cp and cp.x >= paste_btn.x and cp.x <= paste_btn.x + paste_btn.size
        and cp.y >= paste_btn.y and cp.y <= paste_btn.y + paste_btn.size then
        paste_360()
    end
end)

mp.add_key_binding("mouse_btn2", "pasteurl-hide", function()
    if paste_btn.visible then hide_paste_button() end
end)

mp.register_event("end-file", function()
    cleanup_crop()
    commit_video_session()
    save_screentime_data()
end)

mp.register_event("shutdown", function()
    commit_video_session()
    save_screentime_data()
end)

mp.register_event("file-loaded", function()
    local new_path = mp.get_property("path")
    if file_session_path and new_path ~= file_session_path then
        commit_video_session()
        save_screentime_data()
    end

    if new_path and new_path ~= "" then
        local dir = os.getenv("HOME") .. "/.local/state/mpv"
        local f = io.open(dir .. "/last_played", "w")
        if f then
            f:write(new_path .. "\n")
            f:close()
        end
    end
end)

if mp.get_property_number("playlist-count", 0) == 0 then
    local dir = os.getenv("HOME") .. "/.local/state/mpv"
    local f = io.open(dir .. "/last_played", "r")
    if f then
        local last = f:read("*line")
        f:close()
        if last and last ~= "" then
            mp.commandv("loadfile", last)
        end
    end
end
