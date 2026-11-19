# modules/utils.py
import os
import subprocess
import sys

from config import NC, RED, YELLOW


def run_command(command, exit_on_fail=True):
    try:
        subprocess.run(
            command,
            check=True,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(
            f"{RED}Error executing command: {command}\n{e.stderr.decode()}{NC}"
        )
        if exit_on_fail:
            sys.exit(1)
        return False


def run_command_verbose(command):
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError:
        print(f"{RED}Error executing command: {command}{NC}")
        sys.exit(1)


def _read_os_release():
    info = {}
    if not os.path.exists("/etc/os-release"):
        return info
    with open("/etc/os-release") as f:
        for line in f:
            if "=" not in line:
                continue
            key, value = line.strip().split("=", 1)
            info[key.strip()] = value.strip().strip('"')
    return info


def detect_distro():
    info = _read_os_release()
    distro_id = info.get("ID", "").lower()
    id_like = info.get("ID_LIKE", "").lower().split()

    fedora_like = {
        "fedora",
        "nobara",
        "bazzite",
        "ultramarine",
        "silverblue",
        "kinoite",
        "ublue",
    }

    if distro_id == "void":
        return "void"
    if distro_id == "arch" or "arch" in id_like:
        return "arch"
    if (
        distro_id in fedora_like
        or "fedora" in id_like
        or "rhel" in id_like
        or "centos" in id_like
    ):
        return "fedora"

    return distro_id or None


def is_arch_based():
    return detect_distro() == "arch"


def check_for_root():
    if os.geteuid() == 0:
        print(
            f"{RED}Error: Do not run this script with sudo or as the root user.{NC}"
        )
        print(
            f"{YELLOW}Please run it as your normal user: python3 main.py{NC}"
        )
        sys.exit(1)
