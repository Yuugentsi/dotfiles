-- ─── input ───
-- gestures
hl.gesture({ fingers = 3, direction = "swipe", action = "scroll_move" })
hl.gesture({
    fingers   = 4,
    direction = "horizontal",
    action    = "workspace",
})

--
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
        tap_to_click   = true,
    },
}

hl.config({ input = input_cfg })
