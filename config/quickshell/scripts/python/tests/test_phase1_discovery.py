#!/usr/bin/env python3
# scripts/python/tests/test_phase1_discovery.py
"""Phase 1 runtime-discovery tests (§16.1 matrix — all rows, stdlib only).

Drives ai/evidence/discovery.py through the §16.1 24-row matrix plus the
row-4b conmon-verified variant, using ONLY synthetic journal fixtures and an
injectable FakeRunner (no real /proc writes, no real podman, no network, no
LLM). Every row's expectations come from:
- docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md §8.1–8.5 (rules),
- §16.1 rows 1–24 (this file's test methods, one per row),
- Phase-0 fixtures under fixtures/journal/ (rows 1, 2, 4, 16, 17, 21, 24).

Global meta-test at the end enforces two §8.5 shape gates on EVERY result
produced in this suite:
- no top-level "runtime_domain" key,
- no numeric "confidence" anywhere.
"""

import json
import os
import re
import sys
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent  # scripts/python
FIXTURES = BASE / "fixtures" / "journal"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ai.evidence import discovery as d  # noqa: E402

BOOT = "b0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0"  # Phase-0 same-boot id
MISMATCH_BOOT = "11111111222222223333333344444444"  # Phase-0 other-boot id
# motivating fixture container id (64 hex: 32x'f' + 32x'0') — exact string
MOTIV_CID = "ffffffffffffffffffffffffffffffff00000000000000000000000000000000"
WORKLOAD_CID = "a" * 64
CLK = os.sysconf("SC_CLK_TCK")  # never hard-coded (§8.3 step 4)


def journal(name: str) -> dict:
    with open(FIXTURES / name, encoding="utf-8") as fh:
        return json.load(fh)


def proc_stat(pid: int, comm: str, start_seconds: float) -> bytes:
    """Legal proc(5) stat line: 52 fields, comm in parens, starttime idx 19
    AFTER the closing paren (overall field 22), in clock ticks."""
    rest = ["S", "1", str(pid), str(pid), "0", "-1", "4194560"]
    rest += ["0"] * (19 - len(rest))  # indices 7..18
    rest.append(str(int(start_seconds * CLK)))  # index 19 = starttime
    rest += ["0"] * (52 - 22)  # remaining fields
    return f"{pid} ({comm}) ".encode() + " ".join(rest).encode()


class FakeRunner:
    """Injectable Runner (§16 interfaces): file dict + command dict + reads.

    files:   path -> bytes | Exception | None (None ⇒ FileNotFoundError)
    commands: argv[0] -> ProcResult | Exception | callable(argv) -> ProcResult
             (absent ⇒ FileNotFoundError, i.e. binary not installed)
    reads:   every read_file path, for zero-read assertions (row 16).
    """

    def __init__(self, files=None, commands=None):
        self.files = dict(files or {})
        self.commands = dict(commands or {})
        self.reads: list[str] = []
        self.runs: list[list[str]] = []

    # -- Runner protocol ---------------------------------------------------
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


def inspect_result(payload: dict) -> d.ProcResult:
    return d.ProcResult(0, json.dumps([payload]), "")


def base_record(**overrides) -> dict:
    """Synthetic same-boot journal record (motivating-shaped by default)."""
    rec = {
        "_TRANSPORT": "stdout",
        "PRIORITY": "4",
        "__CURSOR": "s+" + BOOT + ":0000000099",
        "__REALTIME_TIMESTAMP": "1733200099000000",
        "__MONOTONIC_TIMESTAMP": "2900000000",
        "_BOOT_ID": BOOT,
        "_MACHINE_ID": "0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f",
        "_HOSTNAME": "synthetic-host",
        "_PID": "18390",
        "_UID": "1000",
        "_GID": "1000",
        "_COMM": "conmon",
        "_EXE": "/usr/bin/conmon",
        "_SYSTEMD_UNIT": "user@1000.service",
        "_SYSTEMD_SLICE": "user-1000.slice",
        "_SYSTEMD_USER_UNIT": f"libpod-conmon-{WORKLOAD_CID}.scope",
        "_SYSTEMD_CGROUP": "/user.slice/user-1000.slice/user@1000.service/"
        f"user.slice/libpod-conmon-{WORKLOAD_CID}.scope",
        "MESSAGE": "synthetic (test-builder record)",
    }
    rec.update(overrides)
    return rec


def default_files(
    pid: int = 18390, cgroup: str | None = None, start_seconds: float = 2900.0
) -> dict:
    """/proc fixtures for a same-boot, still-alive, monotonic-compatible pid."""
    if cgroup is None:
        cgroup = (
            "0::/user.slice/user-1000.slice/user@1000.service/"
            f"user.slice/libpod-conmon-{MOTIV_CID}.scope"
        )
    return {
        d.BOOT_ID_PATH: BOOT.encode(),
        f"/proc/{pid}/cgroup": cgroup.encode(),
        f"/proc/{pid}/stat": proc_stat(pid, "conmon", start_seconds),
        f"/proc/{pid}/status": f"NSpid:\t{pid}\n".encode(),
    }


