-- Keybindings
-- Was: binding.conf
-- bindd description -> { description = "..." }, bindl -> { locked = true }, mouse binds -> { mouse = true }
local mainMod = "SUPER"
local shiftKey = "SHIFT"
local altKey = "ALT"

-- Window control
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Kill the focused application" })
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(altKey .. " + " .. shiftKey .. " + A", hl.dsp.window.pin(), { description = "Pin window" })

-- Voice control
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute 0 toggle"), { description = "Toggle mute" })
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("pactl set-source-mute 0 toggle"),
	{ description = "Toggle microphone mute" }
)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"),
	{ description = "Increase volume" }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"),
	{ description = "Decrease volume" }
)

-- Media control (nibrasshell globals)
hl.bind("XF86AudioPlay", hl.dsp.global("nibrasshell:togglePlaying"), { description = "Play/Pause" })
hl.bind("XF86AudioNext", hl.dsp.global("nibrasshell:nextSong"), { description = "Next track" })
hl.bind("XF86AudioPrev", hl.dsp.global("nibrasshell:previousSong"), { description = "Previous track" })
hl.bind("XF86AudioStop", hl.dsp.global("nibrasshell:stopPlay"), { description = "Stop playback" })

-- Brightness (nibrasshell globals)
hl.bind("XF86MonBrightnessUp", hl.dsp.global("nibrasshell:brightnessUp"), { description = "Increase brightness" })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("nibrasshell:brightnessDown"), { description = "Increase brightness" })

