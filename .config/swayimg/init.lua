-- ─── swayimg/init.lua ───
--
--   prev          ←  h  Prior  BackSpace
--   next          →  l  Next  Space
--   random         y
--   gallery/back   g / Return
--   zoom in/out    + = / -
--   reset          0  r
--   fullscreen     f
--   toggle info    t
--   cycle sort     s
--   trash          D
--   open folder    O
--   load all imgs  N
--   copy img       c
--   copy→wallpapers  Ctrl-c
--   EXIF           Ctrl-e
--   rename all     Ctrl-r
--   wallpaper      W
--   wallpaper blur B
--   wallpaper dark Ctrl-b
--   quit           q
--
-- ─── constants

local HOME             = os.getenv("HOME")
local WALLPAPERS_CACHE = HOME .. "/.cache/scripts/wallpapers"
local WALLPAPERS_DIR   = HOME .. "/media/pictures/wallpapers"

-- ─── helpers

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function dirname(path)
    return path and path:match("^(.*)/[^/]*$") or nil
end

-- Register both lowercase and uppercase variant of a key
local function on_key_both(mode, key, handler)
    mode.on_key(key, handler)
    local other
    if key:match("^Ctrl%-.$") then
        local base = key:sub(-1)
        other = "Ctrl-" .. (base:match("^%l$") and base:upper() or base:lower())
    elseif #key == 1 then
        other = key:match("^%l$") and key:upper() or key:lower()
    end
    if other and other ~= key then
        mode.on_key(other, handler)
    end
end

-- ─── global config

swayimg.enable_decoration(false)
swayimg.imagelist.enable_adjacent(true)
swayimg.imagelist.enable_fsmon(false)
swayimg.text.set_timeout(3)
swayimg.imagelist.set_order("numeric")
swayimg.viewer.set_default_scale("fit")
swayimg.viewer.set_window_background("auto")
swayimg.viewer.limit_preload(6)
swayimg.viewer.limit_history(6)

local empty_text = {}

local default_viewer_text = {
    "{list.index}/{list.total}",
}

local exif_viewer_text = {
    "{name}  ({list.index}/{list.total})",
    "{sizehr}  {format}  {frame.width}x{frame.height}",
    "{meta.Exif.Image.Model}   {meta.Exif.Photo.FocalLength}",
    "ISO {meta.Exif.Photo.ISOSpeedRatings}  f/{meta.Exif.Photo.FNumber}"
    .. "  {meta.Exif.Photo.ExposureTime}s",
    "{meta.Exif.GPSInfo.GPSLatitude}  {meta.Exif.GPSInfo.GPSLongitude}",
    "{meta.Exif.Photo.DateTimeOriginal}",
    "{path}",
}

local exif_on = false

local orders = { "none", "alpha", "numeric", "mtime", "size", "random" }
local order_idx = 3

-- ─── path resolution

local function viewer_path()
    local image = swayimg.viewer.get_image()
    return image and image.path
end

local function gallery_path()
    local image = swayimg.gallery.get_image()
    return image and image.path
end

-- ─── copy to clipboard

local function copy_image(path)
    if not path or path == "" then
        swayimg.text.set_status("No image to copy")
        return
    end

    local command = "sh -c 'mime=$(file --mime-type -b \"$1\");"
        .. " wl-copy --type \"$mime\" < \"$1\"'"
        .. " sh " .. shell_quote(path)

    if os.execute(command) then
        swayimg.text.set_status("Copied image")
    else
        swayimg.text.set_status("Failed to copy image")
    end
end

local function copy_viewer_image()
    copy_image(viewer_path())
end

local function copy_gallery_image()
    copy_image(gallery_path())
end

-- ─── copy to wallpapers folder

