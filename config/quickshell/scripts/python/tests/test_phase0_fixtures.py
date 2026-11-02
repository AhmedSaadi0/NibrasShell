#!/usr/bin/env python3
# scripts/python/tests/test_phase0_fixtures.py
"""Phase 0 fixture integrity tests (stdlib only, no new dependencies).

Freezes:
1. The legacy envelope contract consumed by services/AiService.qml from
   scripts/python/ai/main.py: exactly four top-level keys
   {success, response, updated_history, error}.
2. The legacy solution/analysis response shapes consumed by
   windows/leftwindow/monitoring/components/{BootDetails,SolutionCard}.qml.
3. Synthetic journald-shaped records under fixtures/journal/, including the
   motivating case: SYSLOG_IDENTIFIER != _COMM (stream owner is conmon while
   the identifier names the workload) inside a user@1000.service
   libpod-conmon-*.scope.

All fixture values are synthetic. Provenance and interface notes live in
docs/diag-contract-notes.md (Phase 0) — marker fields are kept out of the
fixture files on purpose so they stay faithful to real journalctl output.

Note on types: `journalctl --output=json` emits scalar trusted fields as
*strings* (e.g. PRIORITY: "4", _PID: "123", __MONOTONIC_TIMESTAMP: "...").
These tests therefore assert string types so any future parser that treats
them as integers fails loudly instead of silently.
"""

import json
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parent
FIXTURES = BASE / "fixtures"
JOURNAL_DIR = FIXTURES / "journal"
LEGACY_DIR = FIXTURES / "legacy_envelope"

LEGACY_FILES = (
    LEGACY_DIR / "boot_analyze_legacy.json",
    LEGACY_DIR / "boot_solution_legacy.json",
)

JOURNAL_FILES = {
    "motivating_conmon_stdout.json",
    "host_systemd_v2.json",
    "host_user_session_v2.json",
    "audit_trusted_identity.json",
    "unknown_sender_minimal.json",
    "boot_mismatch_cursor.json",
}


