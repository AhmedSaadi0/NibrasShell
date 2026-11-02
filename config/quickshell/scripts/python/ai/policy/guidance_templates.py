#!/usr/bin/env python3
"""policy/guidance_templates.py — closed backend-owned G_* template registry
(Phase 4, §11.1; AC #16).

Rules baked into this module:

- The registry is **closed**: exactly the four Release-1 codes below. Any
  other ``guidance_code`` is unregistered ⇒ ``POLICY_REJECTED``
  (``unknown_guidance_code``) by the Phase-3 contract validator; the engine
  never sees it.
- Each template **declares** what it may bind and what evidence it requires
  (§11.1 "Allowed target kind" / "Minimum evidence required" columns). A
  code/target/evidence mismatch is ``POLICY_REJECTED``; a model-authored
  rationale can never relax these constraints.
- Rendering is **backend text only**. Every operational line is authored
  here; backend-recorded facts (opaque ref, unit name, container name/image,
  recorded manager scope, verbatim statuses) fill declared placeholders AFTER
  the line's safety scan — model findings/rationale prose is NEVER
  interpolated and stays labeled model-authored analysis (§10.5-B, §13).
- Release-1 posture: the authored operational text contains **no command
  strings and no executable argv shapes**, and target-carrying advice is
  scoped per §11.2 (the update-review template states no-commands
  explicitly; AC #2 asserts the absence of host-install command strings).
  Every decision stays artifact-scoped.

Capabilities explicitly **not grantable in Release 1** stay out of this
registry on purpose (§11.1 tail): ``service_control``, ``container_lifecycle``,
``recreate_container``, ``package_install``, ``file_edit``, ``host_command``.
"""

from __future__ import annotations

import re
from typing import Any, Callable

TEMPLATE_VERSION = "backend_guidance_template/v1"

# §11.1 — target-kind declarations for the closed registry. Kept IDENTICAL
# to the contract's ``GUIDANCE_TARGET_KIND`` map (single source of truth).
# Release 1 issues no ``host_package_target`` / ``container_image_target``
# references, so G_SOFTWARE_UPDATE_REVIEW binds to null and the engine routes
# its scope from the incident's *resolved claims* (§11.2 rows).
ALLOWED_TARGET_KINDS: dict[str, str | None] = {
    "G_EXPLAIN_ONLY": None,
    "G_REVIEW_CONTAINER_SOT": "container",
    "G_REVIEW_UNIT_STATE": "unit",
    "G_SOFTWARE_UPDATE_REVIEW": None,
}


# ─── minimum-evidence predicates (§11.1, third column) ───────────────────────
# Each returns refusal notes; empty ⇒ the gate passes. These consume ONLY
# backend records (registry + incident), never model text.


def _ev_none(  # noqa: ARG001 — uniform signature across templates
    record: dict[str, Any] | None, incident: dict, registry: Any
) -> list[str]:
    """G_EXPLAIN_ONLY — no evidence beyond a valid incident."""
    return []


def _ev_container_sot(
    record: dict[str, Any], _incident: dict, _registry: Any
) -> list[str]:
    refusals: list[str] = []
    status = record.get("status")
    if status not in ("VERIFIED", "CURRENT_RUNTIME_VERIFIED"):
        refusals.append(
            "template requires a verified container association; the bound "
            f"association records {status!r}"
        )
    time_scope = record.get("time_scope")
    if time_scope not in ("event_time_association", "current_state"):
        refusals.append(
            f"the association's time scope {time_scope!r} is neither a "
            "recorded event-time association nor a separately labeled "
            "current-state association"
        )
    return refusals


def _ev_unit_state(
    record: dict[str, Any], _incident: dict, _registry: Any
) -> list[str]:
    refusals: list[str] = []
    status = record.get("status")
    if status not in ("EVENT_TIME_ATTESTED", "CURRENT_RUNTIME_VERIFIED", "VERIFIED"):
        refusals.append(
            "template requires an event-time or current-state status "
            f"explicitly attached to the unit; the bound unit records {status!r}"
        )
    if record.get("scope") not in ("SYSTEM", "USER"):
        refusals.append(
            "template requires a resolved system/user manager scope; the "
            f"unit ref records {record.get('scope')!r}"
        )
    return refusals


