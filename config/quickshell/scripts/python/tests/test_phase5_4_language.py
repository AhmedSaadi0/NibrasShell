#!/usr/bin/env python3
# scripts/python/tests/test_phase5_4_language.py
"""Phase 5.4 — deterministic language propagation (Arabic/English).

Covers the repaired backend guidance localization and the V2 preferred-language
wiring without any provider request, Quickshell launch, or network access:

- update-review scope routing in English and Arabic (container / host / generic);
- all four guidance codes render in both languages without registry mutation;
- Arabic skeleton safety scanning still fails loudly on command-shaped text;
- ``OrchestratorRun._language_line()`` and the evidence/final message carriers;
- ``main._run_orchestrator_v2()`` forwards the parsed language to the
  orchestrator;
- V1 and V2 system-prompt substitution remove ``$aiPreferredLanguage``;
- language changes only presentation, never policy status/decision/binding.
"""

import contextlib
import copy
import importlib.util
import io
import json
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent  # scripts/python
AI_DIR = ROOT / "ai"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(AI_DIR) not in sys.path:
    # main.py imports its siblings FLAT: from config import …
    sys.path.insert(0, str(AI_DIR))

from ai.agent import contract as C  # noqa: E402
from ai.agent import orchestrator as ORC  # noqa: E402
from ai.agent import prompt_agent as P  # noqa: E402
from ai.policy import engine as E  # noqa: E402
from ai.policy import guidance_templates as G  # noqa: E402

FULL_ID = "a" * 64
CURSOR = "cur-opaque-0001"


# ─── fixtures (same backend envelope shape as the Phase-3/4 suites) ─────────


def make_incident(**overrides):
    incident = {
        "schema_version": C.INCIDENT_SCHEMA,
        "correlation_id": "00000000-0000-0000-0000-000000000001",
        "source": {
            "kind": "journal",
            "boot_id": "b0e0e0e0e0e0e0e0e0e0e0e0e0e0e0",
            "cursor": CURSOR,
            "cursor_utc_us": 1770000000000000,
            "monotonic_us": 60_000_000,
            "event_transport": "stdout/stderr",
            "priority": 3,
        },
        "event": {
            "message_hash": "d" * 64,
            "time_utc_us": 1770000000000000,
            "message_trunc": "systemd restart open-webui failed",
        },
        "record_sender": {"pid": 555, "comm": "journalctl"},
        "referenced_subject": None,
        "event_sender_cgroup": None,
        "event_subject_cgroup": None,
        "current_proc_cgroup": None,
        "current_process_domain": None,
        "proc_qualification": {
            "pid": 1234,
            "compared": True,
            "proc_start_ticks": 500,
            "tick_rate": 100,
            "event_monotonic_us": 60_000_000,
            "outcome": "COMPATIBLE",
        },
        "container_association": {
            "ref": "cont_ref_1",
            "runtime": "podman",
            "status": "VERIFIED",
            "time_scope": "current_state",
            "full_id": FULL_ID,
            "name": "webui",
            "image": "ghcr.io/open-webui",
            "evidence_refs": ["e2"],
        },
        "event_time_unit_claim": {
            "unit": "open-webui.service",
            "unit_field": "_SYSTEMD_UNIT",
            "scope": "SYSTEM",
            "status": "EVENT_TIME_ATTESTED",
            "time_scope": "event_time_association",
        },
        "conmon": None,
        "workload_identity": None,
        "evidence_refs": [
            {
                "id": "e1",
                "origin": "journal_trusted",
                "strength": "strong",
                "time_scope": "event_time",
                "desc": "trusted fields",
            },
            {
                "id": "e2",
                "origin": "runtime_query",
                "strength": "strong",
                "time_scope": "current_state",
                "desc": "podman inspect",
            },
        ],
        "missing_evidence": [],
        "survey_snapshot": {"state": "ABSENT"},
        "redaction": {"rules_applied": [], "items_redacted": 0},
        "severity_hint": "err",
        "limits_note": [],
    }
    for key, value in overrides.items():
        incident[key] = value
    return incident


