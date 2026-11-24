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

    property var ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances

    // السطوع العام للمراقبة من الخارج
    property real brightness: 0
    property bool hasBacklight: false

    // Dim snapshot (class backlight only). -1 means no usable snapshot.
    property bool dimActive: false
    property int dimPercent: 20
    property int snapshotCurrent: -1
    property int snapshotMax: -1
    property bool dimPending: false

    function clampPercent(value) {
        let n = Number(value);
        if (!isFinite(n))
            n = 20;
        return Math.min(100, Math.max(1, Math.round(n)));
    }

    function focusedName(): string {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    }

    function getMonitorForScreen(): var {
        const name = root.focusedName();
        return monitors.find(m => m.modelData.name === name);
    }

    function setDdcWorking(bus: string, working: bool): void {
        let changed = false;
        const updated = root.ddcMonitors.map(m => {
            if (m.busNum === bus && m.ddcWorking !== working) {
                changed = true;
                return Object.assign({}, m, { ddcWorking: working });
            }
            return m;
        });
        if (changed)
            root.ddcMonitors = updated;
    }

    function applyDim(percent): void {
        root.dimPercent = root.clampPercent(percent);
        console.info("[Brightness] applyDim: percent=" + root.dimPercent + " hasBacklight=" + root.hasBacklight + " dimActive=" + root.dimActive);
        if (root.dimActive || !root.hasBacklight)
            return;
        root.dimPending = true;
        snapshotProc.running = true;
    }

    function restoreDim(): void {
        root.dimPending = false;
        if (!root.dimActive)
            return;
        console.info("[Brightness] restoreDim: snapshot=" + root.snapshotCurrent + "/" + root.snapshotMax);
        root.dimActive = false;
        if (root.snapshotCurrent >= 0 && root.snapshotMax > 0) {
            const percent = Math.min(100, Math.max(0, Math.round(root.snapshotCurrent * 100 / root.snapshotMax)));
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "s", `${percent}%`]);
        }
        root.snapshotCurrent = -1;
        root.snapshotMax = -1;
    }

    // User brightness keys while dimmed: re-snapshot after the command settles
    // so restoreDim() returns to the user's new value, not the old baseline.
    function refreshDimSnapshot(): void {
        if (root.dimActive)
            snapshotRefreshTimer.restart();
    }

    function increaseBrightness(): void {
        const monitor = root.getMonitorForScreen();
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.1);
    }

    function decreaseBrightness(): void {
        const monitor = root.getMonitorForScreen();
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.1);
    }

    reloadableId: "brightness"

    Component.onCompleted: backlightProbe.running = true

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
        backlightProbe.running = true;
    }

    Variants {
        id: variants
        model: Quickshell.screens
        Monitor {}
    }

    Process {
        id: backlightProbe
        command: ["sh", "-c", "brightnessctl -c backlight m 2>/dev/null || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                const max = parseInt(data.trim(), 10);
                root.hasBacklight = isFinite(max) && max > 0;
                console.info("[Brightness] backlight probe: hasBacklight=" + root.hasBacklight + " max=" + (isFinite(max) ? max : "n/a"));
            }
        }
    }

    Process {
        id: snapshotProc
        command: ["sh", "-c", "echo \"$(brightnessctl -c backlight g 2>/dev/null) $(brightnessctl -c backlight m 2>/dev/null)\""]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/);
                const current = parseInt(parts[0], 10);
                const max = parseInt(parts[1], 10);
                if (isFinite(current) && isFinite(max) && max > 0 && current >= 0) {
                    root.snapshotCurrent = current;
                    root.snapshotMax = max;
                } else {
                    root.snapshotCurrent = -1;
                    root.snapshotMax = -1;
                }
            }
        }
        onExited: {
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
        onTriggered: snapshotProc.running = true
    }

    Process {
        id: ddcProc
        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (!data.startsWith("Display "))
                    return;
                const lines = data.split("\n").map(l => l.trim());
                const monitorLine = lines.find(l => l.startsWith("Monitor:"));
                const busLine = lines.find(l => l.startsWith("I2C bus:"));
                if (!monitorLine || !busLine)
                    return;
                const model = monitorLine.split(":")[2]?.trim();
                const bus = busLine.split("/dev/i2c-")[1]?.trim().split(/\s+/)[0];
                if (!model || !bus)
                    return;
                root.ddcMonitors.push({
                    model: model,
                    busNum: bus,
                    ddcWorking: null
                });
            }
        }
        onExited: root.ddcMonitorsChanged()
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
        readonly property var ddcInfo: root.ddcMonitors.find(m => m.model === modelData.model) ?? null
        readonly property bool isDdc: ddcInfo !== null
        readonly property bool ddcSupported: isDdc && ddcInfo.ddcWorking === true
        readonly property bool ddcUnsupported: isDdc && ddcInfo.ddcWorking === false
        readonly property string busNum: ddcInfo?.busNum ?? ""
        property real brightness: 0

        function refreshInit(): void {
            if (monitor.ddcUnsupported) {
                initProc.command = [];
                return;
            }
            if (monitor.isDdc) {
                initProc.command = ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"];
            } else {
                initProc.command = ["sh", "-c", "echo \"a b c $(brightnessctl -c backlight g 2>/dev/null) $(brightnessctl -c backlight m 2>/dev/null)\""];
            }
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    if (monitor.isDdc) {
                        const nums = data.match(/\d+/g) || [];
                        const current = parseInt(nums[1], 10);
                        const max = parseInt(nums[2], 10);
                        if (isFinite(current) && isFinite(max) && max > 0) {
                            monitor.brightness = Math.min(1, Math.max(0, current / max));
                            root.setDdcWorking(monitor.busNum, true);
                        } else {
                            root.setDdcWorking(monitor.busNum, false);
                        }
                    } else {
                        const parts = data.trim().split(/\s+/);
                        const current = parseInt(parts[3], 10);
                        const max = parseInt(parts[4], 10);
                        monitor.brightness = (isFinite(current) && isFinite(max) && max > 0)
                            ? Math.min(1, Math.max(0, current / max))
                            : 0;
                    }
                    if (monitor.modelData.name === root.focusedName())
                        root.brightness = monitor.brightness;
                }
            }
            onExited: exitCode => {
                if (monitor.isDdc && exitCode !== 0)
                    root.setDdcWorking(monitor.busNum, false);
            }
        }

        readonly property Connections rootConnections: Connections {
            target: root
            function onDdcMonitorsChanged() {
                monitor.refreshInit();
            }
            function onHasBacklightChanged() {
                if (!monitor.isDdc)
                    monitor.refreshInit();
            }
        }

        onDdcUnsupportedChanged: {
            if (monitor.ddcUnsupported)
                initProc.command = [];
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
            if (monitor.modelData.name === root.focusedName())
                root.brightness = value;

            if (monitor.isDdc) {
                if (!monitor.ddcSupported)
                    return;
                Quickshell.execDetached(["ddcutil", "-b", monitor.busNum, "setvcp", "10", String(rounded)]);
                return;
            }

            if (!root.hasBacklight)
                return;
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "s", `${rounded}%`]);
            root.refreshDimSnapshot();
        }
    }
}
