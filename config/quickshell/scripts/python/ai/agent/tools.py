#!/usr/bin/env python3
"""agent/tools.py — read-only inspection layer (Phase 3, §10.6, §10.3, §14).

Exactly the four tools from the §11.1 allowlist, each built as a FIXED argv
template from backend-validated, registry-resolved parameters (never model
text in argv, ``shell=False``), executed through ONE subprocess wrapper:

- 5 s per-call deadline → SIGTERM → SIGKILL after ≤1 s grace → ``wait()``;
  exit status recorded (§10.3 row "Tool subprocess");
- stdout/stderr collected with a hard cap (stdout 1 MiB; overflow truncates
  and terminates the child — the overflow is recorded, never silent);
- every deadline hit is a typed ``TIMEOUT``, never "probably missing data";
- ≤1 automatic retry per tool request, only for typed transient failures.

§14 hygiene: tool slices sent to the model are redacted (deny-list counts),
bounded (≤4 KiB envelogram per result — the orchestrator also runs the
16 KiB pool cap), and ``/proc/<pid>/environ`` is NEVER read anywhere here.

The runner object is injectable for tests (``run(argv, timeout_s)`` /
``read_file(path, max_bytes)``) so §16.3 rows run with NO real binaries in
the unit suite; the real ``OsToolCommandRunner`` serves the bounded real-device
demo only.
"""

from __future__ import annotations

import errno
import json
import os
import select
import signal
import subprocess
import time
from dataclasses import dataclass, field
from typing import Any, Callable

try:  # package layout (scripts/python on sys.path)
    from ..evidence import redact as _redact
except ImportError:  # flat layout (cwd=scripts/python/ai)
    from evidence import redact as _redact  # type: ignore[no-redef]


# ─── constants (§10.3) ───────────────────────────────────────────────────────

TOOL_DEADLINE_S = 5.0
TOOL_KILL_GRACE_S = 1.0
TOOL_MAX_STDOUT_BYTES = 1024 * 1024  # 1 MiB collection cap (then terminated)
TOOL_MAX_STDERR_BYTES = 32 * 1024
MAX_PROC_FILE_BYTES = 16 * 1024  # bounded /proc reads (stat/status)
MESSAGE_SLICE_CHARS = 200  # per-record message slice in results
STDERR_NOTE_CHARS = 256  # bounded redacted stderr excerpt
TOOL_RESULT_MAX_BYTES = 4 * 1024  # result → model bound (§10.3)

PODMAN = "podman"
SYSTEMCTL = "systemctl"
JOURNALCTL = "journalctl"

# status vocabulary (subprocess wrapper side)
ST_COMPLETED = "COMPLETED"
ST_TIMEOUT = "TIMEOUT_KILLED"
ST_OVERFLOW = "OUTPUT_OVERFLOW"
ST_START_MISSING = "START_MISSING"
ST_START_DENIED = "START_DENIED"
ST_SPAWN_FAILED = "SPAWN_FAILED"

# reason-code vocabulary (typed result side)
R_COMPLETED = "COMPLETED"
R_TIMEOUT = "TIMEOUT"
R_OUTPUT_OVERFLOW = "OUTPUT_OVERFLOW"
R_TOOL_BINARY_MISSING = "TOOL_BINARY_MISSING"
R_PERMISSION_DENIED = "PERMISSION_DENIED"
R_SPAWN_FAILED = "SPAWN_FAILED"
R_TOOL_FAILED = "TOOL_FAILED"
R_PARSE_FAILED = "UNSUPPORTED_RESPONSE"
R_IDENTITY_CONFLICT = "IDENTITY_CONFLICT"
R_PID_NOT_FOUND = "PID_NOT_FOUND"
R_PID_REUSED = "PID_REUSED"
R_STALE_CURRENT_INSTANCE = "STALE_CURRENT_INSTANCE"
R_INVALID_DATA = "INVALID_DATA"
R_SCOPE_UNKNOWN = "SCOPE_UNKNOWN"