def _ev_update_review(  # noqa: ARG001 — uniform signature
    record: dict[str, Any] | None, incident: dict, _registry: Any
) -> list[str]:
    """G_SOFTWARE_UPDATE_REVIEW — matching survey/runtime evidence for the
    exact target class. In R1 no package/image refs are issued, so null
    binding is the only form; the §11.2 event gate (engine) refuses
    non-subjectable events before this template is reachable."""
    return []


# ─── backend-recorded facts (redacted incident data, never model text) ───────


def _container_facts(record: dict[str, Any]) -> str:
    parts: list[str] = []
    runtime = record.get("runtime")
    if isinstance(runtime, str) and runtime:
        parts.append(runtime)
    name = record.get("name")
    if isinstance(name, str) and name:
        parts.append(name)
    image = record.get("image")
    if isinstance(image, str) and image:
        parts.append(image)
    return ", ".join(parts)


def _unit_facts(record: dict[str, Any]) -> str:
    unit = record.get("unit")
    scope = record.get("scope")
    return (
        f"{unit} (manager scope: {scope})"
        if isinstance(unit, str) and unit
        else "the recorded unit"
    )


# ─── authored operational skeletons (AVOID command-shaped tokens) ────────────

_LABEL = "Backend guidance"

_STATIC_LINES: dict[str, list[str]] = {
    "G_EXPLAIN_ONLY": [
        _LABEL + " (explain_only): this response explains the recorded evidence and "
        "its remaining uncertainty; it proposes no action.",
        "Any change to your system remains entirely your separate decision.",
    ],
    "G_REVIEW_CONTAINER_SOT": [
        _LABEL + " (container source-of-truth review): identify what currently "
        "creates this container before considering any recreation. Backend "
        "bound facts: {container_facts}",
        "1. Check for Quadlet definition files that create the container "
        "(the system-wide path and the per-user equivalents).",
        "2. Check for systemd units whose service definition launches the "
        "container runtime directly.",
        "3. Check for compose-style definition files in conventional "
        "project locations.",
        "4. If none of these is found, no container creation source was "
        "identified in the inspected locations — the container's source of "
        "truth remains unknown. Do not assume a manual start, and do not "
        "recommend recreation based on this absence alone.",
        "The recorded workload process identity stays independent and "
        "unverified; review stays container-scoped.",
    ],
    "G_REVIEW_UNIT_STATE": [
        _LABEL + " (unit review, manager-scoped): review the current state of "
        "{unit_facts} in the unit's own recorded manager.",
        "The event-time journal record is the trigger evidence; a "
        "current-state check describes now only, never the event.",
        "No action or service-control change is proposed by review; "
        "nothing in this guidance changes system state, and a user-scope "
        "unit never takes system-manager verbs.",
    ],
    "G_SOFTWARE_UPDATE_REVIEW": [
        _LABEL + " (software update review, {update_scope}): review the relevant "
        "update path manually, as your separate decision — this template "
        "carries no command strings.",
        "The recorded workload process identity (if any) is independent "
        "and stays unverified.",
    ],
}

# Backend-recorded FACT tokens never gate the safety scan (facts may
# legitimately contain a substring like a versioned image name); the scan
# guards the authored skeleton only.
_FORBIDDEN_SKELETON_TOKENS = (
    "dnf",
    "rpm",
    "apt ",
    "venv",
    "python3",
    "sudo",
    " restart",
    " reload",
    "systemctl",
    "podman ",
    "docker ",
    "pip ",
    "curl ",
    "wget ",
    " install ",
)
_SKELETON_RE = re.compile(
    "|".join(re.escape(token) for token in _FORBIDDEN_SKELETON_TOKENS)
)

