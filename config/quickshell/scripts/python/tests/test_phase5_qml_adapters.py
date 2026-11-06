#!/usr/bin/env python3
# scripts/python/tests/test_phase5_qml_adapters.py
"""Phase 5 — QML adapter source contracts + golden UI envelopes.

There is no ``qmllint``/``qmltestrunner`` in this environment, so this suite
uses two deterministic checks:

1. golden JSON fixtures that freeze the legacy and ``nibras.diagnosis/v1``
   response shapes consumed by the QML adapter; and
2. source-contract assertions over the QML that implement the copy/quarantine
   boundary and the required status labels.

The manual runtime checklist lives in ``docs/diag-contract-notes.md`` (Phase 5
section). These tests do not claim that a QML process was launched.
"""

import json
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parent
FIXTURES = BASE / "fixtures"
LEGACY_DIR = FIXTURES / "legacy_envelope"
DIAGNOSIS_DIR = FIXTURES / "diagnosis_envelope"
REPO = BASE.parent.parent.parent

CLOSED_GUIDANCE_STATUSES = {
    "GUIDANCE_VALIDATED",
    "POLICY_REJECTED",
    "ANALYSIS_UNVERIFIED",
}
ALLOWED_ADAPTER_STATUSES = CLOSED_GUIDANCE_STATUSES | {
    "QUARANTINED_LEGACY",
    "STATUS_ABSENT",
}