# typed transient failures eligible for the single §10.3 retry
_RETRYABLE_REASON_CODES = frozenset({R_TIMEOUT, R_SPAWN_FAILED, R_TOOL_FAILED})


# ─── types ───────────────────────────────────────────────────────────────────


@dataclass
class ToolCommandOutcome:
    """Raw subprocess-side outcome (before redaction/slicing)."""

    status: str = ST_COMPLETED
    ec: int | None = None  # None ⇒ no child/terminated without status
    stdout: bytes = b""
    stderr: bytes = b""
    truncated: bool = False
    notes: list[str] = field(default_factory=list)


@dataclass
class ToolResult:
    """Bounded, redacted result handed to the orchestrator (→ model ≤4 KiB)."""

    tool: str
    request_id: str | None = None
    ok: bool = False
    reason_code: str = R_COMPLETED
    payload_text: str = ""  # UTF-8 text already redacted + sliced
    redaction_counts: dict[str, int] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)
    retries_used: int = 0
    argv_used: list[str] | None = None


# ─── subprocess wrapper (§10.3 "Tool subprocess" row) ────────────────────────


def _terminate(proc: subprocess.Popen, grace_s: float) -> tuple[int | None, bool]:
    """SIGTERM → wait ≤grace → SIGKILL → wait(); returns (ec, hard_killed)."""
    if proc.poll() is not None:
        return proc.returncode, False
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except OSError:
        try:
            proc.terminate()  # PID-level fallback
        except OSError:
            pass
    try:
        proc.wait(timeout=max(grace_s, 0.05))
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            try:
                proc.kill()
            except OSError:
                pass
        try:
            proc.wait(timeout=grace_s)
        except subprocess.TimeoutExpired:
            pass
    return proc.returncode, True


