#!/usr/bin/env python3
"""Typed vocabulary and result shapes for Phase 1 runtime discovery.

Source of truth: docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md
- §8.1 taxonomy (transport / identity dimensions / runtime domains)
- §8.2 verification outcome model + closed reason-code vocabulary
- §8.3 discovery algorithm (ordered steps)
- §8.4 cgroup parser rules
- §8.5 DiscoveryResult shape (typed dict, illustrative field list)

All statuses/reasons are plain strings (JSON-serializable); no numeric
"confidence" anywhere (numeric confidence is rejected by §8.5).
"""

from __future__ import annotations

from typing import Any, TypedDict

# ── §8.1-A: event transport (from the trusted _TRANSPORT field) ────────────
TRANSPORT_KERNEL = "KERNEL"
TRANSPORT_AUDIT = "AUDIT"
TRANSPORT_DRIVER = "DRIVER"
TRANSPORT_STDOUT_STDERR = "STDOUT_STDERR"
TRANSPORT_SYSLOG = "SYSLOG"
TRANSPORT_JOURNAL_NATIVE = "JOURNAL_NATIVE"
TRANSPORT_UNKNOWN = "UNKNOWN"

# ── §8.1-C: runtime domains (claimed only on a process entity; never a
#    bare top-level field on the result — §8.5) ─────────────────────────────
DOMAIN_HOST_SYSTEMD = "HOST_SYSTEMD"
DOMAIN_HOST_SESSION = "HOST_SESSION"
DOMAIN_PODMAN_CONTAINER = "PODMAN_CONTAINER"
DOMAIN_DOCKER_CONTAINER = "DOCKER_CONTAINER"
DOMAIN_FLATPAK = "FLATPAK"
DOMAIN_NOT_APPLICABLE = "NOT_APPLICABLE"
DOMAIN_UNKNOWN = "UNKNOWN"

# ── §8.2: verification statuses (claim-scoped) ─────────────────────────────
STATUS_EVENT_TIME_ATTESTED = "EVENT_TIME_ATTESTED"
STATUS_CURRENT_RUNTIME_VERIFIED = "CURRENT_RUNTIME_VERIFIED"
STATUS_VERIFIED = "VERIFIED"
STATUS_AMBIGUOUS = "AMBIGUOUS"
STATUS_UNAVAILABLE = "UNAVAILABLE"

# ── time scopes (kept explicit on every claim — §8.2 time-scope rule) ─────
SCOPE_EVENT_TIME_ASSOCIATION = "event_time_association"
SCOPE_CURRENT_STATE = "current_state"

# ── §8.1-B: sender roles ---------------------------------------------------
ROLE_WORKLOAD_APPEARANCE = "WORKLOAD_APPEARANCE"
ROLE_CONMON = "CONMON"
ROLE_STREAM_OWNER = "STREAM_OWNER"
ROLE_UNKNOWN = "UNKNOWN"

# ── record scope (system vs user manager — §8.3 step 3, §16.1 row 20) ─────
SCOPE_SYSTEM = "SYSTEM"
SCOPE_USER = "USER"
SCOPE_UNKNOWN = "UNKNOWN"

# ── §8.3 step 4: qualification outcomes ------------------------------------
QUAL_OUTCOME_COMPATIBLE = "COMPATIBLE"
QUAL_OUTCOME_STALE = "STALE_CURRENT_INSTANCE"
QUAL_OUTCOME_GONE = "GONE"
QUAL_OUTCOME_UNSAFE_SKIP = "UNSAFE_SKIP"

# ── §8.2: closed failure/vocabulary reason codes ──────────────────────────
REASON_EVIDENCE_CONFLICT = "EVIDENCE_CONFLICT"
REASON_PID_EXITED = "PID_EXITED"
REASON_PID_REUSED = "PID_REUSED"
REASON_STALE_CURRENT_INSTANCE = "STALE_CURRENT_INSTANCE"
REASON_PID_NOT_FOUND = "PID_NOT_FOUND"
REASON_HISTORICAL_IDENTITY_UNAVAILABLE = "HISTORICAL_IDENTITY_UNAVAILABLE"
REASON_PERMISSION_DENIED = "PERMISSION_DENIED"
REASON_WRONG_RUNTIME_CONTEXT = "WRONG_RUNTIME_CONTEXT"
REASON_RUNTIME_UNAVAILABLE = "RUNTIME_UNAVAILABLE"
REASON_NOT_FOUND = "NOT_FOUND"
REASON_TIMEOUT = "TIMEOUT"
REASON_INVALID_DATA = "INVALID_DATA"
REASON_UNSUPPORTED_RUNTIME = "UNSUPPORTED_RUNTIME"
REASON_STALE_EVIDENCE = "STALE_EVIDENCE"
REASON_INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"

REASON_CODES = frozenset(
    {
        REASON_EVIDENCE_CONFLICT,
        REASON_PID_EXITED,
        REASON_PID_REUSED,
        REASON_STALE_CURRENT_INSTANCE,
        REASON_PID_NOT_FOUND,
        REASON_HISTORICAL_IDENTITY_UNAVAILABLE,
        REASON_PERMISSION_DENIED,
        REASON_WRONG_RUNTIME_CONTEXT,
        REASON_RUNTIME_UNAVAILABLE,
        REASON_NOT_FOUND,
        REASON_TIMEOUT,
        REASON_INVALID_DATA,
        REASON_UNSUPPORTED_RUNTIME,
        REASON_STALE_EVIDENCE,
        REASON_INSUFFICIENT_EVIDENCE,
    }
)

