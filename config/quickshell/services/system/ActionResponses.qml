// services/system/ActionResponses.qml

import QtQuick
import Quickshell

import "root:/config"
import "root:/services"

QtObject {
    id: root

    property var systemActionResponses: ({})
    property bool systemActionResponsesReady: false

    property var _responseRotationState: ({
            charging: 0,
            discharging: 0,
            cpu_alerts: 0,
            ram_alerts: 0,
            temp_alerts: 0
        })

    readonly property var _responseKeyAliases: ({
            charge: "charging",
            charging: "charging",
            discharge: "discharging",
            discharging: "discharging",
            cpuAlert: "cpu_alerts",
            cpuAlerts: "cpu_alerts",
            cpu_alerts: "cpu_alerts",
            ramAlert: "ram_alerts",
            ramAlerts: "ram_alerts",
            ram_alerts: "ram_alerts",
            tempAlert: "temp_alerts",
            tempAlerts: "temp_alerts",
            temp_alerts: "temp_alerts"
        })

    function _normalizeResponseKey(key) {
        return root._responseKeyAliases[key] || key;
    }

    function _nextArrayResponse(key, fallbackText, fallbackEmotion) {
        const responses = root.systemActionResponses;
        const responseKey = root._normalizeResponseKey(key);
        const arr = responses[responseKey];
        if (arr && Array.isArray(arr) && arr.length > 0) {
            const idx = root._responseRotationState[responseKey] || 0;
            const result = arr[idx % arr.length];
            root._responseRotationState[responseKey] = (idx + 1) % arr.length;

            if (result && result.text)
                return {
                    text: result.text,
                    emotion: result.emotion || fallbackEmotion
                };
        }

        return {
            text: fallbackText,
            emotion: fallbackEmotion || "thinking"
        };
    }

    function fetchSystemActionMessages() {
        if (root.systemActionResponsesReady && Object.keys(root.systemActionResponses).length > 0)
            return;

        console.info("[ActionResponses] Fetching system action responses from AI...");
        const extraArgs = ["--message", "Generate system action responses"];
        AiService.sendRequest(App.scripts.python.callSystemActionAi, extraArgs, function (data) {
            if (data && typeof data === 'object') {
                root.systemActionResponses = data;
                console.info("[ActionResponses] System action responses loaded successfully.");
            } else {
                console.warn("[ActionResponses] Received invalid data for system actions.");
            }
            root.systemActionResponsesReady = true;
        }, function (errorMessage) {
            console.error("[ActionResponses] Failed to load system action responses:", errorMessage);
            root.systemActionResponsesReady = true;
        }, "SystemActions", 0, { credential: App.systemAiCredential });
    }

    function retrySystemActionMessages() {
        root.systemActionResponsesReady = false;
        root.systemActionResponses = ({});
        root.fetchSystemActionMessages();
    }

    property Timer _fetchTimer: Timer {
        interval: 5000
        running: true
        repeat: false
        onTriggered: root.fetchSystemActionMessages()
    }
}