def _spawn_run(
    argv: list[str],
    deadline_s: float,
    kill_grace_s: float,
    max_stdout: int,
    max_stderr: int,
) -> ToolCommandOutcome:
    """Popen + select() loop: cap-aware collection and honest deadlines."""
    outcome = ToolCommandOutcome()
    deadline = time.monotonic() + max(deadline_s, 0.01)
    try:
        proc = subprocess.Popen(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.DEVNULL,
            shell=False,  # fixed argv only (§11.4)
            start_new_session=True,  # own process group for killpg
        )
    except FileNotFoundError:
        outcome.status = ST_START_MISSING
        return outcome
    except PermissionError:
        outcome.status = ST_START_DENIED
        return outcome
    except OSError as exc:
        outcome.status = ST_SPAWN_FAILED
        outcome.notes.append(f"spawn failed: {type(exc).__name__}")
        return outcome

    fds = (proc.stdout, proc.stderr)
    fd_caps = {proc.stdout: max_stdout, proc.stderr: max_stderr}
    collected = {proc.stdout: bytearray(), proc.stderr: bytearray()}
    overflow = False
    timed_out = False

    def _absorb(fd: Any) -> bool:
        """One bounded read on a pipe. Returns False when the pipe is closed
        (EOF — terminal); sets ``overflow`` when the cap is reached."""
        nonlocal overflow
        cap = fd_caps[fd]
        buf = collected[fd]
        try:
            data = os.read(fd.fileno(), max(cap - len(buf), 0) + 1)
        except OSError:
            data = b""
        if not data:
            return False  # EOF: pipe closed — a never-spinning terminal state
        room = cap - len(buf)
        if room <= 0:
            overflow = True  # cap reached; further bytes stay uncollected
            return True
        buf.extend(data[:room])
        if len(data) > room:
            overflow = True
        return True

    try:
        while fds:  # deadline / cap / every-pipe-EOF are the only ways out
            time_left = deadline - time.monotonic()
            if time_left <= 0:
                timed_out = True
                break
            try:
                readable, _, _ = select.select(fds, [], [], min(time_left, 0.05))
            except InterruptedError:
                continue
            except OSError:
                break
            read_progress = False
            for fd in readable:
                keep = _absorb(fd)
                if keep:
                    read_progress = True
                else:
                    fds = tuple(f for f in fds if f is not fd)  # EOF: drop the pipe
            if overflow:
                break
            if proc.poll() is not None and not read_progress:
                # child exited and no pipe delivered data this pass — EOF drains
                # to empty one iteration later and the loop ends by itself
                continue

        if overflow or timed_out:
            ec, hard = _terminate(proc, kill_grace_s)
            if overflow:
                outcome.status = ST_OVERFLOW
                outcome.notes.append(
                    f"stdout cap reached ({max_stdout} bytes) — collection stopped, "
                    "process group terminated (backend wrapper)"
                )
            else:
                outcome.status = ST_TIMEOUT
                outcome.notes.append(
                    f"deadline hit ({deadline_s:g}s) back — terminate="
                    f"{'SIGKILL' if hard else 'SIGTERM'}, exit reclaimed"
                )
        else:
            ec = proc.returncode

        outcome.ec = ec
        outcome.stdout = bytes(collected[proc.stdout])
        stderr_bytes = bytes(collected[proc.stderr])
        outcome.stderr = stderr_bytes[:TOOL_MAX_STDERR_BYTES]
        if len(stderr_bytes) > TOOL_MAX_STDERR_BYTES:
            outcome.truncated = True
            outcome.notes.append("stderr capped at 32 KiB (§10.3)")
        return outcome
    finally:
        # Phase 4.1 — the ORIGINAL parent-side pipes are always closed, even
        # after they were dropped from ``fds`` at EOF (the Phase-4 tail closed
        # only the still-active subset, leaking unclosed BufferedReaders on
        # the normal path). This covers success, timeout, overflow,
        # SIGTERM/SIGKILL, read/select errors and unexpected exceptions.
        for handle in (proc.stdout, proc.stderr):
            if handle is not None:
                try:
                    handle.close()
                except OSError:
                    pass
        # Never leave a spawned child behind: if it is still alive on any exit
        # path (including unexpected exceptions), terminate its process group
        # and reap it. On the normal path it has already exited.
        if proc.poll() is None:
            final_ec, _ = _terminate(proc, kill_grace_s)
            if outcome.ec is None:
                outcome.ec = final_ec


class OsToolCommandRunner:
    """Real implementation (real-device demo only; read-only argv everywhere)."""

    def __init__(
        self,
        deadline_s: float = TOOL_DEADLINE_S,
        kill_grace_s: float = TOOL_KILL_GRACE_S,
    ) -> None:
        self.deadline_s = deadline_s
        self.kill_grace_s = kill_grace_s

    def run(
        self, argv: list[str], timeout_s: float | None = None
    ) -> ToolCommandOutcome:
        return _spawn_run(
            argv,
            self.deadline_s if timeout_s is None else timeout_s,
            self.kill_grace_s,
            TOOL_MAX_STDOUT_BYTES,
            TOOL_MAX_STDERR_BYTES,
        )

    def read_file(self, path: str, max_bytes: int = MAX_PROC_FILE_BYTES) -> bytes:
        with open(path, "rb") as handle:
            data = handle.read(max_bytes + 1)
        if len(data) > max_bytes:
            raise OSError(errno.ENOSPC, "bounded read cap exceeded", path)
        return data


# ─── redaction + shaping helpers (§14) ───────────────────────────────────────


def _decode(data: bytes) -> str:
    return data.decode("utf-8", errors="replace")


def _stderr_note(outcome: ToolCommandOutcome) -> str:
    text = _decode(outcome.stderr).strip()
    text, _ = _redact.redact_text(text)
    return text[:STDERR_NOTE_CHARS]


