#!/usr/bin/env python3
# scripts/python/tests/test_phase5_3_credential_transport.py
"""Phase 5.3 — API credential transport hardening.

The credential must never travel in process arguments or the child process
environment.  QML hands it to ``AiTask`` in memory; ``AiTask`` writes exactly
one bounded JSON line to the child's stdin; Python reads that line before
provider initialization.

These are source/unit contracts plus one Linux subprocess check of
``/proc/<pid>/cmdline`` and ``/proc/<pid>/environ``.  They do not claim that a
real Quickshell session was launched, nor that process memory is secret from a
privileged observer.
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import subprocess
import sys
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent  # scripts/python
AI_DIR = ROOT / "ai"
REPO = ROOT.parent.parent

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(AI_DIR) not in sys.path:
    sys.path.insert(0, str(AI_DIR))

import config as CFG  # noqa: E402
import main as MAIN  # noqa: E402
from credential_transport import (  # noqa: E402
    MAX_CREDENTIAL_BYTES,
    REDACTED,
    CredentialTransportError,
    read_credential,
    redact_secret,
    redact_structure,
)

FAKE_SENTINEL = "sk-phase53-FAKE-SENTINEL-not-a-real-key"

AI_COMMANDS = (
    "callBootAnalysisAi",
    "callBootSolutionAi",
    "callSpikeAnalysisAi",
    "callWeatherAi",
    "callMusicAi",
    "callIdleCapsuleAi",
    "callTodoAi",
    "callSystemActionAi",
    "callColorPaletteAi",
)

CALL_SITES = {
    "windows/smart_capsule/logic/HoverResponseManager.qml": 2,
    "services/Weather.qml": 1,
    "services/TodoService.qml": 1,
    "services/MusicService.qml": 1,
    "services/system/BootAnalyzer.qml": 2,
    "services/system/ActionResponses.qml": 1,
    "services/analyzers/SpikeDetector.qml": 1,
    "themes/modules/AiThemeAssistant.qml": 1,
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def property_line(source: str, name: str) -> str:
    for line in source.splitlines():
        if name in line and "property var" in line:
            return line
    return ""


class TestQmlCredentialLaunchPaths(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = read(REPO / "config" / "App.qml")
        cls.service = read(REPO / "services" / "AiService.qml")
        cls.task = read(REPO / "services" / "AiTask.qml")

    def test_no_qml_launcher_passes_api_key_in_argv(self):
        offenders = []
        for path in REPO.rglob("*.qml"):
            text = read(path)
            if "--api_key" in text:
                offenders.append(str(path.relative_to(REPO)))
        self.assertEqual(offenders, [])

    def test_every_ai_command_uses_stdin_credential_marker(self):
        for name in AI_COMMANDS:
            with self.subTest(name=name):
                line = property_line(self.app, name)
                self.assertTrue(line, f"{name} not found")
                self.assertIn('"--credential-stdin"', line)
                self.assertNotIn("--api_key", line)
                self.assertNotIn("AiApiKey", line)

        initial = property_line(self.app, "initialAiCommand")
        self.assertTrue(initial)
        self.assertNotIn("--api_key", initial)
        self.assertNotIn("AiApiKey", initial)

        # V1/V2 selection is unchanged.
        self.assertNotIn("--orchestrator", property_line(self.app, "callBootAnalysisAi"))
        self.assertIn(
            '"--orchestrator", "v2"',
            property_line(self.app, "callBootSolutionAi"),
        )

    def test_every_ai_call_site_passes_an_in_memory_credential(self):
        for relative, expected in CALL_SITES.items():
            with self.subTest(file=relative):
                source = read(REPO / relative)
                self.assertEqual(source.count("AiService.sendRequest("), expected)
                self.assertGreaterEqual(source.count("credential:"), expected)

    def test_aitask_writes_one_credential_line_to_stdin(self):
        self.assertIn("property string credential", self.task)
        self.assertIn("stdinEnabled: true", self.task)
        self.assertIn("onStarted:", self.task)
        self.assertIn(
            'aiProcess.write(JSON.stringify({ credential: task.credential || "" }) + "\\n")',
            self.task,
        )
        # Existing environment and lifecycle behavior is preserved.
        self.assertIn("property var environment", self.task)
        self.assertIn("aiProcess.environment = task.environment", self.task)
        self.assertIn("310000", self.task)
        self.assertIn("signal(15)", self.task)
        self.assertIn("signal(9)", self.task)

    def test_aiservice_forwards_credential_without_touching_argv(self):
        self.assertIn('"credential": (options && options.credential', self.service)
        for line in self.service.splitlines():
            if "fullCmd = fullCmd.concat" in line:
                self.assertNotIn("credential", line)
            if "console." in line:
                self.assertNotIn("fullCmd", line)

    def test_list_gemini_processes_use_stdin(self):
        self.assertEqual(self.app.count("listGemini, \"--credential-stdin\""), 2)
        self.assertEqual(self.app.count("stdinEnabled: true"), 2)
        self.assertIn("credentialStdinLine(root.musicAiCredential)", self.app)
        self.assertIn("credentialStdinLine(root.weatherAiCredential)", self.app)

    def test_credential_is_not_put_in_the_child_environment(self):
        self.assertNotIn("NIBRAS_SHELL_AI_API_KEY", self.task)
        self.assertNotIn("API_KEY", self.task)
        self.assertNotIn("credential", self.task.split("property var environment", 1)[1].split("property int watchdogMs", 1)[0])


class TestPythonCredentialTransport(unittest.TestCase):
    def test_reader_delivers_the_exact_sentinel(self):
        stream = io.StringIO(json.dumps({"credential": FAKE_SENTINEL}) + "\n")
        self.assertEqual(read_credential(stream), FAKE_SENTINEL)

    def test_missing_and_malformed_input_fail_without_echoing(self):
        cases = {
            "EMPTY": "",
            "MALFORMED": "not-json\n",
            "MALFORMED_EXTRA": json.dumps(
                {"credential": FAKE_SENTINEL, "extra": True}
            )
            + "\n",
            "MALFORMED_TYPE": json.dumps({"credential": 123}) + "\n",
            "MALFORMED_NEWLINE": json.dumps(
                {"credential": "a\nb"}
            )
            + "\n",
            "OVERSIZED": json.dumps(
                {"credential": "x" * (MAX_CREDENTIAL_BYTES + 1)}
            )
            + "\n",
        }
        for label, payload in cases.items():
            with self.subTest(case=label):
                with self.assertRaises(CredentialTransportError) as ctx:
                    read_credential(io.StringIO(payload))
                self.assertNotIn(FAKE_SENTINEL, str(ctx.exception))
                self.assertIn("CREDENTIAL_TRANSPORT_ERROR:", str(ctx.exception))

    def test_redaction_helpers_remove_the_secret(self):
        self.assertEqual(
            redact_secret(f"boom {FAKE_SENTINEL}", FAKE_SENTINEL),
            f"boom {REDACTED}",
        )
        structure = {
            "error": f"boom {FAKE_SENTINEL}",
            "nested": [FAKE_SENTINEL, {"x": FAKE_SENTINEL}],
        }
        cleaned = redact_structure(structure, FAKE_SENTINEL)
        self.assertNotIn(FAKE_SENTINEL, json.dumps(cleaned))

    def test_legacy_argv_credential_is_rejected_without_echo(self):
        out, err = io.StringIO(), io.StringIO()
        argv = ["main.py", "--api_key", FAKE_SENTINEL, "--message", "hi"]
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(
            out
        ), contextlib.redirect_stderr(err):
            MAIN.main()
        self.assertNotIn(FAKE_SENTINEL, out.getvalue())
        self.assertNotIn(FAKE_SENTINEL, err.getvalue())
        envelope = json.loads(out.getvalue())
        self.assertFalse(envelope["success"])
        self.assertEqual(
            envelope["error"], "CREDENTIAL_TRANSPORT_ERROR:ARGV_FORBIDDEN"
        )

    def test_stdin_credential_reaches_v1_provider_initialization(self):
        seen = {}

        class FakeProvider:
            def generate(self, message, history):
                return "ok", {}

        def fake_provider(args, system, temperature, json_mode):
            seen["api_key"] = args.api_key
            return FakeProvider()

        out = io.StringIO()
        argv = ["main.py", "--credential-stdin", "--message", "hi"]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps({"credential": FAKE_SENTINEL}) + "\n")
        ), mock.patch.object(MAIN, "get_provider", side_effect=fake_provider), contextlib.redirect_stdout(
            out
        ):
            MAIN.main()
        self.assertEqual(seen.get("api_key"), FAKE_SENTINEL)
        self.assertNotIn(FAKE_SENTINEL, out.getvalue())
        self.assertTrue(json.loads(out.getvalue())["success"])

    def test_stdin_credential_reaches_v2_provider_initialization(self):
        seen = {}

        class FakeProvider:
            def generate(self, message, history):
                return "ok", {}

        def fake_provider(args, system, temperature, json_mode):
            seen["api_key"] = args.api_key
            return FakeProvider()

        out = io.StringIO()
        argv = [
            "main.py",
            "--credential-stdin",
            "--orchestrator",
            "v2",
            "--message",
            "hi",
        ]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps({"credential": FAKE_SENTINEL}) + "\n")
        ), mock.patch.object(
            MAIN, "get_provider", side_effect=fake_provider
        ), mock.patch.object(
            CFG, "get_boot_incident", return_value=None
        ), contextlib.redirect_stdout(
            out
        ):
            MAIN.main()
        self.assertEqual(seen.get("api_key"), FAKE_SENTINEL)
        self.assertNotIn(FAKE_SENTINEL, out.getvalue())
        envelope = json.loads(out.getvalue())
        self.assertEqual(
            envelope["response"]["analysis_failure"], "NO_INCIDENTS_COLLECTED"
        )
        self.assertTrue(envelope["response"]["no_action_taken"])

    def test_v1_provider_error_is_redacted(self):
        class FailingProvider:
            def generate(self, message, history):
                raise RuntimeError(f"provider rejected {FAKE_SENTINEL}")

        out = io.StringIO()
        argv = ["main.py", "--credential-stdin", "--message", "hi"]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", io.StringIO(json.dumps({"credential": FAKE_SENTINEL}) + "\n")
        ), mock.patch.object(
            MAIN, "get_provider", return_value=FailingProvider()
        ), contextlib.redirect_stdout(
            out
        ):
            MAIN.main()
        self.assertNotIn(FAKE_SENTINEL, out.getvalue())
        self.assertIn(REDACTED, out.getvalue())

    def test_missing_credential_fails_typed_for_authenticated_provider(self):
        args = SimpleNamespace(
            provider="openai",
            api_key=None,
            model="m",
            base_url=None,
            preferred_language="English",
            user_persona="",
        )
        with mock.patch.object(CFG, "get_system_details", return_value={}):
            with self.assertRaises(CFG.ProviderConfigurationError) as ctx:
                CFG.get_provider(args, "system", 0.7, False)
        self.assertEqual(str(ctx.exception), "MISSING_API_CREDENTIAL")

    def test_credential_free_providers_still_construct(self):
        base = dict(
            api_key=None,
            model="m",
            base_url=None,
            preferred_language="English",
            user_persona="",
        )
        with mock.patch.object(CFG, "get_system_details", return_value={}):
            local = CFG.get_provider(
                SimpleNamespace(provider="local", **base), "system", 0.7, False
            )
            ollama = CFG.get_provider(
                SimpleNamespace(provider="ollama", **base), "system", 0.7, False
            )
        self.assertIsInstance(local, CFG.LocalProvider)
        self.assertIsInstance(ollama, CFG.OllamaProvider)

    def test_provider_and_model_selection_are_preserved(self):
        common = dict(
            api_key="fake-key",
            model="selected-model",
            base_url=None,
            preferred_language="English",
            user_persona="",
        )
        with mock.patch.object(CFG, "get_system_details", return_value={}):
            gemini = CFG.get_provider(
                SimpleNamespace(provider="gemini", **common), "s", 0.7, False
            )
            openrouter = CFG.get_provider(
                SimpleNamespace(provider="openrouter", **common), "s", 0.7, False
            )
            deepseek = CFG.get_provider(
                SimpleNamespace(provider="deepseek", **common), "s", 0.7, False
            )
            openai = CFG.get_provider(
                SimpleNamespace(provider="openai", **common), "s", 0.7, False
            )
        self.assertIsInstance(gemini, CFG.GeminiProvider)
        self.assertIsInstance(openrouter, CFG.OpenRouterProvider)
        self.assertIsInstance(deepseek, CFG.OpenAIProvider)
        self.assertEqual(deepseek.base_url, "https://api.deepseek.com")
        self.assertIsInstance(openai, CFG.OpenAIProvider)
        for provider in (gemini, openrouter, deepseek, openai):
            self.assertEqual(provider.model, "selected-model")

    def test_python_launchers_use_stdin_reader(self):
        for relative in ("scripts/python/ai/main.py", "scripts/python/ai/list-gemini.py"):
            with self.subTest(file=relative):
                source = read(REPO / relative)
                self.assertIn("read_credential(", source)
                self.assertIn("--credential-stdin", source)
                self.assertNotIn(
                    'parser.add_argument("--api_key", required=True', source
                )

    def test_subprocess_cmdline_and_environ_exclude_sentinel(self):
        ai_dir_literal = repr(str(AI_DIR))
        child = (
            "import hashlib, sys, time\n"
            f"sys.path.insert(0, {ai_dir_literal})\n"
            "from credential_transport import read_credential\n"
            "value = read_credential()\n"
            "time.sleep(0.5)\n"
            "print(hashlib.sha256(value.encode()).hexdigest())\n"
        )
        proc = subprocess.Popen(
            [sys.executable, "-c", child],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=dict(os.environ),
        )
        try:
            proc.stdin.write(json.dumps({"credential": FAKE_SENTINEL}) + "\n")
            proc.stdin.flush()

            cmdline = b""
            environ = b""
            deadline = time.time() + 5
            while time.time() < deadline:
                try:
                    cmdline = Path(f"/proc/{proc.pid}/cmdline").read_bytes()
                    environ = Path(f"/proc/{proc.pid}/environ").read_bytes()
                except FileNotFoundError:
                    time.sleep(0.02)
                    continue
                if cmdline:
                    break
                time.sleep(0.02)

            self.assertNotIn(FAKE_SENTINEL.encode(), cmdline)
            self.assertNotIn(FAKE_SENTINEL.encode(), environ)
            stdout, stderr = proc.communicate(timeout=10)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()

        expected = hashlib.sha256(FAKE_SENTINEL.encode()).hexdigest()
        self.assertEqual(stdout.strip(), expected)
        self.assertNotIn(FAKE_SENTINEL, stdout)
        self.assertNotIn(FAKE_SENTINEL, stderr)


if __name__ == "__main__":
    unittest.main()
