import QtQuick
import "root:/config"

QtObject {
    id: root

    readonly property int maxEventsCount: 50

    property ListModel eventsModel: ListModel {}

    property int _eventCounter: 0

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

    function createSpikeEvent(type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride, tempsOverride, tempDevicesOverride, tempHighThreshold, onReady) {
        const eventId = `evt_${Date.now()}_${_eventCounter++}`;
        const severity = type === "TEMP" ? (currentValue >= tempHighThreshold + 10 ? "CRITICAL" : "WARNING") : (currentValue >= thresholdValue ? "WARNING" : "NORMAL");

        eventsModel.insert(0, {
            eventId: eventId,
            type: type,
            value: type === "TEMP" ? `${currentValue}°C` : `${currentValue}%`,
            severity: severity,
            timestamp: _formatTime(new Date()),
            aiAnalysis: "Analyzing... Please wait.",
            aiTitle: "Analyzing...",
            aiNarrative: "",
            aiRootCause: "",
            aiConfidence: 0,
            aiThermalRisk: "",
            aiThermalDetails: "",
            aiProcessName: "",
            aiProcessBehavior: "",
            aiActions: [],
            isLoading: true,
            aiModel: App.systemAiModel || "System AI",

            // [Phase 5 — additive adapter fields | §13]
            // Spike analysis is model-authored unless the backend explicitly
            // supplies a diagnosis adapter record. The default is unverified.
            aiSchemaVersion: "",
            aiAdapterStatus: "ANALYSIS_UNVERIFIED",
            aiVerificationStatus: "",
            aiVerificationReasons: [],
            aiVerificationScope: "",
            aiRuntimeDomain: "",
            aiEventTransport: "",
            aiIdentityLimits: [],
            aiUncertainties: [],
            aiMissingEvidence: [],
            aiEvidence: [],
            aiValidationReasons: []
        });

        _trimEventsModel();
        onReady(eventId);
    }

    function _trimEventsModel() {
        while (eventsModel.count > maxEventsCount)
            eventsModel.remove(eventsModel.count - 1);
    }

    function applySpikeAnalysis(eventId, data) {
        const idx = _findEventIndex(eventId);
        if (idx === -1)
            return;

        const raw = _objectValue(data);
        const validation = _objectValue(raw.validation);
        const schemaVersion = _stringValue(raw.schema_version);
        var adapterStatus = _stringValue(validation.status);
        if (schemaVersion !== "nibras.diagnosis/v1" || adapterStatus === "")
            adapterStatus = "ANALYSIS_UNVERIFIED";

        var validationReasons = _stringArray(validation.reasons);
        if (validationReasons.length === 0)
            validationReasons = _stringArray(validation.reason_codes);

        const verification = _objectValue(raw.verification);
        var verificationReasons = _stringArray(verification.reasons);
        if (verificationReasons.length === 0)
            verificationReasons = _stringArray(verification.reason_codes);

        eventsModel.setProperty(idx, "aiTitle", raw.title || "Analysis Complete");
        eventsModel.setProperty(idx, "aiNarrative", raw.narrative || raw.analysis || "No detailed analysis available.");
        eventsModel.setProperty(idx, "aiRootCause", raw.root_cause_hypothesis || "Unknown cause");
        eventsModel.setProperty(idx, "aiConfidence", raw.confidence_score || 0);

        if (raw.thermal_impact) {
            eventsModel.setProperty(idx, "aiThermalRisk", raw.thermal_impact.risk_level || "low");
            eventsModel.setProperty(idx, "aiThermalDetails", raw.thermal_impact.details || "");
        }

        if (raw.process_anomaly) {
            eventsModel.setProperty(idx, "aiProcessName", raw.process_anomaly.name || "N/A");
            eventsModel.setProperty(idx, "aiProcessBehavior", raw.process_anomaly.behavior || "Unknown behavior");
        }

        eventsModel.setProperty(idx, "aiActions", _stringArray(raw.actions));
        eventsModel.setProperty(idx, "aiSchemaVersion", schemaVersion);
        eventsModel.setProperty(idx, "aiAdapterStatus", adapterStatus);
        eventsModel.setProperty(idx, "aiVerificationStatus", _stringValue(verification.status));
        eventsModel.setProperty(idx, "aiVerificationReasons", verificationReasons);
        eventsModel.setProperty(idx, "aiVerificationScope", _stringValue(verification.time_scope));
        eventsModel.setProperty(idx, "aiRuntimeDomain", _stringValue(raw.runtime_domain));
        eventsModel.setProperty(idx, "aiEventTransport", _stringValue(raw.event_transport));
        eventsModel.setProperty(idx, "aiIdentityLimits", _stringArray(raw.identity_limits));
        var uncertaintyRows = _uncertaintyArray(raw.uncertainties);
        if (uncertaintyRows.length === 0)
            uncertaintyRows = _uncertaintyArray(raw.uncertainty);
        eventsModel.setProperty(idx, "aiUncertainties", uncertaintyRows);
        eventsModel.setProperty(idx, "aiMissingEvidence", _stringArray(raw.missing_evidence));
        eventsModel.setProperty(idx, "aiEvidence", _arrayValue(raw.evidence));
        eventsModel.setProperty(idx, "aiValidationReasons", validationReasons);
        eventsModel.setProperty(idx, "isLoading", false);

        if (raw.severity) {
            const sev = raw.severity.toUpperCase();
            eventsModel.setProperty(idx, "severity", sev === "INFO" ? "NORMAL" : sev);
        }
    }

    function _findEventIndex(eventId) {
        for (let i = 0; i < eventsModel.count; i++) {
            if (eventsModel.get(i).eventId === eventId)
                return i;
        }
        return -1;
    }

    function _formatTime(dt) {
        const hh = dt.getHours().toString().padStart(2, "0");
        const mm = dt.getMinutes().toString().padStart(2, "0");
        const ss = dt.getSeconds().toString().padStart(2, "0");
        return `${hh}:${mm}:${ss}`;
    }
}
