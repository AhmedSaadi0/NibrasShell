// windows/smart_capsule/logic/HoverResponseManager.qml
pragma Singleton

import Quickshell
import QtQuick
import "root:/services"
import "root:/config"
import "root:/config/ConstValues.js" as C
import "root:/windows/smart_capsule/logic"

Singleton {
    id: root

    property var hoverResponses: []
    property bool isPrefetching: false
    property int lastHoverIndex: -1
    property int hoverCounter: 0
    property bool hasStartupRequested: false

    signal freshResponseReady(var item)

    readonly property var fallbackResponses: [
        {
            "text": "Hey there",
            "emotion": "happy"
        },
        {
            "text": "Yes, I am here",
            "emotion": "listening"
        },
        {
            "text": "Need something quick",
            "emotion": "focused"
        },
        {
            "text": "Thinking quietly",
            "emotion": "thinking"
        },
        {
            "text": "Watching you",
            "emotion": "suspicious"
        },
        {
            "text": "Almost awake",
            "emotion": "sleeping"
        },
        {
            "text": "Listening",
            "emotion": "listening"
        },
        {
            "text": "I am smart",
            "emotion": "wink"
        },
        {
            "text": "Tiny joke",
            "emotion": "happy"
        },
        {
            "text": "Ready now",
            "emotion": "shocked"
        }
    ]

    function _trimToEightWords(text) {
        let words = text.trim().split(/\s+/);
        if (words.length <= 8)
            return text.trim();
        return words.slice(0, 8).join(" ");
    }

    function _isValidExtra(text) {
        if (!text)
            return false;
        return text.trim().length >= 20;
    }

    function _sanitizeMainText(text) {
        if (!text)
            return "";
        return _trimToEightWords(String(text)).trim();
    }

    function _sanitizeExtraText(text) {
        if (!text)
            return "";
        let cleaned = String(text).replace(/\s+/g, " ").trim();
        return cleaned;
    }

    function ensureHoverResponses() {
        if (hoverResponses.length > 0 || isPrefetching)
            return;

        if (!App.aiApiKey || App.aiApiKey === "") {
            hoverResponses = fallbackResponses.slice(0);
            console.info("[HoverResponseManager] AI key missing -> using fallback responses:", hoverResponses.length);
            return;
        }

        if (SystemService.bootAnalysisStatus !== "SUCCESS" && SystemService.bootAnalysisStatus !== "ERROR")
            return;

        requestStartupResponses(24, false);
    }

    function requestIdleResponses(count, allowReplace) {
        if (isPrefetching)
            return;

        isPrefetching = true;

        const command = App.scripts.python.callIdleCapsuleHoverBulkAi;
        const args = ["--message_vars", JSON.stringify({
                count: count
            })];

        AiService.sendRequest(command, args, function (data) {
            isPrefetching = false;
            let list = (data && data.responses && Array.isArray(data.responses)) ? data.responses : [];
            let cleaned = [];
            for (let i = 0; i < list.length; i++) {
                let item = list[i];
                if (!item || !item.text)
                    continue;
                let text = _sanitizeMainText(item.text);
                if (text === "")
                    continue;
                let emotion = item.emotion ? String(item.emotion).trim() : "happy";
                let extraText = _sanitizeExtraText(item.extra_text);
                extraText = _isValidExtra(extraText) ? extraText : "";
                let extraDelay = (item.extra_delay_ms !== undefined) ? Number(item.extra_delay_ms) : 0;
                if (!Number.isFinite(extraDelay) || extraDelay <= 0)
                    extraDelay = 1400;
                cleaned.push({
                    "text": text,
                    "emotion": emotion,
                    "extra_text": extraText,
                    "extra_delay_ms": extraDelay
                });
            }
            if (cleaned.length === 0) {
                console.info("[HoverResponseManager] AI responses empty -> fallback");
                if (hoverResponses.length === 0)
                    hoverResponses = fallbackResponses.slice(0);
                return;
            }

            if (allowReplace) {
                hoverResponses = cleaned;
            } else {
                hoverResponses = hoverResponses.concat(cleaned);
            }
            console.info("[HoverResponseManager] AI responses loaded:", cleaned.length, "total:", hoverResponses.length);
        }, function (errorMessage) {
            isPrefetching = false;
            console.error("[HoverResponseManager] AI request failed:", errorMessage);
            if (hoverResponses.length === 0)
                hoverResponses = fallbackResponses.slice(0);
        }, "hoverResponsesIdle", 1, { credential: App.systemAiCredential });
    }

    function requestStartupResponses(count, allowReplace) {
        if (isPrefetching || hasStartupRequested)
            return;

        hasStartupRequested = true;
        isPrefetching = true;

        const command = App.scripts.python.callIdleCapsuleHoverStartupAi;
        const bootLogs = SystemService.bootLogsModel ? SystemService.bootLogsModel : [];
        const args = ["--message_vars", JSON.stringify({
                count: count,
                boot_status: SystemService.bootAnalysisStatus,
                boot_title: SystemService.bootStatusTitle,
                boot_summary: SystemService.aiBootSummary,
                boot_time: SystemService.bootTimeText,
                boot_logs: JSON.stringify(bootLogs)
            })];

        AiService.sendRequest(command, args, function (data) {
            isPrefetching = false;
            let list = (data && data.responses && Array.isArray(data.responses)) ? data.responses : [];
            let cleaned = [];
            for (let i = 0; i < list.length; i++) {
                let item = list[i];
                if (!item || !item.text)
                    continue;
                let text = _sanitizeMainText(item.text);
                if (text === "")
                    continue;
                let emotion = item.emotion ? String(item.emotion).trim() : "happy";
                let extraText = _sanitizeExtraText(item.extra_text);
                extraText = _isValidExtra(extraText) ? extraText : "";
                let extraDelay = (item.extra_delay_ms !== undefined) ? Number(item.extra_delay_ms) : 0;
                if (!Number.isFinite(extraDelay) || extraDelay <= 0)
                    extraDelay = 1400;
                cleaned.push({
                    "text": text,
                    "emotion": emotion,
                    "extra_text": extraText,
                    "extra_delay_ms": extraDelay
                });
            }
            if (cleaned.length === 0) {
                console.info("[HoverResponseManager] AI responses empty -> fallback");
                if (hoverResponses.length === 0)
                    hoverResponses = fallbackResponses.slice(0);
                return;
            }

            if (allowReplace) {
                hoverResponses = cleaned;
            } else {
                hoverResponses = hoverResponses.concat(cleaned);
            }
            console.info("[HoverResponseManager] AI responses loaded (startup):", cleaned.length, "total:", hoverResponses.length);
        }, function (errorMessage) {
            isPrefetching = false;
            console.error("[HoverResponseManager] AI request failed:", errorMessage);
            if (hoverResponses.length === 0)
                hoverResponses = fallbackResponses.slice(0);
        }, "hoverResponsesStartup", 0, { credential: App.systemAiCredential });
    }

    function pickHoverResponse() {
        if (hoverResponses.length === 0)
            hoverResponses = fallbackResponses.slice(0);

        hoverCounter += 1;

        let pool = hoverResponses;

        if (pool.length === 1)
            return pool[0];

        let idx = lastHoverIndex + 1;
        if (idx >= pool.length)
            idx = 0;
        lastHoverIndex = idx;
        return pool[idx];
    }

    function scheduleExtraIfAny(response) {
        if (!response || !_isValidExtra(response.extra_text))
            return;
        extraTextTimer.stop();
        extraTextTimer.interval = response.extra_delay_ms ? response.extra_delay_ms : 2000;
        extraTextTimer.pendingText = response.extra_text;
        extraTextTimer.pendingEmotion = response.emotion || "";
        extraTextTimer.start();
    }

    function requestFreshResponseIfAllowed() {
        return;
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            ensureHoverResponses();
        });
    }

    Connections {
        target: SystemService
        function onBootAnalysisStatusChanged() {
            ensureHoverResponses();
        }
    }

    Timer {
        id: extraTextTimer
        property string pendingText: ""
        property string pendingEmotion: ""
        repeat: false
        onTriggered: {
            if (!pendingText || pendingText === "")
                return;
            CapsuleCoordinator.notifyHoverExtra(pendingText, pendingEmotion);
            pendingText = "";
            pendingEmotion = "";
        }
    }
}