def _final_slice(tool: str, payload_text: str, notes: list[str]) -> str:
    """Wrap the payload + honest notes; whole result ≤ 4 KiB (§10.3)."""
    text_payload = payload_text[:65536]
    envelope = {"tool": tool, "payload": text_payload, "notes": notes}
    try:
        text = json.dumps(envelope, ensure_ascii=False)
    except (TypeError, ValueError):
        text = json.dumps(envelope, ensure_ascii=True)
    if len(text.encode("utf-8", "replace")) <= TOOL_RESULT_MAX_BYTES:
        return text
    keep = text_payload
    note_with_cap = notes + ["RESULT_SLICE_TRUNCATED: payload bounded to 4 KiB"]
    while keep:
        envelope = {"tool": tool, "payload": keep, "notes": note_with_cap}
        text = json.dumps(envelope, ensure_ascii=False)
        if len(text.encode("utf-8", "replace")) <= TOOL_RESULT_MAX_BYTES:
            return text
        keep = keep[: max(int(len(keep) * 0.9) - 1, 0)]
    envelope = {"tool": tool, "payload": "", "notes": note_with_cap}
    return json.dumps(envelope, ensure_ascii=False)


def _make_result(
    tool: str,
    request_id: str | None,
    outcome: ToolCommandOutcome,
    payload_text: str,
    redaction_counts: dict[str, int],
    notes: list[str],
    ok: bool,
    reason_code: str,
    argv_used: list[str] | None,
    retries_used: int = 0,
) -> ToolResult:
    """Final shaping: wrapper notes first, never raw stderr passthrough."""
    merged = list(dict.fromkeys([*outcome.notes, *notes]))
    stderr = _stderr_note(outcome)
    if stderr:
        merged.append(f'stderr_note: "{stderr}"')
    return ToolResult(
        tool=tool,
        request_id=request_id,
        ok=ok,
        reason_code=reason_code,
        payload_text=_final_slice(tool, payload_text, merged),
        redaction_counts=dict(redaction_counts),
        notes=merged,
        retries_used=retries_used,
        argv_used=argv_used,
    )


def _sorted_redact(text: str, counts: dict[str, int]) -> str:
    clean, applied = _redact.redact_text(text)
    for rule, n in applied.items():
        counts[rule] = counts.get(rule, 0) + n
    return clean


def _flow_failure(
    tool: str,
    spec: dict,
    outcome: ToolCommandOutcome,
    argv: list[str],
) -> ToolResult | None:
    """Typed status→reason mapping for subprocess-level failures (None when
    the child completed normally or produced usable flood data)."""
    status = outcome.status
    if status == ST_TIMEOUT:
        return _make_result(
            tool, spec.get("request_id"), outcome, "", {}, [], False, R_TIMEOUT, argv
        )
    if status in (ST_START_MISSING, ST_START_DENIED, ST_SPAWN_FAILED):
        reason = {
            ST_START_MISSING: R_TOOL_BINARY_MISSING,
            ST_START_DENIED: R_PERMISSION_DENIED,
            ST_SPAWN_FAILED: R_SPAWN_FAILED,
        }[status]
        return _make_result(
            tool, spec.get("request_id"), outcome, "", {}, [], False, reason, argv
        )
    return None


def _guarded_run(argv: list[str], runner: Any, timeout_s: float) -> ToolCommandOutcome:
    """``runner.run`` with process-start denials typed (§10.3): a failing
    spawn never escapes as an exception — it becomes a typed wrapper status
    that ``_flow_failure`` maps (binary missing / permission / spawn failed)."""
    try:
        return runner.run(argv, timeout_s=timeout_s)
    except FileNotFoundError:
        return ToolCommandOutcome(
            status=ST_START_MISSING,
            notes=[f"child not started: binary {argv[0]!r} not found (typed)"],
        )
    except PermissionError:
        return ToolCommandOutcome(
            status=ST_START_DENIED,
            notes=[f"child not started: permission denied for {argv[0]!r} (typed)"],
        )
    except OSError as exc:
        return ToolCommandOutcome(
            status=ST_SPAWN_FAILED,
            notes=[f"spawn failed ({type(exc).__name__}) — stderr suppressed"],
        )


