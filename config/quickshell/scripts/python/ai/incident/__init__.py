"""Canonical incident schema (Phase 2, plan §9) — ``nibras.incident/v1``.

``normalizer.py`` turns ONE journal record + its §8.5 discovery result into
a versioned, redaction-aware typed envelope:
single canonical ``source`` (cursor verbatim, monotonic preserved), redacted
bounded ``event`` text + correlation hash, sender/subject kept separate, the
three cgroup dimensions never merged, an opaque backend-issued container
reference, the evidence ledger with ids, honest ``missing_evidence``, the
survey snapshot and redaction counts.

Nothing here is imported by existing callers yet (§18); prompts are not
modified this phase — the incident is data for Phase 3 planning/orchestration.
"""