def load(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def qml_text(relative_path):
    return (REPO / relative_path).read_text(encoding="utf-8")


class GoldenEnvelopeTests(unittest.TestCase):
    """Freeze the two adapter inputs without executing QML."""

    ENVELOPE_KEYS = {"success", "response", "updated_history", "error"}

    def test_unlabeled_legacy_fixture_keeps_legacy_shape(self):
        env = load(LEGACY_DIR / "boot_solution_legacy_unlabeled.json")
        self.assertEqual(set(env.keys()), self.ENVELOPE_KEYS)
        self.assertIs(env["success"], True)
        self.assertIsNone(env["error"])
        response = env["response"]
        self.assertNotIn("schema_version", response)
        self.assertEqual(len(response["solutions"]), 1)
        solution = response["solutions"][0]
        self.assertNotIn("difficulty", solution)
        self.assertNotIn("priority", solution)
        self.assertNotIn("validation", solution)
        self.assertTrue(solution["steps"])
        self.assertTrue(all("command" in step for step in solution["steps"]))

    def test_legacy_fixture_has_no_new_diagnosis_validation(self):
        env = load(LEGACY_DIR / "boot_solution_legacy.json")
        response = env["response"]
        self.assertNotIn("schema_version", response)
        for solution in response["solutions"]:
            self.assertNotIn("validation", solution)
            self.assertNotIn("runtime_domain", solution)
            self.assertNotIn("event_transport", solution)

    def test_diagnosis_fixture_shape_and_closed_statuses(self):
        env = load(DIAGNOSIS_DIR / "boot_solution_diagnosis_v1.json")
        self.assertEqual(set(env.keys()), self.ENVELOPE_KEYS)
        response = env["response"]
        self.assertEqual(response["schema_version"], "nibras.diagnosis/v1")
        self.assertEqual(len(response["solutions"]), 3)

        statuses = set()
        for solution in response["solutions"]:
            validation = solution["validation"]
            self.assertIn(validation["status"], ALLOWED_ADAPTER_STATUSES)
            statuses.add(validation["status"])
            self.assertIsInstance(validation["reasons"], list)
            self.assertNotIn("command", solution)
            self.assertNotIn("script", solution)
            self.assertNotIn("shell", solution)

        self.assertEqual(statuses, CLOSED_GUIDANCE_STATUSES)

    def test_diagnosis_fixture_separates_tool_and_guidance_decisions(self):
        env = load(DIAGNOSIS_DIR / "boot_solution_diagnosis_v1.json")
        response = env["response"]
        tool_decisions = response["validation"]["tool_decisions"]
        self.assertEqual(len(tool_decisions), 2)
        self.assertEqual(
            {decision["status"] for decision in tool_decisions},
            {"TOOL_REQUEST_ALLOWED", "POLICY_REJECTED"},
        )
        for decision in tool_decisions:
            self.assertEqual(decision["artifact"], "nibras.tool_request/v1")
            self.assertIn("reason_codes", decision)

        # A tool allowance must not appear as a guidance status.
        guidance_statuses = {
            solution["validation"]["status"] for solution in response["solutions"]
        }
        self.assertNotIn("TOOL_REQUEST_ALLOWED", guidance_statuses)

    def test_diagnosis_fixture_keeps_uncertainty_and_evidence(self):
        env = load(DIAGNOSIS_DIR / "boot_solution_diagnosis_v1.json")
        solutions = env["response"]["solutions"]
        rejected, validated, analysis_only = solutions

        self.assertEqual(rejected["validation"]["status"], "POLICY_REJECTED")
        self.assertTrue(rejected["identity_limits"])
        self.assertTrue(rejected["uncertainties"])
        self.assertTrue(rejected["missing_evidence"])
        self.assertTrue(rejected["evidence"])
        self.assertEqual(rejected["verification"]["status"], "AMBIGUOUS")
        self.assertEqual(rejected["guidance_lines"], [])
        self.assertEqual(rejected["steps"], [])

        self.assertEqual(validated["validation"]["status"], "GUIDANCE_VALIDATED")
        self.assertTrue(validated["guidance_lines"])
        self.assertEqual(validated["steps"], [])
        self.assertEqual(validated["verification"]["status"], "VERIFIED")

        self.assertEqual(analysis_only["validation"]["status"], "ANALYSIS_UNVERIFIED")
        self.assertEqual(analysis_only["guidance_lines"], [])
        self.assertEqual(analysis_only["steps"], [])


class QmlSourceContractTests(unittest.TestCase):
    """Static source contracts for environments without a QML test runner."""

    def test_boot_details_has_no_fail_open_enum_defaults(self):
        source = qml_text("windows/leftwindow/monitoring/components/BootDetails.qml")
        self.assertNotIn('modelData.difficulty || "easy"', source)
        self.assertNotIn('modelData.priority || "optional"', source)
        self.assertIn('difficulty: modelData.difficulty || ""', source)
        self.assertIn('priority: modelData.priority || ""', source)
        self.assertIn("diagnosisData: modelData", source)

    def test_solution_card_renders_explicit_statuses_and_unlabeled_values(self):
        source = qml_text("windows/leftwindow/monitoring/components/SolutionCard.qml")
        for label in (
            "QUARANTINED_LEGACY",
            "STATUS_ABSENT",
            "GUIDANCE_VALIDATED",
            "POLICY_REJECTED",
            "ANALYSIS_UNVERIFIED",
            "unlabeled",
            "runtime_domain",
            "event_transport",
            "identity_limits",
            "verification_status",
            "verification_time_scope",
            "guidance_lines",
            "validation_reasons",
        ):
            with self.subTest(label=label):
                self.assertIn(label, source)

    def test_solution_card_copy_is_gated_by_artifact_validation(self):
        source = qml_text("windows/leftwindow/monitoring/components/SolutionCard.qml")
        self.assertIn("readonly property bool canCopyGuidance", source)
        self.assertIn('validationStatus === "GUIDANCE_VALIDATED"', source)
        self.assertIn("validated: root.canCopyGuidance", source)
        steps_block = source.split("MODEL-PROPOSED STEPS — QUARANTINED", 1)[1]
        self.assertIn("validated: false", steps_block)

    def test_command_box_defaults_to_quarantine(self):
        source = qml_text("windows/leftwindow/monitoring/components/CommandBox.qml")
        self.assertIn("property bool validated: false", source)
        self.assertIn("visible: !root.validated", source)
        self.assertIn("visible: root.validated", source)
        self.assertIn("selectByMouse: true", source)
        self.assertIn("activeFocusOnPress: root.validated", source)
        self.assertIn("quarantineLabel", source)
        self.assertIn("unvalidated (legacy)", source)

    def test_observed_logs_have_no_copy_path(self):
        source = qml_text("windows/leftwindow/monitoring/components/BootDetails.qml")
        self.assertNotIn("wl-copy", source)
        self.assertNotIn("TextEdit", source)
        self.assertIn("textFormat: Text.PlainText", source)

    def test_boot_analyzer_has_explicit_adapters(self):
        source = qml_text("services/system/BootAnalyzer.qml")
        for token in (
            "nibras.diagnosis/v1",
            "QUARANTINED_LEGACY",
            "STATUS_ABSENT",
            "bootSolutionAdapter",
            "bootToolDecisions",
            "guidance_lines",
            "Array.isArray(data.solutions)",
            "data.response.solutions",
        ):
            with self.subTest(token=token):
                self.assertIn(token, source)

    def test_spike_analysis_remains_labeled_unverified(self):
        store = qml_text("services/analyzers/EventStore.qml")
        self.assertIn('aiAdapterStatus: "ANALYSIS_UNVERIFIED"', store)
        self.assertIn("aiVerificationStatus", store)
        self.assertIn("aiIdentityLimits", store)
        self.assertIn("aiUncertainties", store)

        header = qml_text("windows/leftwindow/monitoring/components/EventHeader.qml")
        self.assertIn("adapterStatus", header)

        analysis = qml_text(
            "windows/leftwindow/monitoring/components/EventAnalysis.qml"
        )
        self.assertIn("model-authored, unverified", analysis)
        self.assertIn("not backend-validated guidance", analysis)
        self.assertNotIn("wl-copy", analysis)
        self.assertNotIn("CommandBox", analysis)

    def test_boot_analyzer_reads_nested_policy_decision_and_template(self):
        source = qml_text("services/system/BootAnalyzer.qml")
        # The V2 envelope nests the authoritative decision and backend template
        # under response.response; the adapter must read those exact fields and
        # must never derive a template from model prose.
        self.assertIn("validationWrapper.guidance_decision", source)
        self.assertIn("payload.guidance_template", source)
        self.assertIn("validationWrapper.template", source)
        self.assertIn("template.lines", source)
        self.assertIn('validationStatus = "STATUS_ABSENT"', source)
        self.assertIn("guidance_lines: guidanceLines", source)

    def test_manual_checklist_is_documented(self):
        notes = (REPO / "docs/diag-contract-notes.md").read_text(encoding="utf-8")
        self.assertIn("Phase 5", notes)
        self.assertIn("Manual checklist", notes)
        for token in (
            "QUARANTINED_LEGACY",
            "GUIDANCE_VALIDATED",
            "POLICY_REJECTED",
            "ANALYSIS_UNVERIFIED",
            "identity_limits",
        ):
            with self.subTest(token=token):
                self.assertIn(token, notes)


if __name__ == "__main__":
    unittest.main(verbosity=2)