# ─── tool 1: journal_query ───────────────────────────────────────────────────


def _exec_journal_query(spec: dict, runner: Any, timeout_s: float) -> ToolResult:
    unit = spec.get("unit")
    pattern = spec.get("pattern")
    cursor = spec.get("since_cursor")
    limit = spec.get("limit") or 20

    argv: list[str] = [JOURNALCTL, "--no-pager", "--output=json"]
    if unit:
        argv += ["-u", str(unit)]
    if pattern:
        argv += ["--grep", str(pattern)]
    if cursor:
        argv += ["--after-cursor", str(cursor)]
    else:
        argv += ["-b", "0"]  # current-boot window when no cursor continuation
    argv += ["-n", str(limit)]

    outcome = _guarded_run(argv, runner, timeout_s)
    counts: dict[str, int] = {}
    notes: list[str] = []

    flow = _flow_failure("journal_query", spec, outcome, argv)
    if flow is not None:
        return flow

    raw_text = _decode(outcome.stdout)
    if outcome.status == ST_OVERFLOW:
        raw_text, tail_note = _drop_partial_tail(raw_text)
        if tail_note:
            notes.append(tail_note)
    elif outcome.ec not in (0, None):
        notes.append(
            f"journalctl exit status {outcome.ec} recorded; typed failure, "
            "no host fallback"
        )
        return _make_result(
            "journal_query",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_TOOL_FAILED,
            argv,
        )

    records: list[dict[str, Any]] = []
    for line in raw_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            record = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            notes.append(
                "UNSUPPORTED_RECORD: one bounded record dropped (it is DATA "
                "and was never executed)"
            )
            continue
        if isinstance(record, dict):
            records.append(record)
    if not records:
        notes.append("no records matched (honest empty result)")

    payload = _records_slice(records)
    redacted_payload = _sorted_redact(payload, counts)
    return _make_result(
        "journal_query",
        spec.get("request_id"),
        outcome,
        redacted_payload,
        counts,
        notes,
        True,
        R_COMPLETED,
        argv,
    )


def _drop_partial_tail(text: str) -> tuple[str, str]:
    if not text:
        return "", ""
    last_newline = text.rfind("\n")
    if last_newline <= 0:
        return "", "OUTPUT_FLOOD: the single incomplete record was dropped"
    return text[:last_newline], "OUTPUT_FLOOD: partial tail record dropped"


def _records_slice(records: list[dict[str, Any]]) -> str:
    """Compact the record set to what the model is allowed to see (no raw
    fields, no cursors — continuation stays backend-managed)."""
    bounded: list[dict[str, Any]] = []
    for record in records:
        message = record.get("MESSAGE")
        bounded.append(
            {
                "PRIORITY": record.get("PRIORITY"),
                "TIME": str(record.get("__REALTIME_TIMESTAMP", "")),
                "UNIT": record.get("_SYSTEMD_UNIT") or record.get("_SYSTEMD_USER_UNIT"),
                "ID": record.get("SYSLOG_IDENTIFIER") or record.get("_COMM"),
                "MESSAGE": (message if isinstance(message, str) else "")[
                    :MESSAGE_SLICE_CHARS
                ],
            }
        )
    return json.dumps(bounded, ensure_ascii=False)


# ─── tool 2: inspect_process (pure /proc reads, typed identity states) ───────


