#!/usr/bin/env python3
"""C5 Incident normalizer — assembles ``nibras.incident/v1`` (plan §9).

One incident = ONE journal record + its §8.5 discovery result.

Hard rules enforced here (§9, §14, §16.2):
- the opaque ``__CURSOR`` passes through VERBATIM; “cursor_utc_us” is derived
  from ``__REALTIME_TIMESTAMP`` and never from parsing the cursor itself;
- ``__MONOTONIC_TIMESTAMP`` is preserved as ``monotonic_us`` and is never
  reconstructed from realtime values;
- raw message text enters only via ``event.message_trunc`` (≤ 2000 chars,
  hard cap) AFTER redaction; ``message_hash`` = full sha256 of the final
  redacted+truncated text; ``message_bytes`` = original utf-8 byte count only;
- repeated (non-unique) fields keep their first value out of identity
  decisions; occurrences are counted, and the JSON arrays are preserved
  verbatim as an evidence item (bounded);
- the three cgroup dimensions are three separate incident fields — a current
  ``/proc`` observation never corroborates or upgrades event-time claims;
- the container reference is backend-issued opaque text (``cont_ref_*``),
  issued only when the association object exists; the model never supplies
  underlying ids;
- uncertainty is preserved end-to-end: missing evidence stays listed, failed
  qualification states stay verbatim, and NO host/kernel fallback exists;
  a current-boot mismatch surfaces ``STALE_EVIDENCE`` instead of a comparison.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import uuid
from typing import Any

try:  # package layout (scripts/python on sys.path)
    from ..evidence import redact
    from ..evidence import discovery as _discovery
    from ..evidence import models as m
except ImportError:  # flat layout (scripts/python/ai on sys.path)
    from evidence import redact
    from evidence import discovery as _discovery
    from evidence import models as m

SCHEMA_VERSION = "nibras.incident/v1"
MESSAGE_CHARS_CAP = 2000  # §9 hard cap for event.message_trunc
_PRESERVED_ARRAYS_ITEM_BYTES = 8 * 1024  # bound for verbatim array evidence
_FAILED_UNIT_CAP = 20  # survey snapshot unit-list bound

OS_RELEASE_PATH = "/etc/os-release"

SEVERITY_HINT: dict[int, str] = {
    0: "emerg",
    1: "alert",
    2: "crit",
    3: "err",
    4: "warning",
    5: "notice",
    6: "info",
    7: "debug",
}

EVIDENCE_ORIGIN_MAP = {
    "journal_record": "journal_trusted",
    "proc_snapshot": "proc",
    "runtime_query": "runtime_query",
}
EVIDENCE_STRENGTH_MAP = {
    "trusted_attestation": "strong",
    "verified_cross_check": "strong",
    "present_state_sample": "supporting",
    "untrusted_content": "weak",
    "conflict": "weak",
}

EVIDENCE_ORIGINS = frozenset(EVIDENCE_ORIGIN_MAP.values())
EVIDENCE_STRENGTHS = frozenset(EVIDENCE_STRENGTH_MAP.values())
VALID_SEVERITIES = frozenset(SEVERITY_HINT.values())


# ─── helpers ─────────────────────────────────────────────────────────────────


def _int_or_none(raw: Any) -> int | None:
    if isinstance(raw, int):
        return raw
    if isinstance(raw, str) and raw.strip().isdigit():
        return int(raw.strip())
    return None


def _boot_of_record(record: dict) -> str | None:
    value = record.get("_BOOT_ID")
    return value if isinstance(value, str) else None


def _raw_message(record: dict) -> str | None:
    """MESSAGE arrives as string, list, null, or arbitrary JSON scalar."""
    value = record.get("MESSAGE")
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(
            element if isinstance(element, str) else str(element) for element in value
        )
    return str(value)


def _survey_absent() -> dict:
    return {
        "state": "ABSENT",
        "note": "survey snapshot not collected — absent, never host-fallback",
    }


# ─── survey snapshot (§18 phase-2 task; C3 refinement deferred) ──────────────


def build_survey_snapshot(
    runner: Any | None = None,
    *,
    failed_unit_cap: int = _FAILED_UNIT_CAP,
) -> dict:
    """Curated host-facts subset (§9 field): distro, pkg manager, podman
    rootless state, failed unit inventory, boot id — all bounded, all via the
    injectable Runner, all read-only. Every failure degrades to ``None`` +
    a note; there is NEVER a host fallback or a guessed value.

    Whitelisted binaries only (``systemctl``, ``podman``), fixed argv,
    discovery's default tool timeout (5 s). Env default-deny by construction:
    no process environment is ever read.
    """
    runner = runner if runner is not None else _discovery.OsRunner()
    snapshot: dict[str, Any] = {
        "state": "COLLECTED",
        "boot_id": None,
        "distro_name": None,
        "distro_version_id": None,
        "package_manager": None,
        "package_manager_path": None,
        "rootless_podman": None,
        "failed_units_count": None,
        "failed_units": [],
        "notes": [],
    }
    notes = snapshot["notes"]

    # boot id (canonical, dash-free — same rule as §8.2 comparisons)
    try:
        head = runner.read_file(_discovery.BOOT_ID_PATH)[:128].decode(
            "utf-8", "replace"
        )
        canonical = _discovery._boot_canonical(head)
        if len(canonical) == 32 and canonical.isalnum():
            snapshot["boot_id"] = canonical
    except OSError:
        notes.append("boot_id absent: current boot id unreadable")

    # distro — from os-release only, never from hardcoded host names
    try:
        text = runner.read_file(OS_RELEASE_PATH)[:4096].decode("utf-8", "replace")
        for line in text.splitlines():
            if line.startswith("NAME=") and snapshot["distro_name"] is None:
                snapshot["distro_name"] = line[5:].strip().strip('"')
            elif (
                line.startswith("VERSION_ID=") and snapshot["distro_version_id"] is None
            ):
                snapshot["distro_version_id"] = line[11:].strip().strip('"')
    except OSError:
        notes.append("distro absent: os-release unreadable")

    # package manager — binary probe, bounded list
    for candidate in ("dnf", "apt", "pacman"):
        path = shutil.which(candidate)
        if path:
            snapshot["package_manager"] = candidate
            snapshot["package_manager_path"] = path
            break

    # rootless podman — correct USER context, JSON mode, read-only
    try:
        proc = runner.run(["podman", "info", "--format", "json"])
        if proc.returncode == 0:
            try:
                data = json.loads(proc.stdout)
                rootless = data.get("host", {}).get("rootless")
                if isinstance(rootless, bool):
                    snapshot["rootless_podman"] = rootless
                else:
                    notes.append("rootless_podman absent: field not boolean")
            except (json.JSONDecodeError, AttributeError, TypeError):
                notes.append("rootless_podman absent: invalid JSON")
        else:
            notes.append(f"rootless_podman absent: exit {proc.returncode}")
    except TimeoutError:
        notes.append("rootless_podman absent: TIMEOUT")
    except OSError:
        notes.append("rootless_podman absent: podman binary unavailable")

    # failed unit inventory — bounded, count + capped list
    try:
        proc = runner.run(
            ["systemctl", "list-units", "--failed", "--no-pager", "--no-legend"]
        )
        if proc.returncode == 0:
            lines = [line for line in proc.stdout.splitlines() if line.strip()]
            snapshot["failed_units_count"] = len(lines)
            snapshot["failed_units"] = lines[:failed_unit_cap]
            if len(lines) > failed_unit_cap:
                notes.append(
                    f"failed_units list capped at {failed_unit_cap} "
                    f"(total {len(lines)})"
                )
        else:
            notes.append(f"failed_units absent: exit {proc.returncode}")
    except TimeoutError:
        notes.append("failed_units absent: TIMEOUT")
    except OSError:
        notes.append("failed_units absent: systemctl unavailable")

    return snapshot


# ─── incident assembly ───────────────────────────────────────────────────────


def _source_block(record: dict, discovery: dict) -> dict:
    realtime_us = _int_or_none(record.get("__REALTIME_TIMESTAMP"))
    boot_id = _boot_of_record(record)
    return {
        "kind": "journal",
        "boot_id": boot_id,  # VERBATIM from the record
        "machine_id": (
            record.get("_MACHINE_ID")
            if isinstance(record.get("_MACHINE_ID"), str)
            else None
        ),
        "cursor": discovery.get("event_ref") or None,  # verbatim, opaque
        "cursor_utc_us": realtime_us,  # realtime attachment, cursor NEVER parsed
        "monotonic_us": discovery.get("event_monotonic_us"),
        "event_transport": discovery.get("event_transport"),
        "priority": _int_or_none(record.get("PRIORITY")),
    }


def _redact_deep(value: Any, counts: dict[str, int], depth: int = 0) -> Any:
    """Redact every string inside a JSON-ish structure.

    §14 contract: preserved content is “verbatim” in STRUCTURE only —
    the redaction layer ALWAYS applies to the bytes that will be stored,
    otherwise masked secrets would re-enter through repeated-field arrays
    (found by the secret-leak test).
    """
    if depth > 6:  # bound pathological nesting
        return str(value)
    if isinstance(value, str):
        redacted, element_counts = redact.redact_text(value)
        for rule, n in element_counts.items():
            counts[rule] = counts.get(rule, 0) + n
        return redacted
    if isinstance(value, list):
        return [_redact_deep(item, counts, depth + 1) for item in value]
    if isinstance(value, dict):
        return {
            key: _redact_deep(item, counts, depth + 1) for key, item in value.items()
        }
    return value


def _event_block(record: dict, evidence_items: list[dict]) -> dict:
    raw = _raw_message(record)
    counts: dict[str, int] = {}
    if raw is not None:
        redacted_text, counts = redact.redact_text(raw)
        message_bytes = len(raw.encode("utf-8"))
    else:
        redacted_text, message_bytes = "", None

    truncated = redacted_text[:MESSAGE_CHARS_CAP]
    event: dict[str, Any] = {
        "message_hash": hashlib.sha256(truncated.encode("utf-8")).hexdigest(),
        "time_utc_us": _int_or_none(record.get("__REALTIME_TIMESTAMP")),
        "message_trunc": truncated,
    }
    if message_bytes is not None:
        event["message_bytes"] = message_bytes
    if record.get("_ERRNO") is not None:
        event["errno"] = str(record.get("_ERRNO"))
    else:
        event["errno"] = None
    msgid = record.get("MESSAGE_ID")
    event["message_id"] = msgid if isinstance(msgid, str) else None
    if event["errno"] is None:
        event.pop("errno")

    # repeated (non-unique) fields: occurrences counted; arrays preserved
    # verbatim in structure (content redacted — §14) as an evidence item;
    # first values stay OUT of identity decisions (discovery already
    # refuses list values, §8.3 step 1)
    occurrences = {
        key: len(val) for key, val in record.items() if isinstance(val, list)
    }
    if occurrences:
        event["occurrence_counts"] = occurrences
        arrays = {
            key: _redact_deep(val, counts)
            for key, val in record.items()
            if isinstance(val, list)
        }
        try:
            payload = json.dumps(arrays, ensure_ascii=False)
        except (TypeError, ValueError):
            payload = None
        if payload is not None and len(payload) <= _PRESERVED_ARRAYS_ITEM_BYTES:
            evidence_items.append(
                {
                    "kind": "repeated_fields_verbatim",
                    "fields": arrays,
                }
            )
        else:
            evidence_items.append(
                {
                    "kind": "repeated_fields_verbatim",
                    "fields": None,
                    "note": "PRESERVATION_DROPPED: arrays exceed bound",
                }
            )
    if counts:
        event["_redaction_counts"] = counts  # folded into redaction block later
    return event


def _sender_block(record: dict, discovery: dict) -> dict | None:
    sender = discovery.get("record_sender")
    conmon = discovery.get("conmon")
    if isinstance(sender, dict):
        sender = dict(sender)
        verified = (
            isinstance(conmon, dict) and conmon.get("status") == m.STATUS_VERIFIED
        )
        sender["role_state"] = (
            "VERIFIED"
            if verified
            else ("CANDIDATE_ONLY" if sender.get("role_candidate") else None)
        )
        if discovery.get("event_transport") == m.TRANSPORT_STDOUT_STDERR:
            sender["stream_owner_note"] = (
                "trusted sender fields identify the host-side stdout stream/"
                "connection owner only (§8.1-A, §21 ref 1)"
            )
        return sender
    return None


def _subject_block(discovery: dict) -> dict | None:
    subject = discovery.get("referenced_subject")
    if isinstance(subject, dict):
        out = dict(subject)
        out["disposition"] = discovery.get("subject_disposition")
        return out
    return None


def _association_block(association: Any, discovery: dict, seq: int) -> dict | None:
    """Backend issues the opaque ref ONLY when the association object exists."""
    if not isinstance(association, dict):
        return None
    out = dict(association)
    out["ref"] = f"cont_ref_{seq}"
    out["init_pid"] = None  # runtime init-PID mapping is Phase-4 work (§8.2)
    runtime_ids = [
        f"e{index}"
        for index, item in enumerate(discovery.get("evidence", []), start=1)
        if item.get("origin") == "runtime_query"
    ]
    out["evidence_refs"] = runtime_ids
    return out


def _bedrock_missing(
    record: dict, discovery: dict, current_boot_id: str | None
) -> list[str]:
    missing = list(discovery.get("missing_evidence", []))
    event_boot = _boot_of_record(record)
    if (
        current_boot_id
        and event_boot
        and _discovery._boot_canonical(event_boot)
        != _discovery._boot_canonical(current_boot_id)
    ):
        # §8.2: a different boot means historical evidence NEVER compares
        # against the current process — surfaced, not silently compared
        missing.append(f"{m.REASON_STALE_EVIDENCE}:boot-mismatch")
    # order-preserving dedup: discovery's ordered probes can hit the same
    # key twice; the incident keeps the first occurrence
    seen: set[str] = set()
    deduped: list[str] = []
    for entry in missing:
        if entry not in seen:
            seen.add(entry)
            deduped.append(entry)
    return deduped


def build_incident(
    record: dict,
    discovery_result: dict,
    *,
    survey_snapshot: dict | None = None,
    current_boot_id: str | None = None,
    correlation_id: str | None = None,
    container_seq: int = 1,
    message_cap: int = MESSAGE_CHARS_CAP,
) -> dict:
    """Assemble the versioned incident envelope for ONE journal record."""
    if not isinstance(record, dict):
        raise TypeError("record must be a journal record dict")
    if not correlation_id:
        correlation_id = str(uuid.uuid4())

    evidence_items: list[dict] = []
    event = _event_block(record, evidence_items)
    source = _source_block(record, discovery_result)

    evidence_refs: list[dict] = []
    for index, item in enumerate(discovery_result.get("evidence", []), start=1):
        origin = item.get("origin")
        strength = item.get("strength")
        evidence_refs.append(
            {
                "id": f"e{index}",
                "origin": EVIDENCE_ORIGIN_MAP.get(origin, origin),
                "strength": EVIDENCE_STRENGTH_MAP.get(strength, strength),
                "time_scope": item.get("time_scope"),
                "desc": item.get("provenance_note"),
            }
        )
    for position, extra in enumerate(evidence_items, start=1):
        extra = dict(extra)
        extra["id"] = f"e{len(evidence_refs) + position}"
        extra["origin"] = "journal_trusted"  # same-record provenance
        extra["strength"] = "weak"  # untrusted JSON content (§9)
        evidence_refs.append(extra)

    redaction_counts = dict(event.pop("_redaction_counts", {}))
    redaction = {
        "rules_applied": sorted(redaction_counts.keys()),
        "items_redacted": sum(redaction_counts.values()),
    }

    missing = _bedrock_missing(record, discovery_result, current_boot_id)

    incident: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "correlation_id": correlation_id,
        "source": source,
        "event": event,
        "record_sender": _sender_block(record, discovery_result),
        "referenced_subject": _subject_block(discovery_result),
        "event_sender_cgroup": discovery_result.get("event_sender_cgroup"),
        "event_subject_cgroup": discovery_result.get("event_subject_cgroup"),
        "current_proc_cgroup": discovery_result.get("current_proc_cgroup"),
        "current_process_domain": discovery_result.get("current_process_domain"),
        "proc_qualification": discovery_result.get("proc_qualification"),
        "container_association": _association_block(
            discovery_result.get("container_association"),
            discovery_result,
            container_seq,
        ),
        "conmon": (
            dict(discovery_result["conmon"])
            if isinstance(discovery_result.get("conmon"), dict)
            else None
        ),
        "workload_identity": discovery_result.get("workload_identity"),
        "evidence_refs": evidence_refs,
        "missing_evidence": missing,
        "survey_snapshot": (
            dict(survey_snapshot) if survey_snapshot else _survey_absent()
        ),
        "redaction": redaction,
        "severity_hint": SEVERITY_HINT.get(source["priority"]),
        "limits_note": list(discovery_result.get("limits_note", [])),
    }
    return incident


# ─── structural self-check ───────────────────────────────────────────────────


def validate_incident(blob: Any) -> list[str]:
    """Structural validation of a ``nibras.incident/v1`` envelope.

    Returns a list of problems (empty ⇒ structurally valid). Consumers
    reject unknown major versions; the normalizer only emits v1.
    """
    problems: list[str] = []
    if not isinstance(blob, dict):
        return ["incident must be a dict"]

    if blob.get("schema_version") != SCHEMA_VERSION:
        problems.append(f"schema_version mismatch: {blob.get('schema_version')!r}")
    try:
        uuid.UUID(str(blob.get("correlation_id")))
    except (ValueError, AttributeError, TypeError):
        problems.append("correlation_id is not a parseable uuid")

    for key in (
        "source",
        "event",
        "record_sender",
        "evidence_refs",
        "missing_evidence",
        "survey_snapshot",
        "redaction",
    ):
        if key not in blob:
            problems.append(f"missing key: {key}")

    source = blob.get("source")
    if isinstance(source, dict):
        if source.get("kind") != "journal":
            problems.append("source.kind must be 'journal'")
        if not isinstance(source.get("boot_id"), (str, type(None))):
            problems.append("source.boot_id must be str|null")
        cursor = source.get("cursor")
        if cursor is not None and not isinstance(cursor, str):
            problems.append("source.cursor must be a verbatim string")
        for key, types in (
            ("cursor_utc_us", (int, type(None))),
            ("monotonic_us", (int, type(None))),
            ("priority", (int, type(None))),
        ):
            if not isinstance(source.get(key), types):
                problems.append(f"source.{key} must be int|null")
        if source.get("priority") is not None and not (0 <= source["priority"] <= 7):
            problems.append("source.priority out of range 0-7")
    else:
        problems.append("source must be a dict")

    if "runtime_domain" in blob:
        problems.append("runtime_domain must never sit at the root (§9)")
    if "event_transport" in blob:
        problems.append("event_transport must not be duplicated at the root (§9)")

    event = blob.get("event")
    if isinstance(event, dict):
        digest = event.get("message_hash")
        if not isinstance(digest, str) or len(digest) != 64:
            problems.append("event.message_hash must be full sha256 hex (64)")
        truncated = event.get("message_trunc")
        if truncated is not None and not isinstance(truncated, str):
            problems.append("event.message_trunc must be str|null")
        if isinstance(truncated, str) and len(truncated) > MESSAGE_CHARS_CAP:
            problems.append("event.message_trunc exceeds 2000-char cap")
        if not isinstance(event.get("time_utc_us"), (int, type(None))):
            problems.append("event.time_utc_us must be int|null")
    else:
        problems.append("event must be a dict")

    sender = blob.get("record_sender")
    if sender is not None and not isinstance(sender, dict):
        problems.append("record_sender must be dict|null")

    association = blob.get("container_association")
    if association is not None:
        if not isinstance(association, dict):
            problems.append("container_association must be dict|null")
        else:
            ref = association.get("ref")
            if not isinstance(ref, str) or not ref.startswith("cont_ref_"):
                problems.append("container ref must be backend-issued cont_ref_*")
            if association.get("init_pid") is not None:
                problems.append("init_pid must be null until Phase-4 mapping")

    evidence_refs = blob.get("evidence_refs", [])
    if not isinstance(evidence_refs, list):
        problems.append("evidence_refs must be a list")
    else:
        ids: list[str] = []
        for item in evidence_refs:
            if not isinstance(item, dict):
                problems.append("evidence_refs entries must be dicts")
                continue
            eid = item.get("id")
            if not isinstance(eid, str) or not eid.startswith("e"):
                problems.append("evidence id must be e<N>")
            else:
                ids.append(eid)
            if (
                "origin" in item
                and item["origin"] not in EVIDENCE_ORIGINS
                and not (item.get("kind") == "repeated_fields_verbatim")
            ):
                problems.append(f"evidence origin unknown: {item.get('origin')!r}")
        if len(ids) != len(set(ids)):
            problems.append("evidence ids must be unique")

    missing = blob.get("missing_evidence")
    if missing is not None and not isinstance(missing, list):
        problems.append("missing_evidence must be a list")

    redaction_block = blob.get("redaction")
    if not isinstance(redaction_block, dict):
        problems.append("redaction must be a dict")
    else:
        if not isinstance(redaction_block.get("rules_applied"), list):
            problems.append("redaction.rules_applied must be a list")
        if not isinstance(redaction_block.get("items_redacted"), int):
            problems.append("redaction.items_redacted must be an int")

    severity = blob.get("severity_hint")
    if severity is not None and severity not in VALID_SEVERITIES:
        problems.append(f"severity_hint unknown: {severity!r}")

    if blob.get("survey_snapshot") is None:
        problems.append("survey_snapshot must be present (state ABSENT allowed)")
    return problems