# ═════════════════════════════ §16.1 matrix ════════════════════════════════


def plain_record(**overrides) -> dict:
    """Synthetic plain host-service record: NO container scope anywhere.
    Used by rows exercising the present-day /proc side (7–16) so the only
    possible association candidates come from the CURRENT cgroup."""
    rec = {
        "_TRANSPORT": "journal",
        "PRIORITY": "4",
        "__CURSOR": "s+" + BOOT + ":0000000333",
        "__REALTIME_TIMESTAMP": "1733200033000000",
        "__MONOTONIC_TIMESTAMP": "2903000000",
        "_BOOT_ID": BOOT,
        "_MACHINE_ID": "0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f",
        "_HOSTNAME": "synthetic-host",
        "_PID": "4199",
        "_UID": "0",
        "_GID": "0",
        "_COMM": "svc",
        "_EXE": "/usr/bin/svc",
        "_SYSTEMD_UNIT": "svc.service",
        "_SYSTEMD_SLICE": "system.slice",
        "_SYSTEMD_CGROUP": "/system.slice/svc.service",
        "MESSAGE": "synthetic plain host service record (test-builder)",
    }
    rec.update(overrides)
    return rec


class Matrix(unittest.TestCase):
    maxDiff = None

    # -- results accumulate here for the final meta-test -------------------
    RESULTS: list[dict] = []

    def discover(self, record, runner=None, **kw):
        result = d.discover(record, runner, **kw)
        self.RESULTS.append(result)
        return result

    # ── §16.1 row 1: system service on host ───────────────────────────────
    def test_row01_host_system_service_event_time_attested(self):
        rec = journal("host_systemd_v2.json")
        runner = FakeRunner({d.BOOT_ID_PATH: BOOT.encode()})
        res = self.discover(rec, runner)
        claim = res["event_time_unit_claim"]
        self.assertEqual(claim["status"], "EVENT_TIME_ATTESTED")
        self.assertEqual(claim["scope"], "SYSTEM")
        self.assertEqual(claim["domain"], "HOST_SYSTEMD")
        self.assertEqual(res["record_sender"]["status"], "EVENT_TIME_ATTESTED")
        self.assertEqual(res["event_transport"], "JOURNAL_NATIVE")
        # no host fallback from current data: pid 721 unreadable ⇒ no current
        # claims; the failed snapshot attempt is retained with its reason
        self.assertIsNone(res["current_process_domain"])
        obs = res["current_proc_cgroup"]
        self.assertIsNone(obs["path"])
        self.assertIn("PID_NOT_FOUND", obs["reason_codes"])
        self.assertIn(
            "HISTORICAL_IDENTITY_UNAVAILABLE", res["proc_qualification"]["reason_codes"]
        )

    # ── §16.1 row 2: user session service ─────────────────────────────────
    def test_row02_host_user_session_scope_flags_user(self):
        rec = journal("host_user_session_v2.json")
        runner = FakeRunner({d.BOOT_ID_PATH: BOOT.encode()})
        res = self.discover(rec, runner)
        claim = res["event_time_unit_claim"]
        self.assertEqual(claim["status"], "EVENT_TIME_ATTESTED")
        self.assertEqual(claim["scope"], "USER")
        self.assertEqual(claim["domain"], "HOST_SESSION")
        sender = res["record_sender"]
        self.assertEqual(sender["unit"], "user@1000.service")
        self.assertEqual(sender["user_unit"], "app-synthetic-000.service")

    # ── §16.1 row 3: rootless podman workload (non-conmon scope) ─────────
    def test_row03_rootless_podman_workload_domain(self):
        rec = base_record(
            _COMM="python3",
            _EXE="/usr/bin/python3.13",
            _SYSTEMD_USER_UNIT=f"libpod-{WORKLOAD_CID}.scope",
            _SYSTEMD_CGROUP=(
                "/user.slice/user-1000.slice/user@1000.service/"
                f"user.slice/libpod-{WORKLOAD_CID}.scope"
            ),
            MESSAGE="synthetic workload journal record",
        )
        runner = FakeRunner(
            default_files(
                cgroup=(
                    "0::/user.slice/user-1000.slice/user@1000.service/"
                    f"user.slice/libpod-{WORKLOAD_CID}.scope"
                )
            ),
            {
                "podman": inspect_result(
                    {"Id": WORKLOAD_CID, "Name": "web", "State": {}}
                )
            },
        )
        res = self.discover(rec, runner)
        sender = res["record_sender"]
        self.assertEqual(sender["runtime_domain"], "PODMAN_CONTAINER")
        assoc = res["container_association"]
        self.assertEqual(assoc["status"], "VERIFIED")
        self.assertEqual(assoc["time_scope"], "event_time_association")
        self.assertEqual(assoc["full_id"], WORKLOAD_CID)
        self.assertIsNone(res["conmon"])
        # subject vs association separation: association alone never verifies
        self.assertEqual(res["workload_identity"]["state"], "UNKNOWN")
        # domain claim lives on the ENTITY, never top-level (§8.5)
        self.assertNotIn("runtime_domain", res)
        # conmon/cgroup invariants: no conmon-classification of the workload
        self.assertNotEqual(sender["role"], "CONMON")

    # ── §16.1 row 4: motivating conmon stream owner ──────────────────────
    def test_row04_motivating_conmon_stream_owner(self):
        rec = journal("motivating_conmon_stdout.json")
        runner = FakeRunner(
            default_files(),
            {
                "podman": inspect_result(
                    {"Id": MOTIV_CID, "Name": "open-webui", "State": {}}
                )
            },
        )
        res = self.discover(rec, runner)
        sender = res["record_sender"]
        self.assertEqual(sender["role"], "STREAM_OWNER")
        self.assertEqual(sender["role_candidate"], "CONMON")
        # sender's own domain stays host-side (user manager), NOT podman
        self.assertNotIn("runtime_domain", sender)
        claim = res["event_time_unit_claim"]
        self.assertEqual(claim["domain"], "HOST_SESSION")
        self.assertEqual(claim["scope"], "USER")
        self.assertEqual(claim["status"], "EVENT_TIME_ATTESTED")
        assoc = res["container_association"]
        self.assertEqual(assoc["status"], "VERIFIED")
        self.assertEqual(assoc["time_scope"], "event_time_association")
        self.assertEqual(assoc["full_id"], MOTIV_CID)
        # no runtime field ⇒ conmon role NOT asserted
        self.assertIsNone(res["conmon"])
        self.assertEqual(res["workload_identity"]["state"], "UNKNOWN")
        # SYSLOG_IDENTIFIER claims the workload but sender is conmon — kept
        # as an untrusted claimed field only
        self.assertEqual(sender["claimed"]["SYSLOG_IDENTIFIER"], "open-webui")

    # ── §16.1 row 4b: conmon verified through State.ConmonPid = sender ───
    def test_row04b_conmon_verified_by_runtime_field(self):
        rec = journal("motivating_conmon_stdout.json")
        runner = FakeRunner(
            default_files(),
            {
                "podman": inspect_result(
                    {
                        "Id": MOTIV_CID,
                        "Name": "open-webui",
                        "State": {"ConmonPid": 18390},
                    }
                )
            },
        )
        res = self.discover(rec, runner)
        conmon = res["conmon"]
        self.assertEqual(conmon["status"], "VERIFIED")
        self.assertEqual(conmon["pid"], 18390)
        self.assertEqual(conmon["source"], "runtime_field(State.ConmonPid)")
        self.assertEqual(res["record_sender"]["role"], "CONMON")
        # verified conmon still never verifies the workload identity
        self.assertEqual(res["workload_identity"]["state"], "UNKNOWN")

    # ── §16.1 row 5: inspect returns a DIFFERENT id ───────────────────────
    def test_row05_inspect_id_conflict(self):
        other = "b" * 64
        rec = base_record()
        runner = FakeRunner(
            default_files(),
            {"podman": inspect_result({"Id": other, "Name": "x", "State": {}})},
        )
        res = self.discover(rec, runner)
        assoc = res["container_association"]
        self.assertEqual(assoc["status"], "AMBIGUOUS")
        self.assertIn("EVIDENCE_CONFLICT", assoc["reason_codes"])
        self.assertNotIn("full_id", assoc)
        self.assertNotEqual(assoc.get("status"), "VERIFIED")
        self.assertNotIn("HOST_SYSTEMD", json.dumps(assoc))

    # ── §16.1 row 6: rootful engine, unprivileged caller ─────────────────
    def test_row06_rootful_context_never_host_nor_unsupported(self):
        rec = base_record(
            _COMM="python3",
            _EXE="/usr/bin/python3.13",
            _SYSTEMD_USER_UNIT=f"libpod-{WORKLOAD_CID}.scope",
            _SYSTEMD_CGROUP=(
                "/user.slice/user-1000.slice/user@1000.service/"
                f"user.slice/libpod-{WORKLOAD_CID}.scope"
            ),
        )
        for variant, command in (
            ("permission", PermissionError("podman")),
            (
                "rootful-stderr",
                d.ProcResult(
                    1, "", "Error: unable to connect to root-owned podman socket"
                ),
            ),
        ):
            with self.subTest(variant=variant):
                runner = FakeRunner(default_files(), {"podman": command})
                res = self.discover(dict(rec), runner)
                assoc = res["container_association"]
                self.assertEqual(assoc["status"], "UNAVAILABLE")
                allowed = {
                    "PERMISSION_DENIED",
                    "WRONG_RUNTIME_CONTEXT",
                    "RUNTIME_UNAVAILABLE",
                }
                self.assertTrue(
                    allowed & set(assoc["reason_codes"]), assoc["reason_codes"]
                )
                self.assertNotIn("UNSUPPORTED_RUNTIME", assoc["reason_codes"])
                # event-time host classification untouched; NO host fallback,
                # NO podman domain added from the failure
                self.assertNotEqual(
                    res["record_sender"].get("runtime_domain"), "HOST_SYSTEMD"
                )
                self.assertNotIn("runtime_domain", res)

    # ── §16.1 row 7: cgroup v1, multi-line host pid ──────────────────────
    def test_row07_cgroup_v1_host_multi_line_membership(self):
        rec = plain_record(_PID="4100", _COMM="svc", _EXE="/usr/bin/svc")
        cg = "2:cpu:/system.slice/foo.service\n5:memory:/system.slice/foo.service\n"
        runner = FakeRunner(
            {
                **default_files(pid=4100, cgroup=""),
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4100/cgroup": cg.encode(),
            },
        )
        res = self.discover(rec, runner)
        obs = res["current_proc_cgroup"]
        self.assertEqual(obs["cgroup_format"], "v1")
        self.assertEqual(len(obs["memberships"]), 2)
        paths = {mem["path"] for mem in obs["memberships"]}
        self.assertEqual(paths, {"/system.slice/foo.service"})
        dom = res["current_process_domain"]
        self.assertEqual(dom["candidate"], "HOST_SYSTEMD")
        # snapshot alone must NOT verify (needs independent query, §8.2)
        self.assertEqual(dom["status"], "AMBIGUOUS")

    # ── §16.1 rows 8: cgroup v1 workload pid, current-state verified ─────
    def test_row08_cgroup_v1_workload_current_verified(self):
        rec = plain_record(_PID="4100", _COMM="python3", _EXE="/usr/bin/python3.13")
        cg = (
            f"11:cpuset:/machine.slice/libpod-{WORKLOAD_CID}.scope\n"
            f"3:cpu,cpuacct:/machine.slice/libpod-{WORKLOAD_CID}.scope\n"
            f"6:memory:/machine.slice/libpod-{WORKLOAD_CID}.scope\n"
        )
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4100/cgroup": cg.encode(),
                "/proc/4100/stat": proc_stat(4100, "python3", 2900.0),
            },
            {"podman": inspect_result({"Id": WORKLOAD_CID, "Name": "w", "State": {}})},
        )
        res = self.discover(rec, runner)
        obs = res["current_proc_cgroup"]
        self.assertEqual(len(obs["memberships"]), 3)
        self.assertEqual(obs["cgroup_format"], "v1")
        assoc = res["container_association"]
        self.assertEqual(assoc["status"], "CURRENT_RUNTIME_VERIFIED")
        self.assertEqual(assoc["time_scope"], "current_state")
        self.assertEqual(assoc["source"], "current_proc_cgroup")
        dom = res["current_process_domain"]
        self.assertEqual(dom["candidate"], "PODMAN_CONTAINER")
        self.assertEqual(dom["status"], "CURRENT_RUNTIME_VERIFIED")
        # nothing current leaked into event-time claims: the event side
        # says exactly what the trusted journal fields attest (plain service)
        self.assertEqual(res["event_time_unit_claim"]["status"], "EVENT_TIME_ATTESTED")
        self.assertEqual(res["event_time_unit_claim"]["domain"], "HOST_SYSTEMD")

    # ── §16.1 row 9: cgroup v2 unified line ──────────────────────────────
    def test_row09_cgroup_v2_unified_host(self):
        rec = plain_record(_PID="4101", _COMM="svc2", _EXE="/usr/bin/svc2")
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4101/cgroup": b"0::/system.slice/example.service\n",
                "/proc/4101/stat": proc_stat(4101, "svc2", 2900.0),
            },
        )
        res = self.discover(rec, runner)
        obs = res["current_proc_cgroup"]
        self.assertEqual(obs["cgroup_format"], "v2")
        mem = obs["memberships"][0]
        self.assertEqual(mem["hierarchy"], 0)
        self.assertEqual(mem["controllers"], [])
        self.assertEqual(mem["path"], "/system.slice/example.service")
        dom = res["current_process_domain"]
        self.assertEqual(dom["candidate"], "HOST_SYSTEMD")
        self.assertEqual(dom["status"], "AMBIGUOUS")

    # ── §16.1 row 10: "(deleted)" suffix ──────────────────────────────────
    def test_row10_deleted_suffix_stripped_flagged(self):
        rec = plain_record(_PID="4102")
        cg = (
            "0::/user.slice/user-1000.slice/user@1000.service/"
            f"user.slice/libpod-conmon-{MOTIV_CID}.scope (deleted)\n"
        )
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4102/cgroup": cg.encode(),
                "/proc/4102/stat": proc_stat(4102, "conmon", 2900.0),
            },
            {"podman": inspect_result({"Id": MOTIV_CID, "State": {}})},
        )
        res = self.discover(rec, runner)
        obs = res["current_proc_cgroup"]
        self.assertTrue(obs["removed_cgroup"])
        self.assertEqual(
            obs["memberships"][0]["path"],
            f"/user.slice/user-1000.slice/user@1000.service/"
            f"user.slice/libpod-conmon-{MOTIV_CID}.scope",
        )
        # observation kept, but no domain / association derived from a
        # removed cgroup (§8.4)
        self.assertIsNone(res["current_process_domain"])
        self.assertIsNone(res["container_association"])
        self.assertEqual(res["proc_qualification"]["outcome"], "COMPATIBLE")

    # ── §16.1 row 11: empty / missing cgroup ─────────────────────────────
    def test_row11_empty_or_missing_cgroup_never_host(self):
        rec = plain_record(_PID="4103", _COMM="gone", _EXE="/usr/bin/gone")
        # no trusted unit/cgroup fields at all ⇒ no event-time host claim
        for key in ("_SYSTEMD_UNIT", "_SYSTEMD_SLICE", "_SYSTEMD_CGROUP"):
            rec.pop(key, None)
        for variant, files in (
            (
                "absent-file",
                {
                    d.BOOT_ID_PATH: BOOT.encode(),
                    "/proc/4103/stat": proc_stat(4103, "gone", 2900.0),
                },
            ),
            (
                "v2-root",
                {
                    d.BOOT_ID_PATH: BOOT.encode(),
                    "/proc/4103/cgroup": b"0::/\n",
                    "/proc/4103/stat": proc_stat(4103, "gone", 2900.0),
                },
            ),
            (
                "bare-slash",
                {
                    d.BOOT_ID_PATH: BOOT.encode(),
                    "/proc/4103/cgroup": b"/\n",
                    "/proc/4103/stat": proc_stat(4103, "gone", 2900.0),
                },
            ),
        ):
            with self.subTest(variant=variant):
                res = self.discover(dict(rec), FakeRunner(dict(files)))
                obs = res["current_proc_cgroup"]
                self.assertIsNotNone(obs)
                self.assertIn("INSUFFICIENT_EVIDENCE", obs["reason_codes"])
                self.assertIsNone(res["current_process_domain"])
                blob = json.dumps(res)
                self.assertNotIn("HOST_SYSTEMD", blob)
                self.assertNotIn("HOST_SESSION", blob)
                self.assertNotIn("PODMAN_CONTAINER", blob)

    # ── §16.1 row 12: inaccessible /proc/<pid>/cgroup ─────────────────────
    def test_row12_permission_denied_cgroup(self):
        rec = base_record(_PID="4104", _COMM="svc3", _EXE="/usr/bin/svc3")
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4104/cgroup": PermissionError("/proc/4104/cgroup"),
                "/proc/4104/stat": proc_stat(4104, "svc3", 2900.0),
            },
        )
        res = self.discover(rec, runner)
        obs = res["current_proc_cgroup"]
        self.assertIn("PERMISSION_DENIED", obs["reason_codes"])
        self.assertIsNone(res["current_process_domain"])
        # qualification can still proceed independently (stat was readable)
        self.assertEqual(res["proc_qualification"]["outcome"], "COMPATIBLE")
        blob = json.dumps(res)
        self.assertNotIn("HOST_SYSTEMD", blob)

    # ── §16.1 row 13: current instance started AFTER the event ───────────
    def test_row13_stale_current_instance_no_binding(self):
        rec = plain_record(
            _PID="4105",
            _COMM="worker",
            _EXE="/usr/bin/worker",
            __MONOTONIC_TIMESTAMP="2000000000",
        )  # 2000 s
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4105/cgroup": (
                    "0::/user.slice/user-1000.slice/user@1000.service/"
                    f"user.slice/libpod-{WORKLOAD_CID}.scope\n"
                ).encode(),
                "/proc/4105/stat": proc_stat(4105, "worker", 2600.0),
            },
            {"podman": inspect_result({"Id": WORKLOAD_CID, "State": {}})},
        )
        res = self.discover(rec, runner)
        qual = res["proc_qualification"]
        self.assertEqual(qual["outcome"], "STALE_CURRENT_INSTANCE")
        self.assertIn("STALE_CURRENT_INSTANCE", qual["reason_codes"])
        self.assertTrue(qual["compared"])
        # /proc metadata NOT attached; no target binding from this PID
        self.assertIsNone(res["current_process_domain"])
        self.assertIsNone(res["container_association"])
        # /proc metadata NOT attached; no target binding from this PID:
        # inspect never executed, no current claims derived
        self.assertEqual(runner.runs, [])
        # event-time claims remain exactly what the journal attests
        claim = res["event_time_unit_claim"]
        self.assertEqual(claim["status"], "EVENT_TIME_ATTESTED")
        self.assertEqual(claim["domain"], "HOST_SYSTEMD")

    # ── §16.1 row 14: start earlier ⇒ compatibility only ─────────────────
    def test_row14_compat_only(self):
        rec = plain_record(
            _PID="4106",
            _COMM="worker2",
            _EXE="/usr/bin/worker2",
            __MONOTONIC_TIMESTAMP="3000000000",
        )  # 3000 s
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4106/cgroup": b"0::/system.slice/late.service\n",
                "/proc/4106/stat": proc_stat(4106, "worker2", 2900.0),
            },
        )
        res = self.discover(rec, runner)
        qual = res["proc_qualification"]
        self.assertEqual(qual["outcome"], "COMPATIBLE")
        self.assertTrue(qual.get("compat_only"))
        self.assertTrue(qual["compared"])
        # current-state claim may exist but is snapshot-only (AMBIGUOUS),
        # and never leaks into the event-time side
        dom = res["current_process_domain"]
        self.assertEqual(dom["candidate"], "HOST_SYSTEMD")
        self.assertEqual(dom["status"], "AMBIGUOUS")
        self.assertEqual(dom["time_scope"], "current_state")

    # ── §16.1 row 15: pid died between reads ──────────────────────────────
    def test_row15_pid_gone_observation_retained(self):
        rec = plain_record(_PID="4107", _COMM="gone2", _EXE="/usr/bin/gone2")
        runner = FakeRunner(
            {
                d.BOOT_ID_PATH: BOOT.encode(),
                "/proc/4107/cgroup": b"0::/system.slice/dying.service\n",
                "/proc/4107/stat": None,
            },  # ENOENT: died between reads
        )
        res = self.discover(rec, runner)
        qual = res["proc_qualification"]
        self.assertEqual(qual["outcome"], "GONE")
        self.assertIn("HISTORICAL_IDENTITY_UNAVAILABLE", qual["reason_codes"])
        self.assertIsNone(res["current_process_domain"])
        self.assertIsNone(res["container_association"])
        obs = res["current_proc_cgroup"]
        # observation captured while examining is retained, present-day only
        self.assertIsNotNone(obs)
        self.assertFalse(obs["pid_present_at_capture"])
        self.assertIn("PID_NOT_FOUND", obs["reason_codes"])
        self.assertIn("proc_snapshot", obs["provenance"])
        # the record itself stays valid
        self.assertEqual(res["event_time_unit_claim"]["status"], "EVENT_TIME_ATTESTED")

    # ── §16.1 row 16: boot mismatch / missing monotonic ──────────────────
    def test_row16_boot_mismatch_and_missing_monotonic(self):
        # variant 1: real other-boot fixture ⇒ ZERO /proc reads at all
        rec = journal("boot_mismatch_cursor.json")
        runner = FakeRunner({d.BOOT_ID_PATH: BOOT.encode()})
        res = self.discover(rec, runner)
        qual = res["proc_qualification"]
        self.assertEqual(qual["outcome"], "UNSAFE_SKIP")
        self.assertFalse(qual["compared"])
        proc_reads = [p for p in runner.reads if re.fullmatch(r"/proc/\d+/.*", p)]
        self.assertEqual(proc_reads, [])
        self.assertIn("same_boot_state", res["missing_evidence"])
        # variant 2: same boot but monotonic missing ⇒ also unsafe skip
        rec2 = plain_record()
        del rec2["__MONOTONIC_TIMESTAMP"]
        runner2 = FakeRunner(default_files(pid=4199))
        res2 = self.discover(rec2, runner2)
        self.assertEqual(res2["proc_qualification"]["outcome"], "UNSAFE_SKIP")
        self.assertFalse(res2["proc_qualification"]["compared"])
        self.assertIn("__MONOTONIC_TIMESTAMP", res2["missing_evidence"])

    # ── §16.1 row 17: missing sender fields ──────────────────────────────
    def test_row17_unknown_sender_never_kernel_claim(self):
        rec = journal("unknown_sender_minimal.json")
        res = self.discover(rec, FakeRunner())
        sender = res["record_sender"]
        self.assertEqual(sender["role"], "UNKNOWN")
        self.assertEqual(sender["status"], "UNAVAILABLE")
        self.assertIn("INSUFFICIENT_EVIDENCE", sender["reason_codes"])
        self.assertEqual(res["event_transport"], "KERNEL")
        self.assertEqual(res.get("subject_disposition"), "NOT_APPLICABLE")
        blob = json.dumps(res)
        self.assertNotIn('"KERNEL"', blob.replace('"event_transport": "KERNEL"', ""))
        self.assertNotIn("HOST_SYSTEMD", blob)
        self.assertNotIn("HOST_SESSION", blob)

    # ── §16.1 row 18: runtime query timeout ──────────────────────────────
    def test_row18_inspect_timeout(self):
        rec = base_record()
        runner = FakeRunner(
            default_files(), {"podman": TimeoutError("inspect deadline")}
        )
        res = self.discover(rec, runner)
        assoc = res["container_association"]
        self.assertEqual(assoc["status"], "UNAVAILABLE")
        self.assertIn("TIMEOUT", assoc["reason_codes"])
        self.assertIn("RUNTIME_UNAVAILABLE", assoc["reason_codes"])
        blob = json.dumps(res)
        self.assertNotIn("HOST_SYSTEMD", blob)
        self.assertNotEqual(assoc.get("status"), "VERIFIED")

    # ── §16.1 row 19: container ref binding primitives ───────────────────
    def test_row19_container_ref_name_never_verified(self):
        assoc = {"full_id": WORKLOAD_CID}
        self.assertEqual(d.validate_container_ref(WORKLOAD_CID, assoc), ("MATCH", []))
        other = "c" * 64
        verdict, reasons = d.validate_container_ref(other, assoc)
        self.assertEqual(verdict, "REJECTED")
        self.assertIn("EVIDENCE_CONFLICT", reasons)
        verdict, reasons = d.validate_container_ref("my-fancy-container", assoc)
        self.assertEqual(verdict, "NAME_ONLY")
        self.assertNotEqual(verdict, "MATCH")
        self.assertIn("INSUFFICIENT_EVIDENCE", reasons)
        # no binding to compare against ⇒ unavailable, never a name match
        verdict, _ = d.validate_container_ref("my-fancy-container", {})
        self.assertEqual(verdict, "UNAVAILABLE")
        # full-hex ref without binding ⇒ rejected (no cross-check basis)
        verdict, reasons = d.validate_container_ref(WORKLOAD_CID, {})
        self.assertEqual(verdict, "REJECTED")
        self.assertIn("INSUFFICIENT_EVIDENCE", reasons)

    # ── §16.1 row 20: SYSTEM vs USER scope of same basename ──────────────
    def test_row20_system_vs_user_same_basename(self):
        sys_rec = base_record(
            _SYSTEMD_UNIT="shared.service",
            _SYSTEMD_USER_UNIT=None,
            _SYSTEMD_CGROUP="/system.slice/shared.service",
        )
        usr_rec = base_record(
            _SYSTEMD_UNIT="user@1000.service",
            _SYSTEMD_USER_UNIT="shared.service",
            _SYSTEMD_CGROUP=(
                "/user.slice/user-1000.slice/user@1000.service/"
                "user.slice/shared.service"
            ),
        )
        sys_res = self.discover(sys_rec, FakeRunner())
        usr_res = self.discover(usr_rec, FakeRunner())
        self.assertEqual(sys_res["event_time_unit_claim"]["scope"], "SYSTEM")
        self.assertEqual(sys_res["event_time_unit_claim"]["domain"], "HOST_SYSTEMD")
        self.assertEqual(usr_res["event_time_unit_claim"]["scope"], "USER")
        self.assertEqual(usr_res["event_time_unit_claim"]["domain"], "HOST_SESSION")
        self.assertNotEqual(
            sys_res["event_time_unit_claim"]["domain"],
            usr_res["event_time_unit_claim"]["domain"],
        )

    # ── §16.1 row 21: audit record w/ trusted identity fields ────────────
    def test_row21_audit_trusted_identity(self):
        rec = journal("audit_trusted_identity.json")
        res = self.discover(rec, FakeRunner())
        self.assertEqual(res["event_transport"], "AUDIT")
        subject = res["referenced_subject"]
        self.assertIsNotNone(subject)
        self.assertEqual(subject["identity_source"], "trusted_audit_fields")
        self.assertEqual(subject["login_uid"], 1000)
        self.assertEqual(subject["audit_session"], 2)
        # body hints present but UNTRUSTED-labeled, never the identity
        hints = subject.get("untrusted_hints") or {}
        self.assertEqual(hints.get("pid"), 99999)
        self.assertIn("never", hints["_note"])
        self.assertNotEqual(subject["identity_source"], "content_derived_hints")
        # journald sender ≠ audited subject: both recorded separately
        self.assertEqual(res["record_sender"]["comm"], "systemd-journald")
        self.assertNotEqual(subject.get("pid"), 99999)

    # ── §16.1 row 22: audit body-only identity hints ─────────────────────
    def test_row22_audit_body_only_identity_unknown(self):
        rec = base_record(
            _TRANSPORT="audit",
            _PID="555",
            _UID="0",
            _GID="0",
            _COMM="systemd-journald",
            _EXE="/usr/lib/systemd/systemd-journald",
            _SYSTEMD_UNIT="systemd-journald.service",
            _SYSTEMD_CGROUP="/system.slice/systemd-journald.service",
            MESSAGE=(
                "SYNTHETIC audit(1733200014.000:55): pid=34455 uid=1000 "
                'comm=synthetic-tool exe="/usr/bin/synthetic-tool" (fixture)'
            ),
        )
        rec.pop("_AUDIT_LOGINUID", None)
        rec.pop("_AUDIT_SESSION", None)
        res = self.discover(rec, FakeRunner())
        subject = res["referenced_subject"]
        # body describes a process ⇒ subject EXISTS, never NOT_APPLICABLE
        self.assertIsNotNone(subject)
        self.assertNotEqual(res.get("subject_disposition"), "NOT_APPLICABLE")
        self.assertEqual(subject["identity_source"], "content_derived_hints")
        self.assertEqual(subject["status"], "UNAVAILABLE")
        self.assertIn("INSUFFICIENT_EVIDENCE", subject["reason_codes"])
        self.assertEqual(subject["untrusted_hints"]["pid"], 34455)
        # content hints can never be a VERIFIED basis
        self.assertNotEqual(subject["status"], "EVENT_TIME_ATTESTED")

    # ── §16.1 row 23: audit record with NO subject identity at all ───────
    def test_row23_audit_subjectless_not_applicable(self):
        rec = base_record(
            _TRANSPORT="audit",
            _PID="555",
            _UID="0",
            _GID="0",
            _COMM="systemd-journald",
            _EXE="/usr/lib/systemd/systemd-journald",
            _SYSTEMD_UNIT="systemd-journald.service",
            _SYSTEMD_CGROUP="/system.slice/systemd-journald.service",
            MESSAGE="SYNTHETIC audit(1733200016.000:77): op=rotate (fixture)",
        )
        rec.pop("_AUDIT_LOGINUID", None)
        rec.pop("_AUDIT_SESSION", None)
        res = self.discover(rec, FakeRunner())
        self.assertIsNone(res["referenced_subject"])
        self.assertEqual(res.get("subject_disposition"), "NOT_APPLICABLE")

    # ── §16.1 row 24: unit + cgroup = ONE journal evidence class ─────────
    def test_row24_shared_provenance_one_class(self):
        rec = journal("host_systemd_v2.json")
        res = self.discover(rec, FakeRunner())
        unit_entries = [
            e
            for e in res["evidence"]
            if "one record provenance" in e["provenance_note"]
        ]
        self.assertEqual(len(unit_entries), 1)
        note = unit_entries[0]["provenance_note"]
        # the single entry covers BOTH fields (never counted twice)
        self.assertIn("unit", note)
        self.assertIn("cgroup", note.lower())
        # and the sender-credential class is a separate claim type
        cred = [e for e in res["evidence"] if "credential" in e["provenance_note"]]
        self.assertEqual(len(cred), 1)


# ═══════════════════════ meta-test: §8.5 shape gates ═══════════════════════


class MetaShapeGates(unittest.TestCase):
    """§8.5 hard shape rules across a spread of records."""

    def _results(self):
        samples = [
            journal("motivating_conmon_stdout.json"),
            journal("host_systemd_v2.json"),
            journal("host_user_session_v2.json"),
            journal("audit_trusted_identity.json"),
            journal("unknown_sender_minimal.json"),
            journal("boot_mismatch_cursor.json"),
            base_record(_COMM="x"),
        ]
        inspect = inspect_result({"Id": MOTIV_CID, "State": {}})
        results = []
        for rec in samples:
            results.append(
                d.discover(rec, FakeRunner(default_files(), {"podman": inspect}))
            )
        return results

    def test_no_top_level_runtime_domain(self):
        for res in self._results():
            self.assertNotIn("runtime_domain", res)

    def test_no_numeric_confidence_anywhere(self):
        def walk(node):
            if isinstance(node, dict):
                self.assertNotIn("confidence", node)
                for value in node.values():
                    walk(value)
            elif isinstance(node, list):
                for value in node:
                    walk(value)

        for res in self._results():
            walk(res)


if __name__ == "__main__":
    unittest.main(verbosity=2)
