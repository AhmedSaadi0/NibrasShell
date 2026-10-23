// components/BaseLauncher.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "root:/themes"
import "root:/components"
import "root:/config"
import "root:/config/EventNames.js" as Events

Item {
    id: root

    // ==========================================================================
    // Shared Properties
    // ==========================================================================

    // --- Search State ---
    property string searchText: ""
    property string selectedCategory: ""

    // --- Command Mode Properties ---
    property bool isCommandMode: CommandsRegistry.isCommandMode(searchText)
    property string commandText: CommandsRegistry.getCommandText(searchText)
    property var filteredCommands: isCommandMode ? CommandsRegistry.filterCommands(commandText) : []

    // --- View State ---
    property string activeCommandView: ""
    property int selectedAppIndex: -1
    property int selectedCommandIndex: -1

    // اللوكال الافتراضي المستخدم عند "تشغيل بلوكال افتراضي" (يتجاوز LANG/LC_ALL فقط)
    readonly property var defaultLocaleEnv: ({
        LANG: "C.UTF-8",
        LC_ALL: "C.UTF-8"
    })

    // --- Computed property for view index ---
    property int currentViewIndex: {
        if (activeCommandView === "wallpaper")
            return 2;
        if (isCommandMode)
            return 1;
        return 0;
    }

    // ==========================================================================
    // Hooks for subclass behavior
    // ==========================================================================

    property var onAppLaunchedCallback: null
    property var onCommandExecutedCallback: null
    property var onResetStateCallback: null
    property var onRequestFocusCallback: null

    // ==========================================================================
    // Shared Functions
    // ==========================================================================

    // --- Favorites Management ---
    function toggleFavorite(appData) {
        if (typeof App !== 'undefined' && appData && appData.id) {
            const appId = appData.id;
            const index = App.favoriteApps.indexOf(appId);
            if (index === -1) {
                App.favoriteApps.push(appId);
            } else {
                App.favoriteApps.splice(index, 1);
            }
            App.updateConfig("favoriteApps", App.favoriteApps);
        }
    }

    function isFavorite(appData) {
        if (typeof App !== 'undefined' && appData && appData.id) {
            const appId = appData.id;
            return App.favoriteApps.indexOf(appId) !== -1;
        }
        return false;
    }

    function togglePinToDock(appData) {
        if (typeof App !== 'undefined' && appData && appData.id) {
            const appId = appData.id;
            const index = App.dockApps.indexOf(appId);
            if (index === -1) {
                App.dockApps.push(appId);
            } else {
                App.dockApps.splice(index, 1);
            }
            App.updateConfig("dockApps", App.dockApps);
            EventBus.emit(Events.DOCK_APPS_CHANGED);
        }
    }

    function isPinnedToDock(appData) {
        if (typeof App !== 'undefined' && appData && appData.id) {
            const appId = appData.id;
            return App.dockApps.indexOf(appId) !== -1;
        }
        return false;
    }

    // --- Command Execution ---
    function executeCommand(cmd) {
        if (cmd && cmd.enabled !== false) {
            if (cmd.isAction) {
                if (cmd.action === "openSettings") {
                    EventBus.emit(Events.OPEN_SETTINGS);
                } else if (cmd.action === "nextWallpaper") {
                    ThemeManager.switchToNextWallpaper();
                } else if (cmd.action === "previousWallpaper") {
                    ThemeManager.switchToPreviousWallpaper();
                }
            } else if (cmd.view !== "") {
                activeCommandView = cmd.view;
            }
        }
        if (onCommandExecutedCallback) {
            onCommandExecutedCallback(cmd);
        }
    }

    function launchApp(command, workingDirectory, environment) {
        if (command) {
            clearSearchText.stop();
            // Quickshell.execDetached passes argv VERBATIM (no shell).
            // لا تدعم كل الإصدارات environment property، لذا نمرر اللوكال
            // عبر prefix يُفسَّره sh مباشرة (مضمون على كل الإصدارات).
            // نمرر كقائمة ["sh", "-c", finalCommand] لتجنب أي غموض في تفسير execDetached.
            let finalCommand = command;
            if (environment) {
                const envPrefix = Object.keys(environment)
                    .map(k => k + "=" + environment[k])
                    .join(" ");
                finalCommand = envPrefix + " " + command;
            }
            console.info("[Locale][BaseLauncher.launchApp] finalCommand:", JSON.stringify(finalCommand));
            console.info("[Locale][BaseLauncher.launchApp] workingDirectory:", JSON.stringify(workingDirectory));
            console.info("[Locale][BaseLauncher.launchApp] env applied:", !!environment);
            // NOTE: list form — {command:[...]} throws TypeError on QS 0.3.0,
            // so workingDirectory is folded into the sh -c script.
            let cdPrefix = "";
            if (workingDirectory)
                cdPrefix = "cd '" + String(workingDirectory).replace(/'/g, "'\\''") + "' && ";
            Quickshell.execDetached(["sh", "-c", cdPrefix + finalCommand]);
            clearSearchText.start();
            if (onAppLaunchedCallback) {
                onAppLaunchedCallback();
            }
        } else {
            console.warn("[Locale][BaseLauncher.launchApp] command فارغ - لا يمكن التشغيل");
        }
    }

    // تشغيل البرنامج مع تجاهل اللوكال الحالي للنظام
    function launchAppWithDefaultLocale(command, workingDirectory) {
        console.info("[Locale] launchAppWithDefaultLocale called, cmd:", JSON.stringify(command), "wd:", JSON.stringify(workingDirectory));
        launchApp(command, workingDirectory, defaultLocaleEnv);
    }

    // --- Selection Helpers ---
    function getActualListIndex(logicalIndex) {
        if (logicalIndex < 0) return -1;
        
        let appCount = 0;
        for (let i = 0; i < filteredAppsModel.values.length; i++) {
            const item = filteredAppsModel.values[i];
            if (item && !item.isHeader) {
                if (appCount === logicalIndex) {
                    return i;
                }
                appCount++;
            }
        }
        return -1;
    }

    function getFirstActualAppIndex() {
        for (let i = 0; i < filteredAppsModel.values.length; i++) {
            const item = filteredAppsModel.values[i];
            if (item && !item.isHeader) {
                return i;
            }
        }
        return -1;
    }

    function getLogicalIndex(actualListIndex) {
        let appCount = 0;
        for (let i = 0; i < filteredAppsModel.values.length && i <= actualListIndex; i++) {
            const item = filteredAppsModel.values[i];
            if (item && !item.isHeader) {
                appCount++;
            }
        }
        return appCount - 1;
    }

    function getAppCount() {
        let count = 0;
        for (let i = 0; i < filteredAppsModel.values.length; i++) {
            const item = filteredAppsModel.values[i];
            if (item && !item.isHeader) {
                count++;
            }
        }
        return count;
    }

    

    // --- Selection Management ---
    function ensureAppSelection() {
        if (isCommandMode || activeCommandView !== "") {
            selectedAppIndex = -1;
            return;
        }

        let appCount = getAppCount();
        if (appCount === 0) {
            selectedAppIndex = -1;
            return;
        }

        if (selectedAppIndex < 0) {
            selectedAppIndex = getActualListIndex(0);
            if (selectedAppIndex < 0) {
                selectedAppIndex = -1;
            }
            return;
        }

        let logicalIndex = getLogicalIndex(selectedAppIndex);
        if (logicalIndex < 0 || logicalIndex >= appCount) {
            selectedAppIndex = getActualListIndex(0);
        }
    }

    function ensureCommandSelection() {
        if (!isCommandMode || filteredCommands.length === 0) {
            selectedCommandIndex = -1;
            return;
        }

        if (selectedCommandIndex >= 0 && selectedCommandIndex < filteredCommands.length && filteredCommands[selectedCommandIndex] && filteredCommands[selectedCommandIndex].enabled !== false) {
            return;
        }

        selectedCommandIndex = -1;
        for (let i = 0; i < filteredCommands.length; i++) {
            if (filteredCommands[i] && filteredCommands[i].enabled !== false) {
                selectedCommandIndex = i;
                return;
            }
        }
    }

    function moveSelection(dir) {
        if (isCommandMode) {
            moveCommandSelection(dir);
            return;
        }
        if (activeCommandView !== "")
            return;

        const model = filteredAppsModel.values;
        let currentActualIndex = selectedAppIndex;

        let newActualIndex = currentActualIndex;
        let found = false;

        if (dir > 0) {
            for (let j = currentActualIndex + 1; j < model.length; j++) {
                const item = model[j];
                if (item && !item.isHeader) {
                    newActualIndex = j;
                    found = true;
                    break;
                }
            }
            if (!found) {
                for (let j = 0; j < currentActualIndex; j++) {
                    const item = model[j];
                    if (item && !item.isHeader) {
                        newActualIndex = j;
                        found = true;
                        break;
                    }
                }
            }
        } else {
            for (let j = currentActualIndex - 1; j >= 0; j--) {
                const item = model[j];
                if (item && !item.isHeader) {
                    newActualIndex = j;
                    found = true;
                    break;
                }
            }
            if (!found) {
                for (let j = model.length - 1; j > currentActualIndex; j--) {
                    const item = model[j];
                    if (item && !item.isHeader) {
                        newActualIndex = j;
                        found = true;
                        break;
                    }
                }
            }
        }

        if (found && newActualIndex >= 0) {
            selectedAppIndex = newActualIndex;
        }
    }

    function moveCommandSelection(dir) {
        if (filteredCommands.length === 0)
            return;

        let idx = selectedCommandIndex;
        if (idx < 0) {
            idx = dir > 0 ? -1 : filteredCommands.length;
        }

        let nextIndex = idx;
        while (true) {
            nextIndex += dir;
            if (nextIndex < 0 || nextIndex >= filteredCommands.length)
                break;

            const candidate = filteredCommands[nextIndex];
            if (candidate && candidate.enabled !== false) {
                selectedCommandIndex = nextIndex;
                return;
            }
        }

        const fallbackStart = dir > 0 ? 0 : filteredCommands.length - 1;
        const fallbackEnd = dir > 0 ? filteredCommands.length : -1;
        for (let i = fallbackStart; i !== fallbackEnd; i += dir) {
            const candidate = filteredCommands[i];
            if (candidate && candidate.enabled !== false) {
                selectedCommandIndex = i;
                return;
            }
        }
    }

    function activateSelection() {
        if (isCommandMode) {
            activateCommandSelection();
            return;
        }
        if (activeCommandView !== "")
            return;

        const item = filteredAppsModel.values[selectedAppIndex];
        if (item && !item.isHeader) {
            launchApp(item.appData.command, item.appData.workingDirectory);
        }
    }

    function activateCommandSelection() {
        if (filteredCommands.length === 0)
            return;

        let idx = selectedCommandIndex;
        if (idx < 0 || idx >= filteredCommands.length || !filteredCommands[idx] || filteredCommands[idx].enabled === false) {
            idx = -1;
            for (let i = 0; i < filteredCommands.length; i++) {
                if (filteredCommands[i] && filteredCommands[i].enabled !== false) {
                    idx = i;
                    break;
                }
            }
        }

        if (idx >= 0 && idx < filteredCommands.length) {
            executeCommand(filteredCommands[idx]);
        }
    }

    function resetState() {
        searchText = "";
        activeCommandView = "";
        selectedAppIndex = -1;
        selectedCommandIndex = -1;
        if (onResetStateCallback) {
            onResetStateCallback();
        }
    }

    function doGainFocus() {
        forceActiveFocus();
        focusTimer.start();
        if (onRequestFocusCallback) {
            onRequestFocusCallback();
        }
    }

    // ==========================================================================
    // Shared Timers
    // ==========================================================================

    Timer {
        id: focusTimer
        interval: 10
        running: false
        repeat: false
        onTriggered: {
            if (onRequestFocusCallback) {
                onRequestFocusCallback();
            }
        }
    }

    Timer {
        id: clearSearchText
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            root.resetState();
        }
    }

    // ==========================================================================
    // Shared Signal
    // ==========================================================================

    signal appLaunched

    // ==========================================================================
    // Shared Models
    // ==========================================================================

    property alias filteredAppsModel: filteredAppsModel

    ScriptModel {
        id: filteredAppsModel
        values: {
            if (root.isCommandMode || root.activeCommandView !== "") {
                return [];
            }

            const search = root.searchText.toLowerCase();
            const category = root.selectedCategory;
            const favoriteApps = (typeof App !== 'undefined') ? App.favoriteApps : [];

            const desktopEntriesValues = DesktopEntries ? DesktopEntries.applications.values : null;
            
            if (!desktopEntriesValues)
                return [];
            
            const allApps = [...desktopEntriesValues].filter(app => app && app.name && app.noDisplay !== true);

            const filtered = allApps.filter(app => {
                if (category !== "") {
                    const categories = app.categories || [];
                    if (!categories.some(cat => cat.toLowerCase().includes(category.toLowerCase())))
                        return false;
                }

                if (search === "")
                    return true;

                const nameMatch = app.name.toLowerCase().includes(search);
                const commentMatch = (app.comment || "").toLowerCase().includes(search);
                const genericNameMatch = (app.genericName || "").toLowerCase().includes(search);
                const categoriesMatch = (app.categories || []).some(cat => cat.toLowerCase().includes(search));

                return nameMatch || commentMatch || genericNameMatch || categoriesMatch;
            });
            
            const sorted = filtered.sort((a, b) => {
                const aIsFavorite = favoriteApps.includes(a.id);
                const bIsFavorite = favoriteApps.includes(b.id);
                if (aIsFavorite && !bIsFavorite)
                    return -1;
                if (!aIsFavorite && bIsFavorite)
                    return 1;
                return a.name.localeCompare(b.name);
            });

            const structured = [];

            if (search === "") {
                const favorites = sorted.filter(app => favoriteApps.includes(app.id));
                if (favorites.length > 0) {
                    structured.push({ isHeader: true, letter: "Favorites", isFavoritesHeader: true });
                    favorites.forEach(app => {
                        structured.push({ isHeader: false, appData: app });
                    });
                }
            }

            let currentLetter = "";
            for (const app of sorted) {
                if (search === "" && favoriteApps.includes(app.id)) continue;

                const firstLetter = app.name.charAt(0).toUpperCase();
                if (firstLetter !== currentLetter) {
                    currentLetter = firstLetter;
                    structured.push({ isHeader: true, letter: currentLetter });
                }
                structured.push({ isHeader: false, appData: app });
            }

            return structured;
        }
    }
}