NO_CLAIMS = {
    "container_association": None,
    "event_time_unit_claim": None,
    "proc_qualification": None,
}

BASE_FINDINGS = [
    {
        "id": "f1",
        "text": "container association present",
        "evidence_refs": ["e1"],
        "severity": "warning",
    },
]


_ABSENT = object()


def diagnosis(
    remediation=_ABSENT,
    ref="cont_ref_1",
    code="G_REVIEW_CONTAINER_SOT",
    rationale="review before any change",
    findings=None,
    action_kind="manual_guidance",
):
    if remediation is _ABSENT:
        remediation = {
            "action_kind": action_kind,
            "guidance_code": code,
            "target_ref": ref,
            "rationale": rationale,
            "risk_level": "low",
            "requires_user_confirmation": True,
        }
    return {
        "schema_version": C.SCHEMA_DIAGNOSIS,
        "response": {
            "incident_summary": "restart of open-webui.service failed",
            "findings": BASE_FINDINGS if findings is None else findings,
            "possible_causes": ["unit restart race"],
            "missing_evidence": ["workload identity"],
            "diagnostic_questions": ["is the unit enabled?"],
            "proposed_remediation": remediation,
            "uncertainties": ["no workload pid claim"],
        },
    }


def _registry(incident):
    return C.RefRegistry.from_incident(incident)


def _orchestrator(language):
    run_obj = ORC.OrchestratorRun(
        make_incident(),
        lambda message, history: ("{}", {}),
        None,
        model_call_deadline_s=10.0,
        incident_watchdog_s=60.0,
        tool_timeout_s=2.0,
        preferred_language=language,
    )
    return run_obj


# ─── update-review scope localization (D1/D2) ───────────────────────────────


class TestUpdateReviewScopeLocalization(unittest.TestCase):
    def _render(self, incident, language):
        return G.render(
            "G_SOFTWARE_UPDATE_REVIEW",
            None,
            incident,
            _registry(incident),
            language=language,
        )

    def _container_only(self):
        return make_incident(
            event_time_unit_claim=None, proc_qualification=None
        )

    def _unit_only(self):
        return make_incident(container_association=None, proc_qualification=None)

    def _generic(self):
        return make_incident(**NO_CLAIMS)

    def test_english_container_scope(self):
        out = self._render(self._container_only(), "English")
        self.assertIn("container-scoped", out["lines"][0])

    def test_english_host_package_scope(self):
        out = self._render(self._unit_only(), "English")
        self.assertIn("host-package scoped", out["lines"][0])

    def test_english_generic_scope(self):
        out = self._render(self._generic(), "English")
        self.assertIn("generic", out["lines"][0])

    def test_arabic_container_scope(self):
        out = self._render(self._container_only(), "Arabic")
        self.assertIn("ضمن نطاق الحاوية", out["lines"][0])
        self.assertNotIn("container-scoped", out["lines"][0])

    def test_arabic_host_package_scope(self):
        out = self._render(self._unit_only(), "Arabic")
        self.assertIn("ضمن نطاق حزم المضيف", out["lines"][0])
        self.assertNotIn("host-package scoped", out["lines"][0])

    def test_arabic_generic_scope(self):
        out = self._render(self._generic(), "Arabic")
        self.assertIn("عام", out["lines"][0])
        self.assertNotIn("generic", out["lines"][0])

    def test_arabic_update_review_has_no_english_scope_labels(self):
        for incident in (
            self._container_only(),
            self._unit_only(),
            self._generic(),
        ):
            with self.subTest(incident=incident["container_association"]):
                joined = "\n".join(self._render(incident, "Arabic")["lines"])
                for label in (
                    "container-scoped",
                    "host-package scoped",
                    "generic",
                ):
                    self.assertNotIn(label, joined)


