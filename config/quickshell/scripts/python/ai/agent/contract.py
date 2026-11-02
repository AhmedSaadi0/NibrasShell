#!/usr/bin/env python3
"""agent/contract.py — strict model-output contracts (Phase 3, §10.4–§10.6, §11).

Ordered validator rule set (§11.3; first mismatch of a *hard* kind rejects
with a precise reason code; unknown top-level keys are allowed + ignored +
logged; prohibited keys are deleted or rejected per artifact):

- ``nibras.tool_request/v1`` — one registered read-only tool per request,
  typed arguments, every target bound to the backend-side ``RefRegistry``
  built ONLY from the incident (§11.3 rule 2: the model may only *quote*
  references the backend supplied). Widening requests (environment variables
  or unlisted inspect fields) are refused outright (§14 default-deny). An
  integer-typed ``since_cursor`` is a schema error — never string-coerced
  (§11.3 rule 4). Prohibited keys (``command``/``script``/``steps``/``shell``)
  are deleted from tool requests (§16.3 row 1 — deletion semantics).
- ``nibras.diagnosis/v1`` — full schema check; ``proposed_remediation`` is
  declarative + non-executable (prohibited keys are REJECTED with repair
  pointer, §16.3 row 11); ``guidance_code`` must be one of the closed
  registry set; ``manual_guidance`` requires it; ``explain_only`` maps to
  ``G_EXPLAIN_ONLY`` and takes no target. Semantic gating of guidance
  templates (minimum evidence per §11.1 rows) is the Phase-4 policy engine
  (``policy/engine.py``) — Phase 3 validates *structure + references*.
- Decision records (§11.3 rule 6) attach per artifact:
  tool requests → ``TOOL_REQUEST_ALLOWED | POLICY_REJECTED``;
  remediation → ``GUIDANCE_VALIDATED | POLICY_REJECTED | ANALYSIS_UNVERIFIED``.
- Bounded JSON parsing + ``<>`` neutralization for the ``<incident>`` /
  ``<tool_output>`` demarcation framing (§10.5).

No provider coupling, no subprocess, no network here — pure validation.
"""

from __future__ import annotations

import json
import re
from typing import Any

try:  # package layout (scripts/python on sys.path)
    from ..incident import normalizer as _nz
except ImportError:  # flat layout (cwd=scripts/python/ai)
    from incident import normalizer as _nz  # type: ignore[no-redef]

INCIDENT_SCHEMA = _nz.SCHEMA_VERSION  # "nibras.incident/v1" — no version drift


# ─── contract identities ─────────────────────────────────────────────────────

SCHEMA_TOOL_REQUEST = "nibras.tool_request/v1"
SCHEMA_DIAGNOSIS = "nibras.diagnosis/v1"

ALLOWED_TOOLS: tuple[str, ...] = (
    "inspect_process",
    "inspect_container",
    "inspect_unit",
    "journal_query",
)
# The underlying identity kind each inspect_* tool requires (§10.4-A alias
# keys: process_ref / container_ref / unit_ref beside the generic target_ref).
KIND_FOR_TOOL: dict[str, str] = {
    "inspect_process": "process",
    "inspect_container": "container",
    "inspect_unit": "unit",
}

ACTION_KINDS: tuple[str, ...] = ("explain_only", "manual_guidance")

# Closed guidance-code registry (§11.1). Semantic *gating* (minimum-evidence
# checks per row) is the Phase-4 policy engine; Phase 3 binds kinds only.
GUIDANCE_CODES: frozenset[str] = frozenset(
    {
        "G_EXPLAIN_ONLY",
        "G_REVIEW_CONTAINER_SOT",
        "G_REVIEW_UNIT_STATE",
        "G_SOFTWARE_UPDATE_REVIEW",
    }
)
# Allowed underlying target kind per code when target_ref is non-null. Phase-3
# note: the incident registry does not issue host_package_*/container_image_*
# refs, so G_SOFTWARE_UPDATE_REVIEW binds to null in this phase; the Phase-4
# engine performs the survey/package evidence matching.
GUIDANCE_TARGET_KIND: dict[str, str | None] = {
    "G_EXPLAIN_ONLY": None,
    "G_REVIEW_CONTAINER_SOT": "container",
    "G_REVIEW_UNIT_STATE": "unit",
    "G_SOFTWARE_UPDATE_REVIEW": None,
}

PROHIBITED_KEYS: frozenset[str] = frozenset({"command", "script", "steps", "shell"})
# §14 default-deny: any widening-shaped key in tool arguments is refused
# outright (not merely ignored).
WIDENING_KEYS: frozenset[str] = frozenset(
    {
        "env",
        "environment",
        "environ",
        "all_env",
        "include_env",
        "labels",
        "mounts",
        "volumes",
    }
)
# Allowed inspect_container fields (§10.6: include subset default [image,state]).
CONTAINER_INCLUDE_VALUES: frozenset[str] = frozenset({"image", "state"})
CONTAINER_INCLUDE_DEFAULT: list[str] = ["image", "state"]

SEVERITIES: frozenset[str] = frozenset({"info", "warning", "critical"})
RISK_LEVELS: frozenset[str] = frozenset({"low", "medium", "high"})

