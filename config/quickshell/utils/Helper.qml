// helpers/Helper.qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Widgets

import "root:/config" as Config

Singleton {
    id: root

    // ==========================================================
    // ==                 WALLPAPER COMMANDS                   ==
    // ==========================================================

    /**
     * @function changeWallpaper
     * @description Generates a command to change the desktop wallpaper using 'swww'.
     * @param {string} wallpaperName - The filename of the wallpaper (e.g., "my-wallpaper.jpg").
     * @returns {string[]} The command array to be executed.
     */
    // NOTE: All command builders below return raw argv arrays executed DIRECTLY
    // (Quickshell.execDetached / Process, no shell). Do NOT embed shell quoting
    // (single/double quotes, backticks) or unexpanded `~`/globs in argv elements:
    // they would be passed literally to the binary. Only builders that wrap
    // their payload in ["sh", "-c", ...] may use shell syntax.
    function changeWallpaper(wallpaperPath) {
        return ['swww', 'img', '--transition-type', 'grow', wallpaperPath];
    }

    function getCursorpos(wallpaperPath) {
        return ["hyprctl", "cursorpos"];
    }

    // ==========================================================
    // ==                  PLASMA COMMANDS                     ==
    // ==========================================================

    /**
     * @function changePlasmaColor
     * @description Generates a command to apply a Plasma color scheme.
     * @param {string} colorSchemeName - The name of the color scheme (e.g., "BreezeDark").
     * @returns {string[]} The command array.
     */
    function changePlasmaColor(colorSchemeName) {
        // This requires the 'plasma-apply-colorscheme' tool to be installed.
        return ['plasma-apply-colorscheme', colorSchemeName];
    }

    function changePlasmaAccentColor(accentColor) {
        // This requires the 'plasma-apply-colorscheme' tool to be installed.
        return ['plasma-apply-colorscheme', '-a', `${accentColor}`];
    }

    /**
     * @function hexToKdeRgb
     * @description Converts a QML Hex color string (#RRGGBB or #AARRGGBB) to KDE Plasma RGB format (R,G,B).
     * @param {string} colorValue - The hex color string.
     * @returns {string} The RGB comma-separated string (e.g., "35,33,54").
     */
    function hexToKdeRgb(colorValue) {
        if (!colorValue)
            return "255,255,255";

        let hex = colorValue.toString().trim();
        if (hex.indexOf("#") === 0)
            hex = hex.substring(1);

        // Handle Qt ARGB format (8 chars) - strip the alpha prefix
        if (hex.length === 8)
            hex = hex.substring(2);

        if (hex.length === 6) {
            let r = parseInt(hex.substring(0, 2), 16);
            let g = parseInt(hex.substring(2, 4), 16);
            let b = parseInt(hex.substring(4, 6), 16);
            if (!isNaN(r) && !isNaN(g) && !isNaN(b))
                return `${r},${g},${b}`;
        }
        return "255,255,255";
    }

    /**
     * @function generateAiPlasmaColorFile
     * @description Generates a complete KDE Plasma .colors file content from a theme color map.
     * @param {var} colors - The theme object containing color properties.
     * @param {string} schemeName - The name for the color scheme.
     * @returns {string} The full INI content for the .colors file.
     */
    function generateAiPlasmaColorFile(colors, schemeName) {
        const primary = hexToKdeRgb(colors._primary || "#22C1EB");
        const secondary = hexToKdeRgb(colors._secondary || "#FD02FF");
        const bgNormal = hexToKdeRgb(colors._surfaceContainer || colors._surface || "#1f1635");
        const bgAlternate = hexToKdeRgb(colors._surfaceContainerHigh || "#2a1e4a");
        const fgNormal = hexToKdeRgb(colors._onSurface || "#EFF0F1");
        const fgInactive = hexToKdeRgb(colors._onSurfaceVariant || "#999999");
        const errorColor = hexToKdeRgb(colors._error || "#ff3333");
        const successColor = hexToKdeRgb(colors._tertiary || "#00E676");
        const warningColor = hexToKdeRgb(colors._secondary || "#FF9100");

        return `[General]
Name=${schemeName}
ColorScheme=${schemeName}
shadeSortColumn=true

[KDE]
contrast=4

[ColorEffects:Disabled]
Color=${bgNormal}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
Enable=false

[Colors:Window]
BackgroundAlternate=${bgAlternate}
BackgroundNormal=${bgNormal}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgInactive}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[Colors:View]
BackgroundAlternate=${bgNormal}
BackgroundNormal=${bgAlternate}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgInactive}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[Colors:Button]
BackgroundAlternate=${bgAlternate}
BackgroundNormal=${bgNormal}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgInactive}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[Colors:Selection]
BackgroundAlternate=${primary}
BackgroundNormal=${secondary}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgNormal}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[Colors:Tooltip]
BackgroundAlternate=${bgNormal}
BackgroundNormal=${bgAlternate}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgInactive}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[Colors:Complementary]
BackgroundNormal=${bgNormal}
ForegroundNormal=${fgNormal}

[Colors:Header]
BackgroundAlternate=${bgAlternate}
BackgroundNormal=${bgNormal}
DecorationFocus=${primary}
DecorationHover=${secondary}
ForegroundActive=${primary}
ForegroundInactive=${fgInactive}
ForegroundLink=${primary}
ForegroundNegative=${errorColor}
ForegroundNeutral=${warningColor}
ForegroundNormal=${fgNormal}
ForegroundPositive=${successColor}
ForegroundVisited=${secondary}

[WM]
activeBackground=${primary}
activeForeground=${bgNormal}
inactiveBackground=${bgNormal}
inactiveForeground=${fgInactive}
`;
    }

    function getWallpapersList(path) {
        const scriptFile = Config.App.scripts.bash.getWallpapers;
        return [scriptFile, `${path}`];
    }

    function applyM3PlasmaColor({
        selectedWallpaperPath,
        themeMode,
        scheme,
        chroma,
        tone
    }) {
        const scriptCommand = Config.App.scripts.python.dynamicM3Command;
        const command = [...scriptCommand, `${selectedWallpaperPath}`, "-m", themeMode, "--scheme", scheme, "--chroma", chroma, "--tone", tone];
        console.info(command);
        return command;
    }

    function changePlasmaFont({
        font,
        key,
        group = "General"
    }) {
        return ['kwriteconfig6', '--file', 'kdeglobals', '--group', group, '--key', key, font];
    }

    /**
     * @function changePlasmaIcons
     * @description Generates a command to apply an icon theme.
     * @param {string} iconThemeName - The name of the icon theme (e.g., "breeze-dark").
     * @returns {string[]} The command array.
     */
    function changePlasmaIcons(iconThemeName) {
        // Uses 'kwriteconfig5' to directly modify the system settings.
        return ['kwriteconfig5', '--file', 'kdeglobals', '--group', 'Icons', '--key', 'Theme', iconThemeName];
    }

    /**
     * @function changeKonsoleProfile
     * @description Generates a command to set the default Konsole profile.
     * @param {string} profileName - The name of the Konsole profile file (e.g., "MyProfile.profile").
     * @returns {string[]} The command array.
     */
    function changeKonsoleProfile(profileName) {
        return ['kwriteconfig5', '--file', 'konsolerc', '--group', 'Desktop Entry', '--key', 'DefaultProfile', profileName];
    }

    // Applies profile immediately to currently opened Konsole sessions via DBus.
    function applyKonsoleProfileToRunningSessions(profileName) {
        const scriptCommand = Config.App.scripts.python.applyKonsoleProfileOpenSessionsCommand;
        return [...scriptCommand, "--profile", `${profileName}`];
    }

    // ==========================================================
    // ==                    GTK COMMANDS                      ==
    // ==========================================================

    /**
     * @function changeGtkTheme
     * @description Generates a command to apply a GTK3/4 theme.
     * @param {string} themeName - The name of the GTK theme (e.g., "Breeze").
     * @returns {string[]} The command array.
     */
    function changeGtkTheme(themeName) {
        // This command sets the theme for both GTK3 and GTK4 in most modern environments.
        return ['gsettings', 'set', 'org.gnome.desktop.interface', 'gtk-theme', themeName];
    }

    function changeGtkColorSchemeTheme(themeName) {
        // This command sets the theme for both GTK3 and GTK4 in most modern environments.
        return ['gsettings', 'set', 'org.gnome.desktop.interface', 'color-scheme', `prefer-${themeName}`];
    }

    function removeOldGtk4Theme() {
        // Shell-quoted on purpose: glob-free but keeps `~` expansion via sh.
        return ['sh', '-c', 'find -P ~/.config/gtk-4.0/ -mindepth 1 ! -name \'settings.ini\' -delete'];
    }

    function changeGtk4Theme(themeName) {
        // Shell-quoted on purpose: needs `~` expansion and `*` glob expansion.
        return ['sh', '-c', `cp -rf ~/.themes/'${themeName}'/gtk-4.0/* ~/.config/gtk-4.0/`];
    }

    /**
     * @function changeGtkIcons
     * @description Generates a command to apply a GTK icon theme.
     * @param {string} iconThemeName - The name of the icon theme.
     * @returns {string[]} The command array.
     */
    function changeGtkIcons(iconThemeName) {
        return ['gsettings', 'set', 'org.gnome.desktop.interface', 'icon-theme', iconThemeName];
    }

    function changeGtkFont(fontName, fontSize) {
        // This command sets the theme for both GTK3 and GTK4 in most modern environments.
        return ['gsettings', 'set', 'org.gnome.desktop.interface', 'font-name', `${fontName} ${fontSize}`];
    }

    function changeCursorTheme(themeName) {
        return ['kwriteconfig5', '--file', 'kcminputrc', '--group', 'Mouse', '--key', 'cursorTheme', themeName];
    }

    function changeCursorSize(size) {
        return ['kwriteconfig5', '--file', 'kcminputrc', '--group', 'Mouse', '--key', 'cursorSize', String(size)];
    }

    function changeGtkCursorTheme(themeName) {
        return ['gsettings', 'set', 'org.gnome.desktop.interface', 'cursor-theme', themeName];
    }

    // ==========================================================
    // ==               APPLICATION STYLING                    ==
    // ==========================================================

    /**
     * @function changeQtStyle
     * @description Generates a command to set the Qt widget style (e.g., Fusion, Breeze).
     * @param {string} styleName - The name of the Qt style.
     * @returns {string[]} The command array.
     */
    function changeQtStyle(styleName) {
        // For KDE Plasma, using kwriteconfig5 is a direct and reliable method.
        return ['kwriteconfig5', '--file', 'kdeglobals', '--group', 'KDE', '--key', 'widgetStyle', styleName];
    }

    /**
     * @function changeKvantumTheme
     * @description Generates a command to apply a Kvantum theme.
     * @param {string} themeName - The name of the Kvantum theme.
     * @returns {string[]} The command array.
     */
    function changeKvantumTheme(themeName) {
        // Requires the 'kvantummanager' tool to be installed.
        return ['kvantummanager', '--set', themeName];
    }

    // ==========================================================
    // ==               NOTIFICATION COMMANDS                  ==
    // ==========================================================

    /**
     * @function sendNotification
     * @description Generates a fully-featured 'notify-send' command array with explicit arguments.
     * @param {string} summary - The notification title (required).
     * @param {string} body - The main notification message.
     * @param {string} icon - Icon name (e.g., "info") or full path to an image.
     * @param {string} urgency - Urgency level: "low", "normal", or "critical".
     * @returns {string[]} The command array for a Process element.
     */
    function sendNotification({
        summary,
        body = "",
        icon = "",
        urgency = "normal"
    }) {
        // Basic validation
        if (!summary) {
            console.error("sendNotification Error: 'summary' (title) is a required argument.");
            return [];
        }

        let command = ['notify-send'];

        // Add App name
        command.push('-a', `NibrasShell`);

        if (urgency) {
            command.push('-u', `${urgency}`);
        }
        if (icon) {
            command.push('-i', `${icon}`);
        }

        // Add the main content (must be last)
        command.push(`${summary}`); // Title
        if (body) {
            command.push(`${body}`); // Message body
        }

        return command;
    }

    function playSoundCommand(soundPath) {
        return ['paplay', `${soundPath}`];
    }

    function createImageOverlayRembg({
        wallpaperPath,
        outputPath,
        model = "u2net",
        alphaMatting = false,
        foregroundThreshold = 240,
        backgroundThreshold = 10,
        erodeSize = 10
    }) {
        if (!wallpaperPath || !outputPath) {
            console.error("createImageOverlayRembg: wallpaperPath and outputPath are required.");
            return [];
        }

        const scriptCommand = Config.App.scripts.python.rembgOverylayWallpaperCommand;

        let commandArray = [...scriptCommand, wallpaperPath, outputPath];

        if (model && model !== "u2net") {
            commandArray.push("--model", model);
        }

        if (alphaMatting) {
            commandArray.push("--alpha-matting");
            if (foregroundThreshold !== undefined) {
                commandArray.push("--foreground-threshold", foregroundThreshold.toString());
            }
            if (backgroundThreshold !== undefined) {
                commandArray.push("--background-threshold", backgroundThreshold.toString());
            }
            if (erodeSize !== undefined) {
                commandArray.push("--erode-size", erodeSize.toString());
            }
        }

        return commandArray;
    }

    // Not in use
    function createImageOverlayOpencv({
        wallpaperPath
    }) {
        const scriptCommand = Config.App.scripts.python.opencvOverylayWallpaperCommand;
        return [...scriptCommand, `${wallpaperPath}`];
    }

    function generateRandomString(length = 7) {
        const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        let result = "";
        const charactersLength = characters.length;

        for (let i = 0; i < length; i++) {
            result += characters.charAt(Math.floor(Math.random() * charactersLength));
        }

        return result;
    }

    function removeUnusedCachedOverlayImages({
        jsonDir,
        imagesDir
    }) {
        const pythonCommand = Config.App.scripts.python.removeUnusedCachedOverlayImagesCommand;
        return [...pythonCommand, "--json_dir", jsonDir, "--images_dir", imagesDir];
    }

    function copyFile(sourcePath, destinationPath) {
        return ['cp', '-f', `${sourcePath}`, `${destinationPath}`];
    }

    function listWifiCommand(wifiInterface = Config.App.networkMonitor) {
        const pythonCommand = Config.App.scripts.python.listWifiCommand;
        const fullCommand = [...pythonCommand, "--interface", `${wifiInterface}`];
        return fullCommand;
    }

    function connectWifiCommand({
        ssid,
        command = "connect",
        password = null,
        wifiInterface = Config.App.networkMonitor
    }) {
        const pythonCommand = Config.App.scripts.python.connectWifiCommand;
        const fullCommand = [...pythonCommand, command, "--ssid", ssid, "--interface", wifiInterface];
        if (password) {
            fullCommand.push("--password", password);
        }
        return fullCommand;
    }

    function wifiDataUsageCommand({
        wifiInterface = Config.App.networkMonitor,
        startDate = null,
        endDate = null
    }) {
        const pythonCommand = Config.App.scripts.python.dataUsageCommand;
        let fullCommand = [...pythonCommand, "--interface", `${wifiInterface}`];
        if (startDate !== null) {
            fullCommand.push("--start-date", startDate);
        }
        if (endDate !== null) {
            fullCommand.push("--end-date", endDate);
        }
        return fullCommand;
    }

    function wifiLiveUsageCommand({
        limit = 8,
        wifiInterface = Config.App.networkMonitor,
        persist = true
    }) {
        const pythonCommand = Config.App.scripts.python.liveUsageCommand;
        let fullCommand = [...pythonCommand, "--limit", `${limit}`, "--interface", `${wifiInterface}`];
        if (!persist)
            fullCommand.push("--no-persist");
        return fullCommand;
    }

    function wifiLiveUsageSummaryCommand({
        hours = 24,
        top = 15,
        wifiInterface = Config.App.networkMonitor
    }) {
        const pythonCommand = Config.App.scripts.python.liveUsageCommand;
        return [...pythonCommand, "--mode", "summary", "--hours", `${hours}`, "--top", `${top}`, "--interface", `${wifiInterface}`];
    }

    function vnstatAppBreakdownCommand({
        hours = 168,
        top = 15,
        wifiInterface = Config.App.networkMonitor,
        startDate = null,
        endDate = null
    }) {
        const pythonCommand = Config.App.scripts.python.liveUsageCommand;
        let fullCommand = [...pythonCommand, "--mode", "summary", "--hours", `${hours}`, "--top", `${top}`, "--interface", `${wifiInterface}`, "--use-vnstat"];
        if (startDate !== null && endDate !== null) {
            fullCommand.push("--start-date", startDate);
            fullCommand.push("--end-date", endDate);
        }
        return fullCommand;
    }

    // ==========================================================
    // ==                 ICON UTILITIES                       ==
    // ==========================================================

    function toImageSource(pathOrUrl) {
        if (!pathOrUrl || pathOrUrl === "")
            return "";
        if (pathOrUrl.startsWith("file://") || pathOrUrl.startsWith("qrc:") || pathOrUrl.startsWith("image://") || pathOrUrl.startsWith("data:") || pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://"))
            return pathOrUrl;
        if (pathOrUrl.startsWith("/"))
            return "file://" + pathOrUrl;
        return pathOrUrl;
    }

    function isDirectImageSource(iconValue) {
        if (!iconValue || iconValue === "")
            return false;
        return iconValue.startsWith("/") || iconValue.startsWith("file://") || iconValue.startsWith("qrc:") || iconValue.startsWith("image://") || iconValue.startsWith("data:") || iconValue.startsWith("http://") || iconValue.startsWith("https://");
    }

    function isFilePath(pathOrUrl) {
        if (!pathOrUrl || pathOrUrl === "")
            return false;
        return pathOrUrl.startsWith("/") || pathOrUrl.startsWith("file://");
    }

    function iconNameFromAppId(appId) {
        let id = appId || "application-x-executable";
        let entry = DesktopEntries.byId(id);
        return (entry && entry.icon) ? entry.icon : id;
    }

    function iconNameFromPath(pathOrUrl) {
        if (!pathOrUrl || pathOrUrl === "")
            return "";
        if (pathOrUrl.startsWith("image://icon/")) {
            let name = pathOrUrl.slice("image://icon/".length);
            return name ? name : "";
        }
        let path = pathOrUrl;
        if (path.startsWith("file://"))
            path = path.slice(7);
        if (!path.startsWith("/"))
            return "";
        let base = path.split("/").pop();
        if (!base || base === "")
            return "";
        let dot = base.lastIndexOf(".");
        if (dot > 0)
            base = base.slice(0, dot);
        return base;
    }

    function resolveThemedIcon(iconName, themedIconPaths, fallbackKey = "application-x-executable") {
        if (!themedIconPaths)
            return "";
        let themedPath = themedIconPaths[iconName];
        if (themedPath && themedPath !== "")
            return toImageSource(themedPath);
        if (fallbackKey && fallbackKey !== "") {
            let fallbackPath = themedIconPaths[fallbackKey];
            if (fallbackPath && fallbackPath !== "")
                return toImageSource(fallbackPath);
        }
        return "";
    }
}
