#!/usr/bin/env python3
"""policy/engine.py — deterministic policy (Phase 4, §11.1–§11.3, AC #2/#5/#16).

Two validation paths, each with its own artifact-scoped decision record
(§11.3 rule 6 — never one global status per response):

- ``evaluate_tool_request(payload, registry)`` → the bounded read-only
  execution gate; status ``TOOL_REQUEST_ALLOWED | POLICY_REJECTED`` per
  request artifact (id = the request's ``request_id``).
- ``evaluate_diagnosis(payload, registry, incident)`` → the declarative
  advice gate; one record for the remediation proposal
  (``proposal_id="rd-1"``) with status
  ``GUIDANCE_VALIDATED | POLICY_REJECTED | ANALYSIS_UNVERIFIED``.

Policy layers added ON TOP of the Phase-3 contract validation (first
mismatch rejects; the contract's structural/reason codes are reused
verbatim so Phase-3 behavior is stable):

1. §11.2 event-transport gate — Phase 4.1 default-deny: only the stdout/
   stderr family, syslog and journal-native records may reach target advice.
   KERNEL/DRIVER never carry a usable subject; AUDIT subject mapping is an
   explicit R1 uncertainty (§8.1-A) — neither ``_AUDIT_LOGINUID``/
   ``_AUDIT_SESSION`` nor body text is a verified basis; UNKNOWN/missing
   values fail closed. No unrelated verified record elsewhere in the
   incident can unlock a non-targetable transport. Refusal uses
   ``event_not_targetable`` and reduces the response to labeled explanation.
2. §11.2 registry-wide unresolved-evidence gate (unknown/ambiguous/
   conflicting/stale/… statuses) — recorded verbatim by the incident, never
   upgraded. Target-carrying advice is refused with
   ``target_evidence_unresolved`` and ALSO reduced to labeled explanation.
3. §11.1 per-template minimum-evidence checks (verified association +
   recorded time scope for the container template; explicitly attached
   event-time/current-state status + resolved manager scope for the unit
   template; null binding plus §11.2 routing for the update-review template).
4. Phase 4.1 evidence-to-target linkage — a target's recorded time-scope
   family must have a backing item in THIS incident's backend ledger; a
   verified record for another dimension, a model assertion or a missing
   file elsewhere never authorizes the proposed target (``evidence_not_linked``).
5. Backend template rendering ACROSS the closed registry: model prose is
   never interpolated; the operational text is the backend's own.

Guarantees (AC #16): the status vocabulary is exactly the closed set and no
status implies that any remediation was executed. The engine is standalone
in Phase 4; the production path wires it at Phase 5 (§18) — the Phase-3
orchestrator flow is unchanged until then.
"""

from __future__ import annotations

from typing import Any

try:  # package layout (scripts/python on sys.path)
    from ..agent import contract as _contract
    from . import guidance_templates as _templates
except ImportError:  # flat layout (cwd=scripts/python/ai)
    import agent.contract as _contract  # type: ignore[no-redef]
    import policy.guidance_templates as _templates  # type: ignore[no-redef]

# closed status vocabulary (§11.3-6 / AC #16 — reused from the contract
# module so there is exactly one source of truth for the literals)
S_TOOL_ALLOWED = _contract.STATUS_TOOL_ALLOWED  # TOOL_REQUEST_ALLOWED
S_POLICY_REJECTED = _contract.STATUS_REJECTED  # POLICY_REJECTED
S_GUIDANCE_VALIDATED = _contract.STATUS_GUIDANCE_VALIDATED
S_ANALYSIS_UNVERIFIED = _contract.STATUS_ANALYSIS_UNVERIFIED

# §11.3-3 — statuses that block target-specific mutation (they permit
# declarative manual_guidance only where the per-template evidence gates
# independently pass). The full bidirectional matrix remains Phase-4 policy;
# the contract keeps its own minimal Phase-3 subset.
BLOCKING_STATUSES = _contract.UNRESOLVED_EVIDENCE_STATUSES

# Phase 4.1 DEFAULT-DENY (§8.1-A / §11.2): only these transports may reach
# target-carrying advice. KERNEL/DRIVER records carry no usable process
# subject; AUDIT has no supported subject mapping in R1 (neither
# ``_AUDIT_LOGINUID``/``_AUDIT_SESSION`` nor body text establishes the
# audited subject); UNKNOWN/missing/unrecognized values fail closed. The
# registry is deliberately NOT consulted — a trusted record elsewhere in
# the incident never converts a non-targetable event into a targetable one.
_TARGETABLE_TRANSPORTS = frozenset({"STDOUT_STDERR", "SYSLOG", "JOURNAL_NATIVE"})
_TRANSPORT_ALIASES = {"STDOUT/STDERR": "STDOUT_STDERR"}

# reason codes (reused from the contract where shared; policy-only ones
# carry an `event_not_targetable`-style name and never collide with the
# contract's set)
R_EVENT_NOT_TARGETABLE = "event_not_targetable"
# Phase 4.1: the target's own time-scope family has no backing item in this
# incident's backend ledger — evidence for another dimension (or a model
# assertion) does not authorize the proposed target.
R_EVIDENCE_NOT_LINKED = "evidence_not_linked"
REDUCTION_NOTE = (
    "target-carrying advice refused by policy; the response is reduced to "
    "labeled explanation only (no actionable content)"
)


