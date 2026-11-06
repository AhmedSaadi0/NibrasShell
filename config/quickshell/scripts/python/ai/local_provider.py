import sys
from typing import Any, Dict, List, Optional, Tuple

import requests
from base_provider import LLMProvider

try:  # package layout (scripts/python on sys.path)
    from .provider_limits import (
        PROVIDER_CONNECT_TIMEOUT_S,
        PROVIDER_READ_TIMEOUT_S,
    )
except ImportError:  # flat layout (cwd=scripts/python/ai)
    from provider_limits import (
        PROVIDER_CONNECT_TIMEOUT_S,
        PROVIDER_READ_TIMEOUT_S,
    )


class LocalProvider(LLMProvider):
    def generate(
        self, message: str, history: Optional[List[Dict[str, str]]] = None
    ) -> Tuple[str, Dict[str, Any]]:
        history = history or []
        messages: List[Dict[str, str]] = []

        if self.system_instruction:
            messages.append({"role": "system", "content": self.system_instruction})

        for h in history:
            messages.append(
                {
                    "role": h.get("role", "user"),
                    "content": h.get("content", ""),
                }
            )

        messages.append({"role": "user", "content": str(message)})

        payload = {
            "model": getattr(self, "model", "local-model"),
            "messages": messages,
            "temperature": getattr(self, "temperature", 0.7),
            # "top_p": 0.9,
            # "max_tokens": 4096,
            "stream": False,
        }

        base_url = getattr(self, "base_url", "http://127.0.0.1:8080")
        endpoint = f"{base_url.rstrip('/')}/v1/chat/completions"

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {getattr(self, 'api_key', 'sk-local')}",
        }

        try:
            response = requests.post(
                endpoint,
                headers=headers,
                json=payload,
                # Phase 6 (§10.3): explicit (connect, read) tuple instead of
                # the old single 1200 s value.  The orchestrator's 120 s
                # supervisor remains the total wall-clock boundary.
                timeout=(PROVIDER_CONNECT_TIMEOUT_S, PROVIDER_READ_TIMEOUT_S),
            )
            response.raise_for_status()
            data = response.json()

            text = data["choices"][0]["message"]["content"].strip()
            return text, {}

        except requests.exceptions.Timeout:
            print("[Local LLM Error] Timeout.", file=sys.stderr)
            # Typed meta is consumed by the v2 orchestrator; the legacy v1
            # path ignores it and still receives the same text shape.
            return "[Local LLM Error] Timeout", {"provider_error": "TIMEOUT"}

        except requests.exceptions.ConnectionError:
            print(
                f"[Local LLM Error] Connection failed: {endpoint}",
                file=sys.stderr,
            )
            return "[Local LLM Error] Connection failed", {
                "provider_error": "CONNECTION"
            }

        except requests.exceptions.HTTPError as e:
            print(f"[Local LLM Error] HTTP Error: {e}", file=sys.stderr)
            return f"[Local LLM Error] HTTP Error: {e}", {
                "provider_error": "HTTP"
            }

        except Exception as e:
            print(f"[Local LLM Error] {e}", file=sys.stderr)
            return f"[Local LLM Error] {e}", {"provider_error": "PROVIDER_ERROR"}
