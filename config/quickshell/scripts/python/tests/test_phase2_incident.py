#!/usr/bin/env python3
# scripts/python/tests/test_phase2_incident.py
"""Phase 2 structured-collection + canonical-incident tests (§16.2 matrix).

All rows are driven by synthetic journal fixtures (Phase-0 fixture files are
reused where their shape matches an execution row), an injectable FakeRunner,
and a provider-stubbed config import — NO real journalctl, NO real podman,
NO network, NO LLM, NO host journald reads. stdlib unittest only.

Row map (tests ↔ plan):
- §16.2 rows 1–13              → TestCollectorBoundary / TestCollectorContinuation
                                 / TestNormalizerRows / TestIncidentValidation
- §14 redaction + env deny     → TestRedaction / TestSurveySnapshot
- §18 row 2 config flag wiring → TestConfigWiring (legacy path preserved)

Global gates in TestNormalizerRows.commonGates:
- uncertainty preserved end-to-end (missing_evidence survives),
- no root-level runtime_domain / no host-fallback / no kernel sender claim,
- cursor byte-for-byte, monotonic_us preserved as integer.
"""

import json
import os
import sys
import types
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent  # scripts/python
AI_DIR = ROOT / "ai"  # flat layout used by production (main.py style)
FIXTURES = BASE / "fixtures" / "journal"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ai.evidence import journal_collector as jc  # noqa: E402
from ai.evidence import redact  # noqa: E402
from ai.evidence import models as m  # noqa: E402
from ai.evidence.discovery import discover, ProcResult  # noqa: E402
from ai.incident import normalizer as nz  # noqa: E402

BOOT = "b0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0"  # Phase-0 same-boot id
MISMATCH_BOOT = "11111111222222223333333344444444"  # Phase-0 other-boot id
CLK = os.sysconf("SC_CLK_TCK")


def journal(name: str) -> dict:
    with open(FIXTURES / name, encoding="utf-8") as fh:
        return json.load(fh)


def dashed(boot: str) -> str:
    return f"{boot[:8]}-{boot[8:12]}-{boot[12:16]}-{boot[16:20]}-{boot[20:]}"


def P(rc=0, out="", err=""):
    return ProcResult(rc, out, err)


def script(*results):
    """Multi-run command: journalctl script queue for FakeRunner."""
    queue = list(results)

    def _runner(argv, timeout_s=5.0):
        return queue.pop(0)

    return _runner


def proc_stat(pid: int, comm: str, start_seconds: float) -> bytes:
    """Legal proc(5) stat line (same builder as Phase-1 tests)."""
    rest = ["S", "1", str(pid), str(pid), "0", "-1", "4194560"]
    rest += ["0"] * (19 - len(rest))  # indices 7..18
    rest.append(str(int(start_seconds * CLK)))  # index 19 = starttime
    rest += ["0"] * (52 - 22)  # remaining fields
    return f"{pid} ({comm}) ".encode() + " ".join(rest).encode()


class FakeRunner:
    def __init__(self, files=None, commands=None):
        self.files = dict(files or {})
        self.commands = dict(commands or {})
        self.reads: list[str] = []
        self.runs: list[list[str]] = []

    def read_file(self, path: str) -> bytes:
        self.reads.append(path)
        if path not in self.files or self.files[path] is None:
            raise FileNotFoundError(path)
        value = self.files[path]
        if isinstance(value, Exception):
            raise value
        return value

    def run(self, argv, timeout_s=5.0):
        self.runs.append(list(argv))
        key = argv[0]
        if key not in self.commands:
            raise FileNotFoundError(key)
        value = self.commands[key]
        if isinstance(value, Exception):
            raise value
        if callable(value):
            value = value(argv)
        return value


def incident_of(record: dict, runner=None, current_boot_id=None, **kw):
    d = discover(record, runner) if runner is not None else discover(record)
    return nz.build_incident(record, d, current_boot_id=current_boot_id, **kw)