local function copy_to_wallpapers(path)
    if not path or path == "" then
        swayimg.text.set_status("No image to copy")
        return
    end

    local command = "mkdir -p " .. shell_quote(WALLPAPERS_DIR)
        .. " && cp -n -- " .. shell_quote(path) .. " " .. shell_quote(WALLPAPERS_DIR .. "/")

    if os.execute(command) then
        swayimg.text.set_status("Copied to wallpapers")
    else
        swayimg.text.set_status("Failed to copy to wallpapers")
    end
end

local function copy_viewer_to_wallpapers()
    copy_to_wallpapers(viewer_path())
end

local function copy_gallery_to_wallpapers()
    copy_to_wallpapers(gallery_path())
end

-- ─── set wallpaper

local function set_wallpaper(path)
    if not path or path == "" then
        swayimg.text.set_status("No image to set as wallpaper")
        return
    end

    local cached_path   = WALLPAPERS_CACHE .. "/current"
    local wallpaper_txt = WALLPAPERS_CACHE .. "/wallpaper"
    local hyprpaper_cfg = WALLPAPERS_CACHE .. "/hyprpaper.conf"

    local command       = "mkdir -p " .. shell_quote(WALLPAPERS_CACHE)
        .. " && cp -- " .. shell_quote(path) .. " " .. shell_quote(cached_path)
        .. " && sh -c '"
        .. "printf \"%s\\n\" \"$1\" > \"" .. wallpaper_txt .. "\"; "
        .. "if ! pgrep -x hyprpaper >/dev/null; then "
        .. "printf \"splash = false\\nipc = true\\npreload = %s\\n"
        .. "wallpaper = ,%s,cover\\n\" \"$1\" \"$1\""
        .. " > \"" .. hyprpaper_cfg .. "\"; "
        .. "hyprpaper -c \"" .. hyprpaper_cfg .. "\""
        .. " >/tmp/hyprpaper-swayimg.log 2>&1 & "
        .. "sleep 0.5; "
        .. "fi; "
        .. "hyprctl hyprpaper preload \"$1\" >/dev/null 2>&1 || true; "
        .. "hyprctl hyprpaper wallpaper \",$1,cover\" >/dev/null 2>&1; "
        .. "hyprctl hyprpaper unload unused >/dev/null 2>&1 || true"
        .. "' sh " .. shell_quote(cached_path)

    if os.execute(command) then
        swayimg.text.set_status("Wallpaper set")
    else
        swayimg.text.set_status("Failed to set wallpaper")
    end
end

local function set_wallpaper_blur(path)
    if not path or path == "" then
        swayimg.text.set_status("No image to set as wallpaper")
        return
    end

    local blurred_path = WALLPAPERS_CACHE .. "/blurred"
    local q            = shell_quote(path)
    local bq           = shell_quote(blurred_path)

    local blur_cmd     = "mkdir -p " .. shell_quote(WALLPAPERS_CACHE)
        .. " && (command -v magick >/dev/null 2>&1"
        .. " && magick " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 " .. bq
        .. " || (command -v convert >/dev/null 2>&1"
        .. " && convert " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 " .. bq
        .. " || gm convert " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 60 " .. bq .. "))"

    if not os.execute(blur_cmd) then
        swayimg.text.set_status("Failed to blur (install imagemagick)")
        return
    end

    set_wallpaper(blurred_path)
end

local function set_viewer_wallpaper()
    set_wallpaper(viewer_path())
end

local function set_viewer_wallpaper_blur()
    set_wallpaper_blur(viewer_path())
end

local function set_gallery_wallpaper()
    set_wallpaper(gallery_path())
end

local function set_gallery_wallpaper_blur()
    set_wallpaper_blur(gallery_path())
end

-- ─── set wallpaper (blur + dark)