_UPDATE_SCOPES = ("container-scoped", "host-package scoped", "generic")


def is_registered(code: str) -> bool:
    return isinstance(code, str) and code in _STATIC_LINES


def requirements(code: str) -> tuple[str | None, Callable[..., list[str]]]:
    """(allowed_target_kinds, minimum_evidence_predicate) for a registered
    code. Raises ``KeyError`` for unregistered codes (the engine maps it)."""
    if code == "G_EXPLAIN_ONLY":
        return ALLOWED_TARGET_KINDS[code], _ev_none
    if code == "G_REVIEW_CONTAINER_SOT":
        return ALLOWED_TARGET_KINDS[code], _ev_container_sot
    if code == "G_REVIEW_UNIT_STATE":
        return ALLOWED_TARGET_KINDS[code], _ev_unit_state
    if code == "G_SOFTWARE_UPDATE_REVIEW":
        return ALLOWED_TARGET_KINDS[code], _ev_update_review
    raise KeyError(code)


def _skeleton(code: str) -> list[str]:
    lines = _STATIC_LINES.get(code)
    if lines is None:
        raise KeyError(code)
    for line in lines:
        hit = _SKELETON_RE.search(line.lower())
        if hit:
            # fail loudly: a template edit introducing a command shape never
            # silently renders unsafe text (backend-invariant, §11.1)
            raise ValueError(
                f"template {code} authored line contains forbidden "
                f"command-shaped token {hit.group()!r}: {line!r}"
            )
    return list(lines)


def render(
    code: str,
    record: dict[str, Any] | None,
    incident: dict,
    registry: Any,
) -> dict[str, Any]:
    """Render one guidance payload (§11.1): the authored skeleton is scanned
    for command-shaped tokens, then backend-recorded facts fill the declared
    placeholders. Model text never enters — placeholders consume only
    backend records (opaque ref, name/image/scope facts the incident already
    carries and redaction already scrubbed)."""
    lines = _skeleton(code)
    facts: dict[str, str] = {}
    if code == "G_REVIEW_CONTAINER_SOT":
        facts["container_facts"] = (
            _container_facts(record) if isinstance(record, dict) else ""
        )
        if facts["container_facts"]:
            facts["container_facts"] = " (" + facts["container_facts"] + ")"
        else:
            facts["container_facts"] = " (backend-bound container reference on file)"
    elif code == "G_REVIEW_UNIT_STATE":
        facts["unit_facts"] = (
            _unit_facts(record) if isinstance(record, dict) else "the recorded unit"
        )
    elif code == "G_SOFTWARE_UPDATE_REVIEW":
        facts["update_scope"] = _update_scope_from_claims(incident, registry)
    try:
        filled = [line.format(**facts) for line in lines]
    except (KeyError, IndexError) as exc:  # a template's brace/placeholder bug
        raise ValueError(f"template {code} rendering invariant broken: {exc}") from exc
    return {
        "source": TEMPLATE_VERSION,
        "artifact": "proposed_remediation",
        "guidance_code": code,
        "target_ref": record.get("_opaque_ref") if isinstance(record, dict) else None,
        "lines": filled,
        "byte_limit_note": "template text is bounded and backend-authored",
    }


def _update_scope_from_claims(incident: dict, registry: Any) -> str:
    """Deterministic scope routing for the null-bound update-review template:
    from RESOLVED backend claims only (§11.2 rows), never from model text."""
    for entry in registry.refs.values():
        status = entry.get("status") if "status" in entry else entry.get("outcome")
        if status in ("VERIFIED", "CURRENT_RUNTIME_VERIFIED", "EVENT_TIME_ATTESTED"):
            if entry.get("kind") == "container":
                return _UPDATE_SCOPES[0]
            if entry.get("kind") == "unit":
                return _UPDATE_SCOPES[1]
    return _UPDATE_SCOPES[2]
