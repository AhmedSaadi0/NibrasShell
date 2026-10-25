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

    // طابور أوامر التنفيذ: Quickshell Process يتجاهل تغيير command أثناء التشغيل،
    // لذا تُرصَّد الأوامر السريعة المتتالية وتُنفَّذ واحداً بعد الآخر
    property var commandQueue: []

    // خطأ آخر أمر تطبيق (hyprctl eval) — قناة منفصلة عن lastError (خطأ تحليل JSON)
    // حتى لا يمسحه التحديث الفوري الذي يحدث بعد 600ms من كل أمر
    property string applyError: ""

    // طلب تحديث وصل أثناء تحديث جارٍ — يُنفَّذ بعد انتهاء الأول بدل التداخل
    property bool refreshPending: false

    // نموذج مستقر بالأسماء: تُحدَّث البيانات داخل البطاقات مباشرة بدل إعادة بنائها.
    // يُسند فقط عندما تتغير قائمة الأسماء فعلياً (توصيل/فصل) — انظر دالة التحليل أدناه
    property var monitorNames: []

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
    // mirrorOf: "none" أو غير معرّف = شاشة مستقلة؛ قيمة موجودة = مرآة للشاشة المصدر
    function isUsable(m) {
        return m && !m.disabled && (!m.mirrorOf || m.mirrorOf === "none");
    }

    function monitorByName(name) {
        return monitors.find(m => m.name === name);
    }

    function refreshMonitors() {
        // منع التداخل: لو التحديث جارٍ نعلِّم الطلب وننفذه بعد انتهاء الأول
        if (monitorProc.running) {
            root.refreshPending = true;
            return;
        }
        // مؤشر التحميل يحجز ارتفاعاً في التخطيط — ننفّشه فقط عند غياب أي بيانات
        // (أول تحميل أو قائمة فارغة) حتى لا يقفز التخطيط مع كل تحديث خلفي
        root.isLoading = (root.monitors || []).length === 0;
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
        // نرسل الحقل دائماً حتى لو فارغاً: hl.monitor يدمج مع القاعدة الموجودة،
        // و"mirror = ''" هو الطريقة الوحيدة لإلغاء المرآة (وإلا تبقى لاصقة) — مثبت عملياً
        lua += `, mirror = "${String(mirror ?? "").trim()}"`;
        lua += " })";
        console.info("[MonitorsSettings] hl.monitor:", lua);
        runCommand(["hyprctl", "eval", lua]);
    }

    // أمر مباشر (dispatch أو eval) — يُنفَّذ فوراً أو يُرصَّد في الطابور إن كانت
    // العملية مشغولة (وإلا سيتجاهله Quickshell بصمت)
    function runCommand(argv) {
        if (applyProc.running) {
            commandQueue.push(argv);
            return;
        }
        applyProc.command = argv;
        applyProc.running = true;
    }

    // بعد انتهاء كل أمر: تابع الطابور، أو حدِّث البيانات مرة واحدة بعد آخر أمر
    function startNextCommand() {
        if (commandQueue.length === 0) {
            refreshTimer.restart();
            return;
        }
        applyProc.command = commandQueue.shift();
        applyProc.running = true;
    }

    // وضع الشاشة في جانب معين باستخدام المواضع النسبية الأصلية في Hyprland:
    // auto-right/auto-left/auto-up/auto-down — Hyprland يحسب التوازن بدقة بنفسه
    // (بكل المقاييس والدورات) بدلاً من حساب البكسل يدوياً بخلط وحدات فيزيائية ومنطقية
    function placeRelative(name, side) {
        const target = monitorByName(name);
        if (!target)
            return;
        const dir = { right: "auto-right", left: "auto-left", above: "auto-up", below: "auto-down" }[side];
        if (!dir)
            return;
        console.info(`[MonitorsSettings] place ${name} ${side} -> position ${dir}`);
        applyRule(name, currentModeString(target), dir, target.scale, target.transform ?? 0, Number(target.vrr ?? 0), "");
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
                    // نُسند أسماء الشاشات فقط عند تغيرها الفعلي (توصيل/فصل):
                    // إسناد مصفوفة جديدة كل تحديث يعيد بناء كل البطاقات ويبدد الحالة المحلية
                    const namesKey = parsed.map(m => m.name).join("\u0001");
                    if (namesKey !== root.monitorNames.join("\u0001")) {
                        root.monitorNames = parsed.map(m => m.name);
                        console.info(`[MonitorsSettings] monitor set changed: ${root.monitorNames.join(", ")}`);
                    }
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
        // نفّذ أي طلب تحديث تم رصده أثناء الجريّ — آمن بعد الخروج (running=false مضمون)
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refreshMonitors();
            }
        }
    }

    // =========================================================
    // 3. تنفيذ الأوامر (Process)
    // =========================================================

    Process {
        id: applyProc
        // آخر مخرجات stdout — يخزنها المجمع لاستخدامها في onExited
        property string lastOutput: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const output = String(this.text || "").trim();
                // hyprctl يطبع "ok" عند النجاح، والأخطاء على stdout أيضاً
                if (output !== "" && output !== "ok")
                    console.warn("[MonitorsSettings] hyprctl apply:", output);
                applyProc.lastOutput = output;
            }
        }
        stderr: SplitParser {
            onRead: data => console.error("[MonitorsSettings] hyprctl:", data)
        }
        onExited: (exitCode, exitStatus) => {
            // hyprctl eval يطبع الأخطاء على stdout ويخرج برمز غير صفري (7 عند فشل Lua)
            const output = applyProc.lastOutput;
            applyProc.lastOutput = "";
            if (exitCode !== 0 || String(output).startsWith("error")) {
                root.applyError = output !== "" ? output : `hyprctl command failed (exit ${exitCode})`;
                errorClearTimer.restart();
            }
            root.startNextCommand();
        }
    }

    // تحديث لاحق بعد التطبيق حتى تستقر حالة Hyprland
    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: root.refreshMonitors()
    }

    // مسح خطأ آخر أمر تطبيق تلقائياً بعد 6 ثوانٍ
    Timer {
        id: errorClearTimer
        interval: 6000
        onTriggered: root.applyError = ""
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

        // تلميح: كل التغييرات هنا runtime فقط (قواعد hl.monitor في الذاكرة)
        SettingsHelperText {
            text: qsTr("Changes apply live for this session and are cleared when Hyprland restarts. Add the matching monitor rule to your Hyprland config to keep them.")
            Layout.fillWidth: true
        }

        // رسالة خطأ: فشل تحليل بيانات (يبقى حتى تحديث ناجح) أو فشل آخر أمر تطبيق (يُمسح تلقائياً)
        Label {
            visible: root.lastError !== "" || root.applyError !== ""
            text: root.applyError !== "" ? root.applyError : root.lastError
            wrapMode: Text.Wrap
            font.pixelSize: 11
            color: selectedTheme.colors.error
            Layout.fillWidth: true
        }

        ListView {
            id: monitorsView
            // موديل مستقر بالأسماء: نفس البطاقات تبقى حية عبر التحديثات، والبيانات
            // تتدفق عبر monitorByName داخل onMonitorChanged في كل بطاقة
            model: root.monitorNames
            spacing: 12

            Layout.fillWidth: true
            implicitHeight: contentHeight

            delegate: MonitorItem {
                required property string modelData
                monitor: root.monitorByName(modelData)
                allMonitors: root.monitors
                selectedTheme: root.selectedTheme

                onApplyRule: (name, res, pos, scale, transform, vrr, mirror) => root.applyRule(name, res, pos, scale, transform, vrr, mirror)
                onPlaceRelative: (name, side) => root.placeRelative(name, side)
                onRunCommand: argv => root.runCommand(argv)
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