local function set_wallpaper_blur_dark(path)
    if not path or path == "" then
        swayimg.text.set_status("No image to set as wallpaper")
        return
    end

    local dark_path = WALLPAPERS_CACHE .. "/blurred_dark"
    local q         = shell_quote(path)
    local dq        = shell_quote(dark_path)

    local cmd       = "mkdir -p " .. shell_quote(WALLPAPERS_CACHE)
        .. " && (command -v magick >/dev/null 2>&1"
        .. " && magick " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 30 " .. dq
        .. " || (command -v convert >/dev/null 2>&1"
        .. " && convert " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 30 " .. dq
        .. " || gm convert " .. q
        .. " -scale 1920x1080^ -gravity center -extent 1920x1080 -blur 0x15 -modulate 30 " .. dq .. "))"

    if not os.execute(cmd) then
        swayimg.text.set_status("Failed to blur (install imagemagick)")
        return
    end

    set_wallpaper(dark_path)
end

local function set_viewer_wallpaper_blur_dark()
    set_wallpaper_blur_dark(viewer_path())
end

local function set_gallery_wallpaper_blur_dark()
    set_wallpaper_blur_dark(gallery_path())
end

-- ─── zoom

local function zoom_viewer(factor)
    local scale = swayimg.viewer.get_scale()
    swayimg.viewer.set_abs_scale(scale * factor)
end

-- ─── trash

local function trash_viewer_image()
    local original_path = viewer_path()
    if not original_path or original_path == "" then
        swayimg.text.set_status("No image to trash")
        return
    end

    swayimg.viewer.switch_image("next")

    if os.execute("gio trash -- " .. shell_quote(original_path)) then
        swayimg.imagelist.remove(original_path)
        swayimg.text.set_status("Moved to trash")
    else
        swayimg.viewer.open(original_path)
        swayimg.text.set_status("Failed to trash image")
    end
end

local function trash_gallery_image()
    local path = gallery_path()
    if not path or path == "" then
        swayimg.text.set_status("No image to trash")
        return
    end

    swayimg.gallery.switch_image("next")

    if os.execute("gio trash -- " .. shell_quote(path)) then
        swayimg.imagelist.remove(path)
        swayimg.text.set_status("Moved to trash")
    else
        swayimg.text.set_status("Failed to trash image")
    end
end

-- ─── load all images

local function open_all_images()
    local count = 0
    local pictures = shell_quote(HOME .. "/Pictures")
    local media = shell_quote(HOME .. "/media/pictures")
    local p = io.popen("find " ..
        pictures .. " " .. media .. " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \\) 2>/dev/null")
    if p then
        for line in p:lines() do
            swayimg.imagelist.add(line)
            count = count + 1
        end
        p:close()
    end

    if count > 0 then
        swayimg.set_mode("gallery")
        swayimg.text.set_status("Loaded " .. count .. " images")
    else
        swayimg.text.set_status("No images found")
    end
end

-- ─── rename all

local function rename_all_random()
    local entries = swayimg.imagelist.get()
    if #entries == 0 then
        swayimg.text.set_status("No images to rename")
        return
    end

    local count = 0
    for _, entry in ipairs(entries) do
        local old = entry.path
        local ext = old:match("%.[^%.\\/]+$") or ""
        local dir = old:match("^(.*)/[^/]*$")
        if dir then
            local new = dir .. "/" .. math.random(100000, 999999) .. ext
            if os.rename(old, new) then
                swayimg.imagelist.remove(old)
                swayimg.imagelist.add(new)
                count = count + 1
            end
        end
    end

    swayimg.text.set_status("Renamed " .. count .. " images")
end

-- ─── sort order

local function cycle_order()
    order_idx = order_idx % #orders + 1
    swayimg.imagelist.set_order(orders[order_idx])
    swayimg.text.set_status("Order: " .. orders[order_idx])
end

-- ─── open folder

local function open_viewer_folder()
    local dir = dirname(viewer_path())
    if not dir or dir == "" then
        swayimg.text.set_status("No folder to open")
        return
    end

    os.execute("thunar " .. shell_quote(dir) .. " >/dev/null 2>&1 &")
end

-- ─── notify