# ─── all four codes, both languages, registry safety ────────────────────────


class TestGuidanceRegistryLocalization(unittest.TestCase):
    def _record(self, code, incident, reg):
        if code == "G_REVIEW_CONTAINER_SOT":
            return E._record_with_ref(reg, "cont_ref_1", incident)
        if code == "G_REVIEW_UNIT_STATE":
            return E._record_with_ref(reg, "unit_ref_1", incident)
        return None

    def test_all_four_codes_render_in_arabic(self):
        incident = make_incident()
        reg = _registry(incident)
        for code in (
            "G_EXPLAIN_ONLY",
            "G_REVIEW_CONTAINER_SOT",
            "G_REVIEW_UNIT_STATE",
            "G_SOFTWARE_UPDATE_REVIEW",
        ):
            with self.subTest(code=code):
                out = G.render(
                    code,
                    self._record(code, incident, reg),
                    incident,
                    reg,
                    language="Arabic",
                )
                self.assertEqual(out["guidance_code"], code)
                self.assertTrue(out["lines"])
                self.assertTrue(all(isinstance(line, str) and line for line in out["lines"]))
                self.assertNotIn("Backend guidance", "\n".join(out["lines"]))

    def test_all_four_codes_preserve_english_behavior(self):
        incident = make_incident()
        reg = _registry(incident)
        for code in (
            "G_EXPLAIN_ONLY",
            "G_REVIEW_CONTAINER_SOT",
            "G_REVIEW_UNIT_STATE",
            "G_SOFTWARE_UPDATE_REVIEW",
        ):
            with self.subTest(code=code):
                out = G.render(
                    code,
                    self._record(code, incident, reg),
                    incident,
                    reg,
                    language="English",
                )
                self.assertEqual(out["guidance_code"], code)
                self.assertIn("Backend guidance", out["lines"][0])

    def test_arabic_skeleton_safety_scan_runs(self):
        incident = make_incident()
        reg = _registry(incident)
        saved = list(G._STATIC_LINES_AR["G_EXPLAIN_ONLY"])
        try:
            G._STATIC_LINES_AR["G_EXPLAIN_ONLY"] = [
                "إرشاد خلفي: run dnf install now."
            ]
            with self.assertRaises(ValueError):
                G.render("G_EXPLAIN_ONLY", None, incident, reg, language="Arabic")
        finally:
            G._STATIC_LINES_AR["G_EXPLAIN_ONLY"] = saved

    def test_render_does_not_mutate_static_registries(self):
        incident = make_incident()
        reg = _registry(incident)
        saved_en = copy.deepcopy(G._STATIC_LINES)
        saved_ar = copy.deepcopy(G._STATIC_LINES_AR)
        saved_scopes = tuple(G._UPDATE_SCOPES)
        saved_scopes_ar = tuple(G._UPDATE_SCOPES_AR)

        for language in ("English", "Arabic"):
            for code in (
                "G_EXPLAIN_ONLY",
                "G_REVIEW_CONTAINER_SOT",
                "G_REVIEW_UNIT_STATE",
                "G_SOFTWARE_UPDATE_REVIEW",
            ):
                G.render(
                    code,
                    self._record(code, incident, reg),
                    incident,
                    reg,
                    language=language,
                )

        self.assertEqual(G._STATIC_LINES, saved_en)
        self.assertEqual(G._STATIC_LINES_AR, saved_ar)
        self.assertEqual(tuple(G._UPDATE_SCOPES), saved_scopes)
        self.assertEqual(tuple(G._UPDATE_SCOPES_AR), saved_scopes_ar)
        self.assertIsNot(
            G._skeleton("G_EXPLAIN_ONLY", "Arabic"),
            G._STATIC_LINES_AR["G_EXPLAIN_ONLY"],
        )


# ─── orchestrator language carriers ─────────────────────────────────────────


