#!/usr/bin/env python3
"""ai/policy — Release-1 deterministic policy package (Phase 4, §11, row 4).

Contents:
- ``guidance_templates`` — the closed backend-owned ``G_*`` template registry
  (§11.1): per-template declared target kinds / minimum evidence / exact
  backend-authored text. Model text is never interpolated into it.
- ``engine`` — two validation paths (§11.3 rule 6): ``tool_request`` gating and
  ``proposed_remediation`` gating; the §11.2 domain×action matrix; per-template
  minimum-evidence checks; backend template rendering. Decision statuses come
  from the closed vocabulary only
  (``TOOL_REQUEST_ALLOWED`` / ``GUIDANCE_VALIDATED`` / ``POLICY_REJECTED`` /
  ``ANALYSIS_UNVERIFIED``) and never imply that any remediation was executed.

The engine is standalone in Phase 4 (its full §16.3/AC matrix is verified by
``tests/test_phase4_policy.py``); the production path wires it at Phase 5, so
the Phase-3 orchestrator behavior remains byte-identical until then (§18).
"""