# §11.3 rule 3 / §11.2 'conflicting or stale' — statuses that block
# target-specific guidance until resolved (Phase-3 minimal gate; the full
# domain × action matrix engine is the Phase-4 row).
UNRESOLVED_EVIDENCE_STATUSES: frozenset[str] = frozenset(
    {
        "AMBIGUOUS",
        "UNAVAILABLE",
        "CONFLICT",
        "GONE",
        "PID_NOT_FOUND",
        "PID_REUSED",
        "STALE",
        "STALE_EVIDENCE",
        "STALE_CURRENT_INSTANCE",
        "NOT_FOUND",
        "PERMISSION_DENIED",
        "TIMEOUT",
        "INVALID_DATA",
        "WRONG_RUNTIME_CONTEXT",
        "HISTORICAL_IDENTITY_UNAVAILABLE",
        "RUNTIME_UNAVAILABLE",
        "UNSAFE_SKIP",
        "INSUFFICIENT_EVIDENCE",
    }
)

INCIDENT_SUMMARY_MAX_CHARS = 400  # §10.4-B
TEXT_FIELD_MAX_CHARS = 2000  # same bound as event.message_trunc (§9)
FINDINGS_MAX = 50
STR_LIST_MAX = 50
RATIONALE_MAX_CHARS = 4000
PATTERN_MAX_CHARS = 64
# Tool-request literal pattern: bounded, no control characters, no regex
# metacharacters (journalctl --grep receives it but stays a bounded literal).
PATTERN_RE = re.compile(r"[A-Za-z0-9 _.,:\-]{1,64}")
TOOL_REQUEST_ID_MAX = 64
JOURNAL_LIMIT_MIN, JOURNAL_LIMIT_MAX, JOURNAL_LIMIT_DEFAULT = 1, 200, 20

TOOL_REQUEST_ARG_KEYS: frozenset[str] = frozenset(
    {
        "target_ref",
        "process_ref",
        "container_ref",
        "unit_ref",
        "pattern",
        "since_cursor",
        "limit",
        "include",
    }
)


# ─── reason codes (typed; surfaced verbatim to tests/audit) ──────────────────

R_OK = "OK"
R_SCHEMA_ERROR = "SCHEMA_ERROR"
R_PROHIBITED_KEY = "PROHIBITED_KEY"
R_TARGET_NOT_FROM_BACKEND = "target_not_from_backend"
R_TARGET_KIND_MISMATCH = "target_kind_mismatch"
R_UNAPPROVED_TOOL = "UNAPPROVED_TOOL"
R_UNKNOWN_ACTION_KIND = "unknown_action_kind"
R_UNKNOWN_EVIDENCE_REF = "UNKNOWN_EVIDENCE_REF"
R_UNKNOWN_GUIDANCE_CODE = "unknown_guidance_code"
R_REFUSED_WIDENING = "REFUSED_WIDENING"
R_INVALID_DATA = "INVALID_DATA"
R_UNBINDABLE_TARGET = "UNBINDABLE_TARGET"  # ref issued but no inspectable identity
R_ROLE_CONTRACT_VIOLATION = "ROLE_CONTRACT_VIOLATION"
R_TARGET_EVIDENCE_UNRESOLVED = "target_evidence_unresolved"
R_MALFORMED_JSON = "MALFORMED_JSON"
R_EMPTY_OUTPUT = "EMPTY_MODEL_OUTPUT"
R_OVERSIZED_OUTPUT = "OVERSIZED_MODEL_OUTPUT"

STATUS_TOOL_ALLOWED = "TOOL_REQUEST_ALLOWED"
STATUS_REJECTED = "POLICY_REJECTED"
STATUS_GUIDANCE_VALIDATED = "GUIDANCE_VALIDATED"
STATUS_ANALYSIS_UNVERIFIED = "ANALYSIS_UNVERIFIED"

# notes attached to decisions (honest audit trail)
N_PROHIBITED_DROPPED = "PROHIBITED_KEY_DROPPED"
N_UNKNOWN_KEYS_IGNORED = "UNKNOWN_KEYS_IGNORED"
N_MODEL_PROSE_NOT_OPERATIONAL = "MODEL_PROSE_NOT_OPERATIONAL"
N_CONFIRMATION_FORCED = "REQUIRES_CONFIRMATION_FORCED"
N_EXPLAIN_ONLY_MAPPED = "EXPLAIN_ONLY_MAPPED"
N_REQUEST_ID_SUBSTITUTED = "REQUEST_ID_SUBSTITUTED"


class ContractProblem(Exception):
    """Ordered first-mismatch rejection: one precise reason + message (§11.3)."""

    def __init__(self, reason_code: str, message: str) -> None:
        super().__init__(message)
        self.reason_code = reason_code
        self.message = message


def tool_decision(
    request_id: str,
    tool: str | None,
    status: str,
    reason_codes: list[str] | None = None,
    details: list[str] | None = None,
) -> dict[str, Any]:
    """§11.3 rule 6 — one record per tool_request."""
    return {
        "artifact": "tool_request",
        "request_id": request_id,
        "tool": tool,
        "status": status,
        "reason_codes": list(reason_codes or []),
        "details": list(details or []),
    }


def guidance_decision(
    proposal_id: str,
    target_ref: str | None,
    guidance_code: str | None,
    status: str,
    reason_codes: list[str] | None = None,
    details: list[str] | None = None,
) -> dict[str, Any]:
    """§11.3 rule 6 — one record for the remediation proposal."""
    return {
        "artifact": "proposed_remediation",
        "proposal_id": proposal_id,
        "target_ref": target_ref,
        "guidance_code": guidance_code,
        "status": status,
        "reason_codes": list(reason_codes or []),
        "details": list(details or []),
    }


# ─── data hygiene (§10.5 demarcation support) ────────────────────────────────


