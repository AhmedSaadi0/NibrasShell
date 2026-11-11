#!/usr/bin/env python3
"""C1 Journal Collector — bounded ``journalctl --output=json`` fetch (§7 C1).

Properties (hard boundaries):
- fixed argv templates, ``shell=False`` upstream in the Runner; argv is never
  built from model text (§10.6);
- default window: ``-b 0 -p warning -n 200`` ⇒ emerg(0)..warning(4);
  notice/info/debug are a SEPARATE configured window, never implied (§16.2);
- cursors pass through VERBATIM (opaque): never int-parsed, sorted, or
  synthesized; continuation via ``--after-cursor`` (§10.6);
- if a continuation cursor cannot be honored (different boot, rotated/evacuated
  data), fall back to an EXPLICIT boot(+time) window and record the limitation
  — never synthesize a cursor;
- all sizes bounded: ≤200 records, ≤512 KiB collected output (R1 §10.3);
- records are typed dicts straight from ``--output=json``; the raw-text short
  format is never parsed;
- injectable Runner (same protocol as discovery) — every subprocess boundary
  is injectable;
- env default-deny by construction: nothing here reads the environment of any
  process, and no argument carries model text.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from . import models as m
from .discovery import BOOT_ID_PATH, ProcResult, Runner, _boot_canonical

JOURNALCTL = "journalctl"

# journalctl `-p NAME` maps NAME → highest priority shown (emerg..NAME).
# `warning` = 4 ⇒ priorities 0–4 included, 5–7 excluded (§16.2 mandated row).
PRIORITY_BOUNDARY: dict[str, int] = {
    "emerg": 0,
    "alert": 1,
    "crit": 2,
    "err": 3,
    "warning": 4,
    "notice": 5,
    "info": 6,
    "debug": 7,
}
PRIORITY_ALIASES: dict[str, str] = {
    "emergency": "emerg",
    "critical": "crit",
    "error": "err",
    "warn": "warning",
    "informational": "info",
}

DEFAULT_PRIORITY = "warning"
DEFAULT_LIMIT = 200
DEFAULT_BOOT = "0"
MAX_OUTPUT_BYTES = 512 * 1024  # R1 payload cap for one collected window

_CURSOR_UNUSABLE_MARKERS = (
    "failed to seek",
    "could not seek",
    "data has been rotated",
    "no such cursor",
    "invalid cursor",
)


def boundary_top(priority_name: str) -> int:
    """Highest priority number included when ``-p NAME`` is used."""
    name = PRIORITY_ALIASES.get(priority_name.lower(), priority_name.lower())
    value = PRIORITY_BOUNDARY.get(name)
    if value is None:
        raise ValueError(f"unsupported priority boundary: {priority_name!r}")
    return value


def boundary_includes(record: dict, priority_name: str) -> bool:
    """Pure predicate: is this record inside the ``-p NAME`` result set?

    journalctl performs the real filtering; this predicate mirrors the
    boundary math for tests and as a safety net (PRIORITY ≤ boundary_top).
    """
    raw = record.get("PRIORITY")
    if isinstance(raw, str) and raw.isdigit():
        return int(raw) <= boundary_top(priority_name)
    return False


def build_argv(
    *,
    boot: str = DEFAULT_BOOT,
    priority: str = DEFAULT_PRIORITY,
    limit: int = DEFAULT_LIMIT,
    after_cursor: str | None = None,
    since: str | None = None,
) -> list[str]:
    """Fixed argv builder — schema validation, never model text (§10.6)."""
    if not isinstance(boot, str) or not boot.strip():
        raise TypeError("boot must be a non-empty string (e.g. '0')")
    if not isinstance(limit, int) or not (1 <= limit <= 200):
        raise ValueError("limit must be an int in [1, 200] (R1 ≤ 200 records)")
    boundary_top(priority)  # validates priority name
    argv = [
        JOURNALCTL,
        "--no-pager",
        "--output=json",
        "-b",
        boot.strip(),
        "-p",
        PRIORITY_ALIASES.get(priority.lower(), priority.lower()),
        "-n",
        str(limit),
    ]
    if after_cursor is not None:
        # an integer/other type is a schema ERROR (§10.6 journal_query)
        if not isinstance(after_cursor, str) or not after_cursor:
            raise TypeError(
                "after_cursor must be an opaque __CURSOR string (§10.6); "
                "an integer/other type is a schema error"
            )
        argv += ["--after-cursor", after_cursor]
    if since is not None:
        if not isinstance(since, str) or not since.strip():
            raise TypeError("since must be an ISO-time string (§10.6)")
        argv += ["--since", since.strip()]
    return argv


@dataclass
class CollectionResult:
    """Bounded collection outcome with counters and honest limitation notes."""

    records: list[dict] = field(default_factory=list)
    last_cursor: str | None = None
    counters: dict[str, int] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)
    argv_used: list[list[str]] = field(default_factory=list)
    current_boot_id: str | None = None
    same_boot_as_cursor_group: bool | None = None
    output_truncated: bool = False
    used_fallback: bool = False
    collection_failed: bool = False
    failure_reasons: list[str] = field(default_factory=list)


def _bump(counters: dict[str, int], key: str, n: int = 1) -> None:
    counters[key] = counters.get(key, 0) + n


def _read_current_boot(runner: Runner) -> str | None:
    try:
        head = runner.read_file(BOOT_ID_PATH)[:128].decode("utf-8", "replace")
        canonical = _boot_canonical(head)
        return canonical if re.fullmatch(r"[0-9a-f]{32}", canonical) else None
    except OSError:
        return None


def _records_from_output(
    text: str, counters: dict[str, int], notes: list[str]
) -> list[dict]:
    """Parse ``--output=json`` lines; per-line caps; never parse raw text."""
    records: list[dict] = []
    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            # INVALID_DATA skip + counter; the pipeline continues (§16.2)
            _bump(counters, "invalid_json_skipped")
            continue
        if not isinstance(record, dict):
            _bump(counters, "invalid_json_skipped")
            continue
        _bump(counters, "records_collected")
        records.append(record)
    if records and len(records) > DEFAULT_LIMIT:
        # limit arg bounds this upstream; the guard documents any excess
        notes.append(f"record cap exceeded ({len(records)}) — truncated")
        records = records[:DEFAULT_LIMIT]
    return records


def _cursor_of(record: dict) -> str | None:
    value = record.get("__CURSOR")
    return value if isinstance(value, str) else None


def collect(
    runner: Runner,
    *,
    boot: str = DEFAULT_BOOT,
    priority: str = DEFAULT_PRIORITY,
    limit: int = DEFAULT_LIMIT,
    after_cursor: str | None = None,
    since: str | None = None,
    fallback_since: str | None = None,
    max_output_bytes: int = MAX_OUTPUT_BYTES,
) -> CollectionResult:
    """One bounded collection window (optionally cursor-continuated).

    Continuation contract (§10.6 / §16.2):
    - the cursor is passed verbatim to ``--after-cursor``;
    - on a cursor-unusable failure (journalctl error OR an EMPTY continuation
      referencing rotated/evacuated data) retry once with an explicit
      boot(+time) window — ``used_fallback=True``, the cursor is NEVER
      synthesized, and the limitation is recorded in ``notes``.
    """
    result = CollectionResult()
    result.current_boot_id = _read_current_boot(runner)

    primary_argv = build_argv(
        boot=boot,
        priority=priority,
        limit=limit,
        after_cursor=after_cursor,
        since=since,
    )
    result.argv_used.append(primary_argv)
    try:
        proc = runner.run(primary_argv)
    except TimeoutError:
        result.collection_failed = True
        result.failure_reasons = [
            m.REASON_TIMEOUT,
            m.REASON_RUNTIME_UNAVAILABLE,
        ]
        result.notes.append("journalctl timeout — fail-closed empty window")
        return result
    except OSError as exc:
        result.collection_failed = True
        result.failure_reasons = [m.REASON_PERMISSION_DENIED]
        result.notes.append(f"journalctl spawn failed: {type(exc).__name__}")
        return result

    primary_records: list[dict] = []
    if proc.returncode != 0:
        result.notes.append(f"journalctl exit {proc.returncode} on primary window")
    else:
        primary_records = _records_from_output(
            proc.stdout[:max_output_bytes], result.counters, result.notes
        )
        if after_cursor is not None and not primary_records and not since:
            result.notes.append(
                "empty continuation — cursor may reference rotated/evacuated "
                "data or a different boot"
            )
        if len(proc.stdout) >= max_output_bytes:
            result.output_truncated = True
            result.notes.append(
                f"output cap {max_output_bytes} bytes reached — window truncated"
            )

    cursor_unusable = proc.returncode != 0 or any(
        marker in (proc.stderr or "").lower() for marker in _CURSOR_UNUSABLE_MARKERS
    )
    fallback_due = bool(after_cursor) and (
        cursor_unusable or (not primary_records and not since)
    )

    if fallback_due:
        result.used_fallback = True
        fallback_argv = build_argv(
            boot=boot,
            priority=priority,
            limit=limit,
            after_cursor=None,  # NO synthesized cursor, ever
            since=fallback_since,
        )
        result.argv_used.append(fallback_argv)
        result.notes.append(
            "cursor unusable — fell back to an explicit boot"
            f"{' + time' if fallback_since else ''} window; no cursor synthesized"
        )
        result.records = []
        result.last_cursor = None
        try:
            proc2 = runner.run(fallback_argv)
        except TimeoutError:
            result.collection_failed = True
            result.failure_reasons = [
                m.REASON_TIMEOUT,
                m.REASON_RUNTIME_UNAVAILABLE,
            ]
            result.notes.append("fallback window also failed — fail-closed")
            return result
        except OSError:
            result.collection_failed = True
            result.failure_reasons = [m.REASON_PERMISSION_DENIED]
            result.notes.append("fallback window also failed — fail-closed")
            return result
        result.records = _records_from_output(
            proc2.stdout[:max_output_bytes], result.counters, result.notes
        )
        if len(proc2.stdout) >= max_output_bytes:
            result.output_truncated = True
            result.notes.append(f"fallback output cap {max_output_bytes} bytes reached")
        result.same_boot_as_cursor_group = None
        if result.current_boot_id:
            boots_in_window = {
                _boot_canonical(str(record.get("_BOOT_ID", "")))
                for record in result.records
                if record.get("_BOOT_ID")
            }
            result.same_boot_as_cursor_group = boots_in_window == {
                result.current_boot_id
            }
        cursor = _cursor_of(result.records[-1]) if result.records else None
        result.last_cursor = cursor
        return result

    # ── primary path: dedup by verbatim cursor, keep insertion order ──
    seen_cursors: set[str] = set()
    deduped: list[dict] = []
    for record in primary_records:
        cursor = _cursor_of(record)
        if cursor is not None:
            if cursor in seen_cursors:
                _bump(result.counters, "duplicate_cursor_skipped")
                continue
            seen_cursors.add(cursor)
        else:
            _bump(result.counters, "non_str_cursor_kept")
        deduped.append(record)
    result.records = deduped
    result.last_cursor = _cursor_of(deduped[-1]) if deduped else None

    if result.current_boot_id and result.records:
        boots_in_window = {
            _boot_canonical(str(record.get("_BOOT_ID", "")))
            for record in result.records
            if record.get("_BOOT_ID")
        }
        result.same_boot_as_cursor_group = boots_in_window == {result.current_boot_id}
    return result