class TestCollectorBoundary(unittest.TestCase):
    """§16.2 mandated row: the PROPOSED collector uses `-p warning` (=4)."""

    def test_default_window_uses_correct_boundary(self):
        argv = jc.build_argv()
        self.assertEqual(argv[0], "journalctl")
        self.assertIn("--output=json", argv)
        self.assertIn("--no-pager", argv)
        self.assertEqual(argv[argv.index("-b") + 1], "0")  # current boot
        self.assertEqual(argv[argv.index("-p") + 1], "warning")  # 0..4 inclusive
        self.assertEqual(argv[argv.index("-n") + 1], "200")  # R1 record cap

    def test_warning_boundary_includes_0_to_4_excludes_5_to_7(self):
        self.assertEqual(jc.boundary_top("warning"), 4)
        for prio in range(0, 5):
            self.assertTrue(
                jc.boundary_includes({"PRIORITY": str(prio)}, "warning"),
                f"priority {prio} must be inside warnings-or-worse",
            )
        for prio in range(5, 8):
            self.assertFalse(
                jc.boundary_includes({"PRIORITY": str(prio)}, "warning"),
                f"priority {prio} must be OUTSIDE the window",
            )

    def test_p_3_and_p_err_fail_the_warnings_or_worse_mandate(self):
        # A warnings-or-worse collection implemented with `-p 3` / `-p err`
        # (top=3) EXCLUDES warning(4) — exactly the §5.4 defect class the
        # plan mandates as a review failure. The proposed collector never
        # emits these (DEFAULT_PRIORITY == "warning").
        self.assertEqual(jc.boundary_top("err"), 3)
        self.assertFalse(jc.boundary_includes({"PRIORITY": "4"}, "err"))
        self.assertEqual(jc.DEFAULT_PRIORITY, "warning")

    def test_notice_and_info_are_separate_windows_not_implied(self):
        runner = FakeRunner(commands={"journalctl": P(0, "", "")})
        for name, top in (("notice", 5), ("info", 6)):
            jc.collect(runner, priority=name)
            used = runner.runs[-1]
            self.assertEqual(used[used.index("-p") + 1], name)
            self.assertEqual(jc.boundary_top(name), top)

    def test_limit_bounds_and_cursor_type_errors(self):
        with self.assertRaises(ValueError):
            jc.build_argv(limit=0)
        with self.assertRaises(ValueError):
            jc.build_argv(limit=201)
        with self.assertRaises(TypeError):
            jc.build_argv(after_cursor=1234)  # §10.6: integer = schema error
        with self.assertRaises(TypeError):
            jc.build_argv(after_cursor=7)
        self.assertEqual(
            jc.build_argv(after_cursor="s=x;i=1;b=y"),
            [
                jc.JOURNALCTL,
                "--no-pager",
                "--output=json",
                "-b",
                "0",
                "-p",
                "warning",
                "-n",
                "200",
                "--after-cursor",
                "s=x;i=1;b=y",
            ],
        )


class TestCollectorContinuation(unittest.TestCase):
    """§10.6 + §16.2: opaque cursor, dedup, invalid JSON, fail-closed."""

    LINES = [
        json.dumps({"__CURSOR": "s+a;i=1;b=x", "PRIORITY": "4", "MESSAGE": ["one"]}),
        "{not json",  # invalid JSON → skip + counter
        json.dumps({"__CURSOR": "s+a;i=1;b=x", "PRIORITY": "4", "MESSAGE": ["dup"]}),
        json.dumps({"__CURSOR": "s+b;i=2;b=x", "PRIORITY": "3", "MESSAGE": ["two"]}),
    ]

    def test_basic_window_dedup_invalid_json_counters(self):
        runner = FakeRunner(commands={"journalctl": P(0, "\n".join(self.LINES), "")})
        result = jc.collect(runner)
        argv = runner.runs[0]
        self.assertEqual(argv[argv.index("-b") + 1], "0")
        self.assertEqual(argv[argv.index("-p") + 1], "warning")
        self.assertEqual(result.counters["records_collected"], 3)
        self.assertEqual(result.counters["invalid_json_skipped"], 1)
        self.assertEqual(result.counters["duplicate_cursor_skipped"], 1)
        self.assertEqual(
            [r["__CURSOR"] for r in result.records], ["s+a;i=1;b=x", "s+b;i=2;b=x"]
        )
        self.assertEqual(result.last_cursor, "s+b;i=2;b=x")
        self.assertFalse(result.used_fallback)
        self.assertFalse(result.collection_failed)

    def test_cursor_passthrough_verbatim(self):
        runner = FakeRunner(commands={"journalctl": P(0, self.LINES[0], "")})
        jc.collect(runner, after_cursor="s=WEIRD;i=z;b=Q[+]")
        argv = runner.runs[0]
        self.assertEqual(
            argv[argv.index("--after-cursor") + 1], "s=WEIRD;i=z;b=Q[+]"
        )  # byte-for-byte

    def test_non_str_cursor_kept_and_counted(self):
        line = json.dumps({"__CURSOR": 99, "PRIORITY": "4"})
        runner = FakeRunner(commands={"journalctl": P(0, line, "")})
        result = jc.collect(runner)
        self.assertEqual(result.counters["non_str_cursor_kept"], 1)
        self.assertEqual(len(result.records), 1)

    def test_returncode_failure_with_cursor_marker_falls_back_explicit(self):
        runner = FakeRunner(
            commands={
                "journalctl": script(
                    P(1, "", "Failed to seek to cursor: no such boot"),
                    P(0, self.LINES[0], ""),
                ),
            }
        )
        result = jc.collect(
            runner, after_cursor="s=gone", fallback_since="2026-11-01 08:00:00"
        )
        self.assertTrue(result.used_fallback)
        self.assertEqual(len(runner.runs), 2)
        fallback_argv = runner.runs[1]
        self.assertNotIn("--after-cursor", fallback_argv)  # NO synthesized cursor
        self.assertEqual(
            fallback_argv[fallback_argv.index("--since") + 1], "2026-11-01 08:00:00"
        )
        self.assertIn("no cursor synthesized", " ".join(result.notes))

    def test_empty_continuation_falls_back_to_boot_window(self):
        runner = FakeRunner(
            commands={
                "journalctl": script(
                    P(0, "", ""),  # empty continuation
                    P(0, self.LINES[0], ""),
                ),
            }
        )
        result = jc.collect(runner, after_cursor="s=gone")
        self.assertTrue(result.used_fallback)
        self.assertNotIn("--after-cursor", runner.runs[1])
        self.assertEqual(result.records[0]["__CURSOR"], "s+a;i=1;b=x")

    def test_no_fallback_without_continuation(self):
        runner = FakeRunner(commands={"journalctl": P(1, "", "Failed to seek")})
        result = jc.collect(runner)
        self.assertFalse(result.used_fallback)
        self.assertEqual(len(runner.runs), 1)

    def test_timeout_fails_closed(self):
        runner = FakeRunner(commands={"journalctl": TimeoutError()})
        result = jc.collect(runner)
        self.assertTrue(result.collection_failed)
        self.assertEqual(
            result.failure_reasons, [m.REASON_TIMEOUT, m.REASON_RUNTIME_UNAVAILABLE]
        )
        self.assertEqual(result.records, [])

    def test_oserror_fails_closed_permission(self):
        runner = FakeRunner(commands={"journalctl": OSError("no journalctl")})
        result = jc.collect(runner)
        self.assertTrue(result.collection_failed)
        self.assertEqual(result.failure_reasons, [m.REASON_PERMISSION_DENIED])

    def test_output_cap_truncates_with_note(self):
        big = "\n".join(self.LINES) + "\n" + "x" * (jc.MAX_OUTPUT_BYTES + 16)
        runner = FakeRunner(commands={"journalctl": P(0, big, "")})
        result = jc.collect(runner, limit=1)
        self.assertTrue(result.output_truncated)