-- Applications
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("konsole"), { description = "Open Konsole" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("konsole"), { description = "Open Konsole" })
hl.bind(
	mainMod .. " + " .. shiftKey .. " + A",
	hl.dsp.exec_cmd("/media/linux/apps/android-studio/bin/studio.sh"),
	{ description = "Open Android Studio" }
)
hl.bind(mainMod .. " + " .. shiftKey .. " + C", hl.dsp.exec_cmd("code"), { description = "Open VS Code" })
hl.bind(mainMod .. " + " .. shiftKey .. " + H", hl.dsp.exec_cmd("~/hopofy.sh"), { description = "Open Hopofy script" })
hl.bind(mainMod .. " + " .. shiftKey .. " + D", hl.dsp.exec_cmd("discord"), { description = "Open Discord" })
hl.bind(mainMod .. " + " .. shiftKey .. " + E", hl.dsp.exec_cmd("dolphin"), { description = "Open Dolphin" })
hl.bind(
	mainMod .. " + " .. shiftKey .. " + B",
	hl.dsp.exec_cmd("brave-browser --password-store=kwallet6"),
	{ description = "Open brave-browser" }
)
hl.bind(mainMod .. " + " .. shiftKey .. " + F", hl.dsp.exec_cmd("firefox"), { description = "Open Firefox" })
hl.bind(
	mainMod .. " + " .. shiftKey .. " + K",
	hl.dsp.exec_cmd("plasma-systemmonitor"),
	{ description = "Open System Monitor" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + M",
	hl.dsp.exec_cmd("missioncenter"),
	{ description = "Open Mission Center" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + S",
	hl.dsp.exec_cmd("systemsettings"),
	{ description = "Open System Settings" }
)
hl.bind(mainMod .. " + " .. shiftKey .. " + T", hl.dsp.exec_cmd("Telegram"), { description = "Open Telegram" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("strawberry"), { description = "Open Strawberry" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("easyeffects"), { description = "Open EasyEffects" })
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Open Hyprpicker" })
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region"), { description = "Take screenshot (region)" })
hl.bind(
	mainMod .. " + " .. shiftKey .. " + P",
	hl.dsp.exec_cmd("GDK_BACKEND=x11 PCSX2"),
	{ description = "Open PCSX2" }
)

-- Menus (quickshell + nibrasshell)
hl.bind(
	mainMod .. " + F1",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleDashboardMenu"),
	{ description = "Toggle Dashboard Menu" }
)
hl.bind(
	mainMod .. " + F2",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleNotificationsMenu"),
	{ description = "Toggle Notification Menu" }
)
hl.bind(
	mainMod .. " + F3",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleWeatherMenu"),
	{ description = "Toggle Weather Menu" }
)
hl.bind(
	mainMod .. " + F4",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleMonitoringMenu"),
	{ description = "Toggle Monitors Menu" }
)
hl.bind(
	mainMod .. " + F5",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleNetworkingMenu"),
	{ description = "Toggle Network Menu" }
)
hl.bind(
	mainMod .. " + F6",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleClipboardMenu"),
	{ description = "Toggle Clipboard Menu" }
)
hl.bind(
	mainMod .. " + F7",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleTodoMenu"),
	{ description = "Toggle Todo Menu" }
)
hl.bind(
	mainMod .. " + I",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleAiMenu"),
	{ description = "Toggle Ai Bots Menu" }
)
hl.bind(
	mainMod .. " + L",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar togglePowerMenu"),
	{ description = "Power options" }
)
hl.bind(
	mainMod .. " + R",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleApplauncherMenu"),
	{ description = "Show application launcher" }
)
hl.bind(mainMod .. " + S", hl.dsp.global("nibrasshell:openSettings"), { description = "Show nibrasshell settings" })
hl.bind(
	mainMod .. " + slash",
	hl.dsp.global("nibrasshell:openCheatsheet"),
	{ description = "Show nibrasshell cheatsheet" }
)
hl.bind(
	mainMod .. " + P",
	hl.dsp.global("nibrasshell:toggleMediaIsland"),
	{ description = "Show nibrasshell media player cap" }
)
hl.bind(
	mainMod .. " + W",
	hl.dsp.global("nibrasshell:toggleWeatherIsland"),
	{ description = "Show nibrasshell weather cap" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + R",
	hl.dsp.exec_cmd("quickshell ipc call LeftBar toggleClipboardMenu"),
	{ description = "Toggle Clipboard" }
)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Move focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Move focus right" })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })

-- Monitors
hl.bind(mainMod .. " + " .. altKey .. " + 1", hl.dsp.focus({ monitor = 0 }), { description = "Focus monitor 1" })
hl.bind(mainMod .. " + " .. altKey .. " + 2", hl.dsp.focus({ monitor = 1 }), { description = "Focus monitor 2" })
hl.bind(
	mainMod .. " + CTRL + 1",
	hl.dsp.workspace.move({ monitor = 0 }),
	{ description = "Move workspace to monitor 1" }
)
hl.bind(
	mainMod .. " + CTRL + 2",
	hl.dsp.workspace.move({ monitor = 1 }),
	{ description = "Move workspace to monitor 2" }
)

hl.bind(mainMod .. " + " .. altKey .. " + R", hl.dsp.force_renderer_reload(), { description = "Force renderer reload" })

-- Move window with mainMod + shift + arrow keys
hl.bind(
	mainMod .. " + " .. shiftKey .. " + left",
	hl.dsp.window.move({ direction = "left" }),
	{ description = "Move window left" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + right",
	hl.dsp.window.move({ direction = "right" }),
	{ description = "Move window right" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + up",
	hl.dsp.window.move({ direction = "up" }),
	{ description = "Move window up" }
)
hl.bind(
	mainMod .. " + " .. shiftKey .. " + down",
	hl.dsp.window.move({ direction = "down" }),
	{ description = "Move window down" }
)

hl.bind(
	mainMod .. " + " .. altKey .. " + left",
	hl.dsp.layout("splitratio -0.1"),
	{ description = "Decrease split ratio" }
)
hl.bind(
	mainMod .. " + " .. altKey .. " + right",
	hl.dsp.layout("splitratio +0.1"),
	{ description = "Increase split ratio" }
)

-- Navigation
hl.bind(mainMod .. " + Escape", hl.dsp.focus({ workspace = "previous" }), { description = "Go to previous workspace" })
hl.bind(mainMod .. " + H", hl.dsp.workspace.toggle_special(), { description = "Toggle special workspace" })
for i = 1, 9 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }), { description = "Go to workspace " .. i })
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }), { description = "Go to workspace 10" })

-- Minimize helpers (custom scripts)
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/minimiz.sh"), { description = "Minimize window" })
hl.bind(
	mainMod .. " + CTRL + N",
	hl.dsp.exec_cmd("sh ~/.config/hypr/scripts/get_minimized.sh"),
	{ description = "Get minimized windows" }
)

-- Move active window to a workspace (silent = follow=false)
for i = 1, 9 do
	hl.bind(
		mainMod .. " + " .. shiftKey .. " + " .. i,
		hl.dsp.window.move({ workspace = i, follow = false }),
		{ description = "Move window to workspace " .. i }
	)
end
hl.bind(
	mainMod .. " + " .. shiftKey .. " + 0",
	hl.dsp.window.move({ workspace = 10, follow = false }),
	{ description = "Move window to workspace 10" }
)

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Scroll to next workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Scroll to previous workspace" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Was: hyprctl dispatch layer "bottom" focused -> new correct way is alter_zorder
hl.bind(
	mainMod .. " + B",
	hl.dsp.window.alter_zorder({ mode = "bottom" }),
	{ description = "Send focused window to bottom layer" }
)
hl.bind(mainMod .. " + " .. altKey .. " + S", hl.dsp.exec_cmd("systemctl suspend"))

-- Lid switch: `hyprctl keyword monitor` is rejected on the Lua engine, so the
-- lid-open rule is applied via hl.monitor through an eval round-trip.
-- NOTE: verify output name (HDMI-A-1 vs HDMI-1-0) via `hyprctl monitors`.
hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd(
		[[hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "1600x0", scale = 1 })']]
	),
	{ locked = true }
)
