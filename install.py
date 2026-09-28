#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# TODO: -> split into several files and use clean code standard

import json

# --- Import necessary libraries ---
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

base_dir = Path(__file__).resolve().parent

# --- Define colors for terminal output ---
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
NC = "\033[0m"  # No Color

# --- Dictionary for all text in languages ---
MESSAGES = {
    "en": {
        "choose_lang": "Choose your language:",
        "main_menu_title": "NibrasShell Installation Script",
        "install_deps_menu": "1. Install Dependencies",
        "install_local": "2. Install NibrasShell",
        "update_quickshell": "3. Update QuickShell",
        "uninstall": "4. Uninstall NibrasShell",
        "create_config": "5. Create/Edit User Config",
        "exit": "6. Exit",
        "choose_option": "Choose an option: ",
        "distro_check_fail": "Error: This script only supports Fedora, Void and Arch Linux.",
        "installing_deps": "Installing dependencies...",
        "backing_up": "Backing up existing configurations...",
        "backup_created": "Backup created at:",
        "installing_nibrasshell": "Copying and setting up NibrasShell files...",
        "install_complete": "NibrasShell setup complete.",
        "reboot_prompt": "It is recommended to reboot your system.",
        "uninstall_prompt": "Are you sure you want to uninstall NibrasShell? (y/n) ",
        "uninstalling": "Uninstalling NibrasShell...",
        "restore_prompt": "Do you want to restore the latest backup? (y/n) ",
        "restoring_backup": "Restoring backup from:",
        "uninstall_complete": "NibrasShell has been uninstalled.",
        "no_backup_found": "No backup found to restore.",
        "invalid_option": "Invalid option, please try again.",
        "deps_menu_title": "Dependency Installation Menu",
        "install_required_only": "1. Install Required Dependencies Only",
        "install_all_deps": "2. Install All (Required + Optional) Dependencies",
        "config_creation_title": "--- User Configuration ---",
        "config_prompt": "This will guide you to create the ~/.nibrasshell.json file.",
        "prompt_username": "Enter your name (for the welcome message): ",
        "prompt_subtitle": "Enter a short subtitle (optional): ",
        "prompt_profile_pic": "Enter the full path to your profile picture: ",
        "prompt_network_select": "Select your primary network interface:",
        "prompt_dark_wallpapers": "Enter the path to your dark wallpapers directory: ",
        "prompt_light_wallpapers": "Enter the path to your light wallpapers directory: ",
        "prompt_city": "Enter your city for weather/prayer times: ",
        "prompt_country": "Enter your country: ",
        "prompt_use_prayer": "Enable prayer times widget? (y/n): ",
        "config_saved": "Configuration file saved to ~/.nibrasshell.json",
        "updating_quickshell": "Updating QuickShell...",
        "update_complete": "QuickShell update complete.",
        "pulling_updates": "Pulling latest updates from git...",
        "copying_files": "Copying QuickShell files...",
        "dnf_error": "Error: DNF failed to install packages.",
        "dnf_conflict_prompt": "How do you want to resolve the conflict?",
        "opt_allow_erasing": "1. Allow erasing conflicting packages (--allowerasing)",
        "opt_skip_broken": "2. Skip broken/conflicting packages (--skip-broken)",
        "opt_cancel": "3. Cancel installation",
        "gemini_api_key": "Enter Gemini API Key: ",
        "music_ai_api_key": "Enter Gemini API Key For Music Analytics:",
        "weather_ai_api_key": "Enter Gemini API Key For Weather Analytics:",
        "ai_preferred_language": "Enter Preferred AI Response Language:",
    },
    "ar": {
        "choose_lang": "اختر لغتك:",
        "main_menu_title": "سكربت تثبيت NibrasShell",
        "install_deps_menu": "1. تثبيت المتطلبات",
        "install_local": "2. تثبيت الواجهة",
        "update_quickshell": "3. تحديث QuickShell",
        "uninstall": "4. حذف الواجهة",
        "create_config": "5. إنشاء/تعديل ملف الإعدادات",
        "exit": "6. خروج",
        "choose_option": "اختر أحد الخيارات: ",
        "distro_check_fail": "خطأ: هذا السكربت يدعم فقط توزيعات فيدورا وآرش لينكس.",
        "installing_deps": "جاري تثبيت المتطلبات...",
        "backing_up": "جاري أخذ نسخة احتياطية من الإعدادات الحالية...",
        "backup_created": "تم إنشاء النسخة الاحتياطية في:",
        "installing_nibrasshell": "جاري نسخ وإعداد ملفات NibrasShell...",
        "install_complete": "اكتمل إعداد NibrasShell.",
        "reboot_prompt": "يوصى بإعادة تشغيل النظام.",
        "uninstall_prompt": "هل أنت متأكد أنك تريد حذف NibrasShell؟ (ن/ل) ",
        "uninstalling": "جاري حذف NibrasShell...",
        "restore_prompt": "هل تريد استعادة آخر نسخة احتياطية؟ (ن/ل) ",
        "restoring_backup": "جاري استعادة النسخة الاحتياطية من:",
        "uninstall_complete": "تم حذف NibrasShell.",
        "no_backup_found": "لم يتم العثور على نسخة احتياطية.",
        "invalid_option": "خيار غير صالح، يرجى المحاولة مرة أخرى.",
        "deps_menu_title": "قائمة تثبيت المتطلبات",
        "install_required_only": "1. تثبيت المتطلبات الضرورية فقط",
        "install_all_deps": "2. تثبيت كل المتطلبات (الضرورية والاختيارية)",
        "config_creation_title": "--- إعدادات المستخدم ---",
        "config_prompt": "سيساعدك هذا الدليل لإنشاء ملف ~/.nibrasshell.json.",
        "prompt_username": "أدخل اسمك (للرسالة الترحيبية): ",
        "prompt_subtitle": "أدخل وصفاً قصيراً (اختياري): ",
        "prompt_profile_pic": "أدخل المسار الكامل لصورتك الشخصية: ",
        "prompt_network_select": "اختر واجهة الشبكة الرئيسية:",
        "prompt_dark_wallpapers": "أدخل مسار مجلد الخلفيات الداكنة: ",
        "prompt_light_wallpapers": "أدخل مسار مجلد الخلفيات الفاتحة: ",
        "prompt_city": "أدخل اسم مدينتك (للطقس ومواقيت الصلاة): ",
        "prompt_country": "أدخل اسم دولتك: ",
        "prompt_use_prayer": "هل تريد تفعيل ودجت مواقيت الصلاة؟ (ن/ل): ",
        "config_saved": "تم حفظ ملف الإعدادات في ~/.nibrasshell.json",
        "updating_quickshell": "جاري تحديث QuickShell...",
        "update_complete": "اكتمل تحديث QuickShell.",
        "pulling_updates": "جاري سحب آخر التحديثات من git...",
        "copying_files": "جاري نسخ ملفات QuickShell...",
        "dnf_error": "خطأ: فشل DNF في تثبيت الحزم.",
        "dnf_conflict_prompt": "كيف تريد معالجة التعارض؟",
        "opt_allow_erasing": "1. السماح باستبدال الحزم المتعارضة (--allowerasing)",
        "opt_skip_broken": "2. تخطي الحزم المعطوبة/المتعارضة (--skip-broken)",
        "opt_cancel": "3. إلغاء التثبيت",
        "gemini_api_key": "أدخل مفتاح Gemini API: ",
        "music_ai_api_key": "أدخل مفتاح Gemini API لتحليل الموسيقى: ",
        "weather_ai_api_key": "أدخل مفتاح Gemini API لتحليل الطقس: ",
        "ai_preferred_language": "أدخل اللغة المفضلة لاستجابة الذكاء الاصطناعي:",
    },
    "cs": {
        "choose_lang": "Vyberte si jazyk:",
        "main_menu_title": "Instalační skript NibrasShell",
        "install_deps_menu": "1. Nainstalovat závislosti",
        "install_local": "2. Nainstalovat NibrasShell",
        "update_quickshell": "3. Aktualizovat QuickShell",
        "uninstall": "4. Odinstalovat NibrasShell",
        "create_config": "5. Vytvořit/upravit konfiguraci uživatele",
        "exit": "6. Ukončit",
        "choose_option": "Vyberte možnost: ",
        "distro_check_fail": "Chyba: Tento skript podporuje pouze Fedoru, Void a Arch Linux.",
        "installing_deps": "Instalace závislostí...",
        "backing_up": "Zálohování existujících konfigurací...",
        "backup_created": "Záloha vytvořena v:",
        "installing_nibrasshell": "Kopírování a nastavení souborů NibrasShell...",
        "install_complete": "Nastavení NibrasShell dokončeno.",
        "reboot_prompt": "Doporučujeme restartovat systém.",
        "uninstall_prompt": "Opravdu chcete odinstalovat NibrasShell? (y/n) ",
        "uninstalling": "Odinstalování NibrasShell...",
        "restore_prompt": "Chcete obnovit poslední zálohu? (y/n) ",
        "restoring_backup": "Obnovení zálohy z:",
        "uninstall_complete": "NibrasShell byl odinstalován.",
        "no_backup_found": "Nebyly nalezeny žádné zálohy k obnovení.",
        "invalid_option": "Neplatná volba, zkuste to znovu.",
        "deps_menu_title": "Nabídka instalace závislostí",
        "install_required_only": "1. Nainstalovat pouze požadované závislosti",
        "install_all_deps": "2. Nainstalujte všechny (požadované + volitelné) závislosti",
        "config_creation_title": "--- Konfigurace uživatele ---",
        "config_prompt": "Toto vás provede vytvořením souboru ~/.nibrasshell.json.",
        "prompt_username": "Zadejte své jméno (pro uvítací zprávu): ",
        "prompt_subtitle": "Zadejte krátký podtitul (volitelné): ",
        "prompt_profile_pic": "Zadejte úplnou cestu k vaší profilové fotografii: ",
        "prompt_network_select": "Vyberte své primární síťové rozhraní:",
        "prompt_dark_wallpapers": "Zadejte cestu k adresáři s tmavými tapetami: ",
        "prompt_light_wallpapers": "Zadejte cestu k adresáři světlých tapet: ",
        "prompt_city": "Zadejte své město pro počasí/časy modliteb: ",
        "prompt_country": "Zadejte svou zemi: ",
        "prompt_use_prayer": "Povolit widget modlitebních časů? (y/n): ",
        "config_saved": "Konfigurační soubor uložen do ~/.nibrasshell.json",
        "updating_quickshell": "Aktualizace QuickShell...",
        "update_complete": "Aktualizace QuickShell dokončena.",
        "pulling_updates": "Stahování nejnovějších aktualizací z gitu...",
        "copying_files": "Kopírování souborů QuickShell...",
        "dnf_error": "Chyba: DNF se nepodařilo nainstalovat balíčky.",
        "dnf_conflict_prompt": "Jak chcete vyřešit konflikt?",
        "opt_allow_erasing": "1. Povolit vymazání konfliktních balíčků (--allowerasing)",
        "opt_skip_broken": "2. Přeskočit poškozené balíčky (--skip-broken)",
        "opt_cancel": "3. Zrušit instalaci",
        "gemini_api_key": "Zadejte Gemini API klíč: ",
        "music_ai_api_key": "Zadejte Gemini API klíč pro analýzu hudby: ",
        "weather_ai_api_key": "Zadejte Gemini API klíč pro analýzu počasí: ",
        "ai_preferred_language": "Zadejte preferovaný jazyk odpovědi AI:",
    },
}