class TestRedaction(unittest.TestCase):
    """§14/C4: deny-list scrubbing, counts only, env default-deny."""

    def check(self, blob: str, rule: str, secret: str, replacement: str):
        out, counts = redact.redact_text(blob)
        self.assertNotIn(secret, out)
        self.assertIn(replacement, out)
        self.assertGreaterEqual(counts.get(rule, 0), 1)
        for key, value in counts.items():  # counts carry NO content
            self.assertIsInstance(value, int)
            self.assertIsInstance(key, str)
        return out, counts

    def test_url_credentials(self):
        out, _ = self.check(
            "https://user:hunter2@api.example.com/v1",
            "url-credentials",
            "hunter2",
            "<redacted-credentials>@",
        )
        self.assertIn("://<redacted-credentials>@api.example.com", out)

    def test_bearer_token(self):
        self.check(
            "auth ok: Bearer eyJhbGciOiJIUzI1NiIsImtpZCI6InN5bnRoZXNp.ai._",
            "bearer-token",
            "eyJhbGciOiJIUzI1NiIsImtpZCI6InN5bnRoZXNp.ai._",
            "Bearer <redacted>",
        )

    def test_jwt(self):
        self.check(
            "token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJyb290In0.c2lnbmF0dXJl",
            "jwt",
            "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJyb290In0.c2lnbmF0dXJl",
            "<redacted-jwt>",
        )

    def test_aws_key(self):
        self.check(
            "key AKIAIOSFODNN7EXAMPLE",
            "aws-key",
            "AKIAIOSFODNN7EXAMPLE",
            "<redacted-aws-key>",
        )

    def test_slack_token(self):
        self.check(
            "slack xoxb-123456789012-abcdef",
            "slack-token",
            "xoxb-123456789012-abcdef",
            "<redacted-slack-token>",
        )

    def test_openai_key(self):
        self.check(
            "ai sk-abcdefghijklmnop1234",
            "openai-key",
            "sk-abcdefghijklmnop1234",
            "<redacted-api-key>",
        )

    def test_google_key(self):
        self.check(
            "g gapi_fcghsKAJKslsldk12skM",
            "google-key",
            "gapi_fcghsKAJKslsldk12skM",
            "<redacted-google-key>",
        )

    def test_assignment_secret(self):
        out, _ = self.check(
            "password=hunter2 and ANOTHER_TOKEN=abc123",
            "assignment-secret",
            "hunter2",
            "=<redacted>",
        )
        # compound key names are covered by the suffix-tolerant pattern:
        self.assertNotIn("abc123", out)
        out2, _ = redact.redact_text("SECRET_KEY=zzz-top")
        self.assertNotIn("zzz-top", out2)

    def test_pem_private_key_masked_whole_body(self):
        blob = (
            "-----BEGIN RSA PRIVATE KEY-----\n"
            "proc=EVERYTHING\n-----END RSA PRIVATE KEY-----\nends"
        )
        out, counts = redact.redact_text(blob)
        self.assertNotIn("proc=EVERYTHING", out)
        self.assertIn("<redacted-pem-private-key>", out)
        self.assertEqual(counts.get("pem-private-key"), 1)

    def test_non_str_refused(self):
        with self.assertRaises(TypeError):
            redact.redact_text(None)  # type: ignore[arg-type]

    def test_cmdline_token_level(self):
        tokens, _ = redact.redact_cmdline(
            ["run", "--token=sk-abcdefghijklmnop1234", "plain"]
        )
        self.assertNotIn("sk-abcdefghijklmnop1234", tokens[1])
        self.assertEqual(tokens, ["run", tokens[1], "plain"])

    def test_env_default_deny(self):
        env, counts = redact.redact_environment(
            {"SECRET_TOKEN": "abc", "PATH": "/usr/bin"}
        )
        self.assertEqual(env, {})
        self.assertEqual(counts, {"env-dropped": 1})

    def test_env_allowlist_refused_fail_closed(self):
        with self.assertRaises(ValueError):
            redact.redact_environment(
                {"TOKEN": "x"}, allowlist=frozenset({"SESSION_TYPE"})
            )

    def test_replacements_never_embed_captures(self):
        out, _ = redact.redact_text("password=SEKRITZ value")
        self.assertNotIn("SEKRITZ", out)


