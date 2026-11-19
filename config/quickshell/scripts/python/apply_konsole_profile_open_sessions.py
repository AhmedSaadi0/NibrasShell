#!/usr/bin/env python3
from __future__ import annotations

import argparse
import configparser
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

DBUS_TIMEOUT_SEC = 5
SERVICE_RE = re.compile(r"^org\.kde\.konsole(?:-\d+)?$")
SESSION_PATH_RE = re.compile(r"^/Sessions/\d+$")
WINDOW_PATH_RE = re.compile(r"^/Windows/\d+$")


def run_cmd(
    cmd: list[str], timeout: int = DBUS_TIMEOUT_SEC
) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


def qdbus_candidates() -> list[str]:
    # Prefer Qt 6 / Plasma 6 binaries before generic `qdbus` (which may be Qt 5).
    raw_candidates = [
        os.environ.get("QDBUS_BIN"),
        shutil.which("qdbus6"),
        shutil.which("qdbus-qt6"),
        "/usr/bin/qdbus6",
        "/usr/bin/qdbus-qt6",
        "/usr/lib/qt6/bin/qdbus",
        "/usr/lib64/qt6/bin/qdbus",
        shutil.which("qdbus"),
        "/usr/bin/qdbus",
    ]
    result: list[str] = []
    for candidate in raw_candidates:
        if (
            candidate
            and os.path.isfile(candidate)
            and os.access(candidate, os.X_OK)
            and candidate not in result
        ):
            result.append(candidate)
    return result


def pick_dbus_backend() -> tuple[str, str] | None:
    for candidate in qdbus_candidates():
        probe = run_cmd([candidate], timeout=3)
        if (
            probe is not None
            and probe.returncode == 0
            and "org.freedesktop.DBus" in probe.stdout
        ):
            return ("qdbus", candidate)

    # Fallback for minimal Plasma 6 installs without qt6-tools.
    busctl_bin = shutil.which("busctl")
    if busctl_bin:
        probe = run_cmd(
            [busctl_bin, "--user", "list", "--no-legend"], timeout=3
        )
        if probe is not None and probe.returncode == 0:
            return ("busctl", busctl_bin)

    return None


def normalize_profile(raw_profile: str) -> tuple[str, str]:
    cleaned = raw_profile.strip()
    if cleaned.endswith(".profile"):
        name = cleaned[: -len(".profile")]
        filename = cleaned
    else:
        name = cleaned
        filename = f"{cleaned}.profile"
    return name, filename


def list_konsole_services(backend: tuple[str, str]) -> list[str]:
    kind, binary = backend
    if kind == "qdbus":
        res = run_cmd([binary])
        if res is None or res.returncode != 0:
            return []
        lines = (line.strip() for line in res.stdout.splitlines())
    else:
        res = run_cmd([binary, "--user", "list", "--no-legend"])
        if res is None or res.returncode != 0:
            return []
        lines = (
            line.split(None, 1)[0]
            for line in res.stdout.splitlines()
            if line.strip()
        )

    return sorted({name for name in lines if SERVICE_RE.match(name)})


def list_object_paths(
    backend: tuple[str, str], service: str
) -> tuple[list[str], list[str]]:
    kind, binary = backend
    if kind == "qdbus":
        res = run_cmd([binary, service])
    else:
        res = run_cmd([binary, "--user", "tree", "--list", service])

    if res is None or res.returncode != 0:
        return [], []

    sessions: list[str] = []
    windows: list[str] = []
    for raw_line in res.stdout.splitlines():
        path = raw_line.strip()
        if SESSION_PATH_RE.match(path):
            sessions.append(path)
        elif WINDOW_PATH_RE.match(path):
            windows.append(path)
    return sessions, windows


def dbus_call_str(
    backend: tuple[str, str],
    service: str,
    path: str,
    interface: str,
    method: str,
    arg: str | None = None,
) -> subprocess.CompletedProcess[str] | None:
    kind, binary = backend
    if kind == "qdbus":
        cmd = [binary, service, path, f"{interface}.{method}"]
        if arg is not None:
            cmd.append(arg)
        return run_cmd(cmd)

    cmd = [binary, "--user", "call", service, path, interface, method]
    if arg is not None:
        cmd.extend(["s", arg])
    return run_cmd(cmd)


