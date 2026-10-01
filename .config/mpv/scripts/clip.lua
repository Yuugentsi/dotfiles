local start_time = nil

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

local function format_stamp(sec)
    sec = math.floor(sec or 0)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if h > 0 then
        return string.format("%02dh%02dm%02ds", h, m, s)
    elseif m > 0 then
        return string.format("%02dm%02ds", m, s)
    end
    return string.format("%02ds", s)
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

local function sanitize_folder(name)
    if not name then return "untitled" end
    name = name:gsub("[/%\\:]", "_"):gsub("%z", "_")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or name == "." or name == ".." then
        return "untitled"
    end
    return name
end

local function toggle_clip()
    local path = mp.get_property("path")
    if not path or path == "" or path:find("^http://") or path:find("^https://") then
        mp.osd_message("⚠️ Local files only", 1500)
        return
    end

    local mp_utils = require "mp.utils"
    if not path:find("^/") and not path:find("^[a-zA-Z]:") then
        path = mp_utils.join_path(mp.get_property("working-directory", ""), path)
    end

    local pos = mp.get_property_number("time-pos")
    if not pos then return end

    if not start_time then
        start_time = pos
        mp.osd_message(string.format("✂️ %s", format_clock(start_time)), 1500)
        return
    end

    local end_time = pos
    if end_time <= start_time then
        mp.osd_message("⚠️ Canceled (end <= start)", 1500)
        start_time = nil
        return
    end

    local in_point = start_time
    local duration = end_time - in_point
    start_time = nil

    local raw_title = mp.get_property("filename/no-ext") or "untitled"
    local folder_name = sanitize_folder(raw_title)
    local base_clips_dir = os.getenv("HOME") .. "/0/videos/clips"
    local out_dir = string.format("%s/%s", base_clips_dir, folder_name)
    os.execute(string.format("mkdir -p %q", out_dir))

    local in_str = format_stamp(in_point)
    local out_str = format_stamp(end_time)
    local base_name = string.format("%s_%s", in_str, out_str)
    local out_name = base_name .. ".mp4"
    local out_path = string.format("%s/%s", out_dir, out_name)

    local counter = 1
    while true do
        local f = io.open(out_path, "r")
        if not f then break end
        f:close()
        out_name = string.format("%s_%d.mp4", base_name, counter)
        out_path = string.format("%s/%s", out_dir, out_name)
        counter = counter + 1
    end

    mp.osd_message(string.format("⏳ %s  •  %s (%s)", format_clock(in_point), format_clock(end_time), format_duration(duration)), 1500)

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        args = {
            "ffmpeg",
            "-y",
            "-ss", string.format("%.3f", in_point),
            "-i", path,
            "-t", string.format("%.3f", duration),
            "-c", "copy",
            "-avoid_negative_ts", "make_zero",
            "-movflags", "+faststart",
            out_path,
        },
    }, function(success, res)
        if res and res.status == 0 then
            mp.osd_message(string.format("📁 %s/\n🎬 %s  (%s)", folder_name, out_name, format_duration(duration)), 2500)
        else
            mp.osd_message("❌ Clip failed", 2000)
        end
    end)
end

mp.add_forced_key_binding("c", "toggle-clip-c", toggle_clip)
mp.add_forced_key_binding("C", "toggle-clip-C", toggle_clip)

mp.register_event("end-file", function()
    start_time = nil
end)
