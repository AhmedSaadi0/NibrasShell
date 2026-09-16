-- Animations: curves + animation definitions
-- Was: variables.conf animations block
hl.config({
	animations = {
		enabled = true,
	},
})

-- Was: animations { bezier = ... } + animation = ...
hl.curve("win_in", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("win_out", { type = "bezier", points = { { 0.3, 0 }, { 0.6, 1 } } })
hl.curve("move", { type = "bezier", points = { { 0.2, 0.85 }, { 0.15, 1 } } })
hl.curve("ui", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("launch", { type = "bezier", points = { { 0.12, 0.95 }, { 0.22, 1 } } })
hl.curve("accelerate", { type = "bezier", points = { { 0.5, 0.0 }, { 1.0, 1.0 } } })

hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "accelerate", style = "slide" })
hl.animation({ leaf = "windows", enabled = true, speed = 8, bezier = "launch", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "win_out", style = "popin 88%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "ui" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 12, bezier = "ui" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 8, bezier = "launch" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 6, bezier = "win_out" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "move", style = "slide" })
