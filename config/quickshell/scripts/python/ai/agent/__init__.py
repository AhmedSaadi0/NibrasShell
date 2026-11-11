"""Agent package (Phase 3, plan §7 C6 / §10 / §11) — bounded orchestration.

Phase 3 scope (plan §18 row 3, gated by ``--orchestrator v2`` — default OFF):

- ``contract.py``     — strict model-output contracts (``nibras.tool_request/v1``,
                        ``nibras.diagnosis/v1``), the backend-side opaque-ref
                        registry built from the incident, the ordered validator
                        rule set (§11.3) and artifact-specific decision records,
                        bounded JSON parsing, ``<incident>``/``<tool_output>``
                        demarcation neutralization (§10.5).
- ``tools.py``        — the four read-only inspection tools with fixed argv
                        builders, typed arguments, subprocess deadline/
                        termination (5 s, SIGTERM→SIGKILL ≤1 s, 1 MiB cap),
                        §14 redaction, and typed reason codes (§10.6, §10.3).
- ``orchestrator.py`` — call-role state machine (A/B evidence turns, C final
                        diagnosis, D ≤1 forced repair, ≤4 model calls), the
                        per-request 120 s wall-clock supervisor, the 300 s
                        incident watchdog, output-size budgets, and the
                        guaranteed safe-failure response (§10.2-B, §10.3).
- ``prompt_agent.py`` — the dedicated agent prompt (roles, contracts, DATA
                        framing, hard rules).

Nothing here mutates the system: every tool is read-only, remediation stays
declarative, and every deadline path yields a neutral ``analysis_failure``
response rather than a partial success. Provider abstraction is untouched;
the orchestrator consumes an injectable ``model_call`` callable only.
"""

# Phase 3 marker (plan §18 row 3). Kept as a plain attribute on purpose —
# the flag ``--orchestrator v2`` is the only runtime switch.
__all__ = ["contract", "tools", "orchestrator", "prompt_agent"]