local function notify(title, message)
    local hyprland = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if hyprland and hyprland ~= "" then
        local command = "hyprctl notify -1 2000 "
            .. shell_quote("rgb(a855f7)") .. " " .. shell_quote(message)
            .. " >/dev/null 2>&1"
        if os.execute(command) then
            return
        end
    end

    os.execute("notify-send -e -t 2000 "
        .. shell_quote(title) .. " " .. shell_quote(message))
end

-- ─── shortcuts help

local function show_shortcuts()
    local text = table.concat({
        "Right/Next/Space: next",
        "Left/Prior/BackSpace: previous",
        "c: copy image",
        "Ctrl-c: copy to wallpapers",
        "Ctrl-e: EXIF info",
        "t: toggle info",
        "f: fullscreen",
        "g: gallery",
        "W: set wallpaper",
        "B: set wallpaper (blur)",
        "+/-: zoom",
        "0/r: reset",
        "s: cycle sort order",
        "y: random image",
        "D: move to trash",
        "O: open folder",
        "q: quit",
    }, "\n")

    notify("", text)
end

-- ─── info / exif toggle

local function toggle_info()
    if swayimg.text.visible() then
        swayimg.text.hide()
    else
        swayimg.text.show()
    end
end

local function toggle_exif()
    exif_on = not exif_on
    if exif_on then
        swayimg.viewer.set_text("bottomleft", empty_text)
        swayimg.gallery.set_text("bottomleft", empty_text)
        swayimg.viewer.set_text("topleft", exif_viewer_text)
        swayimg.gallery.set_text("topleft", exif_viewer_text)
    else
        swayimg.viewer.set_text("topleft", empty_text)
        swayimg.gallery.set_text("topleft", empty_text)
        swayimg.viewer.set_text("bottomleft", default_viewer_text)
        swayimg.gallery.set_text("bottomleft", default_viewer_text)
    end
    swayimg.text.show()
end

-- ─── save last image

local function save_last_image()
    local image = swayimg.viewer.get_image() or swayimg.gallery.get_image()
    local path = image and image.path
    if path then
        local id = path:match("/(%d+)%.?[^/]*$")
        if id then
            local f = io.open(HOME .. "/.cache/scripts/clipboard/last_image", "w")
            if f then
                f:write(id); f:close()
            end
        end
    end
end

-- ─── event handlers

swayimg.on_initialized(function()
    swayimg.viewer.set_text("topleft", empty_text)
    swayimg.viewer.set_text("topright", empty_text)
    swayimg.viewer.set_text("bottomright", empty_text)
    swayimg.viewer.set_text("bottomleft", default_viewer_text)
    swayimg.gallery.set_text("topleft", empty_text)
    swayimg.gallery.set_text("topright", empty_text)
    swayimg.gallery.set_text("bottomright", empty_text)
    swayimg.gallery.set_text("bottomleft", default_viewer_text)
    swayimg.text.hide()
end)

swayimg.on_window_resize(function()
    swayimg.viewer.reset()
end)

swayimg.viewer.on_image_change(function()
    swayimg.viewer.set_text("topleft", empty_text)
    swayimg.viewer.set_text("topright", empty_text)
    swayimg.viewer.set_text("bottomright", empty_text)
    swayimg.viewer.set_text("bottomleft", default_viewer_text)
    exif_on = false
    swayimg.text.show()
end)

swayimg.gallery.on_image_change(function()
    swayimg.gallery.set_text("topleft", empty_text)
    swayimg.gallery.set_text("topright", empty_text)
    swayimg.gallery.set_text("bottomright", empty_text)
    swayimg.gallery.set_text("bottomleft", default_viewer_text)
    exif_on = false
    swayimg.text.show()
end)

-- ─── viewer keybindings ───