class TestV2LanguageCarriers(unittest.TestCase):
    def test_language_line_returns_arabic_directive(self):
        run_obj = _orchestrator("Arabic")
        try:
            line = run_obj._language_line()
        finally:
            run_obj.supervisor.close()
        self.assertIn("LANGUAGE: Respond strictly in Arabic.", line)
        self.assertIn("guidance_code", line)

    def test_language_line_empty_when_omitted(self):
        run_obj = _orchestrator(None)
        try:
            self.assertEqual(run_obj._language_line(), "")
        finally:
            run_obj.supervisor.close()

    def test_arabic_in_evidence_message_outside_data(self):
        run_obj = _orchestrator("Arabic")
        try:
            message = run_obj._evidence_message("A", None)
        finally:
            run_obj.supervisor.close()
        self.assertIn("LANGUAGE: Respond strictly in Arabic.", message)
        self.assertLess(
            message.index("LANGUAGE: Respond strictly in Arabic."),
            message.index("<incident>"),
        )
        self.assertIn("nibras.tool_request/v1", message)

    def test_arabic_in_final_message_outside_data(self):
        run_obj = _orchestrator("Arabic")
        try:
            message = run_obj._final_message(None)
        finally:
            run_obj.supervisor.close()
        self.assertIn("LANGUAGE: Respond strictly in Arabic.", message)
        self.assertLess(
            message.index("LANGUAGE: Respond strictly in Arabic."),
            message.index("<incident>"),
        )
        self.assertIn("nibras.diagnosis/v1", message)

    def test_json_contract_tokens_unchanged(self):
        run_obj = _orchestrator("Arabic")
        try:
            evidence = run_obj._evidence_message("A", None)
            final = run_obj._final_message(None)
        finally:
            run_obj.supervisor.close()
        for token in (
            "nibras.tool_request/v1",
            "request_id",
            "arguments",
            "stated_purpose",
            "cursor",
            "cont_ref_1",
        ):
            self.assertIn(token, evidence)
        for token in (
            "nibras.diagnosis/v1",
            "guidance_code",
            "target_ref",
            "evidence_refs",
            "severity",
            "risk_level",
            "action_kind",
            "cont_ref_1",
        ):
            self.assertIn(token, final)


# ─── main.py ↔ orchestrator wiring ──────────────────────────────────────────


def _install_provider_stubs():
    for name in ("google.generativeai", "openai", "ollama", "requests"):
        if name not in sys.modules:
            stub = types.ModuleType(name)
            if name == "openai":
                stub.OpenAI = object
            if name == "ollama":
                stub.Client = object
            if name == "google.generativeai":

                class _Types:
                    GenerationConfig = dict

                class _Gen:
                    GenerativeModel = object

                stub.configure = lambda **kw: None
                stub.types = _Types
            sys.modules[name] = stub


