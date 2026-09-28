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
import "root:/config"
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

    // نسخة monitors.conf في الذاكرة: تُقرأ مرة واحدة وتُحدَّث عند كل تغيير
    property string confContent: ""
    property bool confLoaded: false
    // تغيير وصل قبل اكتمال قراءة الملف، يُطبَّق فور اكتمالها
    property string pendingRule: ""
    property string pendingMonitor: ""

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

    // تطبيق قاعدة monitor كاملة: name,res,pos,scale[,extra...]
    function applyRule(name, res, pos, scale, extra) {
        const parts = [name, res || "preferred", pos || "auto", String(scale ?? "auto")];
        if (extra && extra !== "")
            parts.push(extra);
        const rule = parts.join(",");
        console.info("[MonitorsSettings] monitor rule:", rule);
        runCommand(["hyprctl", "keyword", "monitor", rule]);
        persistRule(name, rule);
    }

    // حفظ القاعدة في monitors.conf
    // ملاحظة: hyprctl keyword يطبّق القاعدة على المُشغّل الجاري فقط ولا يكتبها في
    // ملف الإعدادات، لذلك نحفظها يدوياً وإلا عاد المقياس إلى قيمته بعد إعادة التشغيل
    function persistRule(name, rule) {
        const m = String(name || "").trim();
        const r = String(rule || "").trim();
        if (!m || !r)
            return;
        // نعدّل الذاكرة المؤقتة مباشرة لتفادي السباق بين قراءتين متتاليتين
        if (!confLoaded) {
            pendingMonitor = m;
            pendingRule = r;
            return; // لم يُقرأ الملف بعد، ستلتقطه onLoaded
        }
        const output = mergeRule(confContent, m, r);
        if (output === confContent)
            return; // لا تغيير، لا داعي للكتابة
        confContent = output;
        monitorsConf.setText(output);
    }

    // استبدال سطر الشاشة داخل نص monitors.conf مع الحفاظ على باقي الأسطر والتعليقات
    // ملاحظة: نتجنب flatMap/flat لأنهما غير مدعومين في محرك QML
    function mergeRule(content, monitorName, rule) {
        const newLine = `monitor=${rule}`;
        const target = String(monitorName || "").trim();
        let replaced = false;

        const lines = [];
        const source = String(content || "").split("\n");
        for (let i = 0; i < source.length; i++) {
            const line = source[i];
            // تجاهل الأسطر الفارغة (تُحذف لاحقاً) والتعليقات
            if (!line.trim()) {
                lines.push(line);
                continue;
            }
            // Hyprland يقبل المسافات حول "=" لذا نُطبّع الشكل قبل المطابقة
            const eq = line.indexOf("=");
            if (eq < 0 || line.slice(0, eq).trim() !== "monitor") {
                lines.push(line);
                continue;
            }
            if (line.slice(eq + 1).split(",")[0].trim() !== target) {
                lines.push(line);
                continue;
            }
            if (replaced)
                continue; // إسقاط أي قاعدة مكررة لنفس الشاشة
            replaced = true;
            lines.push(newLine);
        }

        // إزالة الأسطر الفارغة الزائدة في الطرفين حتى لا تتراكم مع كل حفظ
        while (lines.length > 0 && !lines[0].trim())
            lines.shift();
        while (lines.length > 0 && !lines[lines.length - 1].trim())
            lines.pop();

        if (!replaced) {
            // لا فاصل فارغ بين نهاية الملف والقاعدة الجديدة
            lines.push(newLine);
        }

        return lines.join("\n") + "\n";
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
        applyRule(name, currentModeString(target), `${x}x${y}`, target.scale, "");
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

    // حفظ قواعد الشاشات في ملف إعدادات Hyprland ليعمل التغيير بعد إعادة التشغيل
    FileView {
        id: monitorsConf
        path: App.monitorsConfPath
        watchChanges: false
        atomicWrites: true

        onLoaded: {
            root.confContent = text();
            root.confLoaded = true;
            // تطبيق أي تغيير سبى قبل اكتمال القراءة
            if (root.pendingRule !== "") {
                const rule = root.pendingRule;
                const monitor = root.pendingMonitor;
                root.pendingRule = "";
                root.pendingMonitor = "";
                root.persistRule(monitor, rule);
            }
        }
        onSaveFailed: error => console.error("[MonitorsSettings] monitors.conf write failed:", error)
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

                onApplyRule: (name, res, pos, scale, extra) => root.applyRule(name, res, pos, scale, extra)
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
