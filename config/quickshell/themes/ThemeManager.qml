// themes/ThemeManager.qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/config"
import "root:/services"
import "root:/themes/modules"
import "root:/themes"

Singleton {
    id: root

    // =========================================================
    // 1. Public API & Properties
    // =========================================================

    // Read-only Aliases (Exposing internal state safely)
    readonly property alias selectedTheme: themeLoader.activeThemeInstance
    readonly property alias isInitialThemeReady: root._initialReady
    readonly property alias isApplyingTheme: root._isApplyingTheme
    readonly property alias isClockFontPreviewing: root._clockFontPreviewing
    readonly property alias clockPreviewFont: root._clockPreviewFont
    readonly property alias aiThemeAssistant: aiThemeAssistant
    readonly property alias bridgeSystem: bridgeSystem

    // Wallpaper Data Aliases
    readonly property alias currentWallpaper: wallpaperController.currentWallpaperPath
    readonly property alias localWallpapers: wallpaperController.localWallpapersList
    readonly property alias downloadedWallpapers: wallpaperController.downloadedWallpapersList
    readonly property alias wallhavenWallpapers: wallpaperController.wallhavenWallpapersList

    // Internal State Flags
    property bool _initialReady: false
    property var _pendingCacheData: null
    property string _pendingThemeName: ""
    property string _selectedThemeName: ""
    property bool _isApplyingTheme: false
    property bool _clockFontPreviewing: false
    // خط المعاينة الحية — يقرأه DesktopClock مباشرة (دون سلاسل ربط وسيطة)
    property string _clockPreviewFont: ""

    // =========================================================
    // 2. Signals
    // =========================================================

    // Theme Lifecycle Signals
    signal themeLoadStarted(string themeName)
    signal selectedThemeUpdated
    signal initialThemeReady

    // Feature Signals
    signal wallpaperChanged(string path)
    signal unusedCachedOverlayImagesDeleted
    signal creatingOverlayImageStarted
    signal creatingOverlayImageFinished(string newImagePath)

    // Forwarded Signals (Wallhaven & Downloads)
    signal fetchingWallhavenWallpapersStarted
    signal wallhavenWallpapersFetched(var response)
    signal wallhavenWallpapersError(string errorDetails)
    signal wallpaperDownloadStarted(string filePath)
    signal wallpaperDownloadFinished(string filePath)
    signal wallpaperDownloadError(string errorDetails)

    // =========================================================
    // 3. Public Methods (Wrappers)
    // =========================================================

    function refreshLocalWallpapers() {
        wallpaperController.refreshLocalWallpapers();
    }
    function refreshDownloadedWallpapers() {
        wallpaperController.refreshDownloadedWallpapers();
    }
    function refreshAllWallpaperLists() {
        wallpaperController.refreshAllWallpaperLists();
    }
    function searchWallhaven(url) {
        wallpaperController.searchWallhaven(url);
    }
    function downloadWallhaven(id, fileType, url) {
        wallpaperController.downloadWallhaven(id, fileType, url);
    }

    function getCurrentWallpaper() {
        return wallpaperController.currentWallpaperPath;
    }
    function switchToNextWallpaper() {
        wallpaperController.nextWallpaper();
    }
    function switchToPreviousWallpaper() {
        wallpaperController.previousWallpaper();
    }

    function requestCreateOverlayImage(options) {
        depthEffectController.createOverlayImage(options);
    }

    // تفعيل/إيقاف المعاينة الفورية لخط الساعة (أثناء فتح منتقي الخطوط)
    function setClockFontPreviewing(active) {
        root._clockFontPreviewing = active;
        if (!active)
            root._clockPreviewFont = "";
    }

    // ضبط خط المعاينة الحية — يطبقه DesktopClock فوراً عبر ربط مباشر
    function setClockPreviewFont(family) {
        root._clockPreviewFont = family;
    }

    // =========================================================
    // 4. Sub-Components (Modules)
    // =========================================================

    ThemeLoader {
        id: themeLoader
        onThemeLoaded: themeInstance => {
            // [Phase 4]: Raw QML Object Created
            console.info("[ThemeManager] Phase 4: Theme Object Created");

            // [Phase 5]: Hydration (Injecting Cached Data)
            if (root._pendingCacheData) {
                console.info("[ThemeManager] Phase 5: Injecting cached data into memory...");
                themeSerializer.applyData(themeInstance, root._pendingCacheData);
            } else {
                console.info("[ThemeManager] Phase 5: No cache data found, using defaults.");
            }

            // [Phase 6]: System Application (Single Source of Truth)
            _applyToSystem(themeInstance);

            // Persist Session
            fileSessionWriter.setText(JSON.stringify({
                activeThemeName: themeLoader.currentThemeName
            }));

            // Cleanup
            root._pendingCacheData = null;
            root._pendingThemeName = "";

            // Clear AI assistant chat on theme change
            aiThemeAssistant.clearChat();

            // Notify UI
            root.selectedThemeUpdated();

            if (!root._initialReady) {
                console.info("[ThemeManager] System Ready.");
                root._initialReady = true;
                root.initialThemeReady();
            }
        }
    }

    WallpaperController {
        id: wallpaperController
        onWallpaperReady: path => {
            if (selectedTheme && selectedTheme.systemSettings.enableDynamicColoring) {
                const settings = selectedTheme.systemSettings;
                bridgeSystem.applyM3(path, settings.themeMode, true, settings.dynamicColoringSchemeVariant, settings.dynamicColoringChromaMult, settings.dynamicColoringToneMult);
            }
            root.wallpaperChanged(path);
        }
        // Signal Forwarding
        onFetchingWallhavenWallpapersStarted: root.fetchingWallhavenWallpapersStarted()
        onWallhavenWallpapersFetched: response => root.wallhavenWallpapersFetched(response)
        onWallhavenWallpapersError: errorDetails => root.wallhavenWallpapersError(errorDetails)
        onWallpaperDownloadStarted: filePath => root.wallpaperDownloadStarted(filePath)
        onWallpaperDownloadFinished: filePath => root.wallpaperDownloadFinished(filePath)
        onWallpaperDownloadError: errorDetails => root.wallpaperDownloadError(errorDetails)
    }

    HyprlandBridge {
        id: bridgeHyprland
    }

    SystemBridge {
        id: bridgeSystem
    }

    ThemeSerializer {
        id: themeSerializer
        onKeysRemoved: {
            reloadTheme(true);
        }
    }

    DepthEffectController {
        id: depthEffectController
        onCreatingOverlayImageStarted: root.creatingOverlayImageStarted()
        onUnusedCachedOverlayImagesDeleted: root.unusedCachedOverlayImagesDeleted()
        onCreatingOverlayImageFinished: newImagePath => {
            updateAndApplyTheme({
                "_desktopClockDepthOverlayPath": newImagePath
            }, true);
            root.creatingOverlayImageFinished(newImagePath);
        }
    }

    AiThemeAssistant {
        id: aiThemeAssistant
    }

    // =========================================================
    // 5. Core Logic & Sequence Manager
    // =========================================================

    function cleardUnusedOverlayImages() {
        depthEffectController.cleardUnusedOverlayImages();
    }

    function requestLoadTheme(themeName, forceReload = false) {
        if (themeName === themeLoader.currentThemeName && root._initialReady && !forceReload)
            return;

        console.info(`[ThemeManager] Phase 1: Request received for ${themeName}`);
        root.themeLoadStarted(themeName);

        root._pendingThemeName = themeName;
        root._selectedThemeName = themeName;
        root._pendingCacheData = null;

        const cachePath = App.themeCacheFolderPath + `/${themeName}.json`;

        // Force file reload logic if path is identical
        if (fileThemeCache.path === cachePath) {
            fileThemeCache.path = "";
        }
        fileThemeCache.path = cachePath;

        // Restart safety timer in case file doesn't exist
        timerCacheTimeout.restart();
    }

    function _onCacheFileReady(content) {
        timerCacheTimeout.stop(); // Stop safety timer
        console.info("[ThemeManager] Phase 2: Cache File Check Complete.");

        if (content && content.trim() !== "") {
            try {
                let json = JSON.parse(content);
                // Verify cache belongs to requested theme
                if (json.themeName === root._pendingThemeName) {
                    root._pendingCacheData = json;
                    console.info("[ThemeManager] Valid cache found.");
                }
            } catch (e) {
                console.warn("[ThemeManager] Cache corrupted, ignoring.");
            }
        }

        // [Phase 3]: Instruct Loader
        console.info(`[ThemeManager] Phase 3: Instructing Loader to load ${root._pendingThemeName}`);
        themeLoader.loadTheme(root._pendingThemeName);
    }

    function reloadTheme(forceReload = false) {
        requestLoadTheme(themeLoader.currentThemeName, forceReload);
    }

    function loadDefaultValues(serializedData) {
        if (!selectedTheme || !serializedData)
            return;

        const keysToReset = Object.keys(serializedData);

        console.info(`[Reset] ${keysToReset.length} keys requested for reset.`);
        console.info(`[Reset] Current theme values that will revert to defaults:`);
        for (const key of keysToReset) {
            if (selectedTheme.hasOwnProperty(key)) {
                console.info(`[Reset]   ${key} = ${selectedTheme[key]} → default`);
            }
        }

        if (keysToReset.length > 0) {
            const currentContent = fileThemeCache.text();
            themeSerializer.removeKeysFromCache(themeLoader.currentThemeName, keysToReset, currentContent);
        }
    }

    function updateAndApplyTheme(data, saveToDisk) {
        if (!selectedTheme)
            return;

        // Apply to memory
        themeSerializer.applyData(selectedTheme, data);
        _applyToSystem(selectedTheme);

        // Apply to disk
        if (saveToDisk) {
            themeSerializer.saveToCache(selectedTheme, themeLoader.currentThemeName, true);
        }

        root.selectedThemeUpdated();
    }

    function updateThemePropertyOnly(data, saveToDisk) {
        if (!selectedTheme)
            return;

        // تحديث ذاكرة فقط — دون إعادة تطبيق النظام (Hyprland/GTK/M3/وولبيبر)
        // تُستخدم للمعاينة الحية والتغييرات الخفيفة كخط ساعة سطح المكتب
        themeSerializer.applyData(selectedTheme, data);

        if (saveToDisk) {
            themeSerializer.saveToCache(selectedTheme, themeLoader.currentThemeName, true);
        }

        root.selectedThemeUpdated();
    }

    function updateThemeColorsOnly(data, saveToDisk) {
        if (!selectedTheme)
            return;

        themeSerializer.applyData(selectedTheme, data);
        bridgeHyprland.applyConfig(selectedTheme.hyprlandConfiguration);

        if (saveToDisk) {
            themeSerializer.saveToCache(selectedTheme, themeLoader.currentThemeName, true);
        } else {
            root.selectedThemeUpdated();
        }
    }

    function _applyToSystem(theme) {
        console.info("[ThemeManager] Applying Final Configuration...");
        root._isApplyingTheme = true;
        bridgeHyprland.applyConfig(theme.hyprlandConfiguration);
        bridgeSystem.applySystemTheme(theme.systemSettings, theme.colors, theme.typography);
        wallpaperController.configure(theme.systemSettings);
        applyGuardTimer.restart();
    }

    function addLeftMenuSpacing() {
        bridgeHyprland.addLeftMenuSpacing(selectedTheme.hyprlandConfiguration, selectedTheme.dimensions);
    }

    function resetLeftMenuSpacing() {
        bridgeHyprland.resetLeftMenuSpacing(selectedTheme.hyprlandConfiguration);
    }

    // =========================================================
    // 6. IO & Initialization
    // =========================================================

    Component.onCompleted: {
        timerStartup.start();
    }

    // Delays startup slightly to ensure FileView is ready
    Timer {
        id: timerStartup
        interval: 50
        repeat: false
        onTriggered: {
            console.info("[ThemeManager] Startup: Reading Session...");
            try {
                let txt = fileSessionReader.text();
                let session = JSON.parse(txt);
                let target = session.activeThemeName || "DeerTheme";
                requestLoadTheme(target);
            } catch (e) {
                console.warn("[ThemeManager] Session missing or invalid. Loading default.");
                requestLoadTheme("DeerTheme");
            }
        }
    }

    // Safety fallback if cache file lookup fails/hangs
    Timer {
        id: timerCacheTimeout
        interval: 200
        repeat: false
        onTriggered: {
            console.warn("[ThemeManager] Cache lookup timed out (File likely missing). Proceeding with defaults.");
            _onCacheFileReady("");
        }
    }

    // رفع الحارس بعد 500ms — يكفي لـ KIconEngine كي يستقر
    Timer {
        id: applyGuardTimer
        interval: 500
        repeat: false
        onTriggered: {
            root._isApplyingTheme = false;
            IconService.refreshForNewTheme();
        }
    }

    FileView {
        id: fileSessionReader
        path: App.themeCacheFilePath
    }

    FileView {
        id: fileSessionWriter
        path: App.themeCacheFilePath
        watchChanges: false
    }

    FileView {
        id: fileThemeCache
        watchChanges: false
        onLoaded: {
            if (root._pendingThemeName !== "") {
                _onCacheFileReady(text());
            }
        }
    }
}
