// windows/settings/monitors/MonitorsSettings.qml
// صفحة إعدادات الشاشات: قراءة بيانات Hyprland وعرضها والتحكم بها وقت التشغيل
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

import "root:/windows/settings/monitors"
import "root:/components"
import "root:/components/settings"
import "root:/themes"

M3GroupBox {
    id: root
    title: qsTr("Monitors & Display Settings")
    icon: "󰍹"

    property var selectedTheme: ThemeManager.selectedTheme

    // مصفوفة الشاشات الحية القادمة من hyprctl (stdout = JSON فقط)
    property var monitors: []
    property bool isLoading: true
    property string lastError: ""

    signal close

    // =========================================================
    // 1. دوال مساعدة
    // =========================================================

    // إزالة لاحقة "Hz" من وضع الدقة ليصبح مقبولاً لدى hyprctl
    function stripHz(mode) {
        return String(mode || "").replace(/Hz\s*$/i, "");
    }

    // وضع الدقة الحالي للشاشة (WxH@refresh) مع الحفاظ على المقياس والموضع
    function currentModeString(m) {
        if (!m || !m.width || !m.refreshRate)
            return "preferred";
        return `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}`;
    }

    // الشاشة القابلة للاستخدام في حسابات التخطيط (ليست معطلة وليست مرآة)
    function isUsable(m) {
        return m && !m.disabled && typeof m.mirrorOf !== "number";
    }

    function monitorByName(name) {
        return monitors.find(m => m.name === name);
    }

    // الشاشة المرجعية: المركزة أولاً ثم أول شاشة مفعلة
    function referenceMonitor() {
        const usable = monitors.filter(isUsable);
        return usable.find(m => m.focused) || usable[0] || null;
    }

    function refreshMonitors() {
        root.isLoading = true;
        monitorProc.command = ["hyprctl", "monitors", "all", "-j"];
        monitorProc.running = true;
    }

    // تطبيق قاعدة monitor كاملة عبر Lua: hl.monitor({...})
    // (`hyprctl keyword monitor` is rejected on Hyprland >= 0.56.)
    // transform/vrr/mirror are always sent explicitly so partial edits
    // (resolution, scale, position) never reset rotation or VRR state.
    function applyRule(name, res, pos, scale, transform, vrr, mirror) {
        const mode = stripHz(res || "preferred") || "preferred";
        const position = pos || "auto";
        const scaleVal = String(scale ?? "").trim();
        let lua = `hl.monitor({ output = "${name}"`;
        lua += `, mode = "${mode}"`;
        lua += `, position = "${position === "" ? "auto" : position}"`;
        const scaleNum = Number(scaleVal);
        if (scaleVal !== "" && scaleVal !== "auto" && !isNaN(scaleNum))
            lua += `, scale = ${scaleNum}`;
        const transformNum = Math.floor(Number(transform));
        if (!isNaN(transformNum) && transformNum >= 0 && transformNum <= 7)
            lua += `, transform = ${transformNum}`;
        const vrrNum = Math.floor(Number(vrr));
        if (!isNaN(vrrNum) && vrrNum >= -1 && vrrNum <= 3)
            lua += `, vrr = ${vrrNum}`;
        if (mirror && String(mirror).trim() !== "")
            lua += `, mirror = "${String(mirror).trim()}"`;
        lua += " })";
        console.info("[MonitorsSettings] hl.monitor:", lua);
        runCommand(["hyprctl", "eval", lua]);
    }

    // أمر مباشر (dispatch أو keyword)
    function runCommand(argv) {
        applyProc.command = argv;
        applyProc.running = true;
    }

    // وضع الشاشة في جانب معين نسبةً للشاشة المركزة (يمين/يسار/فوق/تحت)
    function placeRelative(name, side) {
        const target = monitorByName(name);
        const ref = referenceMonitor();
        if (!target || !ref)
            return;

        let x = target.x;
        let y = target.y;
        switch (side) {
        case "right":
            x = ref.x + ref.width;
            y = ref.y;
            break;
        case "left":
            x = ref.x - target.width;
            y = ref.y;
            break;
        case "above":
            y = ref.y - target.height;
            x = ref.x;
            break;
        case "below":
            y = ref.y + ref.height;
            x = ref.x;
            break;
        }

        console.info(`[MonitorsSettings] place ${name} ${side} of ${ref.name} -> ${x}x${y}`);
        applyRule(name, currentModeString(target), `${x}x${y}`, target.scale, target.transform ?? 0, Number(target.vrr ?? 0), "");
    }

    // =========================================================
    // 2. جلب بيانات الشاشات (Process)
    // =========================================================

    Process {
        id: monitorProc
        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text;
                try {
                    const parsed = JSON.parse(output);
                    root.monitors = parsed;
                    root.isLoading = false;
                    root.lastError = "";
                    console.info(`[MonitorsSettings] loaded ${parsed.length} monitor(s)`);
                } catch (e) {
                    root.isLoading = false;
                    root.lastError = qsTr("Failed to parse monitor data.");
                    console.error("[MonitorsSettings] JSON parse error:", e);
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.error("[MonitorsSettings] hyprctl:", data)
        }
    }

    // =========================================================
    // 3. تنفيذ الأوامر (Process)
    // =========================================================

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const output = String(this.text || "").trim();
                // hyprctl يطبع "ok" عند النجاح والأخطاء على stdout أيضاً
                if (output !== "" && output !== "ok")
                    console.warn("[MonitorsSettings] hyprctl apply:", output);
            }
        }
        stderr: SplitParser {
            onRead: data => console.error("[MonitorsSettings] hyprctl:", data)
        }
        onExited: refreshTimer.restart()
    }

    // تحديث لاحق بعد التطبيق حتى تستقر حالة Hyprland
    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: root.refreshMonitors()
    }

    Component.onCompleted: {
        refreshMonitors();
    }

    // تحديث عند إظهار الصفحة
    onVisibleChanged: {
        if (visible)
            refreshMonitors();
    }

    // =========================================================
    // 4. الواجهة
    // =========================================================

    ColumnLayout {
        Layout.fillWidth: true
        spacing: selectedTheme.dimensions.spacingMedium

        LayoutPreview {
            Layout.fillWidth: true
            monitors: root.monitors
            selectedTheme: root.selectedTheme
        }

        Label {
            text: qsTr("Detected Displays") + ` (${root.monitors.length})`
            font.pixelSize: selectedTheme.typography.heading3Size
            font.bold: true
        }

        // رسالة خطأ عند فشل التحليل
        Label {
            visible: root.lastError !== ""
            text: root.lastError
            color: selectedTheme.colors.error
            Layout.fillWidth: true
        }

        ListView {
            id: monitorsView
            model: root.monitors
            spacing: 12

            Layout.fillWidth: true
            implicitHeight: contentHeight

            delegate: MonitorItem {
                required property int index
                monitor: root.monitors[index]
                allMonitors: root.monitors
                selectedTheme: root.selectedTheme

                onApplyRule: (name, res, pos, scale, transform, vrr, mirror) => root.applyRule(name, res, pos, scale, transform, vrr, mirror)
                onPlaceRelative: (name, side) => root.placeRelative(name, side)
                onRunCommand: argv => root.runCommand(argv)
                onRequestRefresh: root.refreshMonitors()
            }

            // --- قسم الأنميشن ---
            add: Transition {
                NumberAnimation {
                    properties: "opacity, scale"
                    from: 0
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            remove: Transition {
                NumberAnimation {
                    properties: "opacity, scale"
                    to: 0
                    duration: 300
                    easing.type: Easing.InCubic
                }
            }
        }

        // مؤشر تحميل بسيط
        RowLayout {
            visible: root.isLoading
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: selectedTheme.colors.primary
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1
                            to: 0.2
                            duration: 600
                        }
                        NumberAnimation {
                            from: 0.2
                            to: 1
                            duration: 600
                        }
                    }
                }
            }
            Text {
                text: qsTr("Loading monitors...")
                color: selectedTheme.colors.onSurfaceVariant
                font.pixelSize: 13
            }
        }
    }

    // =========================================================
    // 5. الفوتر
    // =========================================================

    footer: RowLayout {
        spacing: selectedTheme.dimensions.spacingMedium

        MButton {
            text: "Refresh"
            Layout.preferredWidth: 130
            iconText: "⟳"
            iconFirst: true
            onClicked: root.refreshMonitors()
        }

        Item {
            Layout.fillWidth: true
        }

        MButton {
            text: "Close"
            Layout.preferredWidth: 80
            highlighted: true
            onClicked: close()
        }
    }
}