LANG = "en"  # Default language


# Function to get the correct text based on the selected language.
def msg(key):
    return MESSAGES[LANG][key]


# Function to run a shell command silently (hides output).
def run_command(command):
    try:
        subprocess.run(
            command,
            check=True,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as e:
        print(
            f"{RED}Error executing command: {command}\n{e.stderr.decode()}{NC}"
        )
        sys.exit(1)


# Function to run a shell command and show its output to the user.
def run_command_verbose(command):
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError:
        print(f"{RED}Error executing command: {command}{NC}")
        sys.exit(1)


# Function to detect the user's Linux distribution (Fedora, Void or Arch).
def detect_distro():
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("ID="):
                    return line.strip().split("=")[1].lower().strip('"')
    return None


# TODO: -> not in use yes, Needs testing
def is_arch_based():
    """
    Is Arch or based on Arch
    """
    try:
        with open("/etc/os-release", "r") as f:
            lines = f.readlines()

        os_info = {
            k.strip(): v.strip().strip('"')
            for k, v in (line.split("=", 1) for line in lines if "=" in line)
        }

        if os_info.get("ID") == "arch":
            return True

        if "arch" in os_info.get("ID_LIKE", "").split():
            return True

    except FileNotFoundError:
        return False

    return False


# Function to install all necessary packages.
def install_dependencies(distro, install_optional=False):
    print(f"{YELLOW}{msg('installing_deps')}{NC}")

    # ---------------------------------------------------------
    # 1. تثبيت حزم النظام (System Packages) حسب التوزيعة
    # ---------------------------------------------------------
    # TODO: -> change detection to a better way
    if distro == "fedora" or distro == "nobara":
        print(YELLOW + "Enabling RPM Fusion and COPR repositories..." + NC)
        run_command_verbose(
            "sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        )
        run_command_verbose("sudo dnf copr enable -y solopasha/hyprland")
        run_command_verbose(
            "sudo dnf copr enable -y errornointernet/quickshell"
        )
        run_command_verbose("sudo dnf install -y hyprland quickshell")

        required_pkgs = "plasma-nm playerctl polkit-kde dolphin konsole brightnessctl gammastep wl-clipboard cliphist sysstat bc plasma-systemsettings acpi fish lm_sensors copyq vnstat jq dbus-devel python3-devel python3.13 python3.13-devel"
        optional_pkgs = "strawberry easyeffects blueman telegram-desktop discord kvantum firefox"

        command = f"sudo dnf install -y {required_pkgs}"
        if install_optional:
            command += f" {optional_pkgs}"

        command = f"{command} --skip-broken"

        print(YELLOW + "Installing main packages (Fedora)..." + NC)
        run_command_verbose(command)

    elif is_arch_based():
        print(YELLOW + "Starting Arch installer" + NC)
        # في آرتش: python هي الحزمة الكاملة وتشمل headers (لا يوجد dev)
        # حالياً python في آرتش هي 3.13
        required_pkgs = "base-devel quickshell brightnessctl konsole ark dolphin ffmpegthumbs playerctl polkit-kde-agent jq gammastep wl-clipboard cliphist hyprpicker hyprshot-git bc sysstat systemsettings acpi fish kde-material-you-colors plasma5support plasma5-integration plasma-framework5 ttf-fantasque-nerd powerdevil libjpeg6-turbo python-regex copyq python python313"
        optional_pkgs = "strawberry easyeffects blueman telegram-desktop discord kvantum firefox"

        command = f"yay -S --noconfirm {required_pkgs}"
        if install_optional:
            command += f" {optional_pkgs}"

        print(YELLOW + "Installing main packages (Arch)..." + NC)
        run_command_verbose(command)

    elif distro == "void":
        print(YELLOW + "Adding Void extra repository..." + NC)
        run_command_verbose(
            "echo repository=https://raw.githubusercontent.com/Encoded14/void-extra/repository-x86_64-glibc | sudo tee /etc/xbps.d/20-void-extra.conf"
        )
        run_command_verbose("sudo xbps-install -Sy")

        required_pkgs = "hyprland quickshell plasma-nm playerctl polkit-kde-agent dolphin konsole brightnessctl gammastep wl-clipboard sysstat bc sassc systemsettings acpi fish-shell gnome-bluetooth power-profiles-daemon lm_sensors CopyQ vnstat nethogs xz swww jq python3-devel dbus-devel glib-devel cmake"
        optional_pkgs = (
            "strawberry easyeffects blueman telegram-desktop kvantum firefox"
        )

        command = f"sudo xbps-install -y {required_pkgs}"
        if install_optional:
            command += f" {optional_pkgs}"

        print(YELLOW + "Installing main packages (Void)..." + NC)
        run_command_verbose(command)

    # ---------------------------------------------------------
    # ملاحظة: نتحقق أولاً من اسم الأمر المناسب لبايثون

    python_cmd = get_python_command()
    print(YELLOW + f"Detected Python command: {python_cmd}" + NC)

    print(YELLOW + "Creating NibrasShell env..." + NC)
    # --clear تحذف البيئة القديمة إذا كانت موجودة لضمان التوافق
    run_command_verbose(
        f"{python_cmd} -m venv ~/.cache/nibrasshell/venv --clear"
    )

    print(YELLOW + "Installing python needed packages using env pip..." + NC)
    # تحديث أدوات pip داخل البيئة الوهمية (مهم جداً لحل مشكلة البناء)
    run_command_verbose(
        "~/.cache/nibrasshell/venv/bin/pip install --upgrade pip wheel setuptools"
    )

    # تثبيت المتطلبات
    run_command_verbose(
        f"~/.cache/nibrasshell/venv/bin/pip install -r {base_dir}/config/quickshell/scripts/python/requirements-3.13.txt"
    )

    print(f"{GREEN}Dependencies installed successfully.{NC}")


def get_python_command():
    """
    يبحث عن أمر بايثون المناسب للإصدار 3.13
    """
    # 1. المحاولة الأولى: البحث الصريح عن python3.13 (موجود في فيدورا وبعض التوزيعات)
    if shutil.which("python3.13"):
        return "python3.13"

    # 2. المحاولة الثانية: التحقق مما إذا كان python3 هو الإصدار 3.13 (شائع في آرتش)
    if shutil.which("python3"):
        try:
            version_output = subprocess.check_output(
                ["python3", "--version"], text=True
            ).strip()
            # الناتج يكون مثلاً: Python 3.13.1
            if "3.13" in version_output:
                return "python3"
        except Exception:
            pass

    # 3. إذا فشل كل شيء، نستخدم python3 ونأمل خيراً (أو يمكنك إرجاع None ورفع خطأ)
    return "python3"


# Function to back up existing configuration files.
def backup_configs():
    print(f"{YELLOW}{msg('backing_up')}{NC}")
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup_dir = os.path.join(
        config_dir, "nibrasshell_backups", f"backup-{timestamp}"
    )
    os.makedirs(backup_dir, exist_ok=True)

    configs_to_backup = ["hypr", "quickshell", "easyeffects"]
    fish_config_path = os.path.join(config_dir, "fish", "config.fish")
    for config in configs_to_backup:
        src = os.path.join(config_dir, config)
        if os.path.exists(src):
            shutil.move(src, os.path.join(backup_dir, config))
    if os.path.exists(fish_config_path):
        os.makedirs(os.path.join(backup_dir, "fish"), exist_ok=True)
        shutil.copy(
            fish_config_path,
            os.path.join(backup_dir, "fish", "config.back.fish"),
        )
    print(f"{GREEN}{msg('backup_created')} {backup_dir}{NC}")


# Helper function to extract .tar.gz archives.
def extract_archives(source_dir, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    for item in os.listdir(source_dir):
        if item.endswith((".tar.gz", ".tar.xz", ".tar.bz2")):
            archive_path = os.path.join(source_dir, item)
            print(f"  -> Extracting {item} to {dest_dir}")
            run_command(f"tar -xvf '{archive_path}' -C '{dest_dir}'")


# Function to set the custom Plasma system fonts.
def set_plasma_font():
    print(YELLOW + "Applying custom fonts to Plasma..." + NC)
    # General font settings
    general_font_name = "JF Flat"
    general_font_size = "11"
    general_font_string = (
        f"'{general_font_name}',{general_font_size},-1,5,50,0,0,0,0,0"
    )
    window_title_font_string = (
        f"'{general_font_name}',{general_font_size},-1,5,75,0,0,0,0,0"  # Bold
    )
    # Monospace font settings (for terminals, code editors)
    mono_font_name = "FantasqueSansM Nerd Font Mono"
    mono_font_size = "10"
    mono_font_string = f"'{mono_font_name}',{mono_font_size},-1,5,50,0,0,0,0,0"

    commands = [
        f"kwriteconfig6 --file kdeglobals --group General --key font {general_font_string}",
        f"kwriteconfig6 --file kdeglobals --group General --key menuFont {general_font_string}",
        f"kwriteconfig6 --file kdeglobals --group WM --key activeFont {window_title_font_string}",
        f"kwriteconfig6 --file kdeglobals --group General --key fixed {mono_font_string}",
    ]

    for cmd in commands:
        try:
            run_command(cmd)
        except SystemExit:
            print(
                f"{RED}Warning: Could not execute a font command. Is 'kwrite-tools' installed?{NC}"
            )
            break


# Interactive function to create the user's JSON config file.
def create_user_config_file():
    print("\n" + "=" * 35)
    print(f"{GREEN}{msg('config_creation_title')}{NC}")
    print(f"{YELLOW}{msg('config_prompt')}{NC}")
    print("=" * 35)

    home_dir = os.path.expanduser("~")
    config = {}

    # Get user input
    config["username"] = input(msg("prompt_username"))
    config["subtitle"] = input(msg("prompt_subtitle"))
    config["profilePicture"] = input(msg("prompt_profile_pic"))

    # Auto-detect and select network interface
    try:
        interfaces = [i for i in os.listdir("/sys/class/net") if i != "lo"]
        if not interfaces:
            raise IndexError
        print(f"{YELLOW}{msg('prompt_network_select')}{NC}")
        for idx, iface in enumerate(interfaces):
            print(f"  {idx + 1}. {iface}")
        choice = int(input("> ")) - 1
        config["networkMonitor"] = interfaces[choice]
    except (IndexError, ValueError, FileNotFoundError):
        print(
            f"{RED}Could not detect network interface. Please edit ~/.nibrasshell.json manually.{NC}"
        )
        config["networkMonitor"] = "wlp0s20f3"  # Default fallback

    config["darkM3WallpaperPath"] = input(msg("prompt_dark_wallpapers"))
    config["lightM3WallpaperPath"] = input(msg("prompt_light_wallpapers"))
    config["weatherLocation"] = input(msg("prompt_city"))
    config["city"] = config["weatherLocation"]
    config["country"] = input(msg("prompt_country"))
    config["country"] = input(msg("prompt_country"))

    use_prayer_ans = input(msg("prompt_use_prayer")).lower()
    config["usePrayerTimes"] = use_prayer_ans in ["y", "yes", "ن", "نعم"]

    # Set default values
    config["changePlasmaColor"] = True
    config["networkTimeout"] = 300
    config["networkInterval"] = 1000

    config["geminiApiKey"] = input(msg("gemini_api_key"))
    config["musicAiApiKey"] = input(msg("music_ai_api_key"))
    config["weatherAiApiKey"] = input(msg("weather_ai_api_key"))
    config["aiPreferredLanguage"] = input(msg("ai_preferred_language"))

    config["scripts"] = {
        "dynamicM3Py": None,
        "get_wallpapers": None,
        "createThumbnail": None,
        "gtk_theme": None,
        "systemInfo": None,
        "deviceLocal": None,
        "cpu": None,
        "ram": None,
        "deviceTemp": None,
        "hardwareInfo": None,
        "cpuUsage": None,
        "ramUsage": None,
        "cpuCores": None,
        "devicesTemp2": None,
        "playerctl": None,
    }

    # Write the config to a JSON file
    file_path = os.path.join(home_dir, ".nibrasshell.json")
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"\n{GREEN}{msg('config_saved')}{NC}")


# Main function to install the NibrasShell configs.
def install_nibrasshell():
    backup_configs()
    print(f"{YELLOW}{msg('installing_nibrasshell')}{NC}")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")
    local_share_dir = os.path.join(home_dir, ".local", "share")
    hypr_dest_dir = os.path.join(config_dir, "hypr")

    # Copy main config folders
    # monitors.conf is user-owned: the shell rewrites it whenever a display
    # setting changes, so copying the repo template would wipe saved values.
    preserved_configs = {"monitors.conf"}
    for item in sorted(os.listdir(script_dir)):
        src = os.path.join(script_dir, item)
        dst = os.path.join(hypr_dest_dir, item)
        if item in preserved_configs and os.path.exists(dst):
            print(f"{YELLOW}Keeping existing {item}{NC}")
            continue
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            shutil.copy2(src, dst)
    shutil.copytree(
        os.path.join(hypr_dest_dir, "config", "quickshell"),
        os.path.join(config_dir, "quickshell"),
        dirs_exist_ok=True,
    )
    shutil.copytree(
        os.path.join(hypr_dest_dir, "config", "easyeffects"),
        os.path.join(config_dir, "easyeffects"),
        dirs_exist_ok=True,
    )
    os.makedirs(os.path.join(config_dir, "fish"), exist_ok=True)
    shutil.copy(
        os.path.join(hypr_dest_dir, "config", "config.fish"),
        os.path.join(config_dir, "fish", "config.fish"),
    )

    # Copy and extract themes, icons, and fonts
    print(YELLOW + "Setting up themes, icons, and fonts..." + NC)
    base_config_src = os.path.join(hypr_dest_dir, "config")
    fonts_dest = os.path.join(home_dir, ".fonts")
    os.makedirs(fonts_dest, exist_ok=True)
    shutil.copytree(
        os.path.join(base_config_src, ".fonts"), fonts_dest, dirs_exist_ok=True
    )
    extract_archives(
        os.path.join(base_config_src, "gtk-themes"),
        os.path.join(home_dir, ".themes"),
    )
    extract_archives(
        os.path.join(base_config_src, "icons"),
        os.path.join(local_share_dir, "icons"),
    )
    konsole_dest = os.path.join(local_share_dir, "konsole")
    os.makedirs(konsole_dest, exist_ok=True)
    shutil.copytree(
        os.path.join(base_config_src, "konsole"),
        konsole_dest,
        dirs_exist_ok=True,
    )
    colors_dest = os.path.join(local_share_dir, "color-schemes")
    os.makedirs(colors_dest, exist_ok=True)
    shutil.copytree(
        os.path.join(base_config_src, "plasma-colors"),
        colors_dest,
        dirs_exist_ok=True,
    )
    kvantum_dest = os.path.join(config_dir, "Kvantum")
    os.makedirs(kvantum_dest, exist_ok=True)
    shutil.copytree(
        os.path.join(base_config_src, "kvantum-themes"),
        kvantum_dest,
        dirs_exist_ok=True,
    )

    # Apply system fonts
    set_plasma_font()

    # Set permissions and clean up
    run_command(f"chmod +x {hypr_dest_dir}/scripts/*")
    run_command(f"chmod +x {config_dir}/quickshell/scripts/*")
    installer_in_dest = os.path.join(hypr_dest_dir, os.path.basename(__file__))
    if os.path.exists(installer_in_dest):
        os.remove(installer_in_dest)

    # Prompt user for personal settings
    create_user_config_file()

    print(f"{GREEN}{msg('install_complete')}{NC}")
    print(f"{YELLOW}{msg('reboot_prompt')}{NC}")


def update_quickshell():
    print(f"{YELLOW}{msg('updating_quickshell')}{NC}")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")

    # 1. Git Pull
    print(f"{YELLOW}{msg('pulling_updates')}{NC}")
    try:
        # Change to the script's directory to run git pull
        os.chdir(script_dir)
        run_command_verbose("git pull")
    except Exception as e:
        print(f"{RED}Error during 'git pull': {e}{NC}")
        return
    finally:
        # It's good practice to return to the original directory
        # though it might not be strictly necessary if the script exits.
        os.chdir(os.path.expanduser("~"))

    # 2. Copy only the quickshell files
    print(f"{YELLOW}{msg('copying_files')}{NC}")
    source_quickshell_dir = os.path.join(script_dir, "config", "quickshell")
    dest_quickshell_dir = os.path.join(config_dir, "quickshell")

    if not os.path.exists(source_quickshell_dir):
        print(f"{RED}Source directory not found: {source_quickshell_dir}{NC}")
        return

    # Create destination directory if it doesn't exist
    os.makedirs(dest_quickshell_dir, exist_ok=True)

    try:
        shutil.copytree(
            source_quickshell_dir, dest_quickshell_dir, dirs_exist_ok=True
        )
        print(f"{GREEN}{msg('update_complete')}{NC}")
    except Exception as e:
        print(f"{RED}Error copying files: {e}{NC}")


# Function to uninstall NibrasShell and restore backups.
def uninstall_nibrasshell():
    confirm = input(f"{YELLOW}{msg('uninstall_prompt')}{NC}").lower()
    if confirm in ["y", "yes", "ن", "نعم"]:
        print(f"{YELLOW}{msg('uninstalling')}{NC}")
        home_dir = os.path.expanduser("~")
        config_dir = os.path.join(home_dir, ".config")

        for d in ["hypr", "quickshell", "easyeffects"]:
            path = os.path.join(config_dir, d)
            if os.path.exists(path):
                shutil.rmtree(path)

        restore_confirm = input(f"{YELLOW}{msg('restore_prompt')}{NC}").lower()
        if restore_confirm in ["y", "yes", "ن", "نعم"]:
            backup_base_dir = os.path.join(config_dir, "nibrasshell_backups")
            if os.path.exists(backup_base_dir) and os.listdir(backup_base_dir):
                all_backups = sorted(os.listdir(backup_base_dir), reverse=True)
                latest_backup_dir = os.path.join(
                    backup_base_dir, all_backups[0]
                )
                print(
                    f"{YELLOW}{msg('restoring_backup')} {latest_backup_dir}{NC}"
                )

                for item in os.listdir(latest_backup_dir):
                    src_path = os.path.join(latest_backup_dir, item)
                    dest_path = os.path.join(config_dir, item)
                    if os.path.isdir(src_path):
                        shutil.copytree(
                            src_path, dest_path, dirs_exist_ok=True
                        )
            else:
                print(f"{RED}{msg('no_backup_found')}{NC}")
        print(f"{GREEN}{msg('uninstall_complete')}{NC}")


# Function to prevent the script from being run as root.
def check_for_root():
    if os.geteuid() == 0:
        print(
            f"{RED}Error: Do not run this script with sudo or as the root user.{NC}"
        )
        print(
            f"{YELLOW}Please run it as your normal user: python3 install.py{NC}"
        )
        sys.exit(1)


# Function to display the dependency installation sub-menu.
def show_dependency_menu():
    distro = detect_distro()
    if distro not in ["arch", "fedora", "void"]:
        print(f"{RED}{msg('distro_check_fail')}{NC}")
        return

    print("\n" + "=" * 30)
    print(f"{GREEN}{msg('deps_menu_title')}{NC}")
    print("=" * 30)
    print(msg("install_required_only"))
    print(msg("install_all_deps"))

    choice = input(f"{YELLOW}{msg('choose_option')}{NC}")
    if choice == "1":
        install_dependencies(distro, install_optional=False)
    elif choice == "2":
        install_dependencies(distro, install_optional=True)
    else:
        print(f"{RED}{msg('invalid_option')}{NC}")


# The main function that runs the script.
def main():
    check_for_root()
    global LANG
    print(f"{GREEN}Choose your language / اختر لغتك / Vyberte jazyk:{NC}")
    print("1. English")
    print("2. العربية")
    print("3. Česky")
    lang_choice = input("> ")
    if lang_choice == "2":
        LANG = "ar"
    if lang_choice == "3":
        LANG = "cs"

    while True:
        print("\n" + "=" * 45)
        print(f"{GREEN}{msg('main_menu_title')}{NC}")
        print("=" * 45)
        print(msg("install_deps_menu"))
        print(msg("install_local"))
        print(msg("update_quickshell"))
        print(msg("uninstall"))
        print(msg("create_config"))
        print(msg("exit"))

        choice = input(f"{YELLOW}{msg('choose_option')}{NC}")

        if choice == "1":
            show_dependency_menu()
        elif choice == "2":
            install_nibrasshell()
        elif choice == "3":
            update_quickshell()
        elif choice == "4":
            uninstall_nibrasshell()
        elif choice == "5":
            create_user_config_file()
        elif choice == "6":
            break
        else:
            print(f"{RED}{msg('invalid_option')}{NC}")


# This line ensures the main function is called when the script is executed.
if __name__ == "__main__":
    main()
