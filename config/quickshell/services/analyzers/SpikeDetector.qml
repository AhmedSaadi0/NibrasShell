import QtQuick
import "root:/config"
import "root:/services"
import "root:/services/analyzers"

QtObject {
    id: root

    property CooldownManager cooldownManager
    property DiagnosticsCollector diagnosticsCollector
    property EventStore eventStore

    property real tempHighThreshold: Math.max(1, App.tempHighThreshold || 85)

    function checkCpuSpike(prev, curr) {
        if (prev < 0)
            return;

        const threshold = App.cpuHighLoadThreshold / 100;
        if (!cooldownManager.canTriggerSpike("cpu") || curr < threshold)
            return;

        const delta = curr - prev;
        diagnosticsCollector.collectTopCpuProcesses(function (topList) {
            const procKey = cooldownManager.getTopProcessKey(topList);
            if (cooldownManager.isProcessOnCooldown("cpu", procKey))
                return;

            cooldownManager.markSpike("cpu");
            cooldownManager.markProcessSpike("cpu", procKey);
            eventStore.createSpikeEvent("CPU", Math.round(curr * 100), Math.round(prev * 100), Math.round(delta * 100), threshold * 100, topList, null, null, root.tempHighThreshold, function (eventId) {
                _requestSpikeAnalysis(eventId, "CPU", Math.round(curr * 100), Math.round(prev * 100), Math.round(delta * 100), threshold * 100, topList, null, null);
            });
        });
    }

    function checkRamSpike(prev, curr) {
        if (prev < 0)
            return;

        const threshold = App.ramHighLoadThreshold / 100;
        if (!cooldownManager.canTriggerSpike("ram") || curr < threshold)
            return;

        const delta = curr - prev;
        diagnosticsCollector.collectTopRamProcesses(function (topList) {
            const procKey = cooldownManager.getTopProcessKey(topList);
            if (cooldownManager.isProcessOnCooldown("ram", procKey))
                return;

            cooldownManager.markSpike("ram");
            cooldownManager.markProcessSpike("ram", procKey);
            eventStore.createSpikeEvent("RAM", Math.round(curr * 100), Math.round(prev * 100), Math.round(delta * 100), threshold * 100, topList, null, null, root.tempHighThreshold, function (eventId) {
                _requestSpikeAnalysis(eventId, "RAM", Math.round(curr * 100), Math.round(prev * 100), Math.round(delta * 100), threshold * 100, topList, null, null);
            });
        });
    }

    function checkTempSpike(prevMax, currMax) {
        if (prevMax < 0)
            return;
        if (!cooldownManager.canTriggerSpike("temp") || currMax < root.tempHighThreshold)
            return;

        const delta = currMax - prevMax;
        cooldownManager.markSpike("temp");

        diagnosticsCollector.collectTopCpuProcesses(function (topList) {
            diagnosticsCollector.collectTempDiagnostics(function (tempsData) {
                const tempsSummary = diagnosticsCollector.tempsSummaryFromData(tempsData);
                const tempDevices = diagnosticsCollector.buildTempDevicesList(tempsData);
                eventStore.createSpikeEvent("TEMP", Math.round(currMax), Math.round(prevMax), Math.round(delta), root.tempHighThreshold, topList, tempsSummary, tempDevices, root.tempHighThreshold, function (eventId) {
                    _requestSpikeAnalysis(eventId, "TEMP", Math.round(currMax), Math.round(prevMax), Math.round(delta), root.tempHighThreshold, topList, tempsSummary, tempDevices);
                });
            });
        });
    }

    function emitCpuAlert(value, isReminder, activeForMs) {
        diagnosticsCollector.collectTopCpuProcesses(function (topList) {
            const procKey = cooldownManager.getTopProcessKey(topList);
            if (cooldownManager.isAlertOnCooldown("cpu", procKey))
                return;

            cooldownManager.markAlert("cpu", procKey);
            eventStore.createSpikeEvent("CPU", Math.round(value * 100), Math.round(value * 100), isReminder ? Math.round((activeForMs || 0) / 1000) : 0, App.cpuHighLoadThreshold, topList, null, null, root.tempHighThreshold, function (eventId) {
                _requestSpikeAnalysis(eventId, "CPU", Math.round(value * 100), Math.round(value * 100), isReminder ? Math.round((activeForMs || 0) / 1000) : 0, App.cpuHighLoadThreshold, topList, null, null);
            });
        });
    }

    function emitRamAlert(value, isReminder, activeForMs) {
        diagnosticsCollector.collectTopRamProcesses(function (topList) {
            const procKey = cooldownManager.getTopProcessKey(topList);
            if (cooldownManager.isAlertOnCooldown("ram", procKey))
                return;

            cooldownManager.markAlert("ram", procKey);
            eventStore.createSpikeEvent("RAM", Math.round(value * 100), Math.round(value * 100), isReminder ? Math.round((activeForMs || 0) / 1000) : 0, App.ramHighLoadThreshold, topList, null, null, root.tempHighThreshold, function (eventId) {
                _requestSpikeAnalysis(eventId, "RAM", Math.round(value * 100), Math.round(value * 100), isReminder ? Math.round((activeForMs || 0) / 1000) : 0, App.ramHighLoadThreshold, topList, null, null);
            });
        });
    }

    function _requestSpikeAnalysis(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride, tempsOverride, tempDevicesOverride) {
        if (type === "CPU") {
            if (topListOverride && topListOverride.length) {
                _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride, null, []);
                return;
            }

            diagnosticsCollector.collectTopCpuProcesses(function (topList) {
                _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topList, null, []);
            });
            return;
        }

        if (type === "RAM") {
            if (topListOverride && topListOverride.length) {
                _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride, null, []);
                return;
            }

            diagnosticsCollector.collectTopRamProcesses(function (topList) {
                _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topList, null, []);
            });
            return;
        }

        if (type === "TEMP") {
            if (topListOverride && topListOverride.length && tempDevicesOverride) {
                _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride, tempsOverride || diagnosticsCollector.currentTempsPayload(), tempDevicesOverride);
                return;
            }

            diagnosticsCollector.collectTopCpuProcesses(function (topList) {
                diagnosticsCollector.collectTempDiagnostics(function (tempsData) {
                    _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topListOverride && topListOverride.length ? topListOverride : topList, tempsOverride || diagnosticsCollector.tempsSummaryFromData(tempsData), tempDevicesOverride || diagnosticsCollector.buildTempDevicesList(tempsData));
                });
            });
        }
    }

    function _sendSpikeAi(eventId, type, currentValue, prevValue, deltaValue, thresholdValue, topList, temps, tempDevices) {
        const payload = {
            event_type: type,
            current_value: currentValue,
            previous_value: prevValue,
            delta: deltaValue,
            threshold: thresholdValue,
            timestamp: new Date().toISOString(),
            top_processes: topList || [],
            temp_devices: tempDevices || [],
            temps: temps || diagnosticsCollector.currentTempsPayload()
        };

        console.info(`[SpikeDetector] Sending spike analysis for ${type} event ${eventId}`);
        console.info(`[SpikeDetector] Spike payload:\n${_safePrettyJson(payload)}`);

        AiService.sendRequest(App.scripts.python.callSpikeAnalysisAi, ["--message", JSON.stringify(payload)], function (data) {
            eventStore.applySpikeAnalysis(eventId, data);
        }, function (errorMessage) {
            eventStore.applySpikeAnalysis(eventId, {
                title: "Analysis Failed",
                severity: "warning",
                analysis: errorMessage || "Failed to analyze spike.",
                causes: [],
                actions: []
            });
        }, "spike_analyze_" + eventId, 2, { credential: App.systemAiCredential });
    }

    function _safePrettyJson(value) {
        try {
            return JSON.stringify(value, null, 2);
        } catch (e) {
            return `[unserializable: ${e}]`;
        }
    }
}
