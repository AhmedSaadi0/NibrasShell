"""Phase 5.3 — bounded credential transport over stdin.

The API credential is never placed in process arguments or the process
environment.  The parent (Quickshell ``AiTask`` or ``App`` ``Process``) writes
exactly one JSON object followed by a newline to the child's stdin:

    {"credential": "<secret-or-empty>"}

The child reads at most one bounded line before provider initialization.  A
missing, oversized, or malformed line fails closed with a typed, secret-free
error code.  This module deliberately does not log or echo the value.
"""

from __future__ import annotations

import json
import sys
from typing import Any

MAX_CREDENTIAL_BYTES = 16 * 1024
REDACTED = "[REDACTED]"


class CredentialTransportError(Exception):
    """Typed failure for an invalid one-line credential transport message."""


def read_credential(stream=None) -> str:
    """Read exactly one bounded JSON credential line from *stream*.

    ``stream`` defaults to ``sys.stdin``.  Raises ``CredentialTransportError``
    with a stable reason code; the error text never includes the input value.
    """
    stream = stream if stream is not None else sys.stdin
    try:
        line = stream.readline(MAX_CREDENTIAL_BYTES + 1)
    except (OSError, UnicodeError):
        raise CredentialTransportError(
            "CREDENTIAL_TRANSPORT_ERROR:READ_FAILED"
        ) from None

    if line == "":
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:EMPTY")
    if len(line) > MAX_CREDENTIAL_BYTES:
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:OVERSIZED")

    try:
        payload = json.loads(line)
    except Exception:  # noqa: BLE001 — never echo the raw input
        raise CredentialTransportError(
            "CREDENTIAL_TRANSPORT_ERROR:MALFORMED"
        ) from None

    if not isinstance(payload, dict) or set(payload) != {"credential"}:
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:MALFORMED")

    credential = payload["credential"]
    if not isinstance(credential, str):
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:MALFORMED")
    if "\n" in credential or "\r" in credential or "\x00" in credential:
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:MALFORMED")
    if len(credential.encode("utf-8")) > MAX_CREDENTIAL_BYTES:
        raise CredentialTransportError("CREDENTIAL_TRANSPORT_ERROR:OVERSIZED")
    return credential


def redact_secret(value: Any, secret: str | None) -> Any:
    """Replace *secret* in a string value with ``[REDACTED]``."""
    if not secret or not isinstance(value, str):
        return value
    return value.replace(secret, REDACTED)


def redact_structure(value: Any, secret: str | None) -> Any:
    """Recursively redact *secret* from a JSON-shaped structure."""
    if not secret:
        return value
    if isinstance(value, str):
        return value.replace(secret, REDACTED)
    if isinstance(value, list):
        return [redact_structure(item, secret) for item in value]
    if isinstance(value, dict):
        return {
            key: redact_structure(item, secret) for key, item in value.items()
        }
    return value
