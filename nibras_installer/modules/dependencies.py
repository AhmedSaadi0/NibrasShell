# modules/dependencies.py
import shutil
import subprocess
import sys

from config import GREEN, NC, PROJECT_ROOT, RED, YELLOW

from .i18n import msg
from .utils import (
    detect_distro,
    is_arch_based,
    run_command,
    run_command_verbose,
)


def install_fedora(install_optional):
    print(YELLOW + "Enabling RPM Fusion and COPR repositories..." + NC)
    run_command_verbose(
        "sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    )
    # run_command_verbose("sudo dnf copr enable -y solopasha/hyprland")
    run_command_verbose("sudo dnf copr enable lionheartp/Hyprland")
    run_command_verbose("sudo dnf copr enable -y errornointernet/quickshell")
    run_command_verbose(
        "sudo dnf install -y hyprland quickshell hyprland hyprshot hyprpicker wl-clipboard"
    )

    required_pkgs = "plasma-nm playerctl polkit-kde dolphin konsole brightnessctl gammastep wl-clipboard cliphist sysstat bc glib2-devel dbus-glib-devel plasma-systemsettings acpi fish gnome-bluetooth-libs lm_sensors vnstat nethogs jq dbus-devel python3-devel python3.13 python3.13-devel gcc hyprland-guiutils"
    optional_pkgs = "strawberry easyeffects blueman telegram-desktop discord kvantum firefox"

    base_command = f"sudo dnf install -y {required_pkgs}"
    if install_optional:
        base_command += f" {optional_pkgs}"

    print(YELLOW + "Installing main packages..." + NC)

    # محاولة التثبيت والتعامل مع الأخطاء
    try:
        # نستخدم subprocess مباشرة هنا لنتمكن من التقاط الخطأ (Exception)
        subprocess.run(base_command, check=True, shell=True)
    except subprocess.CalledProcessError:
        print(f"\n{RED}{msg('dnf_error')}{NC}")
        print(f"{YELLOW}{msg('dnf_conflict_prompt')}{NC}")
        print(msg("opt_allow_erasing"))
        print(msg("opt_skip_broken"))
        print(msg("opt_cancel"))

        choice = input(f"{YELLOW}{msg('choose_option')}{NC}")

        retry_command = base_command
        if choice == "1":
            print(YELLOW + "Retrying with --allowerasing..." + NC)
            retry_command += " --allowerasing"
        elif choice == "2":
            print(YELLOW + "Retrying with --skip-broken..." + NC)
            retry_command += " --skip-broken"
        else:
            print(RED + "Installation cancelled by user." + NC)
            sys.exit(1)

        # المحاولة الثانية بناءً على اختيار المستخدم
        try:
            run_command_verbose(retry_command)
        except SystemExit:
            # run_command_verbose يقوم بعمل sys.exit إذا فشل، لذا لا داعي لعمل شيء هنا
            pass

    print(YELLOW + "Installing python needed packages using env pip..." + NC)
    install_python_env()


def install_arch(install_optional):
    print(YELLOW + "Starting Arch installer" + NC)
    required_pkgs = "base-devel quickshell brightnessctl network-manager-applet konsole ark dolphin ffmpegthumbs playerctl polkit-kde-agent jq gammastep wl-clipboard cliphist hyprpicker hyprshot-git bc sysstat sassc systemsettings acpi fish kde-material-you-colors plasma5support plasma5-integration plasma-framework5 ttf-jetbrains-mono-nerd ttf-fantasque-nerd powerdevil gnome-bluetooth-3.0 power-profiles-daemon libjpeg6-turbo python-regex python-pillow python-psutil python python313"
    optional_pkgs = "strawberry easyeffects blueman telegram-desktop discord kvantum firefox"

    command = f"yay -S {required_pkgs}"
    if install_optional:
        command += f" {optional_pkgs}"
    run_command_verbose(command)
    print(YELLOW + "Installing python needed packages using env pip..." + NC)
    install_python_env()


def install_void(install_optional):
    print(YELLOW + "Adding Void extra repository with hyprland..." + NC)
    run_command_verbose(
        "echo repository=https://raw.githubusercontent.com/Encoded14/void-extra/repository-x86_64-glibc | sudo tee /etc/xbps.d/20-void-extra.conf"
    )
    run_command_verbose("sudo xbps-install -S")

    required_pkgs = "hyprland quickshell plasma-nm playerctl polkit-kde-agent dolphin konsole brightnessctl gammastep wl-clipboard sysstat bc sassc systemsettings acpi fish-shell gnome-bluetooth power-profiles-daemon lm_sensors vnstat nethogs xz jq python3-devel dbus-devel glib-devel cmake nerd-fonts"
    optional_pkgs = (
        "strawberry easyeffects blueman telegram-desktop kvantum firefox"
    )

    command = f"sudo xbps-install -y {required_pkgs}"
    if install_optional:
        command += f" {optional_pkgs}"

    print(YELLOW + "Installing main packages..." + NC)
    run_command_verbose(command)
    print(YELLOW + "Installing python needed packages using env pip..." + NC)
    install_python_env()


def get_python_command():
    if shutil.which("python3.13"):
        return "python3.13"
    if shutil.which("python3"):
        try:
            version_output = subprocess.check_output(
                ["python3", "--version"], text=True
            ).strip()
            if "3.13" in version_output:
                return "python3"
        except Exception:
            pass
    return "python3"


def install_python_env():
    python_cmd = get_python_command()
    print(YELLOW + f"Detected Python command: {python_cmd}" + NC)
    run_command_verbose(
        f"{python_cmd} -m venv ~/.cache/nibrasshell/venv --clear"
    )
    run_command_verbose(
        "~/.cache/nibrasshell/venv/bin/pip install --upgrade pip wheel setuptools"
    )
    run_command_verbose(
        f"~/.cache/nibrasshell/venv/bin/pip install -r {PROJECT_ROOT}/config/quickshell/scripts/python/requirements-3.13.txt"
    )


def install_dependencies(distro, install_optional=False):
    print(f"{YELLOW}{msg('installing_deps')}{NC}")

    if distro == "fedora":
        install_fedora(install_optional)
    elif distro == "arch":
        install_arch(install_optional)
    elif distro == "void":
        install_void(install_optional)

    print(f"{GREEN}{msg('deps_success_msg')}{NC}")
    print(YELLOW + "Enabling vnstat service..." + NC)
    run_command("sudo systemctl enable --now vnstat", exit_on_fail=False)

    # print(
    #     f"{GREEN}Dependencies installed successfully. You can do step 2 now{NC}"
    # )


def show_dependency_menu():
    distro = detect_distro()
    # Basic logic check for supported distros
    if distro not in ["fedora", "arch", "void"]:
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
