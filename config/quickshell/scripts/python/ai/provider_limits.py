#!/usr/bin/env python3
"""provider_limits.py — provider-side deadline constants (Phase 6, §10.3).

The orchestrator owns the independent 120 s wall-clock supervisor; these
constants are the *client-side* limits used where the native SDK/requests
API exposes them.  They are intentionally shared so the local provider does
not drift back to an unbounded single 1200 s value.

``requests`` read timeout is inter-byte inactivity, not a total wall clock
(plan §21); the orchestrator supervisor remains the total-deadline boundary.
"""

from __future__ import annotations

PROVIDER_CONNECT_TIMEOUT_S = 5.0
PROVIDER_READ_TIMEOUT_S = 60.0
PROVIDER_REQUEST_DEADLINE_S = 120.0

__all__ = [
    "PROVIDER_CONNECT_TIMEOUT_S",
    "PROVIDER_READ_TIMEOUT_S",
    "PROVIDER_REQUEST_DEADLINE_S",
]