def load(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


class LegacyEnvelopeTests(unittest.TestCase):
    """Freeze the legacy envelope contract (Phase 0 acceptance inputs)."""

    ENVELOPE_KEYS = {"success", "response", "updated_history", "error"}

    def setUp(self):
        self.envelopes = {p.name: load(p) for p in LEGACY_FILES}

    def test_envelope_has_exactly_four_keys(self):
        for name, env in self.envelopes.items():
            with self.subTest(fixture=name):
                self.assertEqual(
                    set(env.keys()),
                    self.ENVELOPE_KEYS,
                    "legacy envelope keys drifted — services/AiService.qml "
                    "consumes exactly {success, response, updated_history, error}",
                )

    def test_envelope_core_values(self):
        for name, env in self.envelopes.items():
            with self.subTest(fixture=name):
                self.assertIs(env["success"], True)
                self.assertIsNone(env["error"])
                self.assertIsInstance(env["updated_history"], list)
                for msg in env["updated_history"]:
                    self.assertEqual(set(msg.keys()), {"role", "content"})
                    self.assertIn(msg["role"], {"user", "assistant"})
                    self.assertTrue(msg["content"].strip())

    def test_boot_analyze_response_shape(self):
        resp = self.envelopes["boot_analyze_legacy.json"]["response"]
        for key in ("title", "summary", "status_color", "boot_duration"):
            self.assertIn(key, resp)
        self.assertIsInstance(resp["logs"], list)
        self.assertGreaterEqual(len(resp["logs"]), 1)
        for entry in resp["logs"]:
            with self.subTest(log=entry.get("process")):
                self.assertIn("time", entry)
                self.assertIn("process", entry)
                self.assertIn("message", entry)
                self.assertIn("raw_details", entry)

    def test_boot_solution_response_shape(self):
        resp = self.envelopes["boot_solution_legacy.json"]["response"]
        solutions = resp["solutions"]
        self.assertIsInstance(solutions, list)
        self.assertGreaterEqual(len(solutions), 1)
        for sol in solutions:
            with self.subTest(solution=sol.get("id")):
                self.assertIn(sol["difficulty"], {"easy", "medium", "hard"})
                self.assertIn(sol["priority"], {"critical", "important", "optional"})
                self.assertIsInstance(sol["steps"], list)
                self.assertGreaterEqual(len(sol["steps"]), 1)
                for step in sol["steps"]:
                    self.assertIn("label", step)
                    self.assertIn("command", step)
                    self.assertIn("warning", step)
                    self.assertIsInstance(step["command"], str)

    def test_boot_solution_has_nonempty_command(self):
        """At least one steps[].command exists — the legacy copy affordance
        that the Phase 0 QML guard quarantines."""
        resp = self.envelopes["boot_solution_legacy.json"]["response"]
        commands = [
            step.get("command") for sol in resp["solutions"] for step in sol["steps"]
        ]
        self.assertTrue(any(cmd for cmd in commands))


class JournalFixtureTests(unittest.TestCase):
    """Synthetic journald-shaped records: common keys, string typing,
    the motivating conmon/scope case, and boot-mismatch boundaries."""

    REQUIRED_COMMON = (
        "_TRANSPORT",
        "_BOOT_ID",
        "__CURSOR",
        "__REALTIME_TIMESTAMP",
        "__MONOTONIC_TIMESTAMP",
        "MESSAGE",
        "PRIORITY",
    )

    WINDOW_FIXTURES = (
        "motivating_conmon_stdout.json",
        "host_systemd_v2.json",
        "host_user_session_v2.json",
        "unknown_sender_minimal.json",
        "boot_mismatch_cursor.json",
    )

    def setUp(self):
        self.records = {name: load(JOURNAL_DIR / name) for name in JOURNAL_FILES}

    def test_expected_fixture_set(self):
        found = {p.name for p in JOURNAL_DIR.glob("*.json")}
        self.assertEqual(
            found,
            JOURNAL_FILES,
            "unexpected or missing fixture under fixtures/journal/",
        )

    def test_required_common_keys_present(self):
        for name, rec in self.records.items():
            with self.subTest(fixture=name):
                missing = {k for k in self.REQUIRED_COMMON if k not in rec}
                self.assertEqual(missing, set())

    def test_required_common_keys_are_string_typed(self):
        for name, rec in self.records.items():
            for key in self.REQUIRED_COMMON:
                with self.subTest(fixture=name, field=key):
                    self.assertIsInstance(
                        rec[key], str, "journalctl --output=json emits strings"
                    )

    def test_pid_uid_string_typing(self):
        """_PID/_UID arrive as strings over journalctl --output=json; keep the
        parser contract explicit."""
        for name in (
            "motivating_conmon_stdout.json",
            "host_systemd_v2.json",
            "host_user_session_v2.json",
            "boot_mismatch_cursor.json",
        ):
            rec = self.records[name]
            for key in ("_PID", "_UID"):
                with self.subTest(fixture=name, field=key):
                    self.assertIsInstance(rec[key], str)

    def test_window_priorities_within_warning_band(self):
        """-p warning means int(PRIORITY) <= 4 on this window's records.
        audit transport is excluded (kernel audit severity is its own
        characterization question — see docs/diag-contract-notes.md)."""
        for name in self.WINDOW_FIXTURES:
            with self.subTest(fixture=name):
                self.assertLessEqual(int(self.records[name]["PRIORITY"]), 4)

    def test_motivating_record_shape(self):
        """Reproduce the motivating case synthetically: the journal record's
        trust-field sender is conmon (stream owner), while SYSLOG_IDENTIFIER
        names the workload, inside a user-manager libpod-conmon scope."""
        rec = self.records["motivating_conmon_stdout.json"]
        self.assertEqual(rec["_COMM"], "conmon")
        self.assertEqual(rec["_EXE"], "/usr/bin/conmon")
        self.assertNotEqual(rec.get("SYSLOG_IDENTIFIER"), "conmon")
        self.assertIn("libpod-conmon-", rec["_SYSTEMD_USER_UNIT"])
        self.assertIn("libpod-conmon-", rec["_SYSTEMD_CGROUP"])
        self.assertEqual(rec["_SYSTEMD_UNIT"], "user@1000.service")
        self.assertIn("_AUDIT_LOGINUID", rec)
        self.assertIn("_AUDIT_SESSION", rec)
        self.assertEqual(int(rec["PRIORITY"]), 4)

    def test_boot_mismatch_differs_from_window_fixtures(self):
        mismatch = self.records["boot_mismatch_cursor.json"]["_BOOT_ID"]
        for name in (
            "motivating_conmon_stdout.json",
            "host_systemd_v2.json",
            "host_user_session_v2.json",
        ):
            with self.subTest(other=name):
                self.assertNotEqual(
                    self.records[name]["_BOOT_ID"],
                    mismatch,
                    "boot_id isolation broken — the mismatch fixture must carry "
                    "a distinct _BOOT_ID for cursor/boot-boundary tests",
                )

    def test_unknown_sender_minimal_lacks_credentialed_fields(self):
        rec = self.records["unknown_sender_minimal.json"]
        self.assertEqual(rec["_TRANSPORT"], "kernel")
        for key in (
            "_PID",
            "_UID",
            "_GID",
            "_COMM",
            "_EXE",
            "_SYSTEMD_UNIT",
            "_SYSTEMD_CGROUP",
        ):
            self.assertNotIn(key, rec)

    def test_audit_fixture_keeps_audit_identity_fields(self):
        rec = self.records["audit_trusted_identity.json"]
        self.assertEqual(rec["_TRANSPORT"], "audit")
        self.assertIn("_AUDIT_LOGINUID", rec)
        self.assertIn("_AUDIT_SESSION", rec)


if __name__ == "__main__":
    unittest.main(verbosity=2)