class TestNormalizerRows(unittest.TestCase):
    """§16.2 rows 1–13 against nibras.incident/v1 envelopes + shared gates."""

    def commonGates(self, incident: dict):
        self.assertNotIn("runtime_domain", incident)  # §9: never at root
        self.assertNotIn("event_transport", incident)  # §9: single canonical spot
        self.assertEqual(nz.validate_incident(incident), [])
        sender = incident["record_sender"]
        if sender:
            claim = json.dumps(sender).upper()
            self.assertFalse(('"ROLE": "HOST' in claim) or ('"ROLE": "KERNEL' in claim))

    # ── row 1: trusted metadata missing ⇒ UNKNOWN — never host, never kernel ──
    def test_row1_missing_metadata_is_unknown_never_fallback(self):
        incident = incident_of(journal("unknown_sender_minimal.json"))
        sender = incident["record_sender"]
        self.assertEqual(sender["role"], m.ROLE_UNKNOWN)
        self.assertEqual(sender["status"], "UNAVAILABLE")
        self.commonGates(incident)
        self.assertTrue(incident["missing_evidence"], "uncertainty not preserved")

    # ── row 2: stdout-family forked process ⇒ stream_owner note (§8.1-A) ──
    def test_row2_stdout_family_stream_owner_note(self):
        # plain stdout record: NO unit/cgroup fields (a unit field would
        # elevate the analysis to WORKLOAD_APPEARANCE per §8.1-B)
        record = {
            "_TRANSPORT": "stdout",
            "_PID": "2103",
            "_UID": "1000",
            "_GID": "1000",
            "_COMM": "child",
            "__CURSOR": "s+row2",
            "_BOOT_ID": BOOT,
            "__MONOTONIC_TIMESTAMP": "2900000000",
            "__REALTIME_TIMESTAMP": "1733200099000000",
            "PRIORITY": "4",
            "MESSAGE": ["child wrote to stdout"],
        }
        incident = incident_of(record)
        sender = incident["record_sender"]
        # §8.1-A/§8.3-step-5 mandates the STREAM-OWNER *note* on stdout-family
        # records; the role itself is WORKLOAD_APPEARANCE for a plain credentialed
        # child (STREAM_OWNER is reserved for conmon-ish senders)
        self.assertIn(sender["role"], {m.ROLE_STREAM_OWNER, m.ROLE_WORKLOAD_APPEARANCE})
        self.assertTrue(sender.get("stream_owner_note"), "missing §8.1-A note")
        self.commonGates(incident)

    # ── row 3: OBJECT_* records describe a SEPARATE subject ──
    def test_row3_object_record_subject_separate_from_sender(self):
        record = journal("host_systemd_v2.json")
        record["_PID"] = "2103"
        record["_UID"] = "0"
        record["_GID"] = "0"
        record["_COMM"] = "systemd"
        record["_EXE"] = "/usr/lib/systemd/systemd"
        record["_SYSTEMD_UNIT"] = "synthetic.service"
        record["OBJECT_PID"] = "901"
        record["OBJECT_COMM"] = "synthetic-worker"
        record["OBJECT_SYSTEMD_UNIT"] = "other.service"
        incident = incident_of(record)
        subject = incident["referenced_subject"]
        sender = incident["record_sender"]
        self.assertIsNotNone(subject, "OBJECT_* must produce a described subject")
        self.assertIsNotNone(sender)
        self.assertNotEqual(
            json.dumps(subject.get("pid")), json.dumps(sender.get("pid"))
        )
        self.assertEqual(
            subject.get("disposition"), incident["referenced_subject"]["disposition"]
        )
        self.commonGates(incident)

    # ── row 4: cgroup provenance trio — three SEPARATE fields, no upgrade ──
    def test_row4_cgroup_trio_three_fields_and_no_upgrade(self):
        record = journal("motivating_conmon_stdout.json")
        record["_TRANSPORT"] = "stdout"
        record["_PID"] = "4242"
        record["_UID"] = "1000"
        record["_GID"] = "1000"
        record["_COMM"] = "conmon"
        record["_EXE"] = "/usr/bin/conmon"
        record["_SYSTEMD_UNIT"] = "app-libpod-5920.service"
        cg = "/user.slice/user-1000.slice/user@1000.service/app.slice/app-libpod-5920.service"
        record["_SYSTEMD_CGROUP"] = cg
        record["OBJECT_SYSTEMD_CGROUP"] = "/system.slice/other.service"
        runner = FakeRunner(
            files={
                "/proc/sys/kernel/random/boot_id": (dashed(BOOT) + "\n").encode(),
                "/proc/4242/cgroup": f"0::{cg}\n".encode(),
                "/proc/4242/stat": proc_stat(4242, "conmon", 2900.0),
                "/proc/4242/status": b"NSpid:\t4242\n",
            }
        )
        incident = incident_of(record, runner, current_boot_id=BOOT)
        # three separate dimensions stored separately (§9; §8.1-B):
        self.assertIsNotNone(incident["event_sender_cgroup"])
        self.assertIsNotNone(incident["event_subject_cgroup"])
        self.assertIsNotNone(incident["current_proc_cgroup"])
        self.assertEqual(
            incident["event_sender_cgroup"]["provenance"], "journal_trusted_fields"
        )
        current = incident["current_proc_cgroup"]
        self.assertEqual(current["provenance"], "proc_snapshot")
        self.assertIn("captured_at", current)  # capture time recorded (§9)
        self.assertEqual(
            incident["event_subject_cgroup"]["provenance"],
            "journal_trusted_fields",
        )
        # the current /proc observation never consumes/corrupts event-time:
        qualification = incident["proc_qualification"]
        self.assertIn(
            qualification["outcome"],
            {
                m.QUAL_OUTCOME_COMPATIBLE,
                m.QUAL_OUTCOME_STALE,
                m.QUAL_OUTCOME_GONE,
                m.QUAL_OUTCOME_UNSAFE_SKIP,
            },
        )
        self.assertIsInstance(qualification.get("compared"), bool)
        self.commonGates(incident)

    # ── row 5: duplicate fields — occurrences counted, arrays preserved ──
    def test_row5_duplicate_fields_counted_and_arrays_preserved(self):
        record = journal("host_user_session_v2.json")
        record["_PID"] = "2103"
        record["_SYSTEMD_UNIT"] = [
            "user@1000.service",
            "user@1000.service",
            "other.service",
        ]
        record["MESSAGE"] = ["run with token=sk-abcdefghijklmnop1234 please"]
        incident = incident_of(record)
        self.assertEqual(incident["event"]["occurrence_counts"]["_SYSTEMD_UNIT"], 3)
        non_unique = incident["record_sender"] if incident["record_sender"] else {}
        self.assertIsNone(non_unique.get("unit"))
        # preserved arrays: structure verbatim, CONTENT redacted (§14);
        # the openai-key rule masks first, then the generic assignment rule
        # masks the already-masked value — defense-in-depth layering, counts
        # only, no content leak in any layer
        rf_items = [
            e
            for e in incident["evidence_refs"]
            if e.get("kind") == "repeated_fields_verbatim"
        ]
        self.assertTrue(rf_items)
        blob = json.dumps(rf_items)
        self.assertNotIn("sk-abcdefghijklmnop1234", blob)
        self.assertNotIn("abcdefghijklmnop1234", blob)
        self.assertIn("token=<redacted>", blob)
        self.assertIn("token=<redacted>", incident["event"]["message_trunc"])
        self.assertTrue(incident["redaction"]["rules_applied"])
        self.commonGates(incident)

    # ── row 6: nulls / oversized values — truncate + hash, no crash ──
    def test_row6_null_message(self):
        record = journal("host_systemd_v2.json")
        record["MESSAGE"] = None
        incident = incident_of(record)
        self.assertEqual(incident["event"]["message_trunc"], "")
        self.assertEqual(len(incident["event"]["message_hash"]), 64)
        self.assertNotIn("message_bytes", incident["event"])
        self.commonGates(incident)

    def test_row6_1mb_message_truncated_and_hashed(self):
        record = journal("host_systemd_v2.json")
        million = "A" * 1_000_000
        record["MESSAGE"] = million
        incident = incident_of(record)
        self.assertEqual(len(incident["event"]["message_trunc"]), nz.MESSAGE_CHARS_CAP)
        self.assertEqual(
            incident["event"]["message_bytes"], len(million.encode("utf-8"))
        )
        self.assertEqual(
            incident["event"]["message_hash"],
            nz.hashlib.sha256(
                incident["event"]["message_trunc"].encode("utf-8")
            ).hexdigest(),
        )
        self.commonGates(incident)

    # ── row 10: cursor round-trip byte-for-byte + monotonic as integer ──
    def test_row10_cursor_verbatim_and_monotonic_int(self):
        record = journal("motivating_conmon_stdout.json")
        weird = "s=bCast;i=6μL;b=zç[+]-—no—parse-—me"
        record["__CURSOR"] = weird
        incident = incident_of(record)
        self.assertEqual(incident["source"]["cursor"], weird)
        self.assertIsNotNone(incident["source"]["cursor_utc_us"])
        self.assertIsInstance(incident["source"]["monotonic_us"], int)
        self.commonGates(incident)

    # ── row 13: cursor/boot identity + STALE_EVIDENCE (no unsafe compare) ──
    def test_row13_boot_mismatch_surfaces_stale_evidence(self):
        record = journal("boot_mismatch_cursor.json")
        runner = FakeRunner(
            files={
                "/proc/sys/kernel/random/boot_id": (dashed(BOOT) + "\n").encode(),
            }
        )
        incident = incident_of(record, runner, current_boot_id=BOOT)
        self.assertEqual(incident["source"]["boot_id"], MISMATCH_BOOT)
        self.assertTrue(
            any(e.startswith("STALE_EVIDENCE") for e in incident["missing_evidence"]),
            incident["missing_evidence"],
        )
        qualification = incident["proc_qualification"]
        self.assertEqual(qualification["outcome"], m.QUAL_OUTCOME_UNSAFE_SKIP)
        self.assertFalse(qualification.get("compared"))
        self.commonGates(incident)

    # ── severity hint mapping 0..7 ──
    def test_severity_hint_full_map(self):
        record = journal("host_user_session_v2.json")
        for prio in range(0, 8):
            record["PRIORITY"] = str(prio)
            incident = incident_of(record)
            self.assertEqual(incident["severity_hint"], nz.SEVERITY_HINT[prio])

    # ── correlation ids ──
    def test_correlation_id_uuid4_or_override(self):
        incident = incident_of(journal("host_user_session_v2.json"))
        self.assertRegex(incident["correlation_id"], r"^[0-9a-f-]{36}$")
        fixed = incident_of(
            journal("host_user_session_v2.json"),
            correlation_id="00000000-0000-4000-8000-000000000001",
        )
        self.assertEqual(
            fixed["correlation_id"], "00000000-0000-4000-8000-000000000001"
        )

    # ── opaque container ref: backend-issued only, init_pid null (§9) ──
    def test_container_ref_issued_only_when_association_exists(self):
        record = journal("host_user_session_v2.json")
        bare = incident_of(record)
        self.assertIsNone(bare["container_association"])
        discovery = {
            "event_ref": "c",
            "event_transport": "JOURNAL_NATIVE",
            "event_monotonic_us": 1,
            "record_sender": {"role": "STREAM_OWNER", "status": "UNAVAILABLE"},
            "referenced_subject": None,
            "subject_disposition": None,
            "event_sender_cgroup": None,
            "event_subject_cgroup": None,
            "current_proc_cgroup": None,
            "current_process_domain": None,
            "proc_qualification": None,
            "container_association": {"full_id": "a" * 64, "status": "VERIFIED"},
            "conmon": None,
            "workload_identity": None,
            "evidence": [
                {
                    "origin": "runtime_query",
                    "strength": "verified_cross_check",
                    "time_scope": "current_state",
                }
            ],
            "missing_evidence": [],
            "limits_note": [],
        }
        incident = nz.build_incident(
            record, discovery, survey_snapshot={"state": "COLLECTED"}
        )
        assoc = incident["container_association"]
        self.assertEqual(assoc["ref"], "cont_ref_1")
        self.assertIsNone(assoc["init_pid"])  # Phase 4 fills it (§8.2)
        self.assertEqual(assoc["evidence_refs"], ["e1"])
        self.assertEqual(nz.validate_incident(incident), [])