def neutralize_markers(text: str) -> str:
    """Neutralize ``<>`` so injected log text can never forge or close the
    ``<incident>``/``<tool_output>`` demarcation markers (§10.5)."""
    if not isinstance(text, str):
        raise TypeError("neutralize_markers expects str")
    return text.replace("<", "&lt;").replace(">", "&gt;")


def parse_contract_json(
    text: str, max_bytes: int = 64 * 1024
) -> tuple[Any, str | None]:
    """Bounded parse of a model output object.

    Returns ``(value, None)`` or ``(None, reason)``. Markdown fences are
    stripped like the legacy path, JSON must be a whole object (both Phase-3
    contracts are objects). Legacy parity: if the direct parse fails, the
    outermost balanced ``{…}`` window embedded in surrounding prose is
    extracted (bounded object-scan) and parsed instead; prose without any
    balanced object stays MALFORMED_JSON — never coerced into data.
    """
    if not isinstance(text, str):
        return None, R_SCHEMA_ERROR
    if not text.strip():
        return None, R_EMPTY_OUTPUT
    if len(text.encode("utf-8", "replace")) > max_bytes:  # ≤64 KiB (§10.3)
        return None, R_OVERSIZED_OUTPUT

    clean = text.strip()
    clean = re.sub(r"^```(?:json)?\s*", "", clean, flags=re.IGNORECASE)
    clean = re.sub(r"\s*```\s*$", "", clean).strip()

    try:
        value = json.loads(clean)
    except (json.JSONDecodeError, ValueError):
        # bounded object-scan fallback: first '{' whose braces balance
        start = clean.find("{")
        if start >= 0 and len(clean) <= max_bytes:
            depth = 0
            in_str = False
            esc = False
            for index in range(start, len(clean)):
                ch = clean[index]
                if in_str:
                    if esc:
                        esc = False
                    elif ch == "\\":
                        esc = True
                    elif ch == '"':
                        in_str = False
                    continue
                if ch == '"':
                    in_str = True
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        window = clean[start : index + 1]
                        try:
                            return json.loads(window), None
                        except (json.JSONDecodeError, ValueError):
                            break
        return None, R_MALFORMED_JSON
    if not isinstance(value, dict):
        return None, R_MALFORMED_JSON  # both contracts are JSON objects
    return value, None


# ─── backend-side opaque reference registry (§11.3 rule 2) ───────────────────


class RefRegistry:
    """Refs issued ONLY from incident content; resolution never trusts model
    strings (§11.3 rule 2 — invented PIDs/hex/units never resolve).

    Issuance rules:
    - ``cont_ref_N``: the association block's backend-issued ``ref`` (verbatim,
      never re-numbered; ``normalizer`` only issues it when the association
      object exists);
    - ``proc_ref_N``: every positive recorded ``proc_qualification.pid``
      (the record carries the recorded identity so the tool can detect
      reuse/staleness; the pid itself stays out of the model's vocabulary);
    - ``unit_ref_N``: every claim with a non-empty ``unit`` name, scope kept
      verbatim (SYSTEM / USER / UNKNOWN) — claims are issued regardless of
      attestation status (the status stays a label in the incident; semantic
      gating is the Phase-4 engine's job);
    - ``evidence_ids``: the ledger ``e<N>`` set for closure checks;
    - ``cursor``: the single incident-supplied opaque ``__CURSOR`` (verbatim;
      the model may only re-quote it exactly).
    """

    __slots__ = ("refs", "evidence_ids", "cursor", "boot_id")

    def __init__(self) -> None:
        self.refs: dict[str, dict[str, Any]] = {}
        self.evidence_ids: frozenset[str] = frozenset()
        self.cursor: str | None = None
        self.boot_id: str | None = None

    @classmethod
    def from_incident(cls, incident: dict) -> "RefRegistry":
        reg = cls()
        source = incident.get("source")
        if isinstance(source, dict):
            cursor = source.get("cursor")
            if isinstance(cursor, str) and cursor:
                reg.cursor = cursor
            boot = source.get("boot_id")
            if isinstance(boot, str) and boot:
                reg.boot_id = boot

        ledger = incident.get("evidence_refs")
        if isinstance(ledger, list):
            reg.evidence_ids = frozenset(
                item["id"]
                for item in ledger
                if isinstance(item, dict) and isinstance(item.get("id"), str)
            )

        # containers — reuse the backend-issued ref verbatim (no re-numbering)
        association = incident.get("container_association")
        if isinstance(association, dict):
            ref = association.get("ref")
            if isinstance(ref, str) and ref.startswith("cont_ref_"):
                status = association.get("status")
                reg.refs[ref] = {
                    "kind": "container",
                    "full_id": (
                        association.get("full_id")
                        if isinstance(association.get("full_id"), str)
                        else None
                    ),
                    "status": status if isinstance(status, str) else None,
                    "time_scope": (
                        association.get("time_scope")
                        if isinstance(association.get("time_scope"), str)
                        else None
                    ),
                }

        # processes — one ref per recorded qualification pid
        qualification = incident.get("proc_qualification")
        proc_seq = 0
        if isinstance(qualification, dict):
            pid = qualification.get("pid")
            if isinstance(pid, int) and not isinstance(pid, bool) and pid > 0:
                proc_seq += 1
                compared = qualification.get("compared") is True
                ticks = qualification.get("proc_start_ticks")
                tick_rate = qualification.get("tick_rate")
                monotonic = qualification.get("event_monotonic_us")
                reg.refs[f"proc_ref_{proc_seq}"] = {
                    "kind": "process",
                    "pid": pid,
                    "recorded_start_ticks": (
                        ticks if compared and isinstance(ticks, int) else None
                    ),
                    "event_monotonic_us": (
                        monotonic if isinstance(monotonic, int) else None
                    ),
                    "tick_rate": (
                        tick_rate if isinstance(tick_rate, (int, float)) else None
                    ),
                    "outcome": qualification.get("outcome"),
                }

        # units — one ref per distinct (unit, scope) across the two claims
        unit_seq = 0
        seen: set[tuple[str, str | None]] = set()
        for claim_key in ("event_time_unit_claim", "event_subject_unit_claim"):
            claim = incident.get(claim_key)
            if not isinstance(claim, dict):
                continue
            unit = claim.get("unit")
            scope = claim.get("scope")
            if not isinstance(unit, str) or not unit:
                continue
            scope_str = scope if isinstance(scope, str) else None
            marker = (unit, scope_str)
            if marker in seen:
                continue
            seen.add(marker)
            unit_seq += 1
            status = claim.get("status")
            time_scope = claim.get("time_scope")
            reg.refs[f"unit_ref_{unit_seq}"] = {
                "kind": "unit",
                "unit": unit,
                "scope": scope_str or "UNKNOWN",
                "status": status if isinstance(status, str) else None,
                "time_scope": (time_scope if isinstance(time_scope, str) else None),
            }
        return reg

    def lookup(self, ref: Any) -> dict[str, Any] | None:
        """Resolve a model-quoted ref strictly (type + membership)."""
        if not isinstance(ref, str):
            return None
        return self.refs.get(ref)

    def unresolved_statuses(self) -> list[str]:
        """Every recorded evidence status inside UNRESOLVED_EVIDENCE_STATUSES.

        Registry-wide scan for the Phase-3 minimal §11.2 gate: process records
        keep their status under ``outcome``; container/unit records under
        ``status``. The full domain×action matrix engine is Phase 4.
        """
        found: list[str] = []
        for record in self.refs.values():
            status = (
                record.get("status") if "status" in record else record.get("outcome")
            )
            if isinstance(status, str) and status in UNRESOLVED_EVIDENCE_STATUSES:
                found.append(status)
        return found


