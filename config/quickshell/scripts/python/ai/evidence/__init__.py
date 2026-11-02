"""Evidence layer (Phase 1+): runtime discovery and typed result models.

Phase 1 scope (plan §7 C2 / §8 / §16.1):
- ``discovery.py`` — deterministic runtime discovery, no LLM, injectable Runner.
- ``models.py``    — closed vocabularies (statuses/domains/reasons) + result shapes.

Phase 2 additions (plan §7 C1/C4 / §10.6 / §14 / §16.2):
- ``journal_collector.py`` — bounded ``journalctl`` fetch at the ``-p warning``
  boundary, opaque-cursor continuation with explicit boot/rotation fallback,
  dedup + counters, size caps.
- ``redact.py`` — mandatory pre-send scrubbing (deny-list rules, counts only;
  env default-deny; cmdline token hygiene).

Additive only; nothing in this package is imported by existing callers except
``config.get_boot_incident()`` (lazy, flag-gated, fail-closed — §18 Phase 2).
"""