def _exec_inspect_process(spec: dict, runner: Any, timeout_s: float) -> ToolResult:
    target = spec.get("target", {})
    pid = target.get("pid")
    counts: dict[str, int] = {}
    notes: list[str] = []
    argv_used: list[str] | None = None  # /proc reads are not subprocesses

    try:
        stat_data = runner.read_file(f"/proc/{pid}/stat", max_bytes=MAX_PROC_FILE_BYTES)
    except FileNotFoundError:
        payload = _sorted_redact(
            json.dumps({"pid": pid, "present": False, "identity_state": "GONE"}),
            counts,
        )
        return _make_result(
            "inspect_process",
            spec.get("request_id"),
            ToolCommandOutcome(),
            payload,
            counts,
            ["the pid is no longer present — typed reason, never a host claim"],
            True,
            R_PID_NOT_FOUND,
            argv_used,
        )
    except PermissionError:
        payload = _sorted_redact(
            json.dumps(
                {"pid": pid, "present": None, "identity_state": "READ_UNAVAILABLE"}
            ),
            counts,
        )
        return _make_result(
            "inspect_process",
            spec.get("request_id"),
            ToolCommandOutcome(),
            payload,
            counts,
            [],
            True,
            R_PERMISSION_DENIED,
            argv_used,
        )
    except OSError as exc:
        return _make_result(
            "inspect_process",
            spec.get("request_id"),
            ToolCommandOutcome(notes=[f"bounded read failure: {type(exc).__name__}"]),
            "",
            counts,
            [],
            False,
            R_INVALID_DATA,
            argv_used,
        )

    parsed = _parse_proc_stat(stat_data)
    if parsed is None:
        return _make_result(
            "inspect_process",
            spec.get("request_id"),
            ToolCommandOutcome(notes=["stat line unparsable"]),
            "",
            counts,
            [],
            False,
            R_INVALID_DATA,
            argv_used,
        )

    recorded = target.get("recorded_start_ticks")
    start_ticks = parsed["start_ticks"]
    rate = target.get("tick_rate")
    monotonic_us = target.get("event_monotonic_us")
    reason_code = R_COMPLETED
    identity_state = "PRESENT_QUALIFIED"

    if recorded is not None and start_ticks != recorded:
        if isinstance(monotonic_us, int) and isinstance(rate, (int, float)) and rate:
            event_ticks = monotonic_us / 1_000_000.0 * float(rate)
            if start_ticks > event_ticks:
                identity_state = "STALE_CURRENT_INSTANCE"
                reason_code = R_STALE_CURRENT_INSTANCE
                notes.append(
                    "current instance started AFTER the event (start-ticks "
                    "comparison) — its /proc metadata is not attached to the record"
                )
            else:
                identity_state = "PID_REUSED"
                reason_code = R_PID_REUSED
                notes.append(
                    "recorded start identity differs — the pid belongs to a "
                    "different process than at event time"
                )
        else:
            identity_state = "PID_REUSED"
            reason_code = R_PID_REUSED
            notes.append(
                "recorded start identity differs — no event-time boundary available"
            )
    elif recorded is None:
        identity_state = "PRESENCE_ONLY"
        notes.append(
            "no recorded start identity in the incident — presence-only "
            "observation; qualification never claimed"
        )

    # /proc/<pid>/status — NSpid only. environ is NEVER touched here (§14).
    nspid: list[int] | None = None
    try:
        status_text = _decode(
            runner.read_file(f"/proc/{pid}/status", max_bytes=MAX_PROC_FILE_BYTES)
        )
        for line in status_text.splitlines():
            if line.startswith("NSpid:"):
                try:
                    nspid = [int(part) for part in line.split(":", 1)[1].split()]
                except ValueError:
                    nspid = None
                break
    except (OSError, ValueError):
        notes.append("status section unavailable — typed, no host fallback")

    payload = _sorted_redact(
        json.dumps(
            {
                "pid": pid,
                "present": True,
                "identity_state": identity_state,
                "start_ticks": start_ticks,
                "comm": parsed["comm"],
                "cmdline_note": "cmdline not read by this tool (§14)",
                "ns_pid_depth": len(nspid) if nspid else None,
            },
            ensure_ascii=False,
        ),
        counts,
    )
    return _make_result(
        "inspect_process",
        spec.get("request_id"),
        ToolCommandOutcome(),
        payload,
        counts,
        notes,
        True,
        reason_code,
        argv_used,
    )