# ─── prohibited-key walk (§11.3 / §16.3 rows 1 and 11) ───────────────────────


def _walk_prohibited(value: Any, paths: list[str], prefix: str = "") -> None:
    """Collect paths of every prohibited key in a bounded nested structure."""
    if len(prefix.split(".")) > 6:  # pathological nesting bound
        return
    if isinstance(value, dict):
        for key, item in value.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            if key in PROHIBITED_KEYS:
                paths.append(path)
            _walk_prohibited(item, paths, path)
    elif isinstance(value, list):
        for pos, item in enumerate(value[:20]):
            _walk_prohibited(item, paths, f"{prefix}[{pos}]")


def _drop_prohibited_paths(obj: dict, paths: list[str]) -> None:
    """Delete the exact key paths previously collected by the walk (while
    preserving surrounding valid fields — deletion semantics, §16.3 row 1)."""
    for path in paths:
        segments = path.split(".")
        container: Any = obj
        ok = True
        for part in segments[:-1]:
            if "[" in part:
                key, rest = part.split("[", 1)
                idx_str = rest.rstrip("]")
                if not idx_str.isdigit():
                    ok = False
                    break
                nxt = container.get(key) if isinstance(container, dict) else None
                if not isinstance(nxt, (list, dict)) or isinstance(nxt, dict):
                    ok = False
                    break
                idx = int(idx_str)
                if not isinstance(nxt, list) or idx >= len(nxt):
                    ok = False
                    break
                container = nxt[idx]
                continue
            nxt = container.get(part) if isinstance(container, dict) else None
            if not isinstance(nxt, dict):
                ok = False
                break
            container = nxt
        if not ok:
            continue
        leaf_part = segments[-1]
        leaf = leaf_part.split("[", 1)[0]
        if (
            isinstance(container, dict)
            and leaf in container
            and leaf in PROHIBITED_KEYS
        ):
            container.pop(leaf, None)


# ─── tool_request validator ──────────────────────────────────────────────────


def _arguments_integrity(args: dict) -> None:
    """Hard-integrity pass over arguments: widening refusal (§14)."""
    for key in args:
        if key in WIDENING_KEYS:
            raise ContractProblem(
                R_REFUSED_WIDENING,
                f"argument '{key}' is an environment/widening request — refused "
                "outright (§14 default-deny)",
            )
    include = args.get("include")
    if include is not None and not isinstance(include, list):
        raise ContractProblem(
            R_REFUSED_WIDENING,
            f"arguments.include must be the bounded field list "
            f"{sorted(CONTAINER_INCLUDE_VALUES)}; other shapes are refused "
            "(§14 default-deny)",
        )
    if isinstance(include, list):
        for item in include:
            if isinstance(item, str) and (
                item in WIDENING_KEYS or item.lower() in WIDENING_KEYS
            ):
                raise ContractProblem(
                    R_REFUSED_WIDENING,
                    f"include('{item}') is a widening request — refused outright "
                    "(§14 default-deny)",
                )