-- ----- navigation -----
swayimg.viewer.on_key("Right", function() swayimg.viewer.switch_image("next") end)
swayimg.viewer.on_key("Left", function() swayimg.viewer.switch_image("prev") end)
swayimg.viewer.on_key("Next", function() swayimg.viewer.switch_image("next") end)
swayimg.viewer.on_key("Prior", function() swayimg.viewer.switch_image("prev") end)
swayimg.viewer.on_key("Space", function() swayimg.viewer.switch_image("next") end)
swayimg.viewer.on_key("BackSpace", function() swayimg.viewer.switch_image("prev") end)

-- ----- copy -----
on_key_both(swayimg.viewer, "c", copy_viewer_image)
on_key_both(swayimg.viewer, "Ctrl-e", toggle_exif)
on_key_both(swayimg.viewer, "Ctrl-c", copy_viewer_to_wallpapers)

-- ----- wallpaper -----
swayimg.viewer.on_key("W", set_viewer_wallpaper)
swayimg.viewer.on_key("B", set_viewer_wallpaper_blur)
swayimg.viewer.on_key("Ctrl-b", set_viewer_wallpaper_blur_dark)

-- ----- help -----
on_key_both(swayimg.viewer, "h", show_shortcuts)

-- ----- fullscreen -----
on_key_both(swayimg.viewer, "f", function() swayimg.toggle_fullscreen() end)

-- ----- quit -----
on_key_both(swayimg.viewer, "q", function()
    save_last_image(); swayimg.exit()
end)

-- ----- misc -----
on_key_both(swayimg.viewer, "s", cycle_order)
on_key_both(swayimg.viewer, "y", function() swayimg.viewer.switch_image("random") end)
on_key_both(swayimg.viewer, "r", function() swayimg.viewer.reset() end)
on_key_both(swayimg.viewer, "g", function() swayimg.set_mode("gallery") end)

-- ----- zoom -----
swayimg.viewer.on_key("plus", function() zoom_viewer(1.1) end)
swayimg.viewer.on_key("equal", function() zoom_viewer(1.1) end)
swayimg.viewer.on_key("KP_Add", function() zoom_viewer(1.1) end)
swayimg.viewer.on_key("minus", function() zoom_viewer(0.9) end)
swayimg.viewer.on_key("KP_Subtract", function() zoom_viewer(0.9) end)
swayimg.viewer.on_key("0", function() swayimg.viewer.reset() end)

-- ----- single-case -----
swayimg.viewer.on_key("D", trash_viewer_image)
swayimg.viewer.on_key("N", open_all_images)
swayimg.viewer.on_key("O", open_viewer_folder)
swayimg.viewer.on_key("t", toggle_info)
swayimg.viewer.on_key("Ctrl-r", rename_all_random)

-- ─── gallery keybindings ───

swayimg.gallery.on_key("Return", function() swayimg.set_mode("viewer") end)

on_key_both(swayimg.gallery, "c", copy_gallery_image)
on_key_both(swayimg.gallery, "Ctrl-e", toggle_exif)
on_key_both(swayimg.gallery, "Ctrl-c", copy_gallery_to_wallpapers)
on_key_both(swayimg.gallery, "s", cycle_order)
on_key_both(swayimg.gallery, "y", function() swayimg.gallery.switch_image("random") end)
on_key_both(swayimg.gallery, "h", show_shortcuts)
on_key_both(swayimg.gallery, "f", function() swayimg.toggle_fullscreen() end)
on_key_both(swayimg.gallery, "q", function()
    save_last_image(); swayimg.exit()
end)

swayimg.gallery.on_key("W", set_gallery_wallpaper)
swayimg.gallery.on_key("B", set_gallery_wallpaper_blur)
swayimg.gallery.on_key("Ctrl-b", set_gallery_wallpaper_blur_dark)
swayimg.gallery.on_key("D", trash_gallery_image)
swayimg.gallery.on_key("N", open_all_images)
swayimg.gallery.on_key("Ctrl-r", rename_all_random)