def evaluate_tool_request(payload: Any, registry: Any) -> dict[str, Any]:
    """Policy wrapper for one ``nibras.tool_request/v1`` artifact (§11.3-6).

    The Phase-3 contract already performs allowlist, typed-args, opaque-ref,
    widening and cursor rules (§11.3 rules 1–4); the engine re-emits the
    SAME artifact-scoped decision with the closed-vocabulary status, so a
    tool decision can never color a guidance decision (separate records).
    """
    return _contract.validate_tool_request(payload, registry)


def _transport_of(incident: dict) -> str:
    source = incident.get("source")
    value = source.get("event_transport") if isinstance(source, dict) else None
    if not isinstance(value, str):
        return ""
    normalized = value.strip().upper()
    return _TRANSPORT_ALIASES.get(normalized, normalized)


def _event_gate(incident: dict) -> tuple[bool, list[str]]:
    """§11.2 transport rows — Phase 4.1 default-deny (§8.1-A).

    Target-carrying advice requires a transport whose records can carry a
    subject identity in R1. KERNEL/DRIVER never do; AUDIT has no supported
    subject mapping (``_AUDIT_LOGINUID``/``_AUDIT_SESSION`` and body text are
    not a verified basis), so audit interaction stays read-only; UNKNOWN,
    missing or unrecognized values fail closed. The registry is NOT
    consulted: a trusted record elsewhere in the incident must not unlock
    target advice for a non-targetable event.

    Returns (target_advice_allowed, notes).
    """
    transport = _transport_of(incident)
    if transport in _TARGETABLE_TRANSPORTS:
        return True, [f"transport {transport}: per-template evidence gates apply"]
    return False, [
        f"transport {transport or '<missing>'!r} is not targetable in Release 1 "
        "(§11.2 / §8.1-A): read-only evidence and labeled explanation only"
    ]


def _record_with_ref(registry: Any, ref: str, incident: dict) -> dict[str, Any] | None:
    """Resolve a model-quoted ref through the backend registry ONLY and
    inject the echo-safe identity: the template's ``target_ref`` field
    carries the opaque ref itself, never raw ids (registry records never
    carry their own key). Container display facts (name/image/runtime) are
    copied from the incident's backend association block — backend-recorded
    data the response already shows, never model text."""
    record = registry.lookup(ref)
    if record is None:
        return None
    injected = dict(record)
    injected["_opaque_ref"] = ref
    if record.get("kind") == "container":
        association = incident.get("container_association")
        if isinstance(association, dict) and association.get("ref") == ref:
            for key in ("runtime", "name", "image"):
                value = association.get(key)
                if isinstance(value, str) and value:
                    injected.setdefault(key, value)
    return injected


# §8.5 time-scope families: an event-time record can only be linked to an
# event-time ledger item; a current-state record only to current-state
# evidence. This is the smallest backend-derivable relationship — the model
# never supplies it (``findings[].evidence_refs`` is display-only prose).
_CURRENT_STATE_SCOPES = frozenset({"current_state", "current_runtime"})


def _time_family(scope: Any) -> str:
    if not isinstance(scope, str):
        return ""
    value = scope.strip().lower()
    if value.startswith("event_time"):
        return "event_time"
    if value in _CURRENT_STATE_SCOPES or value.startswith("current_runtime"):
        return "current_state"
    return ""


def _linked_evidence_ids(record: dict[str, Any], incident: dict) -> list[str]:
    """Evidence ids from THIS incident's backend ledger that share the
    target record's time-scope family (§8.5).

    A target whose family has no ledger item has no supporting evidence
    entry: a verified record for another dimension elsewhere in the incident
    is not linkage, and a model-cited ref is never consulted here.
    """
    family = _time_family(record.get("time_scope"))
    ledger = incident.get("evidence_refs")
    if not family or not isinstance(ledger, list):
        return []
    linked: list[str] = []
    for item in ledger:
        if (
            isinstance(item, dict)
            and isinstance(item.get("id"), str)
            and _time_family(item.get("time_scope")) == family
        ):
            linked.append(item["id"])
    return linked


