-- Hyprland Lua entry point (Hyprland 0.55+ / 0.56.2)
-- Each concern lives in its own module under lua/. No config logic here.
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- Verify with: hyprctl reload && hyprctl configerrors && hyprctl binds && hyprctl clients -j

-- Ensure requires resolve relative to this config dir even if
-- Hyprland does not put it on package.path by default.
package.path = os.getenv("HOME")
	.. "/.config/hypr/?.lua;"
	.. os.getenv("HOME")
	.. "/.config/hypr/?/init.lua;"
	.. package.path

require("lua.monitors")
require("lua.env")
require("lua.autostart")
require("lua.settings")
require("lua.animations")
require("lua.binds")
require("lua.rules")
