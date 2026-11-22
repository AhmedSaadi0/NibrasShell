# modules/installer.py
import os
import shutil
from datetime import datetime

from config import GREEN, NC, PROJECT_ROOT, RED, YELLOW

from .i18n import msg
from .user_config import create_user_config_file
from .utils import run_command


def backup_configs():
    print(f"{YELLOW}{msg('backing_up')}{NC}")
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup_dir = os.path.join(config_dir, "nibrasshell_backups", f"backup-{timestamp}")
    os.makedirs(backup_dir, exist_ok=True)

    configs_to_backup = [
        "hypr", "quickshell", "easyeffects",
        "matugen", "kitty", "alacritty", "gtk-3.0", "gtk-4.0",
    ]
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


def extract_archives(source_dir, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    if not os.path.exists(source_dir):
        return

    for item in os.listdir(source_dir):
        archive_path = os.path.join(source_dir, item)
        if item.endswith((".tar.gz", ".tar.xz", ".tar.bz2")):
            print(f"  -> Extracting {item} to {dest_dir}")
            run_command(f"tar -xvf '{archive_path}' -C '{dest_dir}'")
        elif item.endswith(".zip"):
            print(f"  -> Extracting {item} to {dest_dir}")
            # unzip مطلوب لفك ضغط ثيمات GTK مثل Catppuccin/Gruvbox/Tokyonight
            if shutil.which("unzip") is None:
                print(
                    f"{RED}Warning: unzip not found, skipping {item}. Install unzip.{NC}"
                )
                continue
            run_command(f"unzip -o '{archive_path}' -d '{dest_dir}'")


def set_plasma_font():
    print(YELLOW + "Applying custom fonts to Plasma..." + NC)
    general_font = "'JF Flat',11,-1,5,50,0,0,0,0,0"
    title_font = "'JF Flat',11,-1,5,75,0,0,0,0,0"
    mono_font = "'FantasqueSansM Nerd Font Mono',10,-1,5,50,0,0,0,0,0"

    commands = [
        f"kwriteconfig6 --file kdeglobals --group General --key font {general_font}",
        f"kwriteconfig6 --file kdeglobals --group General --key menuFont {general_font}",
        f"kwriteconfig6 --file kdeglobals --group WM --key activeFont {title_font}",
        f"kwriteconfig6 --file kdeglobals --group General --key fixed {mono_font}",
    ]

    for cmd in commands:
        try:
            run_command(cmd)
        except SystemExit:
            print(
                f"{RED}Warning: Could not execute a font command. Is 'kwriteconfig6' installed?{NC}"
            )
            break


def install_nibrasshell():
    backup_configs()
    print(f"{YELLOW}{msg('installing_nibrasshell')}{NC}")

    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")
    local_share_dir = os.path.join(home_dir, ".local", "share")
    hypr_dest_dir = os.path.join(config_dir, "hypr")

    # PROJECT_ROOT contains the 'main.py'.
    # We assume the resource folders (config, scripts) are inside PROJECT_ROOT.
    # Note: Adjust logic if your 'hypr' files are in a specific subfolder.
    # Assuming the original script had 'config' folder alongside it.

    # Let's assume the resources are in PROJECT_ROOT (files should be there)
    # If you want to copy the WHOLE project as 'hypr' config:
    shutil.copytree(
        PROJECT_ROOT,
        hypr_dest_dir,
        dirs_exist_ok=True,
        ignore=shutil.ignore_patterns("nibras_installer", ".git", "__pycache__"),
    )

    # Setup specific configs
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
    fish_src = os.path.join(hypr_dest_dir, "config", "config.fish")
    if os.path.exists(fish_src):
        shutil.copy(fish_src, os.path.join(config_dir, "fish", "config.fish"))

    # Extract themes/icons/fonts
    print(YELLOW + "Setting up themes, icons, and fonts..." + NC)
    base_config_src = os.path.join(hypr_dest_dir, "config")

    shutil.copytree(
        os.path.join(base_config_src, ".fonts"),
        os.path.join(home_dir, ".fonts"),
        dirs_exist_ok=True,
    )

    extract_archives(
        os.path.join(base_config_src, "gtk-themes"),
        os.path.join(home_dir, ".themes"),
    )
    extract_archives(
        os.path.join(base_config_src, "icons"),
        os.path.join(local_share_dir, "icons"),
    )

    shutil.copytree(
        os.path.join(base_config_src, "konsole"),
        os.path.join(local_share_dir, "konsole"),
        dirs_exist_ok=True,
    )
    shutil.copytree(
        os.path.join(base_config_src, "plasma-colors"),
        os.path.join(local_share_dir, "color-schemes"),
        dirs_exist_ok=True,
    )
    shutil.copytree(
        os.path.join(base_config_src, "kvantum-themes"),
        os.path.join(config_dir, "Kvantum"),
        dirs_exist_ok=True,
    )

    for name in ("matugen", "kitty", "alacritty", "gtk-3.0", "gtk-4.0"):
        src = os.path.join(base_config_src, name)
        if os.path.exists(src):
            shutil.copytree(src, os.path.join(config_dir, name), dirs_exist_ok=True)

    set_plasma_font()

    # Permissions
    run_command(f"chmod +x {hypr_dest_dir}/scripts/*")
    run_command(f"chmod +x {config_dir}/quickshell/scripts/*")

    create_user_config_file()
    print(f"{GREEN}{msg('install_complete')}{NC}")
    print(f"{YELLOW}{msg('reboot_prompt')}{NC}")


def update_quickshell():
    print(f"{YELLOW}{msg('updating_quickshell')}{NC}")
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")

    if not os.path.exists(os.path.join(PROJECT_ROOT, ".git")):
        print(f"{RED}Error: {PROJECT_ROOT} is not a git repository.{NC}")
        print(f"{YELLOW}Please clone the repository using git first.{NC}")
        return

    print(f"{YELLOW}{msg('pulling_updates')}{NC}")
    try:
        os.chdir(PROJECT_ROOT)
        run_command("git pull")
    except Exception as e:
        print(f"{RED}Error during 'git pull': {e}{NC}")
        return

    print(f"{YELLOW}{msg('copying_files')}{NC}")
    source_quickshell = os.path.join(PROJECT_ROOT, "config", "quickshell")
    dest_quickshell = os.path.join(config_dir, "quickshell")

    if not os.path.exists(source_quickshell):
        print(f"{RED}Source directory not found: {source_quickshell}{NC}")
        return

    try:
        shutil.copytree(source_quickshell, dest_quickshell, dirs_exist_ok=True)
        # مزامنة ألوان بلازما وكونسول للثيمات الجديدة (Solarized/RosePine/Oxocarbon)
        for sub in ["plasma-colors", "konsole"]:
            src = os.path.join(PROJECT_ROOT, "config", sub)
            if sub == "plasma-colors":
                dst = os.path.join(home_dir, ".local", "share", "color-schemes")
            else:
                dst = os.path.join(home_dir, ".local", "share", sub)
            if os.path.exists(src):
                print(f"  -> Syncing {sub}...")
                shutil.copytree(src, dst, dirs_exist_ok=True)
        for name in ("matugen", "kitty", "alacritty", "gtk-3.0", "gtk-4.0"):
            src = os.path.join(PROJECT_ROOT, "config", name)
            if os.path.exists(src):
                shutil.copytree(src, os.path.join(config_dir, name), dirs_exist_ok=True)
        print(f"{GREEN}{msg('update_complete')}{NC}")
    except Exception as e:
        print(f"{RED}Error copying files: {e}{NC}")


def uninstall_nibrasshell():
    confirm = input(f"{YELLOW}{msg('uninstall_prompt')}{NC}").lower()
    if confirm not in ["y", "yes", "ن", "نعم"]:
        return

    print(f"{YELLOW}{msg('uninstalling')}{NC}")
    home_dir = os.path.expanduser("~")
    config_dir = os.path.join(home_dir, ".config")

    for d in [
        "hypr", "quickshell", "easyeffects",
        "matugen", "kitty", "alacritty", "gtk-3.0", "gtk-4.0",
    ]:
        path = os.path.join(config_dir, d)
        if os.path.exists(path):
            shutil.rmtree(path)

    restore_confirm = input(f"{YELLOW}{msg('restore_prompt')}{NC}").lower()
    if restore_confirm in ["y", "yes", "ن", "نعم"]:
        backup_base_dir = os.path.join(config_dir, "nibrasshell_backups")
        if os.path.exists(backup_base_dir) and os.listdir(backup_base_dir):
            all_backups = sorted(os.listdir(backup_base_dir), reverse=True)
            latest_backup_dir = os.path.join(backup_base_dir, all_backups[0])
            print(f"{YELLOW}{msg('restoring_backup')} {latest_backup_dir}{NC}")

            for item in os.listdir(latest_backup_dir):
                src_path = os.path.join(latest_backup_dir, item)
                dest_path = os.path.join(config_dir, item)
                if os.path.isdir(src_path):
                    shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
                else:
                    shutil.copy(src_path, dest_path)
        else:
            print(f"{RED}{msg('no_backup_found')}{NC}")

    print(f"{GREEN}{msg('uninstall_complete')}{NC}")
