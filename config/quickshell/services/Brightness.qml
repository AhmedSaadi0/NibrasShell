// services/Brightness.qml

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import Quickshell
import Quickshell.Io
import QtQuick

import "../config"

Singleton {
    id: root

    reloadableId: "brightness"

    property var ddcMonitors: []
    property bool ddcProbed: false
    property bool ddcRescanPending: false

    readonly property list<Monitor> monitors: variants.instances

    readonly property Monitor focusedMonitor: {
        const name = root.focusedName();
        return monitors.find(m => m.modelData.name === name) ?? null;
    }

    // السطوع العام للمراقبة من الخارج (يتحدث تلقائياً مع تغير التركيز أو قيمة الشاشة)
    readonly property real brightness: focusedMonitor ? focusedMonitor.brightness : 0
    property bool hasBacklight: false

    // Dim snapshot (class backlight only). -1 means no usable snapshot.
    property bool dimActive: false
    property int dimPercent: 20
    property int snapshotCurrent: -1
    property int snapshotMax: -1
    property bool dimPending: false

    function clampPercent(value): int {
        let n = Number(value);
        if (!isFinite(n))
            n = 20;
        return Math.min(100, Math.max(1, Math.round(n)));
    }

    function focusedName(): string {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    }

    function getMonitorForScreen(): var {
        return root.focusedMonitor;
    }

    function triggerDetection(): void {
        backlightProbe.running = true;
        if (ddcProc.running) {
            root.ddcRescanPending = true;
            return;
        }
        ddcProc.detectedBuffer = [];
        ddcProc.running = true;
    }

    function applyDim(percent): void {
        const clamped = root.clampPercent(percent);
        root.dimPercent = clamped;
        console.info("[Brightness] applyDim: percent=" + clamped + " hasBacklight=" + root.hasBacklight + " dimActive=" + root.dimActive);

        if (!root.hasBacklight)
            return;

        // إذا كان الخفت مفعلاً مسبقاً، نطبّق المستوى الجديد مباشرة دون تدمير الـ snapshot الأصلي
        if (root.dimActive) {
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "s", `${clamped}%`]);
            return;
        }

        snapshotRefreshTimer.stop();
        root.dimPending = true;
        if (!snapshotProc.running)
            snapshotProc.running = true;
    }

    function restoreDim(): void {
        root.dimPending = false;
        snapshotRefreshTimer.stop();

        if (!root.dimActive)
            return;

        console.info("[Brightness] restoreDim: snapshot=" + root.snapshotCurrent + "/" + root.snapshotMax);
        root.dimActive = false;

        if (root.snapshotCurrent >= 0 && root.snapshotMax > 0) {
            // تمرير القيمة الخام مباشرة يحفظ الدقة ويمنع التقريب إلى 0%
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "s", String(root.snapshotCurrent)]);
        }
        root.snapshotCurrent = -1;
        root.snapshotMax = -1;
    }

    function refreshDimSnapshot(): void {
        if (root.dimActive)
            snapshotRefreshTimer.restart();
    }

    function increaseBrightness(): void {
        const monitor = root.focusedMonitor;
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.1);
    }

    function decreaseBrightness(): void {
        const monitor = root.focusedMonitor;
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.1);
    }

    Component.onCompleted: root.triggerDetection()
    onMonitorsChanged: root.triggerDetection()

    Variants {
        id: variants
        model: Quickshell.screens
        Monitor {}
    }

    Process {
        id: backlightProbe
        command: ["brightnessctl", "-c", "backlight", "-m"]
        property bool seenLine: false
        onRunningChanged: {
            if (running)
                seenLine = false;
        }
        stdout: SplitParser {
            onRead: data => {
                if (backlightProbe.seenLine)
                    return;
                const parts = data.trim().split(",");
                if (parts.length >= 5) {
                    const max = parseInt(parts[4], 10);
                    if (isFinite(max) && max > 0) {
                        backlightProbe.seenLine = true;
                        root.hasBacklight = true;
                        console.info("[Brightness] backlight probe: max=" + max);
                    }
                }
            }
        }
        onExited: exitCode => {
            if (!backlightProbe.seenLine || exitCode !== 0) {
                root.hasBacklight = false;
                console.info("[Brightness] backlight probe: hasBacklight=false");
            }
        }
    }

    Process {
        id: snapshotProc
        command: ["brightnessctl", "-c", "backlight", "-m"]
        property bool parsed: false
        onRunningChanged: {
            if (running)
                parsed = false;
        }
        stdout: SplitParser {
            onRead: data => {
                if (snapshotProc.parsed)
                    return;
                const parts = data.trim().split(",");
                if (parts.length >= 5) {
                    const current = parseInt(parts[2], 10);
                    const max = parseInt(parts[4], 10);
                    if (isFinite(current) && isFinite(max) && max > 0 && current >= 0) {
                        root.snapshotCurrent = current;
                        root.snapshotMax = max;
                        snapshotProc.parsed = true;
                    }
                }
            }
        }
        onExited: exitCode => {
            if (!snapshotProc.parsed || exitCode !== 0) {
                root.snapshotCurrent = -1;
                root.snapshotMax = -1;
            }
            if (!root.dimPending)
                return;
            root.dimPending = false;
            if (root.snapshotCurrent >= 0 && root.snapshotMax > 0) {
                console.info("[Brightness] dim snapshot=" + root.snapshotCurrent + "/" + root.snapshotMax + " -> " + root.dimPercent + "%");
                root.dimActive = true;
                Quickshell.execDetached(["brightnessctl", "-c", "backlight", "s", `${root.dimPercent}%`]);
            }
        }
    }

    Timer {
        id: snapshotRefreshTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.dimActive && !snapshotProc.running)
                snapshotProc.running = true;
        }
    }

    Process {
        id: ddcProc
        property var detectedBuffer: []
        command: ["ddcutil", "detect", "--brief"]

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                const block = data.trim();
                if (!block.startsWith("Display "))
                    return;
                const lines = block.split("\n").map(l => l.trim());
                const monitorLine = lines.find(l => l.startsWith("Monitor:"));
                const busLine = lines.find(l => l.startsWith("I2C bus:"));
                if (!monitorLine || !busLine)
                    return;

                // صيغة ddcutil --brief هي: Monitor: MFG:MODEL:SERIAL
                const monitorParts = monitorLine.split(":");
                const model = monitorParts[2]?.trim() ?? "";
                const serial = monitorParts[3]?.trim() ?? "";
                const bus = busLine.split("/dev/i2c-")[1]?.trim().split(/\s+/)[0] ?? "";
                if (!bus || (!model && !serial))
                    return;

                ddcProc.detectedBuffer.push({
                    model: model,
                    serial: serial,
                    busNum: bus
                });
            }
        }

        onExited: {
            root.ddcMonitors = ddcProc.detectedBuffer.slice();
            root.ddcProbed = true;
            if (root.ddcRescanPending) {
                root.ddcRescanPending = false;
                ddcProc.detectedBuffer = [];
                ddcProc.running = true;
            }
        }
    }

    NibrasShellShortcut {
        name: "brightnessUp"
        onPressed: root.increaseBrightness()
    }

    NibrasShellShortcut {
        name: "brightnessDown"
        onPressed: root.decreaseBrightness()
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData

        // حالة DDC محلية داخل كل شاشة لتفادي إثارة ddcMonitorsChanged لكل الشاشات
        // 0 = غير مفحوص، 1 = مدعوم، -1 = غير مدعوم
        property int ddcState: 0
        property real brightness: 0
        property int pendingPercent: -1

        readonly property var ddcInfo: {
            const serial = monitor.modelData.serialNumber?.trim() ?? "";
            if (serial.length > 0) {
                const bySerial = root.ddcMonitors.find(m => m.serial === serial);
                if (bySerial)
                    return bySerial;
            }
            const model = monitor.modelData.model?.trim() ?? "";
            if (model.length > 0)
                return root.ddcMonitors.find(m => m.model === model) ?? null;
            return null;
        }

        readonly property bool isDdc: ddcInfo !== null
        readonly property bool ddcSupported: isDdc && ddcState === 1
        readonly property bool ddcUnsupported: isDdc && ddcState === -1
        readonly property string busNum: ddcInfo?.busNum ?? ""

        onDdcInfoChanged: {
            monitor.ddcState = 0;
            monitor.refreshInit();
        }

        function refreshInit(): void {
            if (!root.ddcProbed || monitor.ddcUnsupported)
                return;

            if (monitor.isDdc) {
                initProc.command = ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"];
                initProc.running = true;
                return;
            }

            if (root.hasBacklight) {
                initProc.command = ["brightnessctl", "-c", "backlight", "-m"];
                initProc.running = true;
            }
        }

        readonly property Process initProc: Process {
            property bool parsed: false
            onRunningChanged: {
                if (running)
                    parsed = false;
            }
            stdout: SplitParser {
                onRead: data => {
                    if (initProc.parsed)
                        return;
                    const line = data.trim();

                    if (monitor.isDdc) {
                        // صيغة الإخراج القياسية: VCP 10 C <current> <max>
                        const match = line.match(/^VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                        if (match) {
                            const current = parseInt(match[1], 10);
                            const max = parseInt(match[2], 10);
                            if (isFinite(current) && isFinite(max) && max > 0) {
                                monitor.brightness = Math.min(1, Math.max(0, current / max));
                                monitor.ddcState = 1;
                                initProc.parsed = true;
                            }
                        }
                    } else {
                        const parts = line.split(",");
                        if (parts.length >= 5) {
                            const current = parseInt(parts[2], 10);
                            const max = parseInt(parts[4], 10);
                            if (isFinite(current) && isFinite(max) && max > 0) {
                                monitor.brightness = Math.min(1, Math.max(0, current / max));
                                initProc.parsed = true;
                            }
                        }
                    }
                }
            }
            onExited: exitCode => {
                if (monitor.isDdc && (!initProc.parsed || exitCode !== 0))
                    monitor.ddcState = -1;
            }
        }

        // Coalescing queue: عملية واحدة فقط قيد التنفيذ لضمان الترتيب ومنع تزاحم I2C
        readonly property Process setProc: Process {
            onExited: {
                if (monitor.pendingPercent >= 0) {
                    const next = monitor.pendingPercent;
                    monitor.pendingPercent = -1;
                    monitor.dispatchSet(next);
                }
            }
        }

        function dispatchSet(roundedPercent: int): void {
            if (monitor.isDdc) {
                if (!monitor.ddcSupported)
                    return;
                setProc.command = ["ddcutil", "-b", monitor.busNum, "setvcp", "10", String(roundedPercent)];
                setProc.running = true;
                return;
            }

            if (!root.hasBacklight)
                return;
            setProc.command = ["brightnessctl", "-c", "backlight", "s", `${roundedPercent}%`];
            setProc.running = true;
            root.refreshDimSnapshot();
        }

        readonly property Connections rootConnections: Connections {
            target: root
            function onDdcProbedChanged() {
                if (root.ddcProbed)
                    monitor.refreshInit();
            }
            function onHasBacklightChanged() {
                if (!monitor.isDdc)
                    monitor.refreshInit();
            }
        }

        Component.onCompleted: monitor.refreshInit()

        function setBrightness(value: real): void {
            if (monitor.ddcUnsupported)
                return;
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(monitor.brightness * 100) === rounded)
                return;

            monitor.brightness = value;

            if (monitor.isDdc && !monitor.ddcSupported)
                return;
            if (!monitor.isDdc && !root.hasBacklight)
                return;

            if (setProc.running) {
                monitor.pendingPercent = rounded;
            } else {
                monitor.dispatchSet(rounded);
            }
        }
    }
}