class TestMainLanguageWiring(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _install_provider_stubs()
        spec = importlib.util.spec_from_file_location(
            "nibras_main_phase54", AI_DIR / "main.py"
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        cls.main_mod = mod

    def test_main_passes_preferred_language_to_orchestrator(self):
        import agent.orchestrator as flat_orc

        mod = self.main_mod
        config_obj = mod.__dict__.get("config") or sys.modules.get("config")
        self.assertIsNotNone(config_obj)

        class StubProvider:
            def generate(self, message, history):
                return "{}", {}

        captured = {}

        def fake_run(incident, model_call, tool_runner=None, **kwargs):
            captured["kwargs"] = kwargs
            return {
                "success": True,
                "response": {
                    "response": {
                        "validation": {
                            "guidance_decision": {
                                "status": C.STATUS_GUIDANCE_VALIDATED
                            }
                        }
                    }
                },
                "updated_history": [],
                "error": "",
                "orchestrator": {"version": "v2", "model_calls_used": 0},
            }

        args = types.SimpleNamespace(
            orchestrator="v2",
            preferred_language="Arabic",
        )
        orig_provider = mod.get_provider
        orig_bundle = config_obj.get_boot_incident
        mod.get_provider = lambda *a, **k: StubProvider()
        config_obj.get_boot_incident = lambda runner=None, limit=200: {
            "collection": {},
            "incidents": [make_incident()],
        }
        buf = io.StringIO()
        try:
            with mock.patch.object(
                flat_orc, "run_orchestrator", side_effect=fake_run
            ):
                with contextlib.redirect_stdout(buf):
                    mod._run_orchestrator_v2(args)
        finally:
            mod.get_provider = orig_provider
            config_obj.get_boot_incident = orig_bundle

        self.assertEqual(captured["kwargs"].get("preferred_language"), "Arabic")
        envelope = json.loads(buf.getvalue())
        self.assertTrue(envelope["success"])
        src = (AI_DIR / "main.py").read_text(encoding="utf-8")
        self.assertIn("preferred_language=args.preferred_language", src)

    def test_v2_arabic_end_to_end_reaches_backend_guidance(self):
        mod = self.main_mod
        config_obj = mod.__dict__.get("config") or sys.modules.get("config")
        self.assertIsNotNone(config_obj)

        outputs = [
            json.dumps({"schema_version": C.SCHEMA_TOOL_REQUEST, "tool": None}),
            json.dumps({"schema_version": C.SCHEMA_TOOL_REQUEST, "tool": None}),
            json.dumps(
                diagnosis(
                    remediation={
                        "action_kind": "manual_guidance",
                        "guidance_code": "G_SOFTWARE_UPDATE_REVIEW",
                        "target_ref": None,
                        "rationale": "check update path",
                    }
                )
            ),
        ]

        class StubProvider:
            def generate(self, message, history):
                return outputs.pop(0), {}

        args = types.SimpleNamespace(
            orchestrator="v2",
            preferred_language="Arabic",
            api_key=None,
        )
        orig_provider = mod.get_provider
        orig_bundle = config_obj.get_boot_incident
        mod.get_provider = lambda *a, **k: StubProvider()
        config_obj.get_boot_incident = lambda runner=None, limit=200: {
            "collection": {},
            "incidents": [make_incident()],
        }
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                mod._run_orchestrator_v2(args)
        finally:
            mod.get_provider = orig_provider
            config_obj.get_boot_incident = orig_bundle

        envelope = json.loads(buf.getvalue())
        self.assertTrue(envelope["success"])
        self.assertEqual(envelope["orchestrator"]["version"], "v2")
        payload = envelope["response"]["response"]
        template = payload["guidance_template"]
        self.assertEqual(template["guidance_code"], "G_SOFTWARE_UPDATE_REVIEW")
        joined = "\n".join(template["lines"])
        self.assertIn("ضمن نطاق الحاوية", joined)
        self.assertNotIn("container-scoped", joined)


# ─── V1/V2 system-prompt substitution ───────────────────────────────────────


class TestSystemPromptSubstitution(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _install_provider_stubs()
        import config as config_mod
        import prompt as prompt_mod

        cls.config_mod = config_mod
        cls.prompt_mod = prompt_mod

    def _provider(self, language, system_prompt):
        args = types.SimpleNamespace(
            provider="local",
            api_key="fake",
            model="test-model",
            base_url=None,
            preferred_language=language,
            user_persona="",
        )
        return self.config_mod.get_provider(
            args, system_prompt, 0.1, True
        )

    def test_v1_and_v2_prompts_substitute_arabic(self):
        for label, system_prompt in (
            ("v2-agent", P.AGENT_SYSTEM_PROMPT_EN),
            ("v1-system-analyst", self.prompt_mod.SYSTEM_ANALYST_PROMPT),
        ):
            with self.subTest(prompt=label):
                llm = self._provider("Arabic", system_prompt)
                instruction = llm.system_instruction
                self.assertNotIn("$aiPreferredLanguage", instruction)
                self.assertIn("Respond strictly in Arabic", instruction)

    def test_v1_and_v2_prompts_substitute_english(self):
        for label, system_prompt in (
            ("v2-agent", P.AGENT_SYSTEM_PROMPT_EN),
            ("v1-system-analyst", self.prompt_mod.SYSTEM_ANALYST_PROMPT),
        ):
            with self.subTest(prompt=label):
                llm = self._provider("English", system_prompt)
                instruction = llm.system_instruction
                self.assertNotIn("$aiPreferredLanguage", instruction)
                self.assertIn("Respond strictly in English", instruction)


# ─── policy invariance: language changes presentation only ──────────────────


class TestPolicyInvariance(unittest.TestCase):
    def _evaluate(self, payload, incident, language):
        return E.evaluate_diagnosis(
            payload,
            _registry(incident),
            incident,
            preferred_language=language,
        )

    def _assert_presentation_only(self, en, ar):
        self.assertEqual(en["status"], ar["status"])
        self.assertEqual(en["decision"], ar["decision"])
        self.assertEqual(en["analysis"], ar["analysis"])
        self.assertEqual(
            en["template"]["guidance_code"], ar["template"]["guidance_code"]
        )
        self.assertEqual(
            en["template"]["target_ref"], ar["template"]["target_ref"]
        )
        en_meta = {k: v for k, v in en["template"].items() if k != "lines"}
        ar_meta = {k: v for k, v in ar["template"].items() if k != "lines"}
        self.assertEqual(en_meta, ar_meta)
        self.assertNotEqual(en["template"]["lines"], ar["template"]["lines"])

    def test_container_guidance_is_policy_invariant(self):
        incident = make_incident()
        en = self._evaluate(copy.deepcopy(diagnosis()), incident, "English")
        ar = self._evaluate(copy.deepcopy(diagnosis()), incident, "Arabic")
        self._assert_presentation_only(en, ar)
        self.assertEqual(en["status"], C.STATUS_GUIDANCE_VALIDATED)
        self.assertEqual(en["template"]["target_ref"], "cont_ref_1")
        self.assertIn("Backend guidance", en["template"]["lines"][0])
        self.assertIn("إرشاد خلفي", ar["template"]["lines"][0])

    def test_update_review_guidance_is_policy_invariant(self):
        incident = make_incident()
        payload = diagnosis(
            remediation={
                "action_kind": "manual_guidance",
                "guidance_code": "G_SOFTWARE_UPDATE_REVIEW",
                "target_ref": None,
                "rationale": "check update path",
            }
        )
        en = self._evaluate(copy.deepcopy(payload), incident, "English")
        ar = self._evaluate(copy.deepcopy(payload), incident, "Arabic")
        self.assertEqual(en["status"], C.STATUS_GUIDANCE_VALIDATED)
        self._assert_presentation_only(en, ar)
        self.assertIsNone(en["template"]["target_ref"])
        self.assertIn("container-scoped", en["template"]["lines"][0])
        self.assertIn("ضمن نطاق الحاوية", ar["template"]["lines"][0])

    def test_authorization_rejection_is_language_invariant(self):
        incident = make_incident()
        payload = diagnosis(
            ref="cont_ref_999",
            remediation={
                "action_kind": "manual_guidance",
                "guidance_code": "G_REVIEW_CONTAINER_SOT",
                "target_ref": "cont_ref_999",
                "rationale": "invented target",
            },
        )
        en = self._evaluate(copy.deepcopy(payload), incident, "English")
        ar = self._evaluate(copy.deepcopy(payload), incident, "Arabic")
        self.assertEqual(en["status"], C.STATUS_REJECTED)
        self.assertEqual(en["status"], ar["status"])
        self.assertEqual(en["decision"], ar["decision"])
        self.assertIsNone(en["template"])
        self.assertIsNone(ar["template"])


if __name__ == "__main__":
    unittest.main()