def _resolve_target(
    args: dict,
    tool: str,
    registry: RefRegistry,
) -> dict[str, Any]:
    """Bind an inspect-* tool to a registry ref; raise on any failure."""
    kind_wanted = KIND_FOR_TOOL[tool]
    candidates = [
        (key, args[key])
        for key in ("target_ref", f"{kind_wanted}_ref")
        if key in args and args[key] is not None
    ]
    if not candidates:
        raise ContractProblem(
            R_SCHEMA_ERROR,
            f"missing field arguments.target_ref ({kind_wanted}_ref) — {tool} "
            "requires exactly one backend-issued ref",
        )
    key, value = candidates[0]
    other_keys = {alias for alias, _ in candidates[1:]}
    if other_keys:
        raise ContractProblem(
            R_SCHEMA_ERROR,
            "conflicting target keys in arguments — supply exactly one of "
            "target_ref / process_ref / container_ref / unit_ref",
        )
    spec = registry.lookup(value)
    if spec is None:
        raise ContractProblem(
            R_TARGET_NOT_FROM_BACKEND,
            f"arguments.{key}={value!r} is not an incident-issued reference "
            f"(target kind {kind_wanted!r}) — only backend-issued refs resolve",
        )
    if spec.get("kind") != kind_wanted:
        raise ContractProblem(
            R_TARGET_KIND_MISMATCH,
            f"arguments.{key}={value!r} is a {spec.get('kind')!r} ref but "
            f"{tool} requires a {kind_wanted!r} target",
        )
    if kind_wanted == "container" and not spec.get("full_id"):
        raise ContractProblem(
            R_UNBINDABLE_TARGET,
            f"ref {value!r} has no inspectable container identity "
            "(association unverified/unimplemented) — cannot bind an inspect "
            "target",
        )
    if kind_wanted == "unit" and spec.get("scope") == "UNKNOWN":
        raise ContractProblem(
            R_UNBINDABLE_TARGET,
            f"ref {value!r} carries an UNKNOWN manager scope — no scope is "
            "guessed by the backend (the user chooses the review target)",
        )
    return {"key": key, "ref": value, "spec": spec}


def _typed_tool_args(
    tool: str,
    args: dict,
    registry: RefRegistry,
) -> dict[str, Any]:
    """Typed per-tool argument validation (§11.3 rule 4)."""
    if tool == "journal_query":
        spec: dict[str, Any] = {}

        unit_ref = args.get("unit_ref")
        if unit_ref is not None:
            unit_spec = registry.lookup(unit_ref)
            if unit_spec is None:
                raise ContractProblem(
                    R_TARGET_NOT_FROM_BACKEND,
                    f"arguments.unit_ref={unit_ref!r} is not an incident-issued "
                    "unit reference — only backend-issued refs resolve",
                )
            if unit_spec.get("kind") != "unit":
                raise ContractProblem(
                    R_TARGET_KIND_MISMATCH,
                    f"arguments.unit_ref={unit_ref!r} is a "
                    f"{unit_spec.get('kind')!r} ref; journal_query requires a "
                    "unit ref",
                )
            spec["unit"] = unit_spec.get("unit")
            spec["unit_ref"] = unit_ref

        cursor = args.get("since_cursor")
        if cursor is not None:
            # §11.3 rule 4: an integer-typed cursor is a schema error —
            # no string coercion, ever.
            if not isinstance(cursor, str):
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    f"arguments.since_cursor must be the verbatim incident "
                    f"cursor string or null; type {type(cursor).__name__} is a "
                    "schema error (no string coercion)",
                )
            if registry.cursor is None or cursor != registry.cursor:
                raise ContractProblem(
                    R_TARGET_NOT_FROM_BACKEND,
                    "arguments.since_cursor did not match the incident-supplied "
                    "cursor (cursor continuation is verbatim-only)",
                )
            spec["since_cursor"] = cursor

        pattern = args.get("pattern")
        if pattern is not None:
            if not isinstance(pattern, str):
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    "arguments.pattern must be a bounded string or null",
                )
            if not PATTERN_RE.fullmatch(pattern):
                raise ContractProblem(
                    R_INVALID_DATA,
                    f"arguments.pattern must match [A-Za-z0-9 _.,:-]{{1,"
                    f"{PATTERN_MAX_CHARS}}} — control characters and regex "
                    "metacharacters are rejected",
                )
            spec["pattern"] = pattern

        limit = args.get("limit")
        if limit is not None:
            if isinstance(limit, bool) or not isinstance(limit, int):
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    "arguments.limit must be an integer in [1, 200]",
                )
            if not (JOURNAL_LIMIT_MIN <= limit <= JOURNAL_LIMIT_MAX):
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    f"arguments.limit={limit} out of range "
                    f"[{JOURNAL_LIMIT_MIN}, {JOURNAL_LIMIT_MAX}] "
                    "(unbounded args are rejected pre-exec)",
                )
            spec["limit"] = limit

        if not spec:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                "journal_query requires unit_ref, pattern, or since_cursor — a "
                "fully unconstrained global query is not an R1 tool shape",
            )
        return spec

    # inspect_process / inspect_container / inspect_unit
    target = _resolve_target(args, tool, registry)
    spec = {"target_ref": target["ref"], "target": dict(target["spec"])}

    include = args.get("include")
    if include is not None:
        if not isinstance(include, list) or not all(
            isinstance(v, str) for v in include
        ):
            raise ContractProblem(
                R_SCHEMA_ERROR, "arguments.include must be a list of field names"
            )
        if any(v not in CONTAINER_INCLUDE_VALUES for v in include):
            raise ContractProblem(
                R_REFUSED_WIDENING,
                f"arguments.include values outside "
                f"{sorted(CONTAINER_INCLUDE_VALUES)} are refused (§14 "
                "default-deny; no env/labels/mount widening)",
            )
        spec["include"] = list(include)
    elif tool == "inspect_container":
        spec["include"] = list(CONTAINER_INCLUDE_DEFAULT)
    return spec