def _parse_proc_stat(data: bytes) -> dict[str, Any] | None:
    """proc(5) stat line: pid (comm) rest… — comm may contain spaces/parens."""
    text = _decode(data)
    open_paren = text.find("(")
    close_paren = text.rfind(")")
    if open_paren < 0 or close_paren <= open_paren:
        return None
    try:
        pid = int(text[:open_paren].strip())
    except ValueError:
        return None
    comm = text[open_paren + 1 : close_paren]
    fields = text[close_paren + 1 :].split()
    if len(fields) < 21:
        return None
    try:
        start_ticks = int(fields[19])  # starttime (index 22 overall = field 19)
    except (ValueError, IndexError):
        return None
    return {"pid": pid, "comm": comm, "state": fields[0], "start_ticks": start_ticks}


# ─── tool 3: inspect_container (bounded podman inspect subset) ───────────────


_CONTAINER_STATE_KEYS = ("Status", "Running", "Healthy", "Exited")


def _exec_inspect_container(spec: dict, runner: Any, timeout_s: float) -> ToolResult:
    target = spec.get("target", {})
    full_id = target.get("full_id")
    include = spec.get("include")
    if include is None:
        include = list(CONTAINER_INCLUDE_DEFAULT)
    argv: list[str] = [PODMAN, "inspect", "--type", "container", str(full_id)]

    outcome = _guarded_run(argv, runner, timeout_s)
    counts: dict[str, int] = {}
    notes: list[str] = []

    flow = _flow_failure("inspect_container", spec, outcome, argv)
    if flow is not None:
        return flow
    if outcome.status == ST_OVERFLOW:
        return _make_result(
            "inspect_container",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_OUTPUT_OVERFLOW,
            argv,
        )
    if outcome.ec not in (0, None):
        notes.append(
            f"podman inspect exit status {outcome.ec}; typed failure, no host fallback"
        )
        return _make_result(
            "inspect_container",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_TOOL_FAILED,
            argv,
        )

    try:
        payload_raw = json.loads(_decode(outcome.stdout))
    except (json.JSONDecodeError, ValueError):
        return _make_result(
            "inspect_container",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_PARSE_FAILED,
            argv,
        )
    if (
        not isinstance(payload_raw, list)
        or not payload_raw
        or not isinstance(payload_raw[0], dict)
    ):
        return _make_result(
            "inspect_container",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes + ["podman inspect returned an unexpected shape"],
            False,
            R_PARSE_FAILED,
            argv,
        )

    container = payload_raw[0]
    resolved_id = container.get("Id")
    if resolved_id != full_id:
        notes.append(
            "runtime inspect returned a DIFFERENT container id — association "
            "NOT claimed (EVIDENCE_CONFLICT basis, §16.1)"
        )
        return _make_result(
            "inspect_container",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_IDENTITY_CONFLICT,
            argv,
        )

    bounded: dict[str, Any] = {}
    if "name" in include:
        name = container.get("Name")
        bounded["name"] = (
            name[1:] if isinstance(name, str) and name.startswith("/") else name
        )
    if "image" in include:
        bounded["image"] = container.get("ImageName") or container.get("Image")
    if "state" in include:
        state = container.get("State")
        bounded["state"] = (
            {key: state.get(key) for key in _CONTAINER_STATE_KEYS if key in state}
            if isinstance(state, dict)
            else None
        )
    payload = json.dumps({"Id": resolved_id, **bounded}, ensure_ascii=False)
    redacted_payload = _sorted_redact(payload, counts)
    return _make_result(
        "inspect_container",
        spec.get("request_id"),
        outcome,
        redacted_payload,
        counts,
        notes,
        True,
        R_COMPLETED,
        argv,
    )


# ─── tool 4: inspect_unit (machine-readable systemctl show) ──────────────────

