-- ─── input ───
-- gestures
--hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = "1", mode = "live" })
hl.gesture({ fingers = 3, direction = "swipe", action = "scroll_move" })
hl.gesture({
    fingers   = 4,
    direction = "horizontal",
    action    = "workspace",
})

-- keyboard / mouse / touchpad
local input_cfg = {
    kb_layout    = "br",
    kb_variant   = "",
    kb_model     = "",
    kb_options   = "",
    kb_rules     = "",
    follow_mouse        = 1,
    sensitivity         = 0.70,
    accel_profile       = "flat",
    scroll_factor       = 1.2,
    repeat_delay        = 200,
    repeat_rate         = 50,
    special_fallthrough = true,
    touchpad            = {
        natural_scroll = false,
        scroll_factor  = 1.2,
    },
}

hl.config({ input = input_cfg })

-- device override
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = 1,
})
