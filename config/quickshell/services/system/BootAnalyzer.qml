// services/system/BootAnalyzer.qml

import QtQuick
import Quickshell

import "root:/config"
import "root:/services"

QtObject {
    id: root

    property string bootAnalysisStatus: "IDLE"
    property string bootStatusTitle: "System Check"
    property string bootStatusIcon: ""
    property string bootStatusColor: "green"
    property string aiBootSummary: "Waiting for analysis..."
    property string bootTimeText: "--"
    property var bootLogsModel: []

    property string bootSolutionStatus: "IDLE"
    property var bootSolutionsModel: []

    // [Phase 5 — explicit adapters | docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md §13]
    // Legacy responses (no schema_version) are normalized into the same card
    // shape as nibras.diagnosis/v1, but they are always marked
    // QUARANTINED_LEGACY. The adapter never promotes model text to validated
    // guidance; only an explicit backend validation record can do that.
    property string bootSolutionSchemaVersion: ""
    property string bootSolutionAdapter: "none" // none | legacy | diagnosis
    property var bootToolDecisions: []

    function _stringValue(value) {
        return (typeof value === "string" && value !== "" && value !== "null") ? value : "";
    }

    function _stringArray(value) {
        if (value === null || value === undefined)
            return [];
        if (typeof value === "string")
            return value !== "" ? [value] : [];
        if (!Array.isArray(value))
            return [];
        var out = [];
        for (var i = 0; i < value.length; i++) {
            if (typeof value[i] === "string" && value[i] !== "")
                out.push(value[i]);
            else if (typeof value[i] === "number" || typeof value[i] === "boolean")
                out.push(String(value[i]));
        }
        return out;
    }

    function _arrayValue(value) {
        return Array.isArray(value) ? value : [];
    }

    function _uncertaintyArray(value) {
        if (value === null || value === undefined)
            return [];
        if (typeof value === "string")
            return value !== "" ? [value] : [];
        if (Array.isArray(value))
            return _stringArray(value);
        if (typeof value === "object") {
            var rows = [];
            for (var key in value) {
                if (value[key] !== null && value[key] !== undefined && value[key] !== "")
                    rows.push(key + ": " + String(value[key]));
            }
            return rows;
        }
        return [];
    }

    function _objectValue(value) {
        return (value && typeof value === "object" && !Array.isArray(value)) ? value : ({});
    }

    function _normalizeVerification(value) {
        var raw = _objectValue(value);
        var reasons = _stringArray(raw.reasons);
        if (reasons.length === 0)
            reasons = _stringArray(raw.reason_codes);
        return {
            status: _stringValue(raw.status),
            reasons: reasons,
            time_scope: _stringValue(raw.time_scope)
        };
    }

    function _normalizeStep(value) {
        var raw = _objectValue(value);
        return {
            label: _stringValue(raw.label) || _stringValue(raw.title),
            command: _stringValue(raw.command),
            warning: _stringValue(raw.warning)
        };
    }

    function _normalizeSolution(value, index, isDiagnosis, fallbackValidation, fallbackTemplate, allowFallback) {
        var raw = _objectValue(value);
        var validation = _objectValue(raw.validation);
        if (Object.keys(validation).length === 0 && allowFallback)
            validation = _objectValue(fallbackValidation);
        var validationStatus = _stringValue(validation.status);
        var validationReasons = _stringArray(validation.reasons);
        if (validationReasons.length === 0)
            validationReasons = _stringArray(validation.reason_codes);
        var validationDetails = _stringArray(validation.details);
        if (validationReasons.length === 0)
            validationReasons = validationDetails;

        if (isDiagnosis) {
            if (validationStatus === "") {
                // Missing policy state is not a verification claim. It stays
                // visibly unqualified and non-copyable.
                validationStatus = "STATUS_ABSENT";
                validationReasons = ["backend validation status was absent from the response"];
            }
        } else {
            validationStatus = "QUARANTINED_LEGACY";
            validationReasons = ["legacy model-generated suggestion without a nibras.diagnosis/v1 validation record"];
        }

        var verification = _normalizeVerification(raw.verification);
        var template = _objectValue(raw.template);
        if (Object.keys(template).length === 0 && allowFallback)
            template = _objectValue(fallbackTemplate);
        var guidanceLines = _stringArray(raw.guidance_lines);
        if (guidanceLines.length === 0)
            guidanceLines = _stringArray(template.lines);
        if (guidanceLines.length === 0) {
            var remediation = _objectValue(raw.proposed_remediation);
            guidanceLines = _stringArray(remediation.guidance_lines);
        }

        var steps = [];
        var rawSteps = _arrayValue(raw.steps);
        for (var i = 0; i < rawSteps.length; i++)
            steps.push(_normalizeStep(rawSteps[i]));

        var uncertaintyRows = _uncertaintyArray(raw.uncertainties);
        if (uncertaintyRows.length === 0)
            uncertaintyRows = _uncertaintyArray(raw.uncertainty);

        return {
            id: _stringValue(raw.id) || ("solution-" + index),
            related_log: _stringValue(raw.related_log),
            title: _stringValue(raw.title) || (isDiagnosis ? "Diagnostic result" : "Suggested fix"),
            difficulty: _stringValue(raw.difficulty),
            priority: _stringValue(raw.priority),
            description: _stringValue(raw.description) || _stringValue(raw.incident_summary),
            why_this_works: _stringValue(raw.why_this_works) || _stringValue(raw.rationale),
            steps: steps,
            guidance_lines: guidanceLines,
            runtime_domain: _stringValue(raw.runtime_domain),
            event_transport: _stringValue(raw.event_transport),
            verification: verification,
            verification_status: verification.status,
            verification_reasons: verification.reasons,
            verification_time_scope: verification.time_scope,
            identity_limits: _stringArray(raw.identity_limits),
            uncertainties: uncertaintyRows,
            missing_evidence: _stringArray(raw.missing_evidence),
            evidence: _arrayValue(raw.evidence),
            confidence_note: _stringValue(raw.confidence_note),
            validation_status: validationStatus,
            validation_reasons: validationReasons,
            validation_details: validationDetails,
            findings: _arrayValue(raw.findings),
            possible_causes: _stringArray(raw.possible_causes),
            diagnostic_questions: _stringArray(raw.diagnostic_questions),
            adapter: isDiagnosis ? "diagnosis" : "legacy",
            schema_version: isDiagnosis ? "nibras.diagnosis/v1" : ""
        };
    }

    // The orchestrator's nibras.diagnosis/v1 envelope nests the diagnosis under
    // response.response. The additive UI contract in §13 uses solutions[]; this
    // helper lets the adapter render either shape without inventing policy state.
    function _diagnosisEnvelopeSolution(data) {
        var payload = _objectValue(data.response);
        var validationWrapper = _objectValue(payload.validation);
        var validation = _objectValue(validationWrapper.guidance_decision);
        if (Object.keys(validation).length === 0)
            validation = validationWrapper;

        var template = _objectValue(payload.guidance_template);
        if (Object.keys(template).length === 0)
            template = _objectValue(validationWrapper.template);

        var remediation = _objectValue(payload.proposed_remediation);
        var findings = _arrayValue(payload.findings);
        var evidence = [];
        for (var i = 0; i < findings.length; i++) {
            var finding = _objectValue(findings[i]);
            evidence.push({
                id: _stringValue(finding.id),
                origin: "finding",
                strength: _stringValue(finding.severity),
                desc: _stringValue(finding.text),
                evidence_refs: _arrayValue(finding.evidence_refs)
            });
        }

        return {
            id: "diagnosis-1",
            title: "Diagnostic result",
            description: payload.incident_summary,
            why_this_works: remediation.rationale,
            validation: validation,
            guidance_lines: template.lines,
            proposed_remediation: remediation,
            evidence: evidence,
            findings: findings,
            possible_causes: payload.possible_causes,
            missing_evidence: payload.missing_evidence,
            diagnostic_questions: payload.diagnostic_questions,
            uncertainties: payload.uncertainties,
            uncertainty: payload.uncertainty || data.uncertainty,
            runtime_domain: payload.runtime_domain || data.runtime_domain,
            event_transport: payload.event_transport || data.event_transport,
            identity_limits: payload.identity_limits || data.identity_limits,
            verification: payload.verification || data.verification,
            confidence_note: payload.confidence_note || data.confidence_note
        };
    }

    function _extractSolutions(data) {
        if (Array.isArray(data.solutions) && data.solutions.length > 0)
            return data.solutions;
        if (data.response && Array.isArray(data.response.solutions) && data.response.solutions.length > 0)
            return data.response.solutions;
        if (data.schema_version === "nibras.diagnosis/v1" && data.response && typeof data.response === "object")
            return [_diagnosisEnvelopeSolution(data)];
        if (Array.isArray(data.solutions))
            return data.solutions;
        return [];
    }

    function _extractToolDecisions(data) {
        var rawDecisions = [];
        if (data && data.validation && Array.isArray(data.validation.tool_decisions) && data.validation.tool_decisions.length > 0)
            rawDecisions = data.validation.tool_decisions;
        else if (data && data.response && data.response.validation && Array.isArray(data.response.validation.tool_decisions))
            rawDecisions = data.response.validation.tool_decisions;

        var decisions = [];
        for (var i = 0; i < rawDecisions.length; i++) {
            var raw = _objectValue(rawDecisions[i]);
            var reasons = _stringArray(raw.reason_codes);
            if (reasons.length === 0)
                reasons = _stringArray(raw.reasons);
            decisions.push({
                artifact: _stringValue(raw.artifact),
                request_id: _stringValue(raw.request_id),
                tool: _stringValue(raw.tool),
                status: _stringValue(raw.status),
                reasons: reasons,
                details: _stringArray(raw.details)
            });
        }
        return decisions;
    }

    function _applyBootSolutionResponse(data) {
        var isDiagnosis = !!(data && data.schema_version === "nibras.diagnosis/v1");
        var rawSolutions = data ? _extractSolutions(data) : [];
        if (!rawSolutions || rawSolutions.length === 0) {
            console.warn("[BootAnalyzer] Boot solutions response has no solutions array");
            root.bootSolutionsModel = [];
            root.bootToolDecisions = [];
            root.bootSolutionStatus = "ERROR";
            return;
        }

        // §13 keeps artifact decisions per solution. Some envelopes carry one
        // shared validation/template record at response level; use it only when
        // exactly one solution exists so a decision cannot be copied across
        // artifacts.
        var envelopeValidationWrapper = _objectValue(data.validation);
        if (Object.keys(envelopeValidationWrapper).length === 0 && data.response)
            envelopeValidationWrapper = _objectValue(data.response.validation);
        var envelopeValidation = _objectValue(envelopeValidationWrapper.guidance_decision);
        if (Object.keys(envelopeValidation).length === 0)
            envelopeValidation = envelopeValidationWrapper;

        var envelopeTemplate = _objectValue(data.guidance_template);
        if (Object.keys(envelopeTemplate).length === 0 && data.response)
            envelopeTemplate = _objectValue(data.response.guidance_template);
        if (Object.keys(envelopeTemplate).length === 0)
            envelopeTemplate = _objectValue(envelopeValidation.template);
        if (Object.keys(envelopeTemplate).length === 0)
            envelopeTemplate = _objectValue(envelopeValidationWrapper.template);

        var singleSolution = rawSolutions.length === 1;
        var normalized = [];
        for (var i = 0; i < rawSolutions.length; i++)
            normalized.push(_normalizeSolution(rawSolutions[i], i, isDiagnosis, envelopeValidation, envelopeTemplate, singleSolution));

        root.bootSolutionSchemaVersion = isDiagnosis ? "nibras.diagnosis/v1" : "";
        root.bootSolutionAdapter = isDiagnosis ? "diagnosis" : "legacy";
        root.bootToolDecisions = _extractToolDecisions(data);
        root.bootSolutionsModel = normalized;
        root.bootSolutionStatus = "SUCCESS";
    }

    function requestBootSolutions(bootLogs) {
        if (bootSolutionStatus === "LOADING")
            return;

        console.info("[BootAnalyzer] Requesting boot solutions...");
        bootSolutionStatus = "LOADING";
        bootSolutionSchemaVersion = "";
        bootSolutionAdapter = "none";
        bootToolDecisions = [];
        bootSolutionsModel = [];

        const payload = {
            logs: bootLogs || [],
            boot_duration: root.bootTimeText,
            title: root.bootStatusTitle,
            summary: root.aiBootSummary,
            status_color: root.bootStatusColor
        };

        AiService.sendRequest(App.scripts.python.callBootSolutionAi, ["--message", JSON.stringify(payload)], function (data) {
            _applyBootSolutionResponse(data);
            if (root.bootSolutionStatus === "SUCCESS")
                console.info("[BootAnalyzer] Boot solutions received: " + root.bootSolutionsModel.length + " item(s)");
        }, function (errorMessage) {
            console.error("[BootAnalyzer] Boot solutions error: " + errorMessage);
            root.bootSolutionStatus = "ERROR";
        }, "BootSolutions", 0);
    }

    function refreshBootDetails() {
        if (bootAnalysisStatus === "LOADING")
            return;

        console.info("[BootAnalyzer] Starting Boot Analysis...");
        bootAnalysisStatus = "LOADING";
        bootSolutionStatus = "IDLE";
        bootSolutionSchemaVersion = "";
        bootSolutionAdapter = "none";
        bootToolDecisions = [];
        bootSolutionsModel = [];

        const baseCommand = App.scripts.python.callBootAnalysisAi;
        const extraArgs = ["--message", "Analyze Boot Logs"];

        AiService.sendRequest(baseCommand, extraArgs, function (data) {
            if (data && data.title) {
                console.info("[BootAnalyzer] AI Analysis Received: " + data.title);

                root.bootStatusTitle = data.title;
                root.bootStatusIcon = data.icon;
                root.bootStatusColor = data.status_color;
                root.aiBootSummary = data.summary;
                root.bootTimeText = data.boot_duration;
                root.bootLogsModel = data.logs;
                root.bootAnalysisStatus = "SUCCESS";

                if (data.logs && data.logs.length > 0) {
                    Qt.callLater(function () {
                        root.requestBootSolutions(data.logs);
                    });
                }
            } else {
                console.error("[BootAnalyzer] Data received but structure is unexpected");
                root.bootAnalysisStatus = "ERROR";
            }
        }, function (errorMessage) {
            console.error("[BootAnalyzer] AI Process Error: " + errorMessage);
            root.bootAnalysisStatus = "ERROR";
        }, "BootDetails", 0);
    }

    function retryBootAnalysis() {
        if (root.bootAnalysisStatus === "LOADING")
            return;
        root.bootAnalysisStatus = "IDLE";
        root.bootSolutionStatus = "IDLE";
        root.bootSolutionSchemaVersion = "";
        root.bootSolutionAdapter = "none";
        root.bootToolDecisions = [];
        root.bootSolutionsModel = [];
        root.refreshBootDetails();
    }

    property Timer _bootTimer: Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: root.refreshBootDetails()
    }
}