def evaluate_diagnosis(payload: Any, registry: Any, incident: dict) -> dict[str, Any]:
    """Full policy evaluation for one ``nibras.diagnosis/v1`` payload.

    Returns ``{"status", "decision", "template", "analysis"}`` where
    ``analysis`` is the Phase-3 contract result (composable), ``decision``
    is the artifact-scoped guidance record and ``template`` is the
    backend-rendered payload (None unless ``GUIDANCE_VALIDATED``).
    """
    analysis = _contract.validate_diagnosis(payload, registry)
    notes: list[str] = list(analysis.get("notes") or [])

    # 1. first structural mismatch → the record the CONTRACT produced
    #    (unknown guidance code, invented refs, prohibited keys, kind)
    if not analysis["analysis_ok"]:
        decision = analysis["decision"]
        if analysis.get("reason_code") == _contract.R_TARGET_EVIDENCE_UNRESOLVED:
            # §11.2 conflicting/stale rows: the contract refused target
            # advice — the phase-4 label marks the refusal as ALSO reducing
            # the response to labeled explanation (statuses never upgraded)
            decision = dict(decision)
            decision["details"] = [
                *(decision.get("details") or []),
                REDUCTION_NOTE,
            ]
        return {
            "status": S_POLICY_REJECTED,
            "decision": decision,
            "template": None,
            "analysis": analysis,
        }

    remediation = analysis.get("remediation")
    # 2. no proposal → §11.3-6 analysis-only truth: ANALYSIS_UNVERIFIED for
    #    the retained model-authored explanatory content, never operational
    if remediation is None:
        return {
            "status": S_ANALYSIS_UNVERIFIED,
            "decision": analysis["decision"],
            "template": None,
            "analysis": analysis,
        }

    code = remediation["guidance_code"]
    target_ref = remediation.get("target_ref")

    allowed_kinds, evidence_gate = _templates.requirements(code)  # registered ✓

    # 3. §11.2 event gate (kernel / driver / audit-without-trusted-identity).
    #    G_EXPLAIN_ONLY bypasses it on purpose: "explain uncertainty" is
    #    exactly the §11.2 treatment on those transports (labeled
    #    explanation, no target, no operational content).
    if code == "G_EXPLAIN_ONLY":
        gate_ok, gate_notes = (
            True,
            [
                "explain_only binds no target; §11.2 keeps labeled explanation "
                "available on every transport"
            ],
        )
    else:
        gate_ok, gate_notes = _event_gate(incident)
    notes.extend(gate_notes)
    if not gate_ok:
        notes.append(REDUCTION_NOTE)
        decision = _contract.guidance_decision(
            "rd-1",
            target_ref,
            code,
            S_POLICY_REJECTED,
            [R_EVENT_NOT_TARGETABLE],
            notes,
        )
        return {
            "status": S_POLICY_REJECTED,
            "decision": decision,
            "template": None,
            "analysis": analysis,
        }

    record: dict[str, Any] | None = None
    if target_ref is not None:
        record = _record_with_ref(registry, target_ref, incident)
        unresolved = sorted(set(registry.unresolved_statuses()))
        if unresolved:
            # §11.2 unknown/ambiguous/conflicting/stale rows (registry-wide;
            # statuses verbatim, never upgraded) + labeled-explanation
            notes.append(
                f"incident evidence records unresolved state(s) {unresolved} "
                "(statuses verbatim, never upgraded)"
            )
            notes.append(REDUCTION_NOTE)
            decision = _contract.guidance_decision(
                "rd-1",
                target_ref,
                code,
                S_POLICY_REJECTED,
                [_contract.R_TARGET_EVIDENCE_UNRESOLVED],
                notes,
            )
            return {
                "status": S_POLICY_REJECTED,
                "decision": decision,
                "template": None,
                "analysis": analysis,
            }

    # 4. §11.1 per-template minimum-evidence checks
    refusals = list(evidence_gate(record, incident, registry))
    if refusals:
        notes.extend(refusals)
        notes.append(REDUCTION_NOTE)
        decision = _contract.guidance_decision(
            "rd-1",
            target_ref,
            code,
            S_POLICY_REJECTED,
            [_contract.R_TARGET_EVIDENCE_UNRESOLVED],
            notes,
        )
        return {
            "status": S_POLICY_REJECTED,
            "decision": decision,
            "template": None,
            "analysis": analysis,
        }

    # 4b. Phase 4.1 evidence-to-target linkage: the target's own time-scope
    #     family must have a backing item in THIS incident's backend ledger.
    #     A verified record for another dimension, a model assertion or a
    #     missing file elsewhere never authorizes the proposed target.
    if target_ref is not None:
        scope = record.get("time_scope") if record else None
        if not _linked_evidence_ids(record or {}, incident):
            notes.append(
                "no incident evidence item is linked to this target's "
                f"recorded time scope {scope!r}; a verified record for "
                "another dimension does not authorize it"
            )
            notes.append(REDUCTION_NOTE)
            decision = _contract.guidance_decision(
                "rd-1",
                target_ref,
                code,
                S_POLICY_REJECTED,
                [R_EVIDENCE_NOT_LINKED],
                notes,
            )
            return {
                "status": S_POLICY_REJECTED,
                "decision": decision,
                "template": None,
                "analysis": analysis,
            }

    # 5. backend rendering — the ONLY path that produces operational text
    template = _templates.render(code, record, incident, registry)
    decision = _contract.guidance_decision(
        "rd-1",
        target_ref,
        code,
        S_GUIDANCE_VALIDATED,
        [_contract.R_OK],
        [
            _contract.N_MODEL_PROSE_NOT_OPERATIONAL,
            "template rendered from the backend-owned registry "
            f"({_templates.TEMPLATE_VERSION}); artifact-scoped",
            *notes,
        ],
    )
    return {
        "status": S_GUIDANCE_VALIDATED,
        "decision": decision,
        "template": template,
        "analysis": analysis,
    }