def validate_tool_request(
    obj: Any,
    registry: RefRegistry,
    *,
    request_id: str = "tr-1",
    known_request_ids: frozenset[str] = frozenset(),
) -> dict[str, Any]:
    """Full ``nibras.tool_request/v1`` validation (§11.3 ordered application).

    Returns ``{"decision": tool_decision(...), "tool_spec": {...} | None,
    "notes": [...]}`` — ``tool_spec`` present ONLY when allowed and it is the
    clean, backend-resolved execution payload for ``agent.tools.execute``.
    """
    notes: list[str] = []
    rid = request_id
    tool: Any = None
    try:
        if not isinstance(obj, dict):
            raise ContractProblem(R_SCHEMA_ERROR, "tool_request must be a JSON object")
        if obj.get("schema_version") != SCHEMA_TOOL_REQUEST:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"schema_version must be exactly {SCHEMA_TOOL_REQUEST!r}; got "
                f"{obj.get('schema_version')!r}",
            )
        tool = obj.get("tool")

        # §11.3: unknown top-level keys allowed + ignored + logged
        unknown = sorted(
            set(obj)
            - {"schema_version", "request_id", "tool", "arguments", "stated_purpose"}
        )
        if unknown:
            notes.append(f"{N_UNKNOWN_KEYS_IGNORED}: {', '.join(unknown)}")

        rid_model = obj.get("request_id")
        if isinstance(rid_model, str) and rid_model:
            if len(rid_model) > TOOL_REQUEST_ID_MAX:
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    f"request_id exceeds {TOOL_REQUEST_ID_MAX} chars",
                )
            if rid_model in known_request_ids and rid_model != request_id:
                raise ContractProblem(
                    R_SCHEMA_ERROR,
                    "duplicate request_id — ids must be unique within one run",
                )
            rid = rid_model
        else:
            notes.append(
                f"{N_REQUEST_ID_SUBSTITUTED}: request_id missing or not a "
                "string — backend id substituted"
            )

        purpose = obj.get("stated_purpose")
        if purpose is not None and not isinstance(purpose, str):
            raise ContractProblem(
                R_SCHEMA_ERROR, "stated_purpose must be a string when present"
            )

        if tool not in ALLOWED_TOOLS:
            raise ContractProblem(
                R_UNAPPROVED_TOOL,
                f"tool {tool!r} is outside the read-only allowlist "
                f"{list(ALLOWED_TOOLS)}",
            )

        args = obj.get("arguments", {})
        if args is None:
            args = {}
        if not isinstance(args, dict):
            raise ContractProblem(R_SCHEMA_ERROR, "arguments must be an object")

        unknown_args = sorted(set(args) - TOOL_REQUEST_ARG_KEYS)
        if unknown_args:
            notes.append(
                f"{N_UNKNOWN_KEYS_IGNORED}: arguments.{', arguments.'.join(unknown_args)}"
            )

        # prohibited keys anywhere in the artifact are DELETED (§16.3 row 1 —
        # deletion semantics; the remaining valid request may still execute)
        paths: list[str] = []
        _walk_prohibited(obj, paths)
        if paths:
            _drop_prohibited_paths(obj, paths)
            notes.append(f"{N_PROHIBITED_DROPPED}: {', '.join(sorted(paths))}")
            args = obj.get("arguments", {})
            if not isinstance(args, dict):
                args = {}

        _arguments_integrity(args)
        spec = _typed_tool_args(tool, args, registry)

        decision = tool_decision(
            rid, tool, STATUS_TOOL_ALLOWED, [R_OK], details=list(notes)
        )
        spec_out = dict(spec)
        spec_out["request_id"] = rid
        spec_out["tool"] = tool
        spec_out["stated_purpose"] = purpose
        return {"decision": decision, "tool_spec": spec_out, "notes": notes}

    except ContractProblem as problem:
        decision = tool_decision(
            rid, tool, STATUS_REJECTED, [problem.reason_code], [problem.message, *notes]
        )
        return {"decision": decision, "tool_spec": None, "notes": notes}


# ─── diagnosis validator ─────────────────────────────────────────────────────


def _validate_str_list(value: Any, name: str) -> None:
    if value is None:
        return
    if not isinstance(value, list):
        raise ContractProblem(
            R_SCHEMA_ERROR, f"response.{name} must be a list of strings"
        )
    for position, item in enumerate(value):
        if not isinstance(item, str):
            raise ContractProblem(
                R_SCHEMA_ERROR, f"response.{name}[{position}] must be a string"
            )
        if len(item) > TEXT_FIELD_MAX_CHARS:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"response.{name}[{position}] exceeds {TEXT_FIELD_MAX_CHARS} chars",
            )
    if len(value) > STR_LIST_MAX:
        raise ContractProblem(
            R_SCHEMA_ERROR, f"response.{name} exceeds {STR_LIST_MAX} entries"
        )


