// windows/settings/components/BaseThemeSettings.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import "root:/components"
import "root:/components/settings"
import "root:/config"
import "root:/themes"
import "root:/windows/settings/components"

M3GroupBox {
    id: root

    property bool isLoading: true
    property bool isReady: false
    property string lastThemeName: ""

    property bool showApplyButton: false
    property bool showUndoRedoButtons: false

    readonly property var theme: ThemeManager.selectedTheme

    function dim(k, d) {
        return theme ? theme.dimensions[k] : d;
    }
    function typ(k, d) {
        return theme ? theme.typography[k] : d;
    }

    signal saveChanges
    signal cancelChanges
    signal resetToDefaultClicked

    // Radius tokens have a parent/child relationship: _elementRadius and
    // _shapeMedium are normally bound to _baseRadius. Apply the root first so
    // live bindings can cascade; the dependent entries then become no-ops.
    readonly property var _radiusMutationOrder: [
        "_baseRadius",
        "_elementRadius",
        "_shapeMedium",
        "_shapeNone"
    ]

    function syncFromTheme() {
        console.warn("BaseThemeSettings: syncFromTheme() needs to be overridden");
    }

    function serializeData() {
        console.warn("BaseThemeSettings: serializeData() needs to be overridden");
        return {};
    }

    function refresh(force) {
        if (!theme)
            return;

        if (force || theme.themeName !== lastThemeName) {
            isLoading = true;

            syncFromTheme();

            lastThemeName = theme.themeName;
            isReady = true;
            isLoading = false;
            console.info("[" + root.title + "] Local state refreshed.");
        }
    }

    function collectAndApply(saveToDisk) {
        if (isLoading || !isReady || !theme)
            return;

        applyProperties(serializeData(), saveToDisk === true);
    }

    function applyProperties(propertiesMap, saveToDisk = false) {
        if (!theme || isLoading || !isReady)
            return false;

        if (!propertiesMap || typeof propertiesMap !== "object" || Array.isArray(propertiesMap))
            return false;

        // Pass 1: validate and copy every candidate.
        const candidates = {};
        for (const key in propertiesMap) {
            if (!Object.prototype.hasOwnProperty.call(propertiesMap, key))
                continue;
            if (key === "__proto__" || key === "constructor" || key === "prototype")
                continue;
            if (!theme.hasOwnProperty(key)) {
                console.warn(`[${root.title}] Unknown theme property: ${key}`);
                continue;
            }

            const value = propertiesMap[key];
            if (value === undefined || value === null) {
                console.warn(`[${root.title}] Skipping nullish value for ${key}`);
                continue;
            }
            if (typeof value === "number" && !Number.isFinite(value)) {
                console.warn(`[${root.title}] Skipping non-finite value for ${key}: ${value}`);
                continue;
            }

            candidates[key] = value;
        }

        // A base change may cascade into live dependents. If the caller also
        // supplied dependent values, keep them even when they currently equal
        // the target, so the batch can pin the intended final tuple.
        const baseChanging = Object.prototype.hasOwnProperty.call(candidates, "_baseRadius")
                && theme._baseRadius !== candidates["_baseRadius"];
        const pinnedDependents = ["_elementRadius", "_shapeMedium"];

        // Pass 2: drop no-op keys.
        const normalized = {};
        for (const key in candidates) {
            if (!Object.prototype.hasOwnProperty.call(candidates, key))
                continue;

            const mustPin = baseChanging && pinnedDependents.indexOf(key) !== -1;
            if (!mustPin && theme[key] === candidates[key])
                continue;

            normalized[key] = candidates[key];
        }

        // A no-op Apply must not touch the system. A no-op Save must still
        // snapshot the current theme, matching existing Save semantics.
        if (Object.keys(normalized).length === 0 && saveToDisk !== true)
            return false;

        // Pass 3: deterministic dependency order.
        const ordered = {};
        for (const key of root._radiusMutationOrder) {
            if (Object.prototype.hasOwnProperty.call(normalized, key))
                ordered[key] = normalized[key];
        }
        for (const key in normalized) {
            if (!Object.prototype.hasOwnProperty.call(normalized, key))
                continue;
            if (!Object.prototype.hasOwnProperty.call(ordered, key))
                ordered[key] = normalized[key];
        }

        console.info(`[${root.title}] Batch mutation: ${Object.keys(ordered).join(", ") || "(snapshot only)"}`);
        ThemeManager.updateAndApplyTheme(ordered, saveToDisk === true);

        if (saveToDisk === true)
            root.saveChanges();

        return true;
    }

    function applySingleProperty(key, value, saveToDisk = false) {
        if (typeof key !== "string" || key.length === 0)
            return false;

        const propertiesMap = {};
        propertiesMap[key] = value;
        return applyProperties(propertiesMap, saveToDisk);
    }

    function resetToDefault() {
        if (!theme || isLoading)
            return;

        let data = serializeData();
        console.info(`\n========== RESET [${root.title}] ==========`);
        console.info(`[Reset] Serializing ${Object.keys(data).length} keys from component...`);
        for (const key in data) {
            console.info(`[Reset]   ${key} = ${data[key]}`);
        }
        ThemeManager.loadDefaultValues(data);
        root.resetToDefaultClicked();
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            refresh(true);
        });
    }

    Connections {
        target: ThemeManager
        function onSelectedThemeUpdated() {
            if (!root.isLoading)
                refresh(true);
        }
    }

    footer: RowLayout {
        spacing: dim("spacingMedium", 10)

        MButton {
            text: "Reset"
            Layout.preferredWidth: 100
            onClicked: root.resetToDefault()
        }

        // زر تنظيف الكاش يظهر فقط إذا تم تعريف الإشارة في الاستخدام
        MButton {
            text: "Clear Cache"
            visible: root.hasOwnProperty("clearUnusedCache")
            Layout.preferredWidth: 120
            onClicked: root.clearUnusedCache()
        }

        MButton {
            text: "󰕍"
            visible: root.showUndoRedoButtons
            enabled: root.hasOwnProperty("canUndo") ? root.canUndo : false
            Layout.preferredWidth: 40
            onClicked: {
                if (root.hasOwnProperty("undo"))
                    root.undo();
            }
        }

        MButton {
            text: "󰑏"
            visible: root.showUndoRedoButtons
            enabled: root.hasOwnProperty("canRedo") ? root.canRedo : false
            Layout.preferredWidth: 40
            onClicked: {
                if (root.hasOwnProperty("redo"))
                    root.redo();
            }
        }

        Item {
            Layout.fillWidth: true
        }

        MButton {
            text: "Cancel"
            Layout.preferredWidth: 100
            onClicked: {
                root.refresh(true);
                root.cancelChanges();
            }
        }

        // زر تطبيق (بدون حفظ) - يظهر حسب الخاصية
        MButton {
            text: "Apply"
            visible: root.showApplyButton
            Layout.preferredWidth: 100
            onClicked: root.collectAndApply(false)
        }

        MButton {
            text: "Save"
            Layout.preferredWidth: 100
            highlighted: true
            onClicked: root.collectAndApply(true)
        }
    }
}
