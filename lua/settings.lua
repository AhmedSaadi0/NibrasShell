-- Look and feel: input / general / dwindle / gestures / misc / debug
-- Was: variables.conf (animations live in lua/animations.lua)
hl.config({
	input = {
		kb_layout = "us,ara",
		kb_options = "grp:win_space_toggle",
		follow_mouse = 1,
		mouse_refocus = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = { 12, 10, 10, 52 },
		border_size = 2,
		layout = "dwindle",
	},
})

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})
hl.gesture({
	fingers = 3,
	direction = "up",
	mods = "SUPER",
	scale = 1.5,
	action = "fullscreen",
})

hl.config({
	misc = {
		disable_hyprland_logo = true,
	},
})

-- hl.config({
-- 	debug = {
-- 		damage_tracking = 2,
-- 	},
-- })

hl.config({
	gestures = {
		workspace_swipe_invert = false,
	},
})
