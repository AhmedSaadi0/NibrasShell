"""Evidence layer (Phase 1+): runtime discovery and typed result models.

Phase 1 scope (plan §7 C2 / §8 / §16.1):
- ``discovery.py`` — deterministic runtime discovery, no LLM, injectable Runner.
- ``models.py``    — closed vocabularies (statuses/domains/reasons) + result shapes.

Additive only; nothing in this package is imported by existing callers yet (§18).
"""
