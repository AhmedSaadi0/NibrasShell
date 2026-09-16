-- Autostart
-- Was: exec-once.conf
-- hl.exec_cmd is async (no need for & disown). hyprland.start runs once, not on every reload.
hl.on("hyprland.start", function()
	hl.exec_cmd("quickshell")
	hl.exec_cmd("/usr/libexec/kf6/polkit-kde-authentication-agent-1")
	hl.exec_cmd("sleep 30 && kdeconnect-indicator")
	hl.exec_cmd("sleep 30 && nm-applet -sm-disable")
	hl.exec_cmd("sleep 30 && abrt-applet")
	hl.exec_cmd("sleep 30 && thunderbird")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("podman start open-webui")
end)