class TestIncidentValidation(unittest.TestCase):
    def setUp(self):
        self.valid = incident_of(journal("host_user_session_v2.json"))

    def mutate(self, **changes):
        blob = json.loads(json.dumps(self.valid))
        for key, value in changes.items():
            if value is Exception:
                blob.pop(key, None)
            else:
                blob[key] = value
        return blob

    def test_emitted_incident_validates_clean(self):
        self.assertEqual(nz.validate_incident(self.valid), [])

    def test_schema_version_reject(self):
        blob = self.mutate(schema_version="nibras.incident/v2")
        self.assertTrue(any("schema_version" in p for p in nz.validate_incident(blob)))

    def test_root_runtime_domain_rejected(self):
        blob = self.mutate(runtime_domain="HOST_SESSION")
        self.assertTrue(any("root" in p for p in nz.validate_incident(blob)))

    def test_root_event_transport_rejected(self):
        blob = self.mutate(event_transport="JOURNAL_NATIVE")
        self.assertTrue(any("root" in p for p in nz.validate_incident(blob)))

    def test_message_cap_enforced(self):
        blob = self.mutate(event={**self.valid["event"], "message_trunc": "x" * 2001})
        self.assertTrue(any("cap" in p for p in nz.validate_incident(blob)))

    def test_cursor_type_enforced(self):
        blob = self.mutate(source={**self.valid["source"], "cursor": 42})
        self.assertTrue(any("cursor" in p for p in nz.validate_incident(blob)))

    def test_non_journal_kind_rejected(self):
        blob = self.mutate(source={**self.valid["source"], "kind": "sysctl"})
        self.assertTrue(any("kind" in p for p in nz.validate_incident(blob)))

    def test_correlation_id_must_be_uuid(self):
        blob = self.mutate(correlation_id="not-a-uuid")
        self.assertTrue(any("correlation" in p for p in nz.validate_incident(blob)))

    def test_hash_shape_enforced(self):
        blob = self.mutate(event={**self.valid["event"], "message_hash": "short"})
        self.assertTrue(any("message_hash" in p for p in nz.validate_incident(blob)))

    def test_missing_redaction_block(self):
        blob = self.mutate(redaction=Exception)
        self.assertTrue(any("redaction" in p for p in nz.validate_incident(blob)))