def _validate_findings(findings: Any, registry: RefRegistry) -> None:
    if not isinstance(findings, list):
        raise ContractProblem(R_SCHEMA_ERROR, "response.findings must be a list")
    if len(findings) > FINDINGS_MAX:
        raise ContractProblem(
            R_SCHEMA_ERROR, f"response.findings exceeds {FINDINGS_MAX} entries"
        )
    seen_ids: set[str] = set()
    for position, finding in enumerate(findings):
        prefix = f"response.findings[{position}]"
        if not isinstance(finding, dict):
            raise ContractProblem(R_SCHEMA_ERROR, f"{prefix} must be an object")
        fid = finding.get("id")
        if not isinstance(fid, str) or not fid:
            raise ContractProblem(
                R_SCHEMA_ERROR, f"{prefix}.id must be a non-empty string"
            )
        if fid in seen_ids:
            raise ContractProblem(R_SCHEMA_ERROR, f"{prefix}.id duplicates {fid!r}")
        seen_ids.add(fid)
        text = finding.get("text")
        if not isinstance(text, str) or len(text) > TEXT_FIELD_MAX_CHARS:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"{prefix}.text must be a string ≤ {TEXT_FIELD_MAX_CHARS} chars",
            )
        severity = finding.get("severity")
        if severity not in SEVERITIES:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"{prefix}.severity {severity!r} is outside {sorted(SEVERITIES)}",
            )
        refs = finding.get("evidence_refs", [])
        if refs is None:
            refs = []
        if not isinstance(refs, list) or not all(isinstance(r, str) for r in refs):
            raise ContractProblem(
                R_SCHEMA_ERROR, f"{prefix}.evidence_refs must be a list of strings"
            )
        for ref in refs:
            if ref not in registry.evidence_ids:
                raise ContractProblem(
                    R_UNKNOWN_EVIDENCE_REF,
                    f"{prefix}.evidence_refs cites {ref!r} — not present in the "
                    "incident evidence ledger",
                )


def _validate_remediation(
    remediation: Any,
    registry: RefRegistry,
    notes: list[str],
) -> dict[str, Any]:
    """Returns the normalized remediation block; ``{"__absent__": True}`` when
    the model proposed no remediation (labeled analysis-only state)."""
    if remediation is None:
        # §11.3 rule 6: no proposal ⇒ labeled analysis-unverified state.
        return {"__absent__": True}
    if not isinstance(remediation, dict):
        raise ContractProblem(
            R_SCHEMA_ERROR, "response.proposed_remediation must be an object or null"
        )

    action_kind = remediation.get("action_kind")
    if action_kind not in ACTION_KINDS:
        raise ContractProblem(
            R_UNKNOWN_ACTION_KIND,
            f"proposed_remediation.action_kind {action_kind!r} is outside the "
            f"declarative allowlist {list(ACTION_KINDS)}",
        )

    prohibited: list[str] = []
    _walk_prohibited(remediation, prohibited, "proposed_remediation")
    if prohibited:
        raise ContractProblem(
            R_PROHIBITED_KEY,
            "proposed_remediation carries forbidden operational key(s): "
            f"{', '.join(sorted(prohibited))} — remove them; remediation is "
            "declarative and non-executable",
        )

    guidance_code = remediation.get("guidance_code")
    rationale = remediation.get("rationale")
    if rationale is None:
        notes.append("rationale missing — backend records an empty rationale")
    elif not isinstance(rationale, str) or len(rationale) > RATIONALE_MAX_CHARS:
        raise ContractProblem(
            R_SCHEMA_ERROR,
            f"proposed_remediation.rationale must be a string ≤ "
            f"{RATIONALE_MAX_CHARS} chars",
        )
    risk_level = remediation.get("risk_level")
    if risk_level is not None and risk_level not in RISK_LEVELS:
        raise ContractProblem(
            R_SCHEMA_ERROR,
            f"proposed_remediation.risk_level {risk_level!r} is outside "
            f"{sorted(RISK_LEVELS)}",
        )

    if action_kind == "manual_guidance":
        if not isinstance(guidance_code, str) or guidance_code not in GUIDANCE_CODES:
            raise ContractProblem(
                R_UNKNOWN_GUIDANCE_CODE,
                f"manual_guidance requires a registered guidance_code; "
                f"{guidance_code!r} is unregistered or missing",
            )
    else:  # explain_only maps to G_EXPLAIN_ONLY (§11.3 rule 5)
        if guidance_code not in (None, "G_EXPLAIN_ONLY"):
            notes.append(
                f"{N_EXPLAIN_ONLY_MAPPED}: guidance_code {guidance_code!r} "
                "overridden to G_EXPLAIN_ONLY for explain_only"
            )
        else:
            notes.append(
                f"{N_EXPLAIN_ONLY_MAPPED}: action_kind explain_only → "
                "guidance_code G_EXPLAIN_ONLY (no model-chosen code)"
            )
        guidance_code = "G_EXPLAIN_ONLY"

    target_ref = remediation.get("target_ref")
    target_spec: dict[str, Any] | None = None
    if target_ref is not None:
        target_spec = registry.lookup(target_ref)
        if target_spec is None:
            raise ContractProblem(
                R_TARGET_NOT_FROM_BACKEND,
                f"proposed_remediation.target_ref={target_ref!r} is not an "
                "incident-issued reference (target_not_from_backend)",
            )
        allowed_kind = GUIDANCE_TARGET_KIND.get(guidance_code)
        if allowed_kind is None:
            raise ContractProblem(
                R_TARGET_KIND_MISMATCH,
                f"guidance_code {guidance_code!r} takes no target "
                "(target_ref must be null for this code)",
            )
        if target_spec.get("kind") != allowed_kind:
            raise ContractProblem(
                R_TARGET_KIND_MISMATCH,
                f"target_ref={target_ref!r} is a {target_spec.get('kind')!r} "
                f"ref; {guidance_code} requires a {allowed_kind!r} target",
            )

    confirmed = remediation.get("requires_user_confirmation")
    if confirmed is not True:
        notes.append(
            f"{N_CONFIRMATION_FORCED}: requires_user_confirmation="
            f"{confirmed!r} corrected to true"
        )

    normalized: dict[str, Any] = {
        "action_kind": action_kind,
        "guidance_code": guidance_code,
        "target_ref": target_ref,
        "rationale": rationale if isinstance(rationale, str) else "",
        "risk_level": risk_level if isinstance(risk_level, str) else "medium",
        "requires_user_confirmation": True,
    }
    if target_spec is not None:
        # the model never receives the underlying identity — bindings stay
        # inside the backend; only the opaque ref is echoed
        normalized["target_status"] = target_spec.get("status")

    # Phase-3 minimal §11.2/§11.3-3 gate (registry-wide): ANY unresolved
    # evidence status in the incident blocks target-specific advice until
    # re-inspection resolves it (the full domain matrix engine is the
    # Phase-4 policy row). explain_only without a target stays allowed.
    if target_spec is not None and registry.unresolved_statuses():
        raise ContractProblem(
            R_TARGET_EVIDENCE_UNRESOLVED,
            "incident evidence carries unresolved status(es) "
            f"({', '.join(sorted(set(registry.unresolved_statuses())))}) — "
            "no target-specific guidance until re-inspection resolves it "
            "(§11.2 'conflicting or stale')",
        )
    return normalized