# ── provenance / capture markers (§8.1-B correction 2) ────────────────────
PROVENANCE_JOURNAL_TRUSTED = "journal_trusted_fields"
PROVENANCE_PROC_SNAPSHOT = "proc_snapshot"
PROVENANCE_RUNTIME_QUERY = "runtime_query"
CAPTURED_EVENT_TIME = "event_time"
CAPTURED_CURRENT = "present_day"

# ── evidence strengths / origins (§8.5 evidence[] items) ──────────────────
STRENGTH_TRUSTED_ATTESTATION = "trusted_attestation"
STRENGTH_PRESENT_STATE = "present_state_sample"
STRENGTH_VERIFIED_CROSS_CHECK = "verified_cross_check"
STRENGTH_CONFLICT = "conflict"
STRENGTH_UNTRUSTED_CONTENT = "untrusted_content"
ORIGIN_JOURNAL_RECORD = "journal_record"
ORIGIN_PROC_SNAPSHOT = "proc_snapshot"
ORIGIN_RUNTIME_QUERY = "runtime_query"

# ── §8.3 step 1: audit identity sources ───────────────────────────────────
AUDIT_SOURCE_TRUSTED_FIELDS = "trusted_audit_fields"
AUDIT_SOURCE_CONTENT_HINTS = "content_derived_hints"
SOURCE_OBJECT_FIELDS = "object_fields"

# subject disposition when no subject is described (kernel/audit-no-identity)
SUBJECT_DISPOSITION_NOT_APPLICABLE = "NOT_APPLICABLE"


class EvidenceItem(TypedDict, total=False):
    origin: str
    strength: str
    captured_at: float
    time_scope: str
    provenance_note: str


class CgroupObservation(TypedDict, total=False):
    """Journal-side event-time cgroup observation (§8.1-B correction 2)."""

    path: str
    provenance: str
    captured: str
    scope: str
    domain_candidates: list[str]
    container_ids: list[str]
    container_id_kinds: dict[str, str]
    note: str
    reason_codes: list[str]


class CurrentProcCgroup(TypedDict, total=False):
    """Present-day /proc observation; never event-time evidence (§8.3 step 2)."""

    captured_at: float
    provenance: str
    path: Any
    memberships: list[dict[str, Any]]
    cgroup_format: str
    removed_cgroup: bool
    pid_present_at_capture: bool
    reason_codes: list[str]


class EntityClaim(TypedDict, total=False):
    """record_sender / referenced_subject shapes (§8.1-B, §8.5)."""

    pid: int
    uid: int
    gid: int
    comm: str
    exe: str
    unit: str
    user_unit: str
    unit_scope: str
    role: str
    role_candidate: str
    runtime_domain: str
    status: str
    time_scope: str
    reason_codes: list[str]
    identity_source: str
    login_uid: int
    audit_session: int
    untrusted_hints: dict[str, Any]
    claimed: dict[str, str]


class ProcQualification(TypedDict, total=False):
    """§8.3 step 4 outcome object (§8.5)."""

    pid: int
    event_boot_id: str
    event_monotonic_us: int
    event_monotonic_ticks: float
    compared: bool
    outcome: str
    proc_start_ticks: int
    tick_rate: int
    ns_pid_depth: list[int]
    reason_codes: list[str]


class DomainClaim(TypedDict, total=False):
    """current_process_domain / event_time_unit_claim shapes (§8.5)."""

    unit: str
    unit_field: str
    scope: str
    domain: str
    cgroup_suffix: str
    status: str
    time_scope: str
    reason_codes: list[str]
    captured_at: float
    candidate: str


class ContainerAssociation(TypedDict, total=False):
    """Container-association claim — independent of identity (§8.1-B)."""

    source: str
    runtime: str
    full_id: str
    name: str
    image: str
    state: str
    status: str
    time_scope: str
    reason_codes: list[str]
    captured_at: float
    evidence_refs: list[str]


class ConmonRecord(TypedDict, total=False):
    """conmon role record — asserted ONLY on exact runtime PID mapping."""

    pid: int
    status: str
    source: str


class WorkloadIdentity(TypedDict, total=False):
    state: str
    reason_codes: list[str]
    note: str


class DiscoveryResult(TypedDict, total=False):
    """§8.5 result shape (illustrative field list, implemented)."""

    event_ref: str
    event_transport: str
    event_monotonic_us: int
    record_sender: EntityClaim
    referenced_subject: EntityClaim
    subject_disposition: str
    event_sender_cgroup: CgroupObservation
    event_subject_cgroup: CgroupObservation
    current_proc_cgroup: CurrentProcCgroup
    proc_qualification: ProcQualification
    current_process_domain: DomainClaim
    event_time_unit_claim: DomainClaim
    event_subject_unit_claim: DomainClaim
    container_association: ContainerAssociation
    conmon: ConmonRecord
    workload_identity: WorkloadIdentity
    evidence: list[EvidenceItem]
    missing_evidence: list[str]
    limits_note: list[str]