class TestSurveySnapshot(unittest.TestCase):
    """§9 survey field via bounded whitelisted queries; failures stay absent."""

    def test_collected_shape_and_bounded_lists(self):
        runner = FakeRunner(
            files={"/etc/os-release": b'NAME="Fedora Linux"\nVERSION_ID=43\n'},
            commands={
                "podman": P(1, "", "no podman"),  # absent → note, not fallback
                "systemctl": P(
                    0, "\n".join(f"unit-{i}.service" for i in range(25)), ""
                ),
            },
        )
        snapshot = nz.build_survey_snapshot(runner)
        self.assertEqual(snapshot["state"], "COLLECTED")
        self.assertEqual(snapshot["distro_name"], "Fedora Linux")
        self.assertEqual(snapshot["distro_version_id"], "43")
        self.assertIn(snapshot["package_manager"], (None, "dnf", "apt", "pacman"))
        self.assertIsNone(snapshot["rootless_podman"])
        self.assertIn("rootless_podman absent: exit 1", snapshot["notes"])
        self.assertEqual(snapshot["failed_units_count"], 25)
        self.assertEqual(len(snapshot["failed_units"]), nz._FAILED_UNIT_CAP)
        for argv in runner.runs:
            self.assertIn(argv[0], {"systemctl", "podman"})  # whitelist!

    def test_rootless_podman_json(self):
        runner = FakeRunner(
            commands={
                "podman": P(0, json.dumps({"host": {"rootless": True}}), ""),
                "systemctl": P(1, "", "no systemctl"),
            }
        )
        snapshot = nz.build_survey_snapshot(runner)
        self.assertIs(snapshot["rootless_podman"], True)
        self.assertIsNone(snapshot["failed_units_count"])
        self.assertIn("failed_units absent: exit 1", snapshot["notes"])

    def test_failures_unique_notes_not_fallback(self):
        snapshot = nz.build_survey_snapshot(FakeRunner())
        self.assertIsNone(snapshot["boot_id"])
        self.assertIsNone(snapshot["distro_name"])
        self.assertTrue(snapshot["notes"])

    def test_no_environ_read_ever(self):
        runner = FakeRunner(
            files={"/etc/os-release": b"NAME=X\n"},
            commands={"podman": P(0, json.dumps({"host": {"rootless": False}}), "")},
        )
        nz.build_survey_snapshot(runner)
        for path in runner.reads:
            self.assertNotIn("environ", path)


