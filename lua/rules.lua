-- Windows and workspaces
-- Was: rules.conf (0.53+ hyprlang: match:class + float on). Lua: match={class=...}, float=true

-- Terminals & Main -> ws1
hl.window_rule({ match = { class = "^(.*konsole.*)$" }, workspace = 1 })
hl.window_rule({ match = { class = "^(.*kitty.*)$" }, workspace = 1 })
hl.window_rule({ match = { class = "^(.*systemsettings.*)$" }, workspace = 1 })
hl.window_rule({ match = { class = "^(.*gnome-terminal.*)$" }, workspace = 1 })

-- Internet -> ws2
hl.window_rule({ match = { class = "^(.*firefox.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(.*opera.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(.*edge.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(.*Chromium.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(.*Google-chrome.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "^(.*thorium-browser.*)$" }, workspace = 2 })
hl.window_rule({ match = { class = "brave-browser" }, workspace = 2 })

-- Coding -> ws3
hl.window_rule({ match = { class = "^(.*Code.*)$" }, workspace = 3 })
hl.window_rule({ match = { class = "^(.*neovide.*)$" }, workspace = 3 })
hl.window_rule({ match = { class = "^(.*VSCodium.*)$" }, workspace = 3 })
hl.window_rule({ match = { class = "^(.*jetbrains-pycharm-ce.*)$" }, workspace = 3 })

-- Files -> ws4
hl.window_rule({ match = { class = "^(.*dolphin.*)$" }, workspace = 4 })
hl.window_rule({ match = { class = "^(.*pcmanfm-qt.*)$" }, workspace = 4 })
hl.window_rule({ match = { class = "^(.*nemo.*)$" }, workspace = 4 })
hl.window_rule({ match = { class = "^(.*ark.*)$" }, workspace = 4 })
hl.window_rule({ match = { class = ".*Nautilus.*" }, workspace = 4 })

-- Android & Database -> ws5
hl.window_rule({ match = { class = "^(.*studio.*)$" }, workspace = 5 })
hl.window_rule({ match = { class = "^(.*jetbrains-studio.*)$" }, workspace = 5 })
hl.window_rule({ match = { class = "^(.*DBeaver.*)$" }, workspace = 5 })
hl.window_rule({ match = { title = "^(.*LibreOffice.*)$" }, workspace = 5 })
hl.window_rule({ match = { title = "^(.*pgadmin4.*)$" }, workspace = 5 })

-- Chatting -> ws6
hl.window_rule({ match = { title = "^(.*Telegram.*)$" }, workspace = 6 })
hl.window_rule({ match = { title = "^(.*Messages for web.*)$" }, workspace = 6 })
hl.window_rule({ match = { class = "^(.*discord.*)$" }, workspace = 6 })
hl.window_rule({ match = { class = "^(.*thunderbird.*)$" }, workspace = 6 })

-- Media -> ws7
hl.window_rule({ match = { class = "^(.*amarok.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*G4Music.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = ".*music.*" }, workspace = 7 })
hl.window_rule({ match = { class = ".*lollypop.*" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*elisa.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*vlc.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*easyeffects.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*mpv.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "^(.*strawberry.*)$" }, workspace = 7 })
hl.window_rule({ match = { class = "org.kde.dragonplayer" }, workspace = 7 })

-- Games -> ws8
hl.window_rule({ match = { class = "^(.*org.libretro.RetroArch.*)$" }, workspace = 8 })
hl.window_rule({ match = { class = "^(.*pcsx2-qt.*)$" }, workspace = 8 })
hl.window_rule({ match = { class = ".*PCSX2.*" }, workspace = 8 })
hl.window_rule({ match = { class = "^(.*PPSSPPQt.*)$" }, workspace = 8 })
hl.window_rule({ match = { class = "^(.*steam.*)$" }, workspace = 8 })
hl.window_rule({ match = { class = "^(.*lutris.*)$" }, workspace = 8 })
hl.window_rule({ match = { title = "^(.*Winetricks.*)$" }, workspace = 8 })

-- Other temp workspaces -> ws9
hl.window_rule({ match = { class = "^(.*Postman.*)$" }, workspace = 9 })
hl.window_rule({ match = { initial_title = ".*MetaTrader.*" }, workspace = 9 })
hl.window_rule({ match = { class = "org.wireshark.Wireshark" }, workspace = 9 })

-- Dialogs (was float 1 -> float=true)
hl.window_rule({ match = { class = "^(.*org.kde.polkit-kde-authentication-agent-1.*)$" }, float = true })
hl.window_rule({ match = { class = ".*portal.*" }, float = true })
hl.window_rule({ match = { class = "^(.*org.kde.kteatime.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Open File.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Open Folder.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Save As.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Library.*)$" }, float = true })
hl.window_rule({ match = { class = "^(.*dialog.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*dialog.*)$" }, float = true })
hl.window_rule({ match = { title = "^(.*Winetricks.*)$" }, float = true })

-- Floating
hl.window_rule({ match = { class = "^(.*com.github.hluk.copyq.*)$" }, float = true })
hl.window_rule({ match = { class = "Windscribe" }, float = true })

-- Others (was pin 1 / no_blur 1 / pseudo 1 / no_shadow 1)
hl.window_rule({ match = { class = "^(.*9i.*)$" }, pin = true })
hl.window_rule({ match = { class = "^(.*GLava.*)$" }, no_blur = true })
hl.window_rule({ match = { class = "^(.*neovide.*)$" }, no_blur = true })
hl.window_rule({ match = { class = "^(.*GLava.*)$" }, pseudo = true })
hl.window_rule({ match = { class = "^(.*GLava.*)$" }, no_shadow = true })
hl.window_rule({ match = { class = "^(.*GLava.*)$" }, float = true })

-- NibrasShell settings
hl.window_rule({ match = { title = "^(NibrasShellSettings)$" }, float = true })
hl.window_rule({ match = { title = "^(NibrasShellSettings)$" }, size = { 950, 950 } })
hl.window_rule({ match = { title = "^(NibrasShellSettings)$" }, center = true })

-- Layer rules (was layerrule = blur on, ignore_alpha 0, match:namespace ...)
hl.layer_rule({
	match = { namespace = "NibrasShell:logout" },
	blur = true,
	ignore_alpha = 0,
})