def validate_diagnosis(obj: Any, registry: RefRegistry) -> dict[str, Any]:
    """Full ``nibras.diagnosis/v1`` validation (§11.3 ordered).

    Returns ``{"decision": guidance_decision(...), "problems": [...],
    "reason_code": str, "remediation": dict | None, "analysis_ok": bool,
    "notes": [...]}``. problems non-empty ⇒ contract-invalid (the orchestrator
    may spend its single forced-repair rerun on it; persistent failure ⇒
    neutral response — never execution).
    """
    notes: list[str] = []
    problems: list[str] = []
    reason_code: str | None = None
    try:
        if not isinstance(obj, dict):
            raise ContractProblem(R_SCHEMA_ERROR, "diagnosis must be a JSON object")
        if obj.get("schema_version") != SCHEMA_DIAGNOSIS:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"schema_version must be exactly {SCHEMA_DIAGNOSIS!r}; got "
                f"{obj.get('schema_version')!r}",
            )

        unknown = sorted(set(obj) - {"schema_version", "response"})
        if unknown:
            notes.append(f"{N_UNKNOWN_KEYS_IGNORED}: {', '.join(unknown)}")

        payload = obj.get("response")
        if not isinstance(payload, dict):
            raise ContractProblem(
                R_SCHEMA_ERROR,
                "missing or malformed field response (must be an object)",
            )

        unknown_resp = sorted(
            set(payload)
            - {
                "incident_summary",
                "findings",
                "possible_causes",
                "missing_evidence",
                "diagnostic_questions",
                "proposed_remediation",
                "uncertainties",
            }
        )
        if unknown_resp:
            notes.append(
                f"{N_UNKNOWN_KEYS_IGNORED}: response.{', response.'.join(unknown_resp)}"
            )

        for key in (
            "incident_summary",
            "findings",
            "possible_causes",
            "missing_evidence",
            "diagnostic_questions",
            "uncertainties",
            "proposed_remediation",
        ):
            if key not in payload:
                raise ContractProblem(R_SCHEMA_ERROR, f"missing field response.{key}")

        summary = payload["incident_summary"]
        if not isinstance(summary, str) or len(summary) > INCIDENT_SUMMARY_MAX_CHARS:
            raise ContractProblem(
                R_SCHEMA_ERROR,
                f"response.incident_summary must be a string ≤ "
                f"{INCIDENT_SUMMARY_MAX_CHARS} chars",
            )

        _validate_findings(payload["findings"], registry)
        for name in (
            "possible_causes",
            "missing_evidence",
            "diagnostic_questions",
            "uncertainties",
        ):
            _validate_str_list(payload[name], name)

        remediation = _validate_remediation(
            payload["proposed_remediation"], registry, notes
        )

        if remediation.get("__absent__"):
            decision = guidance_decision(
                "rd-1",
                None,
                None,
                STATUS_ANALYSIS_UNVERIFIED,
                ["NO_REMEDIATION_PROPOSED"],
                [N_MODEL_PROSE_NOT_OPERATIONAL, *notes],
            )
            return {
                "decision": decision,
                "problems": [],
                "reason_code": R_OK,
                "remediation": None,
                "analysis_ok": True,
                "notes": notes,
            }

        decision = guidance_decision(
            "rd-1",
            remediation["target_ref"],
            remediation["guidance_code"],
            STATUS_GUIDANCE_VALIDATED,
            [R_OK],
            [N_MODEL_PROSE_NOT_OPERATIONAL, *notes],
        )
        return {
            "decision": decision,
            "problems": [],
            "reason_code": R_OK,
            "remediation": remediation,
            "analysis_ok": True,
            "notes": notes,
        }

    except ContractProblem as problem:
        problems.append(problem.message)
        reason_code = problem.reason_code
        decision = guidance_decision(
            "rd-1", None, None, STATUS_REJECTED, [reason_code], [*problems, *notes]
        )
        return {
            "decision": decision,
            "problems": problems,
            "reason_code": reason_code,
            "remediation": None,
            "analysis_ok": False,
            "notes": notes,
        }
