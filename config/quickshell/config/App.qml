pragma Singleton

import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland

import "root:/utils"

Singleton {
    id: root

    readonly property string mainPath: Quickshell.shellDir
    readonly property var homePath: mainPath.split(".")[0]
    readonly property var configFilePath: homePath + ".nibrasshell.json"
    readonly property string assetsPath: mainPath + "/assets"
    readonly property string bashScriptsPath: mainPath + "/scripts"
    readonly property string wallpapersPath: assetsPath + "/wallpapers"
    readonly property string cacheFolderPath: homePath + ".cache/nibrasshell"
    readonly property string downloadedWallpapersPath: cacheFolderPath + "/wallpapers"
    readonly property string themeCacheFilePath: cacheFolderPath + "/theme.json"
    readonly property string todoFilePath: cacheFolderPath + "/todo.json"
    readonly property string themeCacheFolderPath: cacheFolderPath + "/themes/"
    // الملف الذي يحتفظ Hyprland بقواعد الشاشات (المقياس/الدقة/الموضع)
    readonly property string monitorsConfPath: homePath + ".config/hypr/monitors.conf"
    readonly property string pythonScriptsPath: mainPath + "/scripts/python"
    readonly property string pythonPath: cacheFolderPath + "/venv/bin/python"

    property var availableGeminiMusicModels: []
    property var availableGeminiWeatherModels: []

    property ConfigStore config: ConfigStore {
        configPath: root.configFilePath

        onSettingsLoaded: {
            if (root.aiApiKey !== "" || root.weatherAiApiKey !== "" || root.musicAiApiKey !== "") {
                console.info("Settings loaded, triggering initial models fetch...");
                root.modelsManager.refreshAll();
            } else {
                console.warn("Settings loaded but no API keys found. Skipping model fetch.");
            }
        }
    }

    // --------------------------------------------------------------
    property alias username: root.config.username
    property alias subtitle: root.config.subtitle
    property alias profilePicture: root.config.profilePicture
    property alias networkMonitor: root.config.networkMonitor
    property alias networkInterval: root.config.networkInterval
    property alias city: root.config.city
    property alias country: root.config.country
    property alias weatherLocation: root.config.weatherLocation
    property alias usePrayerTimes: root.config.usePrayerTimes

    // AI Keys
    property alias aiApiKey: root.config.aiApiKey
    property alias weatherAiApiKey: root.config.weatherAiApiKey
    property alias musicAiApiKey: root.config.musicAiApiKey
    property alias systemAiApiKey: root.config.systemAiApiKey

    // AI Persona
    property alias weatherPersona: root.config.weatherPersona
    property alias musicPersona: root.config.musicPersona
    property alias systemPersona: root.config.systemPersona
    property alias todoPersona: root.config.todoPersona

    // AI Configs
    property alias aiProvider: root.config.aiProvider
    property alias aiPreferredLanguage: root.config.aiPreferredLanguage
    property alias weatherAiModel: root.config.weatherAiModel
    property alias musicAiModel: root.config.musicAiModel
    property alias systemAiModel: root.config.systemAiModel
    property alias weatherAiHistoryTurns: root.config.weatherAiHistoryTurns

    // Hardware configs
    property alias enableHighCpuAlert: root.config.enableHighCpuAlert
    property alias enableHighRamAlert: root.config.enableHighRamAlert
    property alias enableHighTempAlert: root.config.enableHighTempAlert
    property alias playCpuAlarmSound: root.config.playCpuAlarmSound
    property alias playRamAlarmSound: root.config.playRamAlarmSound
    property alias playTempAlarmSound: root.config.playTempAlarmSound

    property alias cpuHighLoadThreshold: root.config.cpuHighLoadThreshold
    property alias ramHighLoadThreshold: root.config.ramHighLoadThreshold
    property alias tempHighThreshold: root.config.tempHighThreshold
    property alias resourceAlertCooldownMs: root.config.resourceAlertCooldownMs

    // Shell layout configs
    property alias bottomLauncherWidth: root.config.bottomLauncherWidth
    property alias firstDayOfWeek: root.config.firstDayOfWeek
    property alias menuStyle: root.config.menuStyle

    property alias favoriteApps: root.config.favoriteApps
    property alias dockApps: root.config.dockApps

    // Dock configs
    property alias showDock: root.config.showDock
    property alias dockIconSize: root.config.dockIconSize

    readonly property bool hasWindowsOnWorkspace: {
        if (!Hyprland.focusedWorkspace)
            return false;
        let wsId = Hyprland.focusedWorkspace.id;
        let toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            let win = toplevels[i];
            if (win.workspace && win.workspace.id === wsId) {
                return true;
            }
        }
        return false;
    }

    property alias topBarActiveWindowMinWidth: root.config.topBarActiveWindowMinWidth
    property alias topBarActiveWindowMaxWidth: root.config.topBarActiveWindowMaxWidth

    property alias activeWorkspacesIcons: root.config.activeWorkspacesIcons
    property alias inActiveWorkspacesIcons: root.config.inActiveWorkspacesIcons
    property alias dynamicWorkspaces: root.config.dynamicWorkspaces

    function updateConfig(key, value) {
        root.config.set(key, value);
    }

    function updateConfigMultiple(dataObject) {
        root.config.setMultiple(dataObject);
    }

    // -------------------------------------------------------------------------
    Component.onCompleted: {
        Hyprland.dispatch(`exec mkdir -p ${cacheFolderPath}`);
        Hyprland.dispatch(`exec mkdir -p ${themeCacheFolderPath}`);
    }

    readonly property QtObject modelsManager: QtObject {
        id: manager

        property bool isLoading: false
        property string lastError: ""

        function refreshAll() {
            if (manager.isLoading)
                return;

            console.info("Starting to refresh AI models...");
            manager.isLoading = true;
            manager.lastError = "";

            fetchMusicModelsProcess.running = true;
            fetchWeatherModelsProcess.running = true;
        }

        function parseOutput(output, type) {
            if (!output || output.trim() === "")
                return;

            try {
                const data = JSON.parse(output);

                let modelsList = [];

                if (data.models && Array.isArray(data.models)) {
                    modelsList = data.models.map(function (item) {
                        return item.name;
                    });
                } else if (Array.isArray(data)) {
                    modelsList = data;
                }

                if (modelsList.length > 0) {
                    if (type === "music") {
                        root.availableGeminiMusicModels = modelsList;
                        console.info(`Updated Music Models: ${modelsList.length} found.`);
                    } else if (type === "weather") {
                        root.availableGeminiWeatherModels = modelsList;
                        console.info(`Updated Weather Models: ${modelsList.length} found.`);
                    }
                } else {
                    console.warn(`[Warning] No models found inside '${type}' JSON response.`);
                }
            } catch (e) {
                console.error(`[Error] Failed to parse ${type} models JSON:`, e);
                console.debug("Output start:", output.substring(0, 100));
                manager.lastError = `Error parsing ${type} models`;
            }
        }

        function checkFinished() {
            if (!fetchMusicModelsProcess.running && !fetchWeatherModelsProcess.running) {
                manager.isLoading = false;
                console.info("Finished refreshing models.");
            }
        }
    }

    readonly property QtObject assets: QtObject {
        readonly property string logo: root.assetsPath + "/icons/logo.jpeg"
        readonly property QtObject icons: QtObject {
            readonly property string notification: root.assetsPath + "/icons/notification.png"
            readonly property string weather: root.assetsPath + "/icons/weather-icon.png"
            readonly property string hotWeather: root.assetsPath + "/icons/hot-weather.png"
            readonly property string coldWeather: root.assetsPath + "/icons/cold-weather.png"
            readonly property string fog: root.assetsPath + "/icons/fog.png"
            readonly property string rain: root.assetsPath + "/icons/rain.png"
            readonly property string wind: root.assetsPath + "/icons/wind.png"
            readonly property string thunder: root.assetsPath + "/icons/thunder.png"
            readonly property string mosque: root.assetsPath + "/icons/mosque.png"
            readonly property string highEnergyRate: root.assetsPath + "/icons/electrical-danger-sign.png"
            readonly property string highVoltage: root.assetsPath + "/icons/electrical-danger-sign.png"
            readonly property string highTempWarning: root.assetsPath + "/icons/electrical-danger-sign.png"
        }
        readonly property string fallbackAppIcon: root.assetsPath + "/icons/fallback-app.svg"
        readonly property QtObject audio: QtObject {
            readonly property string powerConnect: root.assetsPath + "/audio/power_in.mp3"
            readonly property string batteryLow: root.assetsPath + "/audio/low-battery.mp3"
            readonly property string notifyStandard: root.assetsPath + "/audio/notification.wav"
            readonly property string notifySoft: root.assetsPath + "/audio/notification2.wav"

            readonly property string smartCapsuleNotification: root.assetsPath + "/audio/smart_capsule.wav"
            readonly property string smartCapsuleWarning: root.assetsPath + "/audio/warning-sound.mp3"
            readonly property string smartCapsuleCritical: root.assetsPath + "/audio/warning-sound.mp3"

            // Not used
            // TODO: -> check these or delete them
            readonly property string desktopLogin: root.assetsPath + "/audio/desktop-login.wav"
            readonly property string desktopLogout: root.assetsPath + "/audio/desktop-logout.mp3"
            readonly property string hotWeather: root.assetsPath + "/audio/cold-weather.mp3"
            readonly property string coldWeather: root.assetsPath + "/audio/cold-weather.mp3"
            readonly property string rain: root.assetsPath + "/audio/rain-notification.mp3"
            readonly property string prayerTime: root.assetsPath + "/audio/prayer-notification.ogg"
            readonly property string highEnergyRate: root.assetsPath + "/audio/warning-sound.mp3"
            readonly property string highVoltage: root.assetsPath + "/audio/warning-sound.mp3"
            readonly property string highTempWarning: root.assetsPath + "/audio/warning-sound.mp3"
            readonly property string cpuHighUsage: root.assetsPath + "/audio/cpu_high_usage.wav"

            function playTone(tone) {
                const command = Helper.playSoundCommand(tone);
                dispatchCommand(`play tone -> ${tone}`, command);
            }
        }

        function getWallpaperPath(wallpaper) {
            return root.wallpapersPath + "/" + wallpaper;
        }
    }

    readonly property QtObject scripts: QtObject {
        readonly property QtObject python: QtObject {
            // Monotoring
            readonly property string batteryInfo: root.pythonScriptsPath + "/battery_info.py"
            readonly property string systemDiagnostics: root.pythonScriptsPath + "/system_diagnostics.py"
            readonly property string systemMonitor: root.pythonScriptsPath + "/system_monitor.py"
            readonly property string diskUsage: root.pythonScriptsPath + "/disk_usage.py"

            // Wallpaper & coloring
            // To get the wallpapers in a single folder
            readonly property string dynamicM3: root.pythonScriptsPath + "/m3/dynamic-m3.py"
            // To scan themes json files for wallpapers list and get them all as a single list
            readonly property string scanWallpapers: root.pythonScriptsPath + "/scan_wallpapers.py"

            // Depth effect
            readonly property string rembgOverylayWallpaper: root.pythonScriptsPath + "/create_depth_image_rembg.py"
            readonly property string opencvOverylayWallpaper: root.pythonScriptsPath + "/create_depth_image_opencv.py"
            readonly property string removeUnusedCachedOverlayImages: root.pythonScriptsPath + "/overlay_cache_images_cleaner.py"

            // WIFI
            readonly property string listWifi: root.pythonScriptsPath + "/network/list_wifi.py"
            readonly property string connectWifi: root.pythonScriptsPath + "/network/connect_wifi.py"
            readonly property string dataUsage: root.pythonScriptsPath + "/network/data_usage.py"
            readonly property string liveUsage: root.pythonScriptsPath + "/network/live_usage.py"

            // AI
            readonly property string mainAI: root.pythonScriptsPath + "/ai/main.py"
            readonly property string listGemini: root.pythonScriptsPath + "/ai/list-gemini.py"

            readonly property string getClipboard: root.pythonScriptsPath + "/get_clipboard.py"
            readonly property string applyKonsoleProfileOpenSessions: root.pythonScriptsPath + "/apply_konsole_profile_open_sessions.py"
            // Integration settings scripts
            readonly property string listQtStyles: root.pythonScriptsPath + "/list_qt_styles.py"
            readonly property string listIconThemes: root.pythonScriptsPath + "/list_icon_themes.py"
            readonly property string listPlasmaSchemes: root.pythonScriptsPath + "/list_plasma_schemes.py"
            readonly property string listKvantumThemes: root.pythonScriptsPath + "/list_kvantum_themes.py"
            readonly property string listKonsoleProfiles: root.pythonScriptsPath + "/list_konsole_profiles.py"
            readonly property string listGtkThemes: root.pythonScriptsPath + "/list_gtk_themes.py"
            readonly property string listCursorThemes: root.pythonScriptsPath + "/list_cursor_themes.py"

            // Commands
            readonly property var batteryInfoCommand: [pythonPath, batteryInfo]
            readonly property var systemDiagnosticsCommand: [pythonPath, systemDiagnostics]
            readonly property var systemMonitorCommand: [pythonPath, systemMonitor]
            readonly property var diskUsageCommand: [pythonPath, diskUsage]

            readonly property var dynamicM3Command: [pythonPath, dynamicM3]
            readonly property var scanWallpapersCommand: [pythonPath, scanWallpapers, "--themes_cache_dir", root.themeCacheFolderPath, "--shell_dir", root.mainPath]
            readonly property var rembgOverylayWallpaperCommand: [pythonPath, rembgOverylayWallpaper]
            readonly property var opencvOverylayWallpaperCommand: [pythonPath, opencvOverylayWallpaper]
            readonly property var removeUnusedCachedOverlayImagesCommand: [pythonPath, removeUnusedCachedOverlayImages]

            readonly property var listWifiCommand: [pythonPath, listWifi]
            readonly property var liveUsageCommand: [pythonPath, liveUsage]
            readonly property var dataUsageCommand: [pythonPath, dataUsage]
            readonly property var connectWifiCommand: [pythonPath, connectWifi]
            readonly property var applyKonsoleProfileOpenSessionsCommand: [pythonPath, applyKonsoleProfileOpenSessions]
            // Integration settings commands
            readonly property var listQtStylesCommand: [pythonPath, listQtStyles]
            readonly property var listIconThemesCommand: [pythonPath, listIconThemes]
            readonly property var listPlasmaSchemesCommand: [pythonPath, listPlasmaSchemes]
            readonly property var listKvantumThemesCommand: [pythonPath, listKvantumThemes]
            readonly property var listKonsoleProfilesCommand: [pythonPath, listKonsoleProfiles]
            readonly property var listGtkThemesCommand: [pythonPath, listGtkThemes]
            readonly property var listCursorThemesCommand: [pythonPath, listCursorThemes]

            readonly property var initialAiCommand: [pythonPath, mainAI, "--preferred_language", root.aiPreferredLanguage, "--provider", aiProvider]

            readonly property var callBootAnalysisAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "boot_analyze", "--json_mode", "--user_persona", root.systemPersona, "--model", root.systemAiModel]
            readonly property var callBootSolutionAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "boot_solution", "--json_mode", "--user_persona", root.systemPersona, "--model", root.systemAiModel]
            readonly property var callSpikeAnalysisAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "spike_analyze", "--json_mode", "--user_persona", root.systemPersona, "--model", root.systemAiModel]
            readonly property var callWeatherAi: [...initialAiCommand, "--api_key", (root.weatherAiApiKey !== "" ? root.weatherAiApiKey : root.aiApiKey), "--preset", "weather", "--user_persona", root.weatherPersona, "--model", root.weatherAiModel]
            readonly property var callMusicAi: [...initialAiCommand, "--api_key", (root.musicAiApiKey !== "" ? root.musicAiApiKey : root.aiApiKey), "--preset", "music", "--user_persona", root.musicPersona, "--model", root.musicAiModel]
            readonly property var callIdleCapsuleAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "idle_capsule", "--json_mode", "--model", root.systemAiModel]
            readonly property var callIdleCapsuleHoverBulkAi: [...callIdleCapsuleAi, "--message_key", "idle_capsule_bulk"]
            readonly property var callIdleCapsuleHoverStartupAi: [...callIdleCapsuleAi, "--message_key", "idle_capsule_startup"]
            readonly property var callTodoAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "todo", "--json_mode", "--user_persona", root.todoPersona, "--model", root.systemAiModel]
            readonly property var callSystemActionAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "system_action", "--json_mode", "--user_persona", root.systemPersona, "--model", root.systemAiModel]
            readonly property var callColorPaletteAi: [...initialAiCommand, "--api_key", (root.systemAiApiKey !== "" ? root.systemAiApiKey : root.aiApiKey), "--preset", "color_palette", "--json_mode", "--user_persona", root.systemPersona, "--model", root.systemAiModel]
        }

        readonly property QtObject bash: QtObject {
            // Files
            readonly property string internet: root.bashScriptsPath + "/internet.sh"
            readonly property string deviceTempreture: root.bashScriptsPath + "/temp.sh"
            readonly property string getWallpapers: root.bashScriptsPath + "/get_wallpapers.sh"

            // Commands
            readonly property var internetCommand: ["sh", "-c", `${internet} ${root.networkMonitor}`]
            readonly property var deviceTempretureCommand: ["sh", "-c", deviceTempreture]

            function downloadWallpaperCommand(destPath, url) {
                return ["sh", "-c", "mkdir -p '" + root.downloadedWallpapersPath + "' && curl -s -L -o '" + destPath + "' '" + url + "'"];
            }
        }
    }

    readonly property QtObject weather: QtObject {
        readonly property string language: "ar"
        readonly property string location: root.weatherLocation
        readonly property string format: "j1"
    }

    readonly property QtObject prayerTimes: QtObject {
        readonly property string city: root.city
        readonly property string country: root.country
    }

    function dispatchCommand(description, commandArray) {
        if (!Array.isArray(commandArray) || commandArray.length === 1) {
            console.warn(`Skipping empty command: ${description}`);
            return;
        }
        console.info("[App] [dispatchCommand] " + description + " -> " + commandArray.join(' '));
        Hyprland.dispatch(`exec ${commandArray.join(' ')}`);
    }

    Process {
        id: fetchMusicModelsProcess

        command: [root.pythonPath, root.scripts.python.listGemini, "--api_key", (root.musicAiApiKey !== "" ? root.musicAiApiKey : root.aiApiKey)]

        stdout: StdioCollector {
            onStreamFinished: {
                root.modelsManager.parseOutput(this.text.toString(), "music");
            }
        }

        onRunningChanged: if (!running)
            root.modelsManager.checkFinished()
    }

    Process {
        id: fetchWeatherModelsProcess

        command: [root.pythonPath, root.scripts.python.listGemini, "--api_key", (root.weatherAiApiKey !== "" ? root.weatherAiApiKey : root.aiApiKey)]

        stdout: StdioCollector {
            onStreamFinished: {
                root.modelsManager.parseOutput(this.text.toString(), "weather");
            }
        }

        onRunningChanged: if (!running)
            root.modelsManager.checkFinished()
    }
}
