#!/usr/bin/env python3
"""C4 Redaction layer — mandatory PRE-SEND scrubbing (§7 C4, §14).

Outputs: redacted text/mapping + rule-counts ONLY. Raw secret matches are
never stored, logged, hashed into fixtures, or returned in any form.

Rules (deny-list regex set, plan §14 list):
  * ``url-credentials``    — ``scheme://user:pass@`` (scheme kept, creds dropped)
  * ``bearer-token``       — ``Authorization: Bearer <token>`` style values
  * ``jwt``                — three-segment JWTs
  * ``aws-key``            — ``AKIA…`` access key ids
  * ``slack-token``        — ``xoxa/b/p/r/s-…`` tokens
  * ``openai-key``         — ``sk-…`` style API keys
  * ``google-key``         — ``gapi_…`` style keys
  * ``assignment-secret``  — ``password=…`` / ``secret=…`` env-like values
  * ``pem-private-key``    — whole PEM private-key bodies

Section-level drop (preferred over fuzzy masking for non-targeted fields):
  * ``redact_environment()`` — env VALUES *and* NAMES default-deny (§14);
    no ``/proc/<pid>/environ`` read happens anywhere in this layer.

Counting rule: counts only — a rule hit produces a replacement whose content
is fixed combinatorial text, never a capture of the matched secret.
"""

from __future__ import annotations

import re
from typing import Callable, Pattern

_RULES: tuple[tuple[str, str, str | Callable], ...] = (
    (
        # bounded char windows keep this rule linear on long noisy input —
        # the unbounded version catastrophically backtracked (§16.2 row:
        # “1 MB MESSAGE → truncate + hash; no crash”)
        "url-credentials",
        r"([A-Za-z][A-Za-z0-9+.\-]{0,31}://)"
        r"[^/\s:@]{1,64}:[^@\s/]{1,1024}@",
        r"\1<redacted-credentials>@",
    ),
    ("bearer-token", r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{8,}", "Bearer <redacted>"),
    (
        "jwt",
        r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}\b",
        "<redacted-jwt>",
    ),
    ("aws-key", r"\bAKIA[0-9A-Z]{16}\b", "<redacted-aws-key>"),
    ("slack-token", r"\bxox[a-z]-[0-9A-Za-z\-]{10,}\b", "<redacted-slack-token>"),
    ("openai-key", r"\bsk-[A-Za-z0-9]{16,}\b", "<redacted-api-key>"),
    ("google-key", r"\bgapi_[A-Za-z0-9_\-]{20,}\b", "<redacted-google-key>"),
)

_RE_ASSIGNMENT_SECRET = re.compile(
    # suffix/prefix-tolerant: matches ANOTHER_TOKEN=…, SECRET_KEY=… etc.
    # (\b cannot see inside compound identifiers built from word chars)
    r"(?i)\b[\w\-]*(password|passwd|secret|api_?key|token|client_secret|"
    r"access_token|auth)[\w\-]*\b[ \t]*[=:][ \t]*(\S+)"
)
_RE_PEM = re.compile(
    r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?"
    r"-----END [A-Z0-9 ]*PRIVATE KEY-----",
)


def redact_text(text: str) -> tuple[str, dict[str, int]]:
    """Scrub one text blob; return (redacted_text, {rule_id: occurrences})."""
    if not isinstance(text, str):
        # redaction is hygiene for text bodies; non-str callers are a caller
        # bug surfaced loudly (never silently coerced)
        raise TypeError("redact_text expects str")

    counts: dict[str, int] = {}

    # PEM composite first: one body, never fragmented line-by-line
    body, n_pem = _RE_PEM.subn("<redacted-pem-private-key>", text)
    if n_pem:
        counts["pem-private-key"] = counts.get("pem-private-key", 0) + n_pem
        text = body

    for rule_id, source, replacement in _RULES:
        pattern: Pattern[str] = re.compile(source)
        new_text = pattern.sub(replacement, text)
        if new_text != text:
            counts[rule_id] = counts.get(rule_id, 0) + len(pattern.findall(text))
            text = new_text

    text, n_assign = _RE_ASSIGNMENT_SECRET.subn(
        lambda mtch: f"{mtch.group(1).lower()}=<redacted>", text
    )
    if n_assign:
        counts["assignment-secret"] = counts.get("assignment-secret", 0) + n_assign

    return text, counts


def redact_environment(
    env: dict | None, allowlist: frozenset | None = None
) -> tuple[dict, dict[str, int]]:
    """§14 default-deny: env VALUES *and* NAMES never enter context.

    Release 1 refuses every non-empty allowlist HERE (plan: an allowlist must
    first be configured *and validated in backend code* — that backend
    validation is not part of this layer; a refusal is fail-closed).
    A dropped mapping keeps only the count.
    """
    if allowlist is None:
        allowlist = frozenset()
    if allowlist:
        raise ValueError(
            "env allowlist requires backend validation before any redaction "
            "(§14) — refused at the redaction layer in R1"
        )
    if env:
        return {}, {"env-dropped": 1}
    return {}, {}


def redact_cmdline(cmdline: str | list) -> tuple[list[str], dict[str, int]]:
    """cmdline hygiene (§14: cmdline may contain user text) — token-level."""
    counts: dict[str, int] = {}
    if isinstance(cmdline, str):
        tokens = cmdline.split("\x00") if "\x00" in cmdline else cmdline.split()
    elif isinstance(cmdline, (list, tuple)):
        tokens = [str(token) for token in cmdline]
    else:
        tokens = []

    redacted_tokens: list[str] = []
    for token in tokens:
        clean, token_counts = redact_text(token)
        redacted_tokens.append(clean)
        for rule, n in token_counts.items():
            counts[rule] = counts.get(rule, 0) + n
    return redacted_tokens, counts
