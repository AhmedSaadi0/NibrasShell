#!/usr/bin/env python3
"""audit.py — bounded, metadata-only diagnostic audit log (Phase 6, §14).

The daemon appends one JSON object per line to
``$XDG_STATE_HOME/nibrasshell/ai-diagnostics/audit.jsonl`` (default
``~/.local/state/nibrasshell/ai-diagnostics/audit.jsonl``, overridable with
``NIBRAS_SHELL_AI_AUDIT_LOG``).  The record intentionally contains only the
fields the plan permits::

    {ts, correlation_id, stage, outcome, reason_codes[], redaction_counts,
     budget_usage, latency_ms}

No incident text, log message, command line, tool argv, prompt, model output,
or secret value is accepted by this module.  The sanitizer additionally caps
string/list/dict sizes so a caller cannot accidentally make one audit line
unbounded.  Audit writes are best-effort and **never** fail the diagnostic
request: a permissions/disk error is counted in ``last_error`` and swallowed.

Environment:
  * ``NIBRAS_SHELL_AI_AUDIT_LOG`` — explicit path override (tests/ops).
  * ``NIBRAS_SHELL_AI_AUDIT_DISABLED`` — ``1/true/yes/on`` disables writes.
  * ``XDG_STATE_HOME`` — standard state-directory root.

The module is stdlib-only and has no provider/tool coupling.
"""

from __future__ import annotations

import json
import os
import re
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

AUDIT_SCHEMA = "nibras.audit/v1"
AUDIT_STAGES = frozenset({"collect", "discover", "orchestrate", "validate", "render"})

_MAX_REASON_CODES = 32
_MAX_REASON_LEN = 96
_MAX_TEXT_LEN = 160
_MAX_MAPPING_KEYS = 32
_MAX_LIST_ITEMS = 16
_MAX_DEPTH = 3

_SAFE_KEY = re.compile(r"[^A-Za-z0-9_.:-]+")
_WRITE_LOCK = threading.Lock()


def default_audit_path() -> Path:
    """Return the plan-mandated per-user audit path (§14)."""
    raw = os.environ.get("XDG_STATE_HOME", "").strip()
    if raw:
        state_home = Path(raw).expanduser()
    else:
        state_home = Path.home() / ".local" / "state"
    return state_home / "nibrasshell" / "ai-diagnostics" / "audit.jsonl"


def _clean_text(value: Any, limit: int = _MAX_TEXT_LEN) -> str:
    if value is None:
        return ""
    text = str(value)
    # Keep the audit line single-line even if a caller passes a newline.
    text = text.replace("\x00", "").replace("\r", " ").replace("\n", " ")
    return text[:limit]


def _clean_key(value: Any) -> str:
    key = _SAFE_KEY.sub("_", str(value))[:_MAX_TEXT_LEN]
    return key or "field"


def _clean_scalar(value: Any, depth: int = 0) -> Any:
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return (
            value
            if value == value and value not in (float("inf"), float("-inf"))
            else 0.0
        )
    if isinstance(value, str):
        return _clean_text(value)
    if depth >= _MAX_DEPTH:
        return _clean_text(value)
    if isinstance(value, dict):
        return _clean_mapping(value, depth + 1)
    if isinstance(value, (list, tuple)):
        return [
            _clean_scalar(item, depth + 1) for item in list(value)[:_MAX_LIST_ITEMS]
        ]
    return _clean_text(value)


def _clean_mapping(value: Any, depth: int = 0) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    cleaned: dict[str, Any] = {}
    for key, item in list(value.items())[:_MAX_MAPPING_KEYS]:
        cleaned[_clean_key(key)] = _clean_scalar(item, depth)
    return cleaned


def _clean_reason_codes(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        values = [value]
    elif isinstance(value, (list, tuple, set, frozenset)):
        values = list(value)
    else:
        values = [value]
    out: list[str] = []
    for item in values:
        code = _clean_text(item, _MAX_REASON_LEN)
        if code and code not in out:
            out.append(code)
        if len(out) >= _MAX_REASON_CODES:
            break
    return out


def _utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


class AuditLogger:
    """Append-only JSONL audit writer; instantiate once per diagnostic run."""

    def __init__(
        self, path: str | os.PathLike[str] | None = None, *, enabled: bool = True
    ):
        self.path = Path(path) if path is not None else default_audit_path()
        self.enabled = bool(enabled)
        self.last_error: str | None = None
        self.write_errors = 0
        self.records_written = 0

    @classmethod
    def from_env(cls, *, enabled: bool | None = None) -> "AuditLogger":
        """Build a logger from the documented environment contract."""
        if enabled is None:
            disabled = os.environ.get(
                "NIBRAS_SHELL_AI_AUDIT_DISABLED", ""
            ).strip().lower() in {"1", "true", "yes", "on"}
            enabled = not disabled
        path = os.environ.get("NIBRAS_SHELL_AI_AUDIT_LOG", "").strip()
        return cls(path or None, enabled=enabled)

    @classmethod
    def disabled(cls) -> "AuditLogger":
        """No-I/O logger for library calls/tests that do not opt in."""
        return cls(None, enabled=False)

    def emit(
        self,
        stage: str,
        outcome: str,
        *,
        correlation_id: str | None = None,
        reason_codes: Any = None,
        redaction_counts: Any = None,
        budget_usage: Any = None,
        latency_ms: Any = None,
    ) -> bool:
        """Append one sanitized audit record; return False on failure/disabled.

        This method is deliberately non-throwing: audit failure must never
        turn a safe diagnostic response into an application failure.
        """
        if not self.enabled:
            return False

        record = {
            "schema_version": AUDIT_SCHEMA,
            "ts": _utc_now(),
            "correlation_id": _clean_text(correlation_id) or None,
            "stage": _clean_text(stage, 32),
            "outcome": _clean_text(outcome, _MAX_REASON_LEN),
            "reason_codes": _clean_reason_codes(reason_codes),
            "redaction_counts": _clean_mapping(redaction_counts),
            "budget_usage": _clean_mapping(budget_usage),
            "latency_ms": _clean_mapping(latency_ms),
        }
        # The event is deliberately stable and metadata-only.  Unknown caller
        # keys are never copied into the line.
        line = json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n"
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with _WRITE_LOCK:
                fd = os.open(
                    self.path,
                    os.O_APPEND | os.O_CREAT | os.O_WRONLY,
                    0o600,
                )
                try:
                    os.write(fd, line.encode("utf-8"))
                finally:
                    os.close(fd)
        except OSError as exc:
            self.write_errors += 1
            self.last_error = _clean_text(f"{type(exc).__name__}: {exc}")
            return False
        self.records_written += 1
        return True


def read_audit_events(path: str | os.PathLike[str]) -> list[dict[str, Any]]:
    """Read valid JSONL events for tests/operators; malformed lines are skipped."""
    events: list[dict[str, Any]] = []
    try:
        with Path(path).open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    value = json.loads(line)
                except (json.JSONDecodeError, TypeError):
                    continue
                if isinstance(value, dict):
                    events.append(value)
    except OSError:
        return []
    return events


__all__ = [
    "AUDIT_SCHEMA",
    "AUDIT_STAGES",
    "AuditLogger",
    "default_audit_path",
    "read_audit_events",
]
