// services/system/ResourceMonitor.qml

import QtQuick
import Quickshell
import Quickshell.Io

import "root:/config"

QtObject {
    id: root

    property real cpuUsage: 0.0
    property real ramUsage: 0.0
    property real gpuUsage: 0.0
    property real vramUsage: 0.0
    property real vramUsedMb: 0.0
    property real vramTotalMb: 0.0

    // استهلاك الطاقة بالواط (Watts) — قيم مطلقة من سكربت المراقبة ولا تُقسم على 100
    property real cpuPowerW: 0.0
    property real gpuPowerW: 0.0
    property real totalPowerW: 0.0
    readonly property real cpuHighThreshold: App.cpuHighLoadThreshold / 100.0
    readonly property real ramHighThreshold: App.ramHighLoadThreshold / 100.0
    readonly property bool isCpuHigh: cpuUsage >= cpuHighThreshold
    readonly property bool isRamHigh: ramUsage >= ramHighThreshold
    readonly property real tempHighThreshold: Math.max(1, App.tempHighThreshold || 85)
    readonly property real tempResetThreshold: Math.max(0, tempHighThreshold - 3)

    property real cpuMaxTemp: 0.0
    property real gpuMaxTemp: 0.0
    property real storageMaxTemp: 0.0

    property var _cpuAlertState: _createResourceAlertState()
    property var _ramAlertState: _createResourceAlertState()
    property var _tempAlertState: _createTempAlertState()

    signal cpuSampled(real previousValue, real currentValue)
    signal ramSampled(real previousValue, real currentValue)
    signal temperatureSampled(real previousMax, real currentMax)
    signal cpuAlert(real value, bool isReminder, int activeForMs)
    signal ramAlert(real value, bool isReminder, int activeForMs)
    signal tempAlert(real value, bool isReminder, int activeForMs)
    signal cpuNormal
    signal ramNormal
    signal tempNormal

    property ResourceDiagnostics _diagnostics: ResourceDiagnostics {
        onTempDiagnosticsReady: data => root._cacheTempDiagnostics(data)
    }

    function requestTopCpuProcesses(callback) {
        _diagnostics.requestTopCpuProcesses(callback);
    }

    function requestTopRamProcesses(callback) {
        _diagnostics.requestTopRamProcesses(callback);
    }

    function requestTempDiagnostics(callback) {
        _diagnostics.requestTempDiagnostics(callback);
    }

    function _getTopProcessKey(kind, topList) {
        if (!topList || !topList.length)
            return "";

        const top = topList[0];
        if (top.pid !== undefined && top.pid !== null)
            return `${top.pid}:${top.name || ""}`;
        return top.name || "";
    }

    function _createResourceAlertState() {
        return {
            active: false,
            lastAlertAt: 0,
            breachedAt: 0,
            lastAlertProcessKey: "",
            episodeProcessKey: "",
            hasSentCurrentEpisode: false,
            requestPending: false
        };
    }

    function _createTempAlertState() {
        return {
            active: false,
            lastAlertAt: 0,
            breachedAt: 0,
            hasSentCurrentEpisode: false
        };
    }

    function _resetResourceAlertState(kind, notifyNormal) {
        const state = kind === "cpu" ? root._cpuAlertState : root._ramAlertState;

        state.active = false;
        state.breachedAt = 0;
        state.episodeProcessKey = "";
        state.hasSentCurrentEpisode = false;
        state.requestPending = false;

        if (notifyNormal) {
            if (kind === "cpu")
                root.cpuNormal();
            else
                root.ramNormal();
        }
    }

    function _emitResourceAlert(kind, currentValue, isReminder, activeForMs) {
        if (kind === "cpu")
            root.cpuAlert(currentValue, isReminder, activeForMs);
        else
            root.ramAlert(currentValue, isReminder, activeForMs);
    }

    function _resetTempAlertState(notifyNormal) {
        root._tempAlertState.active = false;
        root._tempAlertState.breachedAt = 0;
        root._tempAlertState.hasSentCurrentEpisode = false;

        if (notifyNormal)
            root.tempNormal();
    }

    function _cacheTempDiagnostics(data) {
        const prevMax = Math.max(root.cpuMaxTemp, root.gpuMaxTemp, root.storageMaxTemp);
        const newCpu = typeof data.cpu_max_temp === "number" ? data.cpu_max_temp : root.cpuMaxTemp;
        const newGpu = typeof data.gpu_max_temp === "number" ? data.gpu_max_temp : root.gpuMaxTemp;
        const newStorage = typeof data.storage_max_temp === "number" ? data.storage_max_temp : root.storageMaxTemp;
        root.cpuMaxTemp = newCpu;
        root.gpuMaxTemp = newGpu;
        root.storageMaxTemp = newStorage;
        const newMax = Math.max(newCpu, newGpu, newStorage);
        if (newMax !== prevMax)
            root.temperatureSampled(prevMax, newMax);
    }

    function _handleTempAlert(currentValue) {
        const state = root._tempAlertState;
        const alertsEnabled = App.enableHighTempAlert;
        const now = Date.now();
        const cooldownExpired = state.lastAlertAt === 0 || (now - state.lastAlertAt >= App.resourceAlertCooldownMs);

        if (currentValue <= 0)
            return;

        if (!alertsEnabled) {
            if (state.active)
                root._resetTempAlertState(true);
            return;
        }

        if (currentValue < root.tempResetThreshold) {
            if (state.active)
                root._resetTempAlertState(true);
            return;
        }

        if (currentValue < root.tempHighThreshold)
            return;

        if (!state.active) {
            state.active = true;
            state.breachedAt = now;
            state.hasSentCurrentEpisode = false;
        }

        if (!state.hasSentCurrentEpisode) {
            if (!cooldownExpired)
                return;

            state.hasSentCurrentEpisode = true;
            state.lastAlertAt = now;
            root.tempAlert(currentValue, false, 0);
            return;
        }

        if (!cooldownExpired)
            return;

        state.lastAlertAt = now;
        root.tempAlert(currentValue, true, Math.max(0, now - state.breachedAt));
    }

    function _evaluateResourceEpisode(kind, currentValue, procKey) {
        const state = kind === "cpu" ? root._cpuAlertState : root._ramAlertState;
        const now = Date.now();
        const cooldownExpired = state.lastAlertAt === 0 || (now - state.lastAlertAt >= App.resourceAlertCooldownMs);
        const processChanged = procKey && state.lastAlertProcessKey && procKey !== state.lastAlertProcessKey;

        state.episodeProcessKey = procKey || state.episodeProcessKey;

        if (!state.hasSentCurrentEpisode) {
            if (!state.lastAlertProcessKey || !procKey || processChanged || cooldownExpired) {
                state.hasSentCurrentEpisode = true;
                state.lastAlertAt = now;
                state.lastAlertProcessKey = procKey || state.lastAlertProcessKey;
                _emitResourceAlert(kind, currentValue, false, 0);
            }
            return;
        }

        if (!cooldownExpired)
            return;

        state.lastAlertAt = now;
        state.lastAlertProcessKey = procKey || state.episodeProcessKey || state.lastAlertProcessKey;
        _emitResourceAlert(kind, currentValue, true, Math.max(0, now - state.breachedAt));
    }

    function _resolveResourceEpisode(kind, currentValue) {
        const state = kind === "cpu" ? root._cpuAlertState : root._ramAlertState;

        if (state.requestPending)
            return;

        state.requestPending = true;
        const requestFn = kind === "cpu" ? root.requestTopCpuProcesses : root.requestTopRamProcesses;
        requestFn(function (topList) {
            state.requestPending = false;

            const latestValue = kind === "cpu" ? root.cpuUsage : root.ramUsage;
            const threshold = kind === "cpu" ? root.cpuHighThreshold : root.ramHighThreshold;
            if (!state.active || latestValue < threshold)
                return;

            const procKey = root._getTopProcessKey(kind, topList);
            root._evaluateResourceEpisode(kind, latestValue, procKey);
        });
    }

    function _handleResourceAlert(kind, currentValue) {
        const threshold = kind === "cpu" ? root.cpuHighThreshold : root.ramHighThreshold;
        const alertsEnabled = kind === "cpu" ? App.enableHighCpuAlert : App.enableHighRamAlert;
        const state = kind === "cpu" ? root._cpuAlertState : root._ramAlertState;

        if (!alertsEnabled) {
            if (state.active)
                _resetResourceAlertState(kind, true);
            return;
        }

        if (currentValue < threshold) {
            if (state.active)
                _resetResourceAlertState(kind, true);
            return;
        }

        if (!state.active) {
            state.active = true;
            state.breachedAt = Date.now();
            state.episodeProcessKey = "";
            state.hasSentCurrentEpisode = false;
            _resolveResourceEpisode(kind, currentValue);
            return;
        }

        if (!state.hasSentCurrentEpisode) {
            if (state.episodeProcessKey)
                _evaluateResourceEpisode(kind, currentValue, state.episodeProcessKey);
            return;
        }

        if (Date.now() - state.lastAlertAt < App.resourceAlertCooldownMs)
            return;

        _evaluateResourceEpisode(kind, currentValue, state.episodeProcessKey || state.lastAlertProcessKey);
    }

    property Process _hardwareMonitorProc: Process {
        command: App.scripts.python.systemMonitorCommand
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    const metrics = JSON.parse(data.trim());

                    if (metrics.error) {
                        console.warn("[ResourceMonitor] Monitor script error:", metrics.error);
                        return;
                    }

                    const prevCpu = root.cpuUsage;
                    root.cpuUsage = metrics.cpu / 100.0;
                    root.cpuSampled(prevCpu, root.cpuUsage);
                    root._handleResourceAlert("cpu", root.cpuUsage);

                    const prevRam = root.ramUsage;
                    root.ramUsage = metrics.ram / 100.0;
                    root.ramSampled(prevRam, root.ramUsage);
                    root._handleResourceAlert("ram", root.ramUsage);

                    const prevTemp = root.cpuMaxTemp;
                    root.cpuMaxTemp = metrics.temp;
                    root.temperatureSampled(prevTemp, root.cpuMaxTemp);
                    root._handleTempAlert(root.cpuMaxTemp);

                    // GPU: القيمة -1 تعني عدم توفر مصدر قراءة، فيبقى 0
                    if (typeof metrics.gpu === "number" && metrics.gpu >= 0)
                        root.gpuUsage = metrics.gpu / 100.0;

                    // VRAM: القيمة -1 تعني عدم توفر ذاكرة GPU
                    if (typeof metrics.vram === "number" && metrics.vram >= 0) {
                        root.vramUsage = metrics.vram / 100.0;
                        root.vramUsedMb = metrics.vram_used || 0;
                        root.vramTotalMb = metrics.vram_total || 0;
                    }

                    // الطاقة بالواط: قراءات مطلقة مع فحص أمان للنوع والقيمة
                    const cpuPwr = (typeof metrics.cpu_pwr === "number" && isFinite(metrics.cpu_pwr)) ? metrics.cpu_pwr : 0.0;
                    const gpuPwr = (typeof metrics.gpu_pwr === "number" && isFinite(metrics.gpu_pwr)) ? metrics.gpu_pwr : 0.0;
                    root.cpuPowerW = cpuPwr;
                    root.gpuPowerW = gpuPwr;

                    // الإجمالي: نستخدم قيمة السكربت إن توفرت، وإلا نحسبها من مجموع المكونات
                    root.totalPowerW = (typeof metrics.total_pwr === "number" && isFinite(metrics.total_pwr))
                        ? metrics.total_pwr
                        : (cpuPwr + gpuPwr);
                } catch (e) {
                    console.error("[ResourceMonitor] Error parsing JSON:", e, "Data:", data);
                }
            }
        }
    }
}