_UNIT_PROPS = (
    "Id",
    "LoadState",
    "ActiveState",
    "SubState",
    "UnitFileState",
    "FragmentPath",
    "ExecMainPID",
    "Result",
)


def _exec_inspect_unit(spec: dict, runner: Any, timeout_s: float) -> ToolResult:
    target = spec.get("target", {})
    unit = target.get("unit")
    scope = target.get("scope")
    if scope == "USER":
        argv: list[str] = [SYSTEMCTL, "--user", "show"]
    elif scope == "SYSTEM":
        argv = [SYSTEMCTL, "show"]
    else:
        payload = _sorted_redact(
            json.dumps({"unit": unit, "scope": scope}, ensure_ascii=False), {}
        )
        return _make_result(
            "inspect_unit",
            spec.get("request_id"),
            ToolCommandOutcome(),
            payload,
            {},
            ["scope is UNKNOWN — no manager is guessed"],
            False,
            R_SCOPE_UNKNOWN,
            None,
        )
    for prop in _UNIT_PROPS:
        argv += ["-p", prop]
    argv.append(str(unit))

    outcome = _guarded_run(argv, runner, timeout_s)
    counts: dict[str, int] = {}
    notes: list[str] = []

    flow = _flow_failure("inspect_unit", spec, outcome, argv)
    if flow is not None:
        return flow
    if outcome.status == ST_OVERFLOW:
        return _make_result(
            "inspect_unit",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_OUTPUT_OVERFLOW,
            argv,
        )
    if outcome.ec not in (0, None):
        notes.append(
            f"systemctl exit status {outcome.ec}; typed failure, no host fallback"
        )
        return _make_result(
            "inspect_unit",
            spec.get("request_id"),
            outcome,
            "",
            counts,
            notes,
            False,
            R_TOOL_FAILED,
            argv,
        )

    bounded: dict[str, str] = {}
    load_state = None
    for line in _decode(outcome.stdout).splitlines():
        line = line.strip("\n")
        if not line or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key in _UNIT_PROPS:
            bounded[key] = _sorted_redact(value[:256], counts)
            if key == "LoadState":
                load_state = bounded[key]

    if load_state == "not-found":
        notes.append(
            "unit NOT FOUND in the current manager — not-found recorded as DATA, "
            "never a host/service claim"
        )
    payload = _sorted_redact(
        json.dumps(
            {"unit": unit, "scope": scope, "present_props": bounded},
            ensure_ascii=False,
        ),
        counts,
    )
    return _make_result(
        "inspect_unit",
        spec.get("request_id"),
        outcome,
        payload,
        counts,
        notes,
        True,
        R_COMPLETED,
        argv,
    )


# ─── dispatch with the single §10.3 retry ────────────────────────────────────

_EXECUTORS: dict[str, Callable[[dict, Any, float], ToolResult]] = {
    "journal_query": _exec_journal_query,
    "inspect_process": _exec_inspect_process,
    "inspect_container": _exec_inspect_container,
    "inspect_unit": _exec_inspect_unit,
}


def execute(
    tool: str,
    tool_spec: dict,
    runner: Any,
    *,
    timeout_s: float = TOOL_DEADLINE_S,
) -> ToolResult:
    """Execute ONE validated tool request. One automatic retry per request,
    only for typed transient failures (≤1 retry per tool, §10.3)."""
    if runner is None:
        runner = OsToolCommandRunner()
    executor = _EXECUTORS[tool]
    result = executor(tool_spec, runner, timeout_s)
    if not result.ok and result.reason_code in _RETRYABLE_REASON_CODES:
        retried = executor(tool_spec, runner, timeout_s)
        retried.retries_used = 1
        retried.notes = list(
            dict.fromkeys(retried.notes + ["RETRY_BUDGET: single §10.3 retry consumed"])
        )
        return retried
    return result


# re-export for orchestrator convenience (no import cycles: contract is
# data-only and never imports tools)
CONTAINER_INCLUDE_DEFAULT = ["image", "state"]
