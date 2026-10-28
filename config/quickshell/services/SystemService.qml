// services/SystemService.qml

pragma Singleton
import QtQuick
import Quickshell

import "root:/config"
import "root:/services"
import "root:/services/system"

Singleton {
    id: root

    // =========================================================
    // Boot Analysis
    // =========================================================

    property alias bootAnalysisStatus: bootAnalyzer.bootAnalysisStatus
    property alias bootStatusTitle: bootAnalyzer.bootStatusTitle
    property alias bootStatusIcon: bootAnalyzer.bootStatusIcon
    property alias bootStatusColor: bootAnalyzer.bootStatusColor
    property alias aiBootSummary: bootAnalyzer.aiBootSummary
    property alias bootTimeText: bootAnalyzer.bootTimeText
    property alias bootLogsModel: bootAnalyzer.bootLogsModel

    property alias bootSolutionStatus: bootAnalyzer.bootSolutionStatus
    property alias bootSolutionsModel: bootAnalyzer.bootSolutionsModel

    function requestBootSolutions(bootLogs) {
        bootAnalyzer.requestBootSolutions(bootLogs);
    }

    function refreshBootDetails() {
        bootAnalyzer.refreshBootDetails();
    }

    function retryBootAnalysis() {
        bootAnalyzer.retryBootAnalysis();
    }

    // =========================================================
    // System Action Responses (Preload)
    // =========================================================

    property alias systemActionResponses: actionResponses.systemActionResponses
    property alias systemActionResponsesReady: actionResponses.systemActionResponsesReady

    function fetchSystemActionMessages() {
        actionResponses.fetchSystemActionMessages();
    }

    function retrySystemActionMessages() {
        actionResponses.retrySystemActionMessages();
    }

    function _nextArrayResponse(key, fallbackText, fallbackEmotion) {
        return actionResponses._nextArrayResponse(key, fallbackText, fallbackEmotion);
    }

    // =========================================================
    // Hardware State
    // =========================================================

    property alias volume: hardwareState.volume
    property alias isMuted: hardwareState.isMuted
    property alias volumeIcon: hardwareState.volumeIcon

    property alias brightness: hardwareState.brightness
    property alias brightnessIcon: hardwareState.brightnessIcon

    property alias hasBattery: hardwareState.hasBattery
    property alias batteryPercent: hardwareState.batteryPercent
    property alias batteryState: hardwareState.batteryState
    property alias isCharging: hardwareState.isCharging
    property alias batteryIcon: hardwareState.batteryIcon

    property alias currentLayout: hardwareState.currentLayout

    // =========================================================
    // Resource Monitor
    // =========================================================

    property alias cpuUsage: resourceMonitor.cpuUsage
    property alias ramUsage: resourceMonitor.ramUsage
    property alias gpuUsage: resourceMonitor.gpuUsage
    property alias vramUsage: resourceMonitor.vramUsage
    property alias vramUsedMb: resourceMonitor.vramUsedMb
    property alias vramTotalMb: resourceMonitor.vramTotalMb
    property alias cpuPowerW: resourceMonitor.cpuPowerW
    property alias gpuPowerW: resourceMonitor.gpuPowerW
    property alias totalPowerW: resourceMonitor.totalPowerW
    property alias cpuHighThreshold: resourceMonitor.cpuHighThreshold
    property alias ramHighThreshold: resourceMonitor.ramHighThreshold
    property alias isCpuHigh: resourceMonitor.isCpuHigh
    property alias isRamHigh: resourceMonitor.isRamHigh
    property alias tempHighThreshold: resourceMonitor.tempHighThreshold
    property alias tempResetThreshold: resourceMonitor.tempResetThreshold
    property alias cpuMaxTemp: resourceMonitor.cpuMaxTemp
    property alias gpuMaxTemp: resourceMonitor.gpuMaxTemp
    property alias storageMaxTemp: resourceMonitor.storageMaxTemp

    signal cpuSampled(real previousValue, real currentValue)
    signal ramSampled(real previousValue, real currentValue)
    signal temperatureSampled(real previousMax, real currentMax)
    signal cpuAlert(real value, bool isReminder, int activeForMs)
    signal ramAlert(real value, bool isReminder, int activeForMs)
    signal tempAlert(real value, bool isReminder, int activeForMs)
    signal cpuNormal
    signal ramNormal
    signal tempNormal

    function requestTopCpuProcesses(callback) {
        resourceMonitor.requestTopCpuProcesses(callback);
    }

    function requestTopRamProcesses(callback) {
        resourceMonitor.requestTopRamProcesses(callback);
    }

    function requestTempDiagnostics(callback) {
        resourceMonitor.requestTempDiagnostics(callback);
    }

    // =========================================================
    // Children
    // =========================================================

    BootAnalyzer {
        id: bootAnalyzer
    }

    ActionResponses {
        id: actionResponses
    }

    HardwareState {
        id: hardwareState
    }

    ResourceMonitor {
        id: resourceMonitor
        onCpuSampled: (previousValue, currentValue) => root.cpuSampled(previousValue, currentValue)
        onRamSampled: (previousValue, currentValue) => root.ramSampled(previousValue, currentValue)
        onTemperatureSampled: (previousMax, currentMax) => root.temperatureSampled(previousMax, currentMax)
        onCpuAlert: (value, isReminder, activeForMs) => root.cpuAlert(value, isReminder, activeForMs)
        onRamAlert: (value, isReminder, activeForMs) => root.ramAlert(value, isReminder, activeForMs)
        onTempAlert: (value, isReminder, activeForMs) => root.tempAlert(value, isReminder, activeForMs)
        onCpuNormal: () => root.cpuNormal()
        onRamNormal: () => root.ramNormal()
        onTempNormal: () => root.tempNormal()
    }
}
