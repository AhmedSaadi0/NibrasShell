#!/usr/bin/env python3
"""Deterministic runtime discovery for one journald record (Phase 1).

Plan of record: docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md
§7 C2 boundary table, §8.1-8.5 (algorithm/taxonomy/outcome/parse/shape),
§16.1 runtime-discovery test matrix, §18 additive-only mandate.

Hard boundaries (§7 C2):
- no LLM, no network, no privilege escalation, no user switching;
- trusted journal fields are the ONLY event-time identity evidence;
- present-day /proc observations never upgrade an event-time claim;
- no host/kernel fallback; unknown stays unknown/ambiguous/unavailable;
- conmon is a host-side monitor candidate, never a workload classification;
- cursors pass through verbatim (opaque strings, never int-parsed);
- injectable Runner covers EVERY /proc read and runtime query.

Usage (unused by callers yet — §18):
    from ai.evidence import discovery, models
    result = discovery.discover(record, discovery.OsRunner())
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
from dataclasses import dataclass
from typing import Any, Callable, Protocol, Sequence

from . import models as m

# ─── injectable boundaries (§16 "injectable Runner at every edge") ─────────

BOOT_ID_PATH = "/proc/sys/kernel/random/boot_id"
DEFAULT_TOOL_TIMEOUT_S = 5.0
PODMAN_INSPECT_ARGV = ("podman", "container", "inspect", "--type", "container")

# bounded reads (§8.3 preamble: all sizes bounded)
MAX_CGROUP_BYTES = 4096
MAX_STAT_BYTES = 4096
MAX_STATUS_BYTES = 8192
MAX_AUDIT_BODY_CHARS = 8192
MAX_INSPECT_BYTES = 1 << 20
MAX_BOOT_ID_BYTES = 128


@dataclass(frozen=True)
class ProcResult:
    """Outcome of an injected subprocess (read-only runtime queries only)."""

    returncode: int
    stdout: str
    stderr: str


class Runner(Protocol):
    """Every /proc file read and podman/systemd query passes through here."""

    def read_file(self, path: str) -> bytes: ...

    def run(
        self, argv: Sequence[str], timeout_s: float = DEFAULT_TOOL_TIMEOUT_S
    ) -> ProcResult: ...


class OsRunner:
    """Default runner: plain file reads + subprocess (timeout, shell=False)."""

    def read_file(self, path: str) -> bytes:
        with open(path, "rb") as fh:
            return fh.read()

    def run(
        self, argv: Sequence[str], timeout_s: float = DEFAULT_TOOL_TIMEOUT_S
    ) -> ProcResult:
        proc = subprocess.run(
            list(argv),
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
            shell=False,
        )
        return ProcResult(proc.returncode, proc.stdout or "", proc.stderr or "")


# ─── trusted-field helpers (§8.3 step 1) ────────────────────────────────────


def _trusted_str(record: dict, key: str) -> str | None:
    """journalctl --output=json emits strings; a list means non-unique field.

    Non-unique (list) values stay OUT of identity decisions and are flagged
    down the line (INVALID_DATA) — never silently taken as first element.
    """
    value = record.get(key)
    if isinstance(value, str):
        return value
    return None


def _trusted_int(record: dict, key: str, missing: list[str]) -> int | None:
    raw = _trusted_str(record, key)
    if raw is None:
        # absent key ≠ non-unique (list) value: flagged distinctly
        missing.append(f"{key}:{m.REASON_INVALID_DATA}" if key in record else key)
        return None
    return _int_or_flag(raw, key, missing)


def _int_or_flag(raw: str, key: str, missing: list[str]) -> int | None:
    raw = raw.strip()
    if not raw:
        missing.append(f"{key}:{m.REASON_INVALID_DATA}")
        return None
    if not re.fullmatch(r"\d+", raw):
        missing.append(f"{key}:{m.REASON_INVALID_DATA}")
        return None
    return int(raw)


def _optional_int(raw: str | None) -> int | None:
    if raw is None:
        return None
    raw = raw.strip()
    return int(raw) if re.fullmatch(r"\d+", raw) else None


def _classify_transport(raw: str | None, record: dict, missing: list[str]) -> str:
    mapping = {
        "kernel": m.TRANSPORT_KERNEL,
        "audit": m.TRANSPORT_AUDIT,
        "driver": m.TRANSPORT_DRIVER,
        "stdout": m.TRANSPORT_STDOUT_STDERR,
        "syslog": m.TRANSPORT_SYSLOG,
        "journal": m.TRANSPORT_JOURNAL_NATIVE,
    }
    if raw is None:
        missing.append("_TRANSPORT")
        return m.TRANSPORT_UNKNOWN
    value = mapping.get(raw.lower())
    if value is None:
        missing.append(f"_TRANSPORT:{m.REASON_INVALID_DATA}")
        return m.TRANSPORT_UNKNOWN
    return value


def _decode_bytes(data: bytes) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        # byte-preserving fallback; exotic path components pass through
        return data.decode("latin-1")


def _boot_canonical(text: str) -> str:
    """Canonical boot-id form: lowercase 32-hex, dashes/braces stripped.

    journal `_BOOT_ID` is dash-free; `/proc/sys/kernel/random/boot_id` is a
    dashed UUID — both normalize to the same canonical value here."""
    return text.strip().lower().replace("-", "").strip("{}")


# ─── cgroup v1/v2 multi-line parser (§8.3 step 2, §8.4) ─────────────────────

_V1_LINE = re.compile(r"^(\d+):([^:]*):(.*)$")
_HEX64 = r"[0-9a-fA-F]{64}"
_LIBPOD_CONMON = re.compile(r"(?:^|/)libpod-conmon-(" + _HEX64 + r")\.scope(?:/|$)")
_LIBPOD_WORKLOAD = re.compile(r"(?:^|/)libpod-(" + _HEX64 + r")\.scope(?:/|$)")
_DOCKER_PATH = re.compile(r"/docker/(" + _HEX64 + r")(?:/|\.[a-z]|$)")
_DELETED_SUFFIX = " (deleted)"


def parse_proc_cgroup_text(text: str) -> dict[str, Any]:
    """Robust multi-line parse: v1 (hierarchy:controllers:path), v2 (0::) or
    hybrid. Retains ALL memberships; classifies later from the union (§8.4)."""
    memberships: list[dict[str, Any]] = []
    malformed: list[str] = []
    saw_v1 = saw_v2 = False
    for line in text.splitlines():
        line = line.rstrip("\r")
        if not line.strip():
            continue
        match = _V1_LINE.match(line)
        if not match:
            malformed.append(line)
            continue
        hierarchy = int(match.group(1))
        controllers = [c for c in match.group(2).split(",") if c]
        path = match.group(3)
        removed = False
        if path.endswith(_DELETED_SUFFIX):
            path = path[: -len(_DELETED_SUFFIX)]
            removed = True
        if hierarchy == 0:
            saw_v2 = True
        else:
            saw_v1 = True
        memberships.append(
            {
                "hierarchy": hierarchy,
                "controllers": controllers,
                "path": path,
                "removed_cgroup": removed,
            }
        )
    root_like = any(m_["path"] in ("", "/") for m_ in memberships)
    for member in memberships:
        if member["path"] in ("", "/"):
            member["root_like"] = True
    m_format = "hybrid" if (saw_v1 and saw_v2) else ("v2" if saw_v2 else "v1")
    return {
        "memberships": memberships,
        "cgroup_format": m_format,
        "malformed_lines": malformed,
        "root_like": root_like,
    }


def _classify_member(member: dict[str, Any]) -> None:
    """Annotate ONE cgroup path: scope, domain candidates, container ids.

    Root-like and unknown paths produce NO domain candidates (§8.4).
    libpod-conmon-<64hex>.scope is a host-side monitor/stream candidate —
    it is NOT a PODMAN_CONTAINER domain signature (§8.3 step 5).
    """
    path = member["path"]
    member.setdefault("container_ids", [])
    member.setdefault("container_id_kinds", {})
    member.setdefault("domain_candidates", [])
    member.setdefault("scope", m.SCOPE_UNKNOWN)
    if member.get("root_like"):
        return
    conmon = _LIBPOD_CONMON.search(path)
    if conmon:
        member["container_ids"].append(conmon.group(1))
        member["container_id_kinds"][conmon.group(1)] = "CONMON"
    else:
        workload = _LIBPOD_WORKLOAD.search(path)
        if workload:
            member["container_ids"].append(workload.group(1))
            member["container_id_kinds"][workload.group(1)] = "WORKLOAD"
            member["domain_candidates"].append(m.DOMAIN_PODMAN_CONTAINER)
    docker = _DOCKER_PATH.search(path)
    if docker:
        member["container_ids"].append(docker.group(1))
        member["container_id_kinds"][docker.group(1)] = "DOCKER"
        member["domain_candidates"].append(m.DOMAIN_DOCKER_CONTAINER)
    if "app-flatpak-" in path:
        member["domain_candidates"].append(m.DOMAIN_FLATPAK)
    if path.startswith("/system.slice/"):
        member["scope"] = m.SCOPE_SYSTEM
        if not member["domain_candidates"]:
            member["domain_candidates"].append(m.DOMAIN_HOST_SYSTEMD)
    elif path.startswith("/user.slice/user-") or re.search(
        r"/session-\d+\.scope(?:/|$)", path
    ):
        member["scope"] = m.SCOPE_USER
        if not member["domain_candidates"]:
            member["domain_candidates"].append(m.DOMAIN_HOST_SESSION)


def _classify_memberships(memberships: list[dict[str, Any]]) -> None:
    for member in memberships:
        _classify_member(member)


def _union_domain(
    memberships: list[dict[str, Any]],
) -> tuple[str | None, str | None]:
    """Classify from the UNION of all lines — never first-line-only (§8.4)."""
    candidates: list[str] = []
    has_user_scope = False
    for member in memberships:
        if member.get("root_like"):
            continue
        candidates.extend(member.get("domain_candidates", []))
        if member.get("scope") == m.SCOPE_USER:
            has_user_scope = True
    domain = None
    if m.DOMAIN_FLATPAK in candidates:
        domain = m.DOMAIN_FLATPAK
    elif m.DOMAIN_PODMAN_CONTAINER in candidates:
        domain = m.DOMAIN_PODMAN_CONTAINER
    elif m.DOMAIN_DOCKER_CONTAINER in candidates:
        domain = m.DOMAIN_DOCKER_CONTAINER
    elif m.DOMAIN_HOST_SYSTEMD in candidates:
        domain = m.DOMAIN_HOST_SYSTEMD
    elif m.DOMAIN_HOST_SESSION in candidates:
        domain = m.DOMAIN_HOST_SESSION
    if domain is None:
        return None, None
    scope = m.SCOPE_SYSTEM if domain == m.DOMAIN_HOST_SYSTEMD else m.SCOPE_USER
    if domain not in (m.DOMAIN_HOST_SYSTEMD, m.DOMAIN_HOST_SESSION):
        scope = m.SCOPE_USER if has_user_scope else m.SCOPE_UNKNOWN
    return domain, scope


def _observe_journal_cgroup(path: str) -> dict[str, Any]:
    """Journal-side event-time cgroup observation wrapper (§8.1-B, §8.5)."""
    member: dict[str, Any] = {"path": path}
    if path.endswith(_DELETED_SUFFIX):
        member["path"] = path
    _classify_member(member)
    obs: dict[str, Any] = {
        "path": path,
        "provenance": m.PROVENANCE_JOURNAL_TRUSTED,
        "captured": m.CAPTURED_EVENT_TIME,
        "scope": member.get("scope", m.SCOPE_UNKNOWN),
        "domain_candidates": member.get("domain_candidates", []),
    }
    ids = member.get("container_ids") or []
    if ids:
        obs["container_ids"] = ids
        obs["container_id_kinds"] = member.get("container_id_kinds", {})
    if path in ("", "/"):
        obs["reason_codes"] = [m.REASON_INSUFFICIENT_EVIDENCE]
    if path.endswith(_DELETED_SUFFIX):
        obs["note"] = "(deleted) suffix preserved verbatim"
    return obs


# ─── event-time unit/cgroup consistency — ONE journal class (§8.3 step 3) ──


def _unit_claim(
    unit: str | None, user_unit: str | None, cgroup_path: str | None
) -> dict[str, Any]:
    """Trusted unit vs trusted event-time cgroup of the SAME record.

    Field provenance rules:
    - _SYSTEMD_UNIT and _SYSTEMD_CGROUP share one record → count as ONE
      evidence class, never two independent sources (§8.2 correction 4);
    - `_SYSTEMD_UNIT=user@<uid>.service` marks a user-manager record; the
      user-manager unit is in _SYSTEMD_USER_UNIT.
    """
    base = {"time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION}
    if cgroup_path is None and unit is None and user_unit is None:
        base.update(
            status=m.STATUS_UNAVAILABLE,
            reason_codes=[m.REASON_INSUFFICIENT_EVIDENCE],
        )
        return base
    user_match = re.fullmatch(r"user@(\d+)\.service", unit or "")
    if user_unit is not None or user_match:
        uid = user_match.group(1) if user_match else None
        if uid is None and cgroup_path:
            found = re.search(r"/user@(\d+)\.service/", cgroup_path)
            uid = found.group(1) if found else None
        consistent = False
        suffix = None
        if cgroup_path and uid is not None:
            marker = f"/user@{uid}.service/"
            if marker in (cgroup_path + "/"):
                suffix = (cgroup_path + "/").partition(marker)[2]
                if user_unit is None:
                    consistent = True
                else:
                    consistent = (
                        cgroup_path.endswith("/" + user_unit)
                        or suffix == user_unit
                        or suffix == f"user.slice/{user_unit}"
                    )
        field = "_SYSTEMD_USER_UNIT" if user_unit else "_SYSTEMD_UNIT"
        payload = {
            "unit": user_unit or unit,
            "unit_field": field,
            "scope": m.SCOPE_USER,
        }
        if consistent:
            payload.update(
                domain=m.DOMAIN_HOST_SESSION,
                cgroup_suffix=suffix,
                status=m.STATUS_EVENT_TIME_ATTESTED,
                reason_codes=[],
            )
        elif cgroup_path is None:
            payload.update(
                domain=None,
                status=m.STATUS_UNAVAILABLE,
                reason_codes=[m.REASON_INSUFFICIENT_EVIDENCE],
            )
        else:
            payload.update(
                domain=None,
                status=m.STATUS_AMBIGUOUS,
                reason_codes=[m.REASON_EVIDENCE_CONFLICT],
            )
        base.update(payload)
        return base
    if unit is None:
        base.update(
            status=m.STATUS_UNAVAILABLE,
            reason_codes=[m.REASON_INSUFFICIENT_EVIDENCE],
        )
        return base
    consistent = cgroup_path == f"/system.slice/{unit}"
    base.update(
        unit=unit,
        unit_field="_SYSTEMD_UNIT",
        scope=m.SCOPE_SYSTEM,
    )
    if consistent:
        base.update(
            domain=m.DOMAIN_HOST_SYSTEMD,
            cgroup_suffix=unit,
            status=m.STATUS_EVENT_TIME_ATTESTED,
            reason_codes=[],
        )
    elif cgroup_path is None:
        base.update(
            domain=None,
            status=m.STATUS_UNAVAILABLE,
            reason_codes=[m.REASON_INSUFFICIENT_EVIDENCE],
        )
    else:
        base.update(
            domain=None,
            status=m.STATUS_AMBIGUOUS,
            reason_codes=[m.REASON_EVIDENCE_CONFLICT],
        )
    return base


# ─── audit body = untrusted content (§8.3 step 1, correction 1) ────────────

_RE_AUDIT_PID = re.compile(r"\bpid=(\d+)")
_RE_AUDIT_UID = re.compile(r"\buid=(\d+)")
_RE_AUDIT_EXE = re.compile(r'\bexe="([^"]+)"|\bexe=([^\s,]+)')
_RE_AUDIT_COMM = re.compile(r"\bcomm=([^\s,]+)")


def _parse_audit_body(message: str | None) -> dict[str, Any]:
    hints: dict[str, Any] = {}
    if not message:
        return hints
    window = message[:MAX_AUDIT_BODY_CHARS]
    pid = _RE_AUDIT_PID.search(window)
    uid = _RE_AUDIT_UID.search(window)
    exe = _RE_AUDIT_EXE.search(window)
    comm = _RE_AUDIT_COMM.search(window)
    if pid:
        hints["pid"] = int(pid.group(1))
    if uid:
        hints["uid"] = int(uid.group(1))
    if comm:
        hints["comm"] = comm.group(1)
    if exe:
        hints["exe"] = exe.group(1) or exe.group(2)
    return hints


# ─── event-time qualification of the current /proc instance (§8.3 step 4) ──


def _tick_rate() -> int | None:
    """Platform tick rate — never hard-coded (§8.3 step 4)."""
    try:
        value = int(os.sysconf("SC_CLK_TCK"))
        return value if value > 0 else None
    except (OSError, ValueError, AttributeError):
        return None


def _parse_proc_stat(data: bytes) -> dict[str, Any] | None:
    """proc(5): comm sits between the FIRST '(' and the LAST ')' (may contain
    spaces/parenthesis-like text, truncated at 16 chars) — never whitespace-
    split from the start. starttime = field 22, clock ticks since boot."""
    text = _decode_bytes(data[:MAX_STAT_BYTES])
    open_idx = text.find("(")
    close_idx = text.rfind(")")
    if open_idx == -1 or close_idx == -1 or close_idx < open_idx:
        return None
    comm = text[open_idx + 1 : close_idx]
    rest = text[close_idx + 1 :].split()
    # rest[0]=state(field 3) ... rest[19]=starttime(field 22)
    if len(rest) < 20 or not re.fullmatch(r"\d+", rest[19]):
        return None
    return {"comm": comm, "proc_start_ticks": int(rest[19])}


def _parse_nspid(data: bytes | None) -> list[int]:
    if not data:
        return []
    for line in _decode_bytes(data[:MAX_STATUS_BYTES]).splitlines():
        if line.startswith("NSpid:"):
            parts = line.split()[1:]
            values = [int(t) for t in parts if t.isdigit()]
            if values:
                return values
    return []


# ─── runtime query (§8.3 step 5 — read-only, correct context, no fallback) ─


def _run_container_inspect(
    runner: Runner, container_id: str | None
) -> tuple[Any | None, list[str]]:
    if container_id is None:
        return None, [m.REASON_INSUFFICIENT_EVIDENCE]
    try:
        result = runner.run(list(PODMAN_INSPECT_ARGV) + [container_id])
    except TimeoutError:
        return None, [m.REASON_TIMEOUT, m.REASON_RUNTIME_UNAVAILABLE]
    except PermissionError:
        return None, [m.REASON_PERMISSION_DENIED]
    except OSError:
        # binary missing / spawn problem — the runtime, not a scope claim
        return None, [m.REASON_RUNTIME_UNAVAILABLE]
    if result.returncode != 0:
        stderr_l = (result.stderr or "").lower()
        if "permission" in stderr_l:
            return None, [m.REASON_PERMISSION_DENIED]
        if "root" in stderr_l:
            # rootful-vs-rootless visibility — a context failure (§8.2),
            # never UNSUPPORTED_RUNTIME and never ahost reclassification
            return None, [m.REASON_WRONG_RUNTIME_CONTEXT]
        return None, [m.REASON_RUNTIME_UNAVAILABLE]
    text = result.stdout[:MAX_INSPECT_BYTES]
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None, [m.REASON_INVALID_DATA]
    if not isinstance(parsed, list) or not parsed or not isinstance(parsed[0], dict):
        return None, [m.REASON_INVALID_DATA]
    return parsed[0], []


def _safe_read(runner: Runner, path: str, limit: int) -> bytes | None:
    try:
        return runner.read_file(path)[:limit]
    except OSError:
        return None


# ─── sender/subject builders (§8.1-B entities; §8.5 shapes) ────────────────


def _build_entity(
    pid: int | None,
    uid: int | None,
    gid: int | None,
    comm: str | None,
    exe: str | None,
    unit: str | None,
    user_unit: str | None,
    status: str,
    reasons: list[str],
    *,
    identity_source: str | None = None,
    runtime_domain: str | None = None,
) -> dict[str, Any]:
    has_creds = pid is not None or uid is not None or bool(comm) or bool(exe)
    conmon_ish = (comm == "conmon") or (
        isinstance(exe, str) and exe.rstrip("/").endswith("/conmon")
    )
    entity: dict[str, Any] = {
        "role": (
            m.ROLE_UNKNOWN
            if not has_creds
            else (m.ROLE_STREAM_OWNER if conmon_ish else m.ROLE_WORKLOAD_APPEARANCE)
        ),
        "status": status,
        "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
        "reason_codes": list(reasons),
    }
    if pid is not None:
        entity["pid"] = pid
    if uid is not None:
        entity["uid"] = uid
    if gid is not None:
        entity["gid"] = gid
    if comm:
        entity["comm"] = comm
    if exe:
        entity["exe"] = exe
    if unit:
        entity["unit"] = unit
    if user_unit:
        entity["user_unit"] = user_unit
    if conmon_ish and has_creds:
        # pattern alone can never assert the role (§8.3 step 5)
        entity["role_candidate"] = m.ROLE_CONMON
    if runtime_domain is not None:
        entity["runtime_domain"] = runtime_domain
    if identity_source is not None:
        entity["identity_source"] = identity_source
    return entity


# ─── main entry (§8.3 steps 1-6, in order) ──────────────────────────────────


def discover(
    record: dict,
    runner: Runner | None = None,
    *,
    clock: Callable[[], float] | None = None,
) -> dict[str, Any]:
    """Return the §8.5 DiscoveryResult (typed dict) for ONE journal record.

    ``runner`` covers every /proc read and runtime query (injectable).
    ``clock`` only stamps ::captured_at fields. No state is mutated.
    """
    runner = runner if runner is not None else OsRunner()
    try:
        now_value = float(clock() if clock is not None else time.time())
    except Exception:
        now_value = 0.0

    missing: list[str] = []
    limits: list[str] = [
        "no host/kernel fallback (§8.3 step 6)",
        "current /proc data never upgrades event-time claims (§8.2)",
        "process domains vs container association kept separate (§8.1-B)",
        "role CONMON requires exact runtime PID mapping (§8.3 step 5)",
        "State.ConmonPid availability on the installed podman version is "
        "unverified (§21 ref 7); asserted only when present",
    ]
    result: dict[str, Any] = {}

    # ── step 1a: opaque identity of the record itself ──
    event_ref = _trusted_str(record, "__CURSOR")
    if event_ref is None:
        missing.append("__CURSOR")
        event_ref = ""
    result["event_ref"] = event_ref  # opaque string, verbatim, never parsed
    raw_transport = _trusted_str(record, "_TRANSPORT")
    result["event_transport"] = _classify_transport(raw_transport, record, missing)
    monotonic_us = _trusted_int(record, "__MONOTONIC_TIMESTAMP", missing)
    result["event_monotonic_us"] = monotonic_us
    realtime_us = _optional_int(_trusted_str(record, "__REALTIME_TIMESTAMP"))
    if realtime_us is None:
        missing.append("__REALTIME_TIMESTAMP")
    boot_id_event = _trusted_str(record, "_BOOT_ID")
    if boot_id_event is None:
        missing.append("_BOOT_ID")
    else:
        # _BOOT_ID in the journal is dash-free hex; /proc boot_id is a dashed
        # UUID — normalize BOTH to canonical 32-hex before any comparison
        boot_id_event = _boot_canonical(boot_id_event)
        if not re.fullmatch(r"[0-9a-f]{32}", boot_id_event):
            missing.append("_BOOT_ID:unparsable")
            boot_id_event = None

    # current boot id — a snapshot, may itself fail
    current_boot_id: str | None = None
    try:
        head = _decode_bytes(runner.read_file(BOOT_ID_PATH)[:MAX_BOOT_ID_BYTES])
        candidate = _boot_canonical(head)
        if re.fullmatch(r"[0-9a-f]{32}", candidate):
            current_boot_id = candidate
        else:
            missing.append("current_boot_id:unparsable")
    except OSError as exc:
        missing.append(f"current_boot_id:{type(exc).__name__}")

    boot_comparable = (
        boot_id_event is not None
        and current_boot_id is not None
        and boot_id_event == current_boot_id
    )

    # ── step 1b: sender credentials (trusted fields only) ──
    sender_pid = _trusted_int(record, "_PID", missing)
    sender_uid = _trusted_int(record, "_UID", missing)
    sender_gid = _trusted_int(record, "_GID", missing)
    sender_comm = _trusted_str(record, "_COMM")
    sender_exe = _trusted_str(record, "_EXE")
    unit_system = _trusted_str(record, "_SYSTEMD_UNIT")
    unit_user = _trusted_str(record, "_SYSTEMD_USER_UNIT")

    if sender_pid is None and sender_uid is None and not sender_comm:
        sender = _build_entity(
            None,
            None,
            None,
            None,
            None,
            unit_system,
            unit_user,
            m.STATUS_UNAVAILABLE,
            [m.REASON_INSUFFICIENT_EVIDENCE],
        )
    else:
        sender = _build_entity(
            sender_pid,
            sender_uid,
            sender_gid,
            sender_comm,
            sender_exe,
            unit_system,
            unit_user,
            m.STATUS_EVENT_TIME_ATTESTED,
            [],
        )
    login_uid = _optional_int(_trusted_str(record, "_AUDIT_LOGINUID"))
    audit_session = _optional_int(_trusted_str(record, "_AUDIT_SESSION"))
    if login_uid is not None:
        sender["login_uid"] = login_uid
    if audit_session is not None:
        sender["audit_session"] = audit_session
    syslog_identifier = _trusted_str(record, "SYSLOG_IDENTIFIER")
    if syslog_identifier is not None:
        sender.setdefault("claimed", {})["SYSLOG_IDENTIFIER"] = syslog_identifier
    result["record_sender"] = sender

    # event-time cgroup observations (journal trusted, §8.1-B correction 2)
    sender_cg_path = _trusted_str(record, "_SYSTEMD_CGROUP")
    subject_cg_path = _trusted_str(record, "OBJECT_SYSTEMD_CGROUP")
    event_sender_cgroup = None
    if sender_cg_path is not None:
        event_sender_cgroup = _observe_journal_cgroup(sender_cg_path)
    result["event_sender_cgroup"] = event_sender_cgroup

    # ── step 1c: subject — OBJECT_* fields, else AUDIT handling ──
    obj_pid = _optional_int(_trusted_str(record, "OBJECT_PID"))
    obj_uid = _optional_int(_trusted_str(record, "OBJECT_UID"))
    obj_comm = _trusted_str(record, "OBJECT_COMM")
    obj_exe = _trusted_str(record, "OBJECT_EXE")
    obj_unit = _trusted_str(record, "OBJECT_SYSTEMD_UNIT")
    obj_user_unit = _trusted_str(record, "OBJECT_SYSTEMD_USER_UNIT")
    has_object = any(
        v is not None
        for v in (
            obj_pid,
            obj_uid,
            obj_comm,
            obj_exe,
            obj_unit,
            obj_user_unit,
            subject_cg_path,
        )
    )
    referenced_subject = None
    event_subject_cgroup = None
    if has_object:
        referenced_subject = _build_entity(
            obj_pid,
            obj_uid,
            None,
            obj_comm,
            obj_exe,
            obj_unit,
            obj_user_unit,
            m.STATUS_EVENT_TIME_ATTESTED,
            [],
            identity_source=m.SOURCE_OBJECT_FIELDS,
        )
        if subject_cg_path:
            event_subject_cgroup = _observe_journal_cgroup(subject_cg_path)
            domain, _ = _union_domain(event_subject_cgroup_membership(subject_cg_path))
            if domain is not None:
                # the described object's own event-time path — trusted
                referenced_subject["runtime_domain"] = domain
    elif result["event_transport"] == m.TRANSPORT_AUDIT:
        if login_uid is not None or audit_session is not None:
            referenced_subject = {
                "identity_source": m.AUDIT_SOURCE_TRUSTED_FIELDS,
                "status": m.STATUS_EVENT_TIME_ATTESTED,
                "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
                "reason_codes": [],
                "runtime_domain": m.DOMAIN_UNKNOWN,
            }
            if login_uid is not None:
                referenced_subject["login_uid"] = login_uid
            if audit_session is not None:
                referenced_subject["audit_session"] = audit_session
            limits.append(
                "audit identity attempted from trusted _AUDIT_* fields; "
                "whether they map to the audited subject for THIS audit "
                "event type is unconfirmed (§4 #24) — mapping stays labeled"
            )
        body_hints = _parse_audit_body(_trusted_str(record, "MESSAGE"))
        if body_hints:
            if referenced_subject is None:
                referenced_subject = {
                    "identity_source": m.AUDIT_SOURCE_CONTENT_HINTS,
                    "status": m.STATUS_UNAVAILABLE,
                    "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
                    "reason_codes": [m.REASON_INSUFFICIENT_EVIDENCE],
                    "runtime_domain": m.DOMAIN_UNKNOWN,
                }
            referenced_subject["untrusted_hints"] = {
                **body_hints,
                "_note": "userspace-provided audit content; content-derived "
                "hints never become the sole basis of VERIFIED "
                "(§8.1-A, §8.3 step 1)",
            }
            limits.append("audit body parsed as UNTRUSTED content hints only")
        if referenced_subject is None:
            result["subject_disposition"] = m.SUBJECT_DISPOSITION_NOT_APPLICABLE
    else:
        result["subject_disposition"] = m.SUBJECT_DISPOSITION_NOT_APPLICABLE
    result["referenced_subject"] = referenced_subject
    result["event_subject_cgroup"] = event_subject_cgroup

    # ── step 3: trusted unit/cgroup consistency — ONE class per side ──
    result["event_time_unit_claim"] = _unit_claim(
        unit_system, unit_user, sender_cg_path
    )
    if has_object and (obj_unit or obj_user_unit):
        result["event_subject_unit_claim"] = _unit_claim(
            obj_unit, obj_user_unit, subject_cg_path
        )

    # ── steps 2+4: current snapshot + event-time qualification ──
    qual_pid = obj_pid if obj_pid is not None else sender_pid
    proc_qualification: dict[str, Any] | None = None
    current_proc_cgroup: dict[str, Any] | None = None
    current_memberships: list[dict[str, Any]] = []
    pid_gone = False
    pid_stale = False

    if qual_pid is None:
        missing.append("_PID" if obj_pid is None else "OBJECT_PID")
    if qual_pid is not None and not boot_comparable:
        missing.append("same_boot_state")
    if qual_pid is not None and not monotonic_us:
        missing.append("__MONOTONIC_TIMESTAMP")
    if qual_pid is not None and boot_comparable and monotonic_us:
        cgroup_path = f"/proc/{qual_pid}/cgroup"
        stat_path = f"/proc/{qual_pid}/stat"
        status_path = f"/proc/{qual_pid}/status"
        proc_qualification = {
            "pid": qual_pid,
            "event_boot_id": boot_id_event,
            "event_monotonic_us": monotonic_us,
            "compared": False,
        }
        try:
            cg_text = _decode_bytes(runner.read_file(cgroup_path)[:MAX_CGROUP_BYTES])
            parsed_cg = parse_proc_cgroup_text(cg_text)
            _classify_memberships(parsed_cg["memberships"])
            current_memberships = parsed_cg["memberships"]
            current_proc_cgroup = {
                "captured_at": now_value,
                "provenance": m.PROVENANCE_PROC_SNAPSHOT,
                "path": (
                    current_memberships[0]["path"] if current_memberships else None
                ),
                "memberships": current_memberships,
                "cgroup_format": parsed_cg["cgroup_format"],
                "removed_cgroup": any(
                    mem.get("removed_cgroup") for mem in current_memberships
                ),
                "pid_present_at_capture": True,
                "reason_codes": (
                    [] if not parsed_cg["malformed_lines"] else [m.REASON_INVALID_DATA]
                ),
            }
            if parsed_cg["root_like"] or not current_memberships:
                # empty body or a pure root line ("0::/") — nothing to
                # classify; surfaced as INSUFFICIENT, never a host claim
                current_proc_cgroup["reason_codes"] = list(
                    current_proc_cgroup["reason_codes"]
                ) + [m.REASON_INSUFFICIENT_EVIDENCE]
        except FileNotFoundError:
            # /proc/<pid>/cgroup missing: ambiguous between "pid gone" and
            # "snapshot unobservable right now" — the STAT read below decides
            # (row 11 vs row 15). Never a host reclassification either way.
            current_proc_cgroup = {
                "captured_at": now_value,
                "provenance": m.PROVENANCE_PROC_SNAPSHOT,
                "pid_present_at_capture": None,  # unknown at this instant
                "path": None,
                "memberships": [],
                "reason_codes": [
                    m.REASON_NOT_FOUND,
                    m.REASON_INSUFFICIENT_EVIDENCE,
                ],
            }
        except PermissionError:
            current_proc_cgroup = {
                "captured_at": now_value,
                "provenance": m.PROVENANCE_PROC_SNAPSHOT,
                "pid_present_at_capture": True,
                "reason_codes": [m.REASON_PERMISSION_DENIED],
            }
        except OSError:
            current_proc_cgroup = {
                "captured_at": now_value,
                "provenance": m.PROVENANCE_PROC_SNAPSHOT,
                "pid_present_at_capture": True,
                "reason_codes": [m.REASON_INVALID_DATA],
            }

        try:
            stat_data = runner.read_file(stat_path)
        except FileNotFoundError:
            if current_proc_cgroup is not None:
                current_proc_cgroup["pid_present_at_capture"] = False
                current_proc_cgroup["reason_codes"] = list(
                    current_proc_cgroup.get("reason_codes") or []
                ) + [m.REASON_PID_NOT_FOUND]
            proc_qualification["outcome"] = m.QUAL_OUTCOME_GONE
            proc_qualification["reason_codes"] = [
                m.REASON_HISTORICAL_IDENTITY_UNAVAILABLE
            ]
            pid_gone = True
            limits.append(
                "pid no longer present — record NOT marked invalid; the "
                "cgroup observation (captured during examination) stays a "
                "present-day-only record and never event-time evidence"
            )
        else:
            parsed_stat = _parse_proc_stat(stat_data)
            tick_rate = _tick_rate()
            if parsed_stat is None or tick_rate is None:
                proc_qualification["outcome"] = m.QUAL_OUTCOME_UNSAFE_SKIP
                proc_qualification["reason_codes"] = [m.REASON_INVALID_DATA]
                missing.append("proc_stat_unparsable")
            else:
                start_ticks = parsed_stat["proc_start_ticks"]
                event_ticks = monotonic_us * tick_rate / 1_000_000
                proc_qualification["compared"] = True
                proc_qualification["proc_start_ticks"] = start_ticks
                proc_qualification["tick_rate"] = tick_rate
                proc_qualification["event_monotonic_ticks"] = event_ticks
                nspid = _parse_nspid(_safe_read(runner, status_path, MAX_STATUS_BYTES))
                if nspid:
                    proc_qualification["ns_pid_depth"] = nspid
                if start_ticks * 1_000_000 > monotonic_us * tick_rate:
                    proc_qualification["outcome"] = m.QUAL_OUTCOME_STALE
                    proc_qualification["reason_codes"] = [
                        m.REASON_STALE_CURRENT_INSTANCE
                    ]
                    pid_stale = True
                    limits.append(
                        "current PID instance started AFTER the event — "
                        "its /proc metadata is not attached to the record; "
                        "no target binding from this PID (§8.3 step 4)"
                    )
                else:
                    proc_qualification["outcome"] = m.QUAL_OUTCOME_COMPATIBLE
                    proc_qualification["compat_only"] = True
                    limits.append(
                        "start-ticks ≤ event monotonic is a compatibility "
                        "check only — sender/subject claims still need "
                        "their per-claim cross-checks (§8.3 step 4)"
                    )
    elif qual_pid is not None:
        proc_qualification = {
            "pid": qual_pid,
            "event_boot_id": boot_id_event,
            "event_monotonic_us": monotonic_us if monotonic_us else None,
            "compared": False,
            "outcome": m.QUAL_OUTCOME_UNSAFE_SKIP,
            "reason_codes": [m.REASON_INSUFFICIENT_EVIDENCE],
        }
    result["proc_qualification"] = proc_qualification
    result["current_proc_cgroup"] = current_proc_cgroup

    # current-domain claim: present-day only, needs independent cross-check.
    # A ` (deleted)` cgroup is a present-day view of a REMOVED cgroup — keep
    # the observation, but derive no domain/association from it (§8.4).
    current_removed = any(mem.get("removed_cgroup") for mem in current_memberships)
    current_process_domain: dict[str, Any] | None = None
    if current_memberships and not pid_stale and not pid_gone and not current_removed:
        domain, scope = _union_domain(current_memberships)
        if domain is None:
            current_process_domain = None
        elif domain == m.DOMAIN_FLATPAK:
            current_process_domain = {
                "candidate": domain,
                "status": m.STATUS_AMBIGUOUS,
                "reason_codes": [m.REASON_UNSUPPORTED_RUNTIME],
                "captured_at": now_value,
                "time_scope": m.SCOPE_CURRENT_STATE,
            }
        else:
            current_process_domain = {
                "candidate": domain,
                "status": m.STATUS_AMBIGUOUS,
                "reason_codes": [m.REASON_INSUFFICIENT_EVIDENCE],
                "captured_at": now_value,
                "time_scope": m.SCOPE_CURRENT_STATE,
            }
            if scope is not None:
                current_process_domain["scope"] = scope
    result["current_process_domain"] = current_process_domain

    # ── step 5: container association + conmon separation ──
    ev_sender_ids = (event_sender_cgroup or {}).get("container_ids") or []
    ev_sender_kinds = (event_sender_cgroup or {}).get("container_id_kinds") or {}
    ev_subject_ids = (event_subject_cgroup or {}).get("container_ids") or []
    ev_subject_kinds = (event_subject_cgroup or {}).get("container_id_kinds") or {}

    def _pick(ids: list, kinds: dict, source: str, is_current: bool):
        for cid in ids:
            if kinds.get(cid) == "WORKLOAD":
                return cid, source, is_current
        for cid in ids:
            if kinds.get(cid) == "CONMON":
                return cid, source, is_current
        return None

    candidate = _pick(ev_sender_ids, ev_sender_kinds, "event_sender_cgroup", False)
    if candidate is None:
        candidate = _pick(
            ev_subject_ids, ev_subject_kinds, "event_subject_cgroup", False
        )
    if (
        candidate is None
        and current_memberships
        and not pid_stale
        and not pid_gone
        and not current_removed
    ):
        for member in current_memberships:
            ids = member.get("container_ids") or []
            kinds = member.get("container_id_kinds") or {}
            picked = _pick(ids, kinds, "current_proc_cgroup", True)
            if picked is not None:
                candidate = picked
                break

    association: dict[str, Any] | None = None
    conmon_record: dict[str, Any] | None = None
    if candidate is not None:
        cid, source_name, is_current = candidate
        container, reasons = _run_container_inspect(runner, cid)
        association = {
            "source": source_name,
            "runtime": "podman",
            "status": m.STATUS_UNAVAILABLE,
            "time_scope": (
                m.SCOPE_CURRENT_STATE if is_current else m.SCOPE_EVENT_TIME_ASSOCIATION
            ),
            "reason_codes": list(reasons),
            "captured_at": now_value,
            "evidence_refs": [source_name, "podman_inspect"],
        }
        if container is None:
            limits.append(
                "runtime query failed — context/access failure recorded; "
                f"no host fallback ({','.join(reasons)} | §8.2)"
            )
        else:
            resolved_id = container.get("Id")
            if resolved_id == cid:
                association["full_id"] = cid
                name = container.get("Name")
                if isinstance(name, str):
                    association["name"] = name
                image = container.get("ImageName") or container.get("Image")
                if isinstance(image, str):
                    association["image"] = image
                state = container.get("State")
                if isinstance(state, dict):
                    conmon_pid = state.get("ConmonPid")
                    if (
                        isinstance(conmon_pid, int)
                        and sender_pid is not None
                        and conmon_pid == sender_pid
                    ):
                        conmon_record = {
                            "pid": conmon_pid,
                            "status": m.STATUS_VERIFIED,
                            "source": "runtime_field(State.ConmonPid)",
                        }
                        sender["role"] = m.ROLE_CONMON
                if is_current:
                    association["status"] = m.STATUS_CURRENT_RUNTIME_VERIFIED
                    if (
                        current_process_domain is not None
                        and current_process_domain.get("candidate")
                        == m.DOMAIN_PODMAN_CONTAINER
                    ):
                        current_process_domain["status"] = (
                            m.STATUS_CURRENT_RUNTIME_VERIFIED
                        )
                        current_process_domain["reason_codes"] = []
                else:
                    association["status"] = m.STATUS_VERIFIED
                    # §8.1-C: a non-conmon libpod-<64hex>.scope tied to the
                    # actual sender process + correct-context cross-check ⇒
                    # the SENDER entity may carry the event-time process
                    # domain PODMAN_CONTAINER (verified basis: cross-check).
                    # Never derived from the scope name alone (row 3).
                    if (
                        source_name == "event_sender_cgroup"
                        and ev_sender_kinds.get(cid) == "WORKLOAD"
                    ):
                        sender["runtime_domain"] = m.DOMAIN_PODMAN_CONTAINER
            else:
                association["status"] = m.STATUS_AMBIGUOUS
                association["reason_codes"] = [m.REASON_EVIDENCE_CONFLICT]
                limits.append(
                    "runtime inspect returned a different container id — "
                    "association NOT claimed (EVIDENCE_CONFLICT, §16.1)"
                )
    result["container_association"] = association
    result["conmon"] = conmon_record
    result["workload_identity"] = {
        "state": "UNKNOWN",
        "reason_codes": [m.REASON_INSUFFICIENT_EVIDENCE],
        "note": "VERIFIED requires a disjoint mechanism pair (authoritative "
        "runtime init-PID mapping + in-container process evidence); "
        "conmon/stream-owner identity and container association "
        "alone never verify it (§8.2)",
    }

    # ── evidence ledger (§8.5 evidence[]) ──
    evidence: list[dict[str, Any]] = []
    if (
        sender.get("pid") is not None
        or sender.get("uid") is not None
        or sender.get("comm")
    ):
        evidence.append(
            {
                "origin": m.ORIGIN_JOURNAL_RECORD,
                "strength": m.STRENGTH_TRUSTED_ATTESTATION,
                "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
                "provenance_note": "trusted sender credential fields (_PID/_UID/_GID/_COMM/_EXE); "
                "stdout-family caveat: identifies the stream/connection "
                "owner only (§21 ref 1)",
            }
        )
    unit_claim = result.get("event_time_unit_claim") or {}
    if unit_claim.get("status") == m.STATUS_EVENT_TIME_ATTESTED:
        evidence.append(
            {
                "origin": m.ORIGIN_JOURNAL_RECORD,
                "strength": m.STRENGTH_TRUSTED_ATTESTATION,
                "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
                "provenance_note": "ONE journal evidence class: unit field(s) + event cgroup "
                "share one record provenance — never counted twice "
                "(§8.2 correction 4)",
            }
        )
    if (
        referenced_subject is not None
        and referenced_subject.get("identity_source") == m.AUDIT_SOURCE_CONTENT_HINTS
    ):
        evidence.append(
            {
                "origin": m.ORIGIN_JOURNAL_RECORD,
                "strength": m.STRENGTH_UNTRUSTED_CONTENT,
                "time_scope": m.SCOPE_EVENT_TIME_ASSOCIATION,
                "provenance_note": "audit message body parsed as untrusted content hints only",
            }
        )
    if current_proc_cgroup is not None:
        evidence.append(
            {
                "origin": m.ORIGIN_PROC_SNAPSHOT,
                "strength": m.STRENGTH_PRESENT_STATE,
                "time_scope": m.SCOPE_CURRENT_STATE,
                "captured_at": current_proc_cgroup.get("captured_at"),
                "provenance_note": "present-day /proc snapshot — NOT event-time membership "
                "(§8.3 step 2)",
            }
        )
    if association is not None and association.get("status") in (
        m.STATUS_VERIFIED,
        m.STATUS_CURRENT_RUNTIME_VERIFIED,
    ):
        evidence.append(
            {
                "origin": m.ORIGIN_RUNTIME_QUERY,
                "strength": m.STRENGTH_VERIFIED_CROSS_CHECK,
                "time_scope": association["time_scope"],
                "captured_at": association.get("captured_at"),
                "provenance_note": "podman inspect cross-check (read-only, correct context; "
                f"capture at {association['time_scope']})",
            }
        )
    result["evidence"] = evidence
    result["missing_evidence"] = missing
    if realtime_us is not None:
        limits.append(
            "__REALTIME_TIMESTAMP kept as a secondary hint only — not immune "
            "to clock changes (§8.3 step 1)"
        )
    result["limits_note"] = limits
    return result


def event_subject_cgroup_membership(
    subject_cg_path: str,
) -> list[dict[str, Any]]:
    """Memberships-shaped view of a journal-side subject cgroup path."""
    member: dict[str, Any] = {
        "hierarchy": 0,
        "controllers": [],
        "path": subject_cg_path,
    }
    _classify_member(member)
    return [member]


def validate_container_ref(
    ref: str, association: dict[str, Any] | None
) -> tuple[str, list[str]]:
    """§16.1 row "container id unknown (name only)": the record-issued
    full-ID binding wins; a name/label ref is NEVER a VERIFIED basis.

    Phase-1 primitive for later phases (§10.5 opaque refs). Returns
    (verdict, reason_codes):
    - MATCH        — ref is the full container id already bound in the record;
    - NAME_ONLY    — name/label match: candidate only, never VERIFIED;
    - REJECTED     — full-hex ref ≠ bound id (or no binding to compare);
    - UNAVAILABLE  — no full id available to compare against.
    """
    if not isinstance(ref, str) or not ref.strip():
        return ("REJECTED", [m.REASON_INVALID_DATA])
    ref = ref.strip()
    full = (association or {}).get("full_id")
    if re.fullmatch(_HEX64, ref):
        if not full:
            return ("REJECTED", [m.REASON_INSUFFICIENT_EVIDENCE])
        if ref == full:
            return ("MATCH", [])
        return ("REJECTED", [m.REASON_EVIDENCE_CONFLICT])
    if not full:
        return ("UNAVAILABLE", [m.REASON_INSUFFICIENT_EVIDENCE])
    return ("NAME_ONLY", [m.REASON_INSUFFICIENT_EVIDENCE])