def parse_dbus_string_output(kind: str, stdout: str) -> str:
    text = stdout.strip()
    if kind == "busctl":
        # `busctl call` outputs: s "ProfileName"
        m = re.match(r'^s\s+"(.*)"$', text)
        if m:
            return m.group(1)
    return text.strip('"')


def apply_and_verify(
    backend: tuple[str, str],
    service: str,
    path: str,
    interface: str,
    setter: str,
    getter: str,
    profile_name: str,
    profile_file: str,
) -> bool:
    kind, _ = backend
    for value in (profile_name, profile_file):
        res = dbus_call_str(backend, service, path, interface, setter, value)
        if res is None or res.returncode != 0:
            continue

        verify = dbus_call_str(backend, service, path, interface, getter)
        if verify is not None and verify.returncode == 0:
            current = parse_dbus_string_output(kind, verify.stdout)
            if current in (profile_name, profile_file):
                return True
        else:
            # If getter is unavailable, trust zero exit code from setter.
            return True
    return False


def persist_default_profile(profile_file: str) -> bool:
    config_home = Path(
        os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config")
    )
    konsolerc = config_home / "konsolerc"

    for tool in ("kwriteconfig6", "kwriteconfig5"):
        tool_bin = shutil.which(tool)
        if tool_bin:
            res = run_cmd(
                [
                    tool_bin,
                    "--file",
                    str(konsolerc),
                    "--group",
                    "Desktop Entry",
                    "--key",
                    "DefaultProfile",
                    profile_file,
                ]
            )
            if res is not None and res.returncode == 0:
                return True

    # Safe stdlib fallback if kwriteconfig6 is not installed.
    try:
        konsolerc.parent.mkdir(parents=True, exist_ok=True)
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str  # Preserve KDE CamelCase keys.
        if konsolerc.is_file():
            cp.read(konsolerc, encoding="utf-8")
        if not cp.has_section("Desktop Entry"):
            cp.add_section("Desktop Entry")
        cp.set("Desktop Entry", "DefaultProfile", profile_file)
        with konsolerc.open("w", encoding="utf-8") as fh:
            cp.write(fh, space_around_delimiters=False)
        return True
    except OSError as exc:
        print(
            f"[KonsoleProfile] Failed to update {konsolerc}: {exc}",
            file=sys.stderr,
        )
        return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Switch Konsole profile on Plasma 6."
    )
    parser.add_argument(
        "--profile",
        required=True,
        help="Konsole profile name (with or without .profile)",
    )
    parser.add_argument(
        "--no-persist",
        action="store_true",
        help="Do not update DefaultProfile in konsolerc",
    )
    args = parser.parse_args()

    profile_name, profile_file = normalize_profile(args.profile)
    if not profile_name:
        print("[KonsoleProfile] Empty profile name.", file=sys.stderr)
        return 1

    persisted = (
        True if args.no_persist else persist_default_profile(profile_file)
    )

    backend = pick_dbus_backend()
    if not backend:
        print(
            f"[KonsoleProfile] No qdbus6/qdbus/busctl found; persisted={persisted}."
        )
        return 0

    services = list_konsole_services(backend)
    if not services:
        print(
            f"[KonsoleProfile] No running Konsole DBus service found; persisted={persisted}."
        )
        return 0

    sessions_updated = 0
    sessions_failed = 0
    windows_updated = 0
    windows_failed = 0

    for service in services:
        sessions, windows = list_object_paths(backend, service)

        for session_path in sessions:
            ok = apply_and_verify(
                backend,
                service,
                session_path,
                "org.kde.konsole.Session",
                "setProfile",
                "profile",
                profile_name,
                profile_file,
            )
            if ok:
                sessions_updated += 1
            else:
                sessions_failed += 1

        for window_path in windows:
            ok = apply_and_verify(
                backend,
                service,
                window_path,
                "org.kde.konsole.Window",
                "setDefaultProfile",
                "defaultProfile",
                profile_name,
                profile_file,
            )
            if ok:
                windows_updated += 1
            else:
                windows_failed += 1

    print(
        "[KonsoleProfile] "
        f"backend={backend[0]} persisted={persisted} "
        f"sessions={sessions_updated}/{sessions_updated + sessions_failed} "
        f"windows={windows_updated}/{windows_updated + windows_failed}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
