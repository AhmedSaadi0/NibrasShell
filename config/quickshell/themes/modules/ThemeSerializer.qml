import QtQuick
import Quickshell.Io
import "root:/config" // للوصول لـ App

Item {
    id: root

    // القوائم التي نود حفظها (منقولة من ThemeManager القديم)
    readonly property var _colorKeys: [
        "themeName",
        // M3 Core
        "_primary", "_onPrimary", "_secondary", "_onSecondary",
        "_tertiary", "_onTertiary", "_error", "_onError",
        // M3 Surface
        "_surface", "_onSurface", "_surfaceDim", "_surfaceBright",
        "_surfaceContainerLowest", "_surfaceContainerLow", "_surfaceContainer",
        "_surfaceContainerHigh", "_surfaceContainerHighest",
        "_surfaceVariant", "_onSurfaceVariant",
        // M3 Container
        "_primaryContainer", "_onPrimaryContainer",
        "_secondaryContainer", "_onSecondaryContainer",
        "_tertiaryContainer", "_onTertiaryContainer",
        "_errorContainer", "_onErrorContainer",
        // M3 Outline
        "_outline", "_outlineVariant",
        // M3 Inverse
        "_inverseSurface", "_onInverseSurface", "_inversePrimary",
        // M3 Shadow/Scrim
        "_shadow", "_scrim"
    ]
    readonly property var _dimKeys: ["_baseRadius", "_barHeight", "_barBottomMargin", "_barWidgetsHeight", "_menuHeight", "_menuWidth", "_menuWidgetsMargin", "_elementRadius", "_spacingSmall", "_spacingMedium", "_spacingLarge", "_shapeNone", "_shapeExtraSmall", "_shapeSmall", "_shapeMedium", "_shapeLarge", "_shapeExtraLarge", "_shapeFull", "_dialogIconSize", "_iconButtonSize", "_iconButtonRadius", "_chipHeight", "_scrollbarWidth", "_statCardRadius", "_statCardHeight", "_dialogOpenScaleDuration", "_dialogOpenOpacityDuration", "_dialogInitialScale"]
    readonly property var _typeKeys: ["_iconFont", "_bodyFont", "_baseFontSize", "_heading1Size", "_heading2Size", "_heading3Size", "_heading4Size", "_mediumFontSize", "_smallFontSize"]
    readonly property var _hyprKeys: ["_hyprBorderWidth", "_hyprActiveBorder", "_hyprInactiveBorder", "_hyprRounding", "_hyprDropShadow", "_hyprGapsIn", "_hyprGapsOut", "_hyprLayout", "_hyprAnimationsEnabled", "_hyprBezier", "_hyprAnimWindows", "_hyprAnimWindowsIn", "_hyprAnimWindowsMove", "_hyprAnimWindowsOut", "_hyprAnimBorder", "_hyprAnimBorderAngle", "_hyprAnimFadeIn", "_hyprAnimFadeOut", "_hyprAnimWorkspaces", "_hyprBlurEnabled", "_hyprBlurSize", "_hyprBlurPasses", "_hyprDimInactive", "_hyprDimStrength", "_hyprShadowRange", "_hyprShadowOffset", "_hyprShadowColor"]
    readonly property var _wallKeys: ["_enableDynamicColoring", "_enableDynamicWallpapers", "_dynamicWallpapersInterval", "_dynamicWallpapersPath", "_selectedWallpaperIndex", "_wallpaper", "_dynamicColoringSchemeVariant", "_dynamicColoringChromaMult", "_dynamicColoringToneMult", "_enableWallpaperBlur"]
    readonly property var _sysKeys: ["_qtThemeStyle", "_kvantumTheme", "_plasmaColorScheme", "_konsoleProfile", "_enableAccentColoring", "_gtkTheme", "_themeIcons", "_themeMode", "_cursorTheme", "_cursorSize"]
    readonly property var _clockKeys: ["_desktopClockLocal", "_desktopClockFont", "_desktopClockEnabled", "_desktopClockColor", "_desktopClockFormat", "_desktopClockPosition", "_desktopClockDepthEffectEnabled", "_desktopClockDepthModel", "_desktopClockDepthOverlayPath", "_desktopClockSize", "_desktopClockGlowColor", "_desktopClockGlowEnabled", "_desktopClockGlowIntensity", "_desktopClockShadowColor", "_desktopClockShadowEnabled", "_desktopClockUseThemeColor", "_desktopClockUseAnimation"]

    // تجميع الكل
    readonly property var allKeys: _colorKeys.concat(_dimKeys).concat(_typeKeys).concat(_hyprKeys).concat(_wallKeys).concat(_sysKeys).concat(_clockKeys)

    signal cacheFileUpdated
    signal keysRemoved

    // حفظ الثيم الحالي للكاش
    function saveToCache(themeInstance, fileName, notify = false) {
        if (!themeInstance)
            return;

        let data = {};
        for (const key of allKeys) {
            if (themeInstance.hasOwnProperty(key)) {
                data[key] = themeInstance[key];
            }
        }

        // كتابة الملف
        cacheFile.path = App.themeCacheFolderPath + `/${fileName}.json`;
        cacheFile.signalToCall = "apply";
        cacheFile.setText(JSON.stringify(data, null, 2));

        if (notify) {
            console.info("[ThemeSerializer] Theme saved to cache:", fileName);
        }
    }

    // تطبيق بيانات JSON على الثيم النشط
    function applyData(themeInstance, jsonData) {
        console.info("[ThemeSerializer] applyData called.");

        if (!themeInstance) {
            console.error("[ThemeSerializer] ERROR: themeInstance is null!");
            return;
        }
        if (!jsonData) {
            console.error("[ThemeSerializer] ERROR: jsonData is null!");
            return;
        }

        let appliedCount = 0;
        let keys = Object.keys(jsonData);
        console.info(`[ThemeSerializer] Processing ${keys.length} keys from JSON.`);

        const isDynamicColoring = themeInstance.systemSettings.enableDynamicColoring;

        for (const key of keys) {
            if (key === "themeName" || (isDynamicColoring && _colorKeys.includes(key)))
                continue;

            if (themeInstance.hasOwnProperty(key)) {
                try {
                    let oldVal = themeInstance[key];
                    let newVal = jsonData[key];

                    if (oldVal !== newVal) {
                        themeInstance[key] = newVal;
                        appliedCount++;
                    }
                } catch (err) {
                    console.warn(`[ThemeSerializer] Failed to set property ${key}: ${err.message}`);
                }
            } else
            // خاصية في الجيسون غير موجودة في الثيم
            // console.info(`[ThemeSerializer] Skipped unknown key: ${key}`);
            {}
        }
        console.info(`[ThemeSerializer] Finished. Total properties updated: ${appliedCount}`);
    }

    function removeKeysFromCache(themeName, keysToRemove, currentCacheContent) {
        if (!keysToRemove || !Array.isArray(keysToRemove)) {
            console.error("[Reset] Error: keysToRemove is invalid or not an array:", keysToRemove);
            return;
        }

        console.info(`[Reset] Removing ${keysToRemove.length} keys from cache for theme: ${themeName}`);

        let json = {};

        if (currentCacheContent && currentCacheContent.trim() !== "") {
            try {
                json = JSON.parse(currentCacheContent);
            } catch (e) {
                console.warn("[Reset] Cache content corrupted, treating as empty.");
                json = {};
            }
        }

        let removedCount = 0;
        let removedKeys = [];
        for (const key of keysToRemove) {
            if (json.hasOwnProperty(key)) {
                removedKeys.push(`${key} = ${json[key]}`);
                delete json[key];
                removedCount++;
            }
        }

        if (removedCount > 0) {
            console.info(`[Reset] Keys removed from cache (${removedCount}):`);
            for (const entry of removedKeys) {
                console.info(`[Reset]   ${entry} → deleted (will revert to default)`);
            }
            console.info(`[Reset] Remaining keys in cache: ${Object.keys(json).length}`);
            for (const key of Object.keys(json)) {
                console.info(`[Reset]   ${key} = ${json[key]} (preserved)`);
            }

            try {
                const filePath = App.themeCacheFolderPath + `/${themeName}.json`;
                cacheFile.path = filePath;
                cacheFile.signalToCall = "removeCache";
                cacheFile.setText(JSON.stringify(json, null, 2));
                console.info(`[Reset] Cache file updated successfully.`);
            } catch (e) {
                console.error("[Reset] Failed to write to cache file:", e);
            }
        } else {
            console.info("[Reset] No matching keys found in cache to remove (Already defaults?).");
        }

        console.info(`========== RESET END ==========\n`);
    }

    FileView {
        id: cacheFile
        watchChanges: false

        property string signalToCall: ""

        onDataChanged: {
            switch (signalToCall) {
            case "apply":
                cacheFile.signalToCall = "";
                return root.cacheFileUpdated();
            case "removeCache":
                cacheFile.signalToCall = "";
                return root.keysRemoved();
            }

            cacheFile.signalToCall = "";
        }
    }
}