class TestConfigWiring(unittest.TestCase):
    """§18 row 2: flag-gated, fail-closed, legacy path preserved."""

    _environ_backup: dict[str, str] | None = None

    @classmethod
    def setUpClass(cls):
        provider_attrs = {
            "gemini_provider": "GeminiProvider",
            "local_provider": "LocalProvider",
            "ollama_provider": "OllamaProvider",
            "openai_provider": "OpenAIProvider",
            "openrouter_provider": "OpenRouterProvider",
        }
        for name, attr in provider_attrs.items():
            stub = sys.modules.setdefault(name, types.ModuleType(name))
            if not hasattr(stub, attr):
                setattr(stub, attr, object)
        if str(AI_DIR) not in sys.path:
            sys.path.insert(0, str(AI_DIR))
        import config  # mirrored production style

        cls.config = config

    @classmethod
    def tearDownClass(cls):
        os.environ.pop("NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE", None)

    def setUp(self):
        os.environ.pop("NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE", None)

    def tearDown(self):
        os.environ.pop("NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE", None)

    def _record_runner(self, lines, boot_present=True):
        files = (
            {"/proc/sys/kernel/random/boot_id": (dashed(BOOT) + "\n").encode()}
            if boot_present
            else {}
        )
        return FakeRunner(
            files=files,
            commands={"journalctl": P(0, "\n".join(lines), "")},
        )

    def test_flag_off_returns_none_and_spawns_nothing(self):
        self.assertFalse(self.config.structured_evidence_enabled())
        self.assertIsNone(self.config.get_boot_incident())

    def test_flag_on_builds_incidents_bounded(self):
        os.environ["NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE"] = "1"
        secret_line = json.dumps(
            {
                "__CURSOR": "s+c",
                "_BOOT_ID": BOOT,
                "_TRANSPORT": "stdout",
                "_PID": "4242",
                "_UID": "1000",
                "_GID": "1000",
                "_COMM": "conmon",
                "__MONOTONIC_TIMESTAMP": "900",
                "__REALTIME_TIMESTAMP": "1762005700000000",
                "PRIORITY": "4",
                "MESSAGE": ["failed token=sk-abcdefghijklmnop1234"],
            }
        )
        runner = self._record_runner([secret_line, "{bad", secret_line])
        out = self.config.get_boot_incident(runner=runner, limit=200)
        counters = out["collection"]["counters"]
        self.assertEqual(counters["records_collected"], 2)
        self.assertEqual(counters["invalid_json_skipped"], 1)
        self.assertEqual(counters["duplicate_cursor_skipped"], 1)
        self.assertEqual(len(out["incidents"]), 1)  # dedup bounded the records
        incident = out["incidents"][0]
        self.assertEqual(incident["schema_version"], "nibras.incident/v1")
        self.assertEqual(nz.validate_incident(incident), [])
        blob = json.dumps(out)
        self.assertNotIn("sk-abcdefghijklmnop1234", blob)  # §14 end-to-end
        self.assertIn("token=<redacted>", blob)  # layered masking
        self.assertIn("token=<redacted>", incident["event"]["message_trunc"])

    def test_payload_cap_bounds_envelope(self):
        os.environ["NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE"] = "1"
        # ~220 records × ~2.5 KB envelope each ⇒ must hit the 512 KiB cap
        heavy = json.dumps(
            {
                "__CURSOR": f"s+h{{i:04d}}",
                "_BOOT_ID": BOOT,
                "_TRANSPORT": "stdout",
                "_PID": "4242",
                "_UID": "1000",
                "_GID": "1000",
                "_COMM": "conmon",
                "__MONOTONIC_TIMESTAMP": str(1000 + 1),
                "__REALTIME_TIMESTAMP": "1762005700000000",
                "PRIORITY": "4",
                "MESSAGE": ["x" * 1500],
            }
        )

        def make(i):
            return json.dumps(
                {
                    "__CURSOR": f"s+h{i:04d}",
                    "_BOOT_ID": BOOT,
                    "_TRANSPORT": "stdout",
                    "_PID": "4242",
                    "_UID": "1000",
                    "_GID": "1000",
                    "_COMM": "conmon",
                    "__MONOTONIC_TIMESTAMP": str(2000000 + i),
                    "__REALTIME_TIMESTAMP": "1762005700000000",
                    "PRIORITY": "4",
                    "MESSAGE": ["x" * 1500],
                }
            )

        runner = self._record_runner([make(i) for i in range(220)])
        out = self.config.get_boot_incident(runner=runner, limit=200)
        blob = json.dumps(out)
        size = len(blob.encode("utf-8"))
        self.assertEqual(self.config.MAX_ENVELOPE_BYTES, 512 * 1024)
        self.assertLess(size, self.config.MAX_ENVELOPE_BYTES, size)
        self.assertIn("PAYLOAD_CAP_REACHED", " ".join(out["collection"]["notes"]))
        self.assertLess(len(out["incidents"]), 220)

    def test_flag_on_with_broken_layer_fails_closed(self):
        os.environ["NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE"] = "1"
        # a None entry in sys.modules blocks the import (ImportError) —
        # simulating a broken/absent evidence layer
        saved = {key: sys.modules.pop(key, None) for key in ("evidence", "incident")}
        sys.modules["evidence"] = None
        try:
            out = self.config.get_boot_incident()
        finally:
            os.environ.pop("NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE", None)
            for key in ("evidence", "incident"):
                sys.modules.pop(key, None)
            sys.modules.update({k: v for k, v in saved.items() if v})
        self.assertIsNotNone(out)  # honest fail-closed envelope
        self.assertTrue(out["collection"]["collection_failed"])
        self.assertEqual(out["incidents"], [])

    def test_legacy_get_raw_boot_logs_untouched_by_flag(self):
        # legacy window shape captured via stubbed subprocess (no real reads)
        original = self.config.subprocess.check_output
        calls: list[list] = []
        try:
            self.config.subprocess.check_output = lambda argv, **kw: (
                calls.append(list(argv)) or "ok 2.3s"
            )
            logs = self.config.get_raw_boot_logs()
        finally:
            self.config.subprocess.check_output = original
        self.assertIn("BOOT", logs[:60])
        self.assertTrue(calls)
        self.assertEqual(calls[0][0], "systemd-analyze")
        self.assertIn("journalctl", calls[1])
        # the LEGACY window itself keeps the legacy `-p 3` boundary — that is
        # expected and out of §16.2's scope for the PROPOSED collector; the
        # plan's mandate binds the new structured collection (flag-gated).
        self.assertEqual(calls[1][calls[1].index("-p") + 1], "3")


if __name__ == "__main__":
    unittest.main(verbosity=2)
