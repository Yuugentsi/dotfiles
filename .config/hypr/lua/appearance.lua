-- ─── appearance ───
hl.config({ xwayland = { force_zero_scaling = true, use_nearest_neighbor = true } })

-- -------------------- general --------------------
hl.config({
    general = {
        gaps_in          = 2,
        gaps_out         = 8,

        border_size      = 2,

        col              = {
            active_border   = { colors = { "rgba(a855f7ee)", "rgba(402759ee)" }, angle = 45 },
            inactive_border = "rgba(29183add)",
        },

        resize_on_border = false,
        allow_tearing    = true,
        layout           = "scrolling",
        snap             = {
            enabled    = true,
            window_gap = 10,
        },
    },
})

-- -------------------- layouts --------------------
-- ----- master -----
hl.config({
    master = {
        new_status = "slave",
    },
})

-- ----- scrolling -----
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.97,
        focus_fit_method = 0,
        follow_focus = true,
        follow_min_visible = 0.4,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
        wrap_focus = true,
        wrap_swapcol = true,
        direction = "right",
    },
})

-- -------------------- misc --------------------
hl.config({
    misc = {
        vrr                           = 1,
        force_default_wallpaper       = 0,
        disable_hyprland_logo         = true,
        disable_splash_rendering      = true,
        render_unfocused_fps          = 15,
        animate_manual_resizes        = false,
        animate_mouse_windowdragging  = false,
        always_follow_on_dnd          = true,
    },
    render = {
        direct_scanout                = 2,
        new_render_scheduling         = true,
    },
    cursor = {
        no_hardware_cursors           = 0,
        no_break_fs_vrr               = 2,
        hide_on_key_press             = true,
        inactive_timeout              = 3,
        sync_gsettings_theme          = true,
    },
    debug = {
        vfr                           = true,
    },
    ecosystem = {
        no_donation_nag               = true,
        no_update_news                = true,
    },
})

-- -------------------- decoration --------------------
hl.config({
    decoration = {
        rounding         = 10,
        rounding_power   = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        dim_inactive     = false,
        dim_strength     = 0.12,
        dim_around       = 0.45,
        dim_special      = 0.0,

        -- ----- shadow -----
        shadow           = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        -- ----- blur -----
        blur             = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            vibrancy          = 0.1696,
            new_optimizations = true,
            ignore_opacity    = true,
            popups            = true,
        },

        -- ----- glow -----
        glow             = {
            enabled      = false,
            range        = 10,
            render_power = 3,
            color        = 0xeea855f7,
        },
    },
})

-- -------------------- animations --------------------
hl.config({
    animations = {
        enabled = false,
    },
})
