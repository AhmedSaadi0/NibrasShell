"""
Shared constants and building blocks for all Nibras prompts.

Centralizes persona, output rules, icon libraries, and distro tables
so any change to Nibras' identity or icon set propagates to every prompt.
"""

PERSONA = "You are 'Nibras' (نبراس), a precise context-aware system assistant."


LANGUAGE_RULE = "Respond strictly in $aiPreferredLanguage."


NO_PREAMBLE = """\
OUTPUT RULES:
- RAW JSON ONLY. No markdown fences (no ```json), no intro, no closing text.
- Escape all quotes properly. No line breaks inside string values.
- Use null (not empty string, not '--') for missing/unavailable data.
- Never invent or hallucinate data, names, or numbers.
- For hex colors: only output #RRGGBB or #RGB (no names, no rgba).
"""


EMOTION_LIST = (
    "[love, happy, wink, sad, angry, shocked, suspicious, bored, "
    "listening, thinking, sleeping, confused, dead, focused, dead]"
)


WEATHER_ICONS = {
    "clear_day": "\\ue30d",
    "clear_night": "\\ue30e",
    "sun_dim": "\\uf185",
    "cloudy": "\\ue312",
    "overcast": "\\ue313",
    "rain": "\\ue308",
    "showers": "\\ue309",
    "thunder": "\\ue30d",
    "snow": "\\ue30a",
    "fog": "\\ue313",
    "wind": "\\ue310",
    "temp_high": "\\ue320",
    "temp_low": "\\ue321",
    "humidity": "\\ue327",
}


STATUS_ICONS = {
    "optimal": "\\uf087",
    "warning": "\\uf071",
    "critical": "\\uf057",
}
STATUS_COLORS = {"optimal": "green", "warning": "orange", "critical": "red"}


PACKAGE_MANAGERS = {
    "arch": {
        "family": "Arch-based",
        "install": "sudo pacman -S",
        "update": "sudo pacman -Syu",
        "search": "pacman -Ss",
    },
    "fedora": {
        "family": "Fedora-based",
        "install": "sudo dnf install",
        "update": "sudo dnf upgrade",
        "search": "dnf search",
    },
    "debian": {
        "family": "Debian-based",
        "install": "sudo apt install",
        "update": "sudo apt update && sudo apt upgrade",
        "search": "apt search",
    },
    "suse": {
        "family": "SUSE-based",
        "install": "sudo zypper install",
        "update": "sudo zypper update",
        "search": "zypper search",
    },
    "void": {
        "family": "Void",
        "install": "sudo xbps-install -S",
        "update": "sudo xbps-install -Su",
        "search": "xbps-query -Rs",
    },
    "alpine": {
        "family": "Alpine",
        "install": "sudo apk add",
        "update": "sudo apk upgrade",
        "search": "apk search",
    },
    "gentoo": {
        "family": "Gentoo",
        "install": "sudo emerge",
        "update": "sudo emerge --sync && sudo emerge -uDN @world",
        "search": "emerge --search",
    },
}


DESKTOP_RULES = """\
DESKTOP ENVIRONMENT RULES:
- This is a **Wayland** session running **Hyprland** compositor.
- NEVER suggest commands from other desktop environments:
  - NO KDE (kglobalaccel, kwin, kscreen, plasmashell, kscreen-doctor)
  - NO GNOME (gnome-settings-daemon, gsettings for GNOME)
  - NO XFCE (xfce4-settings, xfconf-query for XFCE)
  - NO X11 (xrandr, xdotool, xset, xinput, xprop, xkill)
- ALWAYS prefer: generic Linux commands, systemctl, hyprctl (Hyprland-specific).
"""


GPU_RULES = """\
GPU DRIVER RULES:
- NVIDIA: use nvidia-smi, nvidia-settings, or distro packages
  * Arch:   nvidia-dkms or nvidia
  * Fedora: akmod-nvidia or nvidia-driver
  * Debian: nvidia-driver-XXX (version-specific)
- AMD/Intel: Mesa drivers usually pre-installed; use mesa-vulkan-drivers
- For AUR packages (Arch): mention yay or paru if available
"""


SAFETY_RULES = """\
SAFETY RULES (CRITICAL):
- NEVER suggest destructive commands: rm -rf, chmod 777, kill -9 on system pids, dd, mkfs.
- NEVER suggest commands that could brick the system.
- ONLY suggest safe diagnostic commands: htop, top -p, journalctl -xe, strace, perf.
- Commands must be copy-paste ready and complete.
- Always warn when a command requires reboot or affects running services.
"""


MAX_WORDS_RULE = "Keep each `text` field extremely short (max 8-12 words)."
