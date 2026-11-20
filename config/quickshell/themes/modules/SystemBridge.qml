import QtQuick
import Quickshell.Io
import "root:/config"
import "root:/utils" as Utils

Item {
    id: root

    signal m3Applied()
    signal m3Failed(string reason)

    property var _pendingM3Command: null
    property string _m3KonsoleProfile: ""
    property string _m3Stderr: ""

    // دالة لتطبيق الثيم العام (GTK/Qt)
    function applySystemTheme(settings, colors, typography) {
        if (!settings)
            return;

        // Qt & Plasma
        _dispatch("Plasma Color", Utils.Helper.changePlasmaColor(settings.plasmaColorScheme));
        _dispatch("Plasma Icons", Utils.Helper.changePlasmaIcons(settings.themeIcons));
        _dispatch("Konsole Profile", Utils.Helper.changeKonsoleProfile(settings.konsoleProfile));
        if (!settings.enableDynamicColoring)
            _dispatch("Konsole Running Sessions Profile", Utils.Helper.applyKonsoleProfileToRunningSessions(settings.konsoleProfile.replace(".profile", "")));
        _dispatch("Qt Style", Utils.Helper.changeQtStyle(settings.qtThemeStyle));
        _dispatch("Kvantum Theme", Utils.Helper.changeKvantumTheme(settings.kvantumTheme));

        // NOTE: raw values, no shell quoting — App.dispatchCommand executes argv
        // directly (no shell), and kwriteconfig stores the value verbatim.
        // (Quoting here would land literally in kdeglobals, breaking the font.)
        const generalFont = `${settings.fontName},11,-1,5,50,0,0,0,0,0`;
        const titleFont = `${settings.fontName},11,-1,5,75,0,0,0,0,0`;
        const smallFont = `${settings.fontName},9,-1,5,75,0,0,0,0,0`;
        const toolBarFont = `${settings.fontName},10,-1,5,75,0,0,0,0,0`;
        const monoFont = "FantasqueSansM Nerd Font Mono,10,-1,5,50,0,0,0,0,0";

        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: generalFont,
            key: "font",
            group: "General"
        }));
        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: generalFont,
            key: "menuFont",
            group: "General"
        }));
        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: titleFont,
            key: "activeFont",
            group: "WM"
        }));
        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: monoFont,
            key: "fixed",
            group: "General"
        }));
        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: smallFont,
            key: "smallestReadableFont",
            group: "General"
        }));
        _dispatch("Plasma General Font", Utils.Helper.changePlasmaFont({
            font: toolBarFont,
            key: "toolBarFont",
            group: "General"
        }));
        // GTK
        _dispatch("GTK Theme", Utils.Helper.changeGtkTheme(settings.gtkTheme));
        _dispatch("GTK Icons", Utils.Helper.changeGtkIcons(settings.themeIcons));
        _dispatch("GTK Color Schema", Utils.Helper.changeGtkColorSchemeTheme(settings.themeMode));
        _dispatch("GTK 4 Clean", Utils.Helper.removeOldGtk4Theme());
        _dispatch("GTK 4 Apply", Utils.Helper.changeGtk4Theme(settings.gtkTheme));
        _dispatch("GTK Font", Utils.Helper.changeGtkFont(settings.fontName, typography.baseFontSize));
        _dispatch("Cursor Theme", Utils.Helper.changeCursorTheme(settings.cursorTheme));
        _dispatch("GTK Cursor Theme", Utils.Helper.changeGtkCursorTheme(settings.cursorTheme));
        _dispatch("Cursor Size", Utils.Helper.changeCursorSize(settings.cursorSize));

        // Accent Color
        if (!settings.enableDynamicColoring && settings.enableAccentColoring) {
            accentColorTimer.accentColor = colors.primary;
            accentColorTimer.start();
        }
    }

    // دالة منفصلة لتطبيق M3 (تستدعى عند تغير الخلفية)
    function applyM3(wallpaperPath, themeMode, enabled, scheme, contrast, konsoleProfile) {
        if (!enabled)
            return;

        // حماية: لا نطبق M3 على مسارات غير صحيحة
        if (!wallpaperPath || wallpaperPath === "" || wallpaperPath.indexOf("/") === -1) {
            console.warn("[SystemBridge] Skipping M3, invalid wallpaper path:", wallpaperPath);
            return;
        }

        const data = {
            selectedWallpaperPath: wallpaperPath,
            themeMode: themeMode,
            scheme: scheme,
            contrast: contrast
        };
        const command = Utils.Helper.applyM3PlasmaColor(data);

        root._m3KonsoleProfile = konsoleProfile || "MaterialYouAlt.profile";
        console.info("[SystemBridge] Applying M3 on:", wallpaperPath, command);

        if (m3Process.running) {
            root._pendingM3Command = command;
            return;
        }

        m3Process.command = command;
        m3Process.running = true;
    }

    // Custom AI-generated Plasma color scheme writer
    FileView {
        id: customPlasmaColorWriter
        watchChanges: false
        onSaved: console.info("[SystemBridge] Custom Plasma color scheme written successfully.")
        onSaveFailed: error => console.error("[SystemBridge] Failed to write custom Plasma color scheme:", error)
    }

    /**
     * @function applyCustomColorScheme
     * @description Generates a KDE Plasma .colors file from theme colors, writes it to disk, and applies it.
     * @param {var} colors - The theme object containing color properties (_primary, _secondary, etc.).
     * @param {string} schemeName - The name for the new color scheme.
     */
    function applyCustomColorScheme(colors, schemeName) {
        if (!colors || !schemeName)
            return;

        const content = Utils.Helper.generateAiPlasmaColorFile(colors, schemeName);
        const folderPath = App.homePath + ".local/share/color-schemes/";
        const filePath = folderPath + schemeName + ".colors";

        console.info("[SystemBridge] Writing custom Plasma color scheme to:", filePath);
        customPlasmaColorWriter.path = filePath;
        customPlasmaColorWriter.setText(content);

        _dispatch("Plasma AI Color Scheme", Utils.Helper.changePlasmaColor(schemeName));
    }

    function _dispatch(desc, cmd) {
        if (cmd)
            App.dispatchCommand(desc, cmd);
    }

    Process {
        id: m3Process

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.toString().trim();
                if (output !== "")
                    console.info("[M3] " + output);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._m3Stderr = this.text.toString().trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._m3Stderr === "") {
                const profile = root._m3KonsoleProfile.replace(".profile", "");
                _dispatch("Konsole M3 Refresh", Utils.Helper.applyKonsoleProfileToRunningSessions(profile));
                root.m3Applied();
            } else {
                const reason = root._m3Stderr || `exit ${exitCode} (${exitStatus})`;
                console.error("[SystemBridge] M3 failed:", reason);
                root.m3Failed(reason);
            }

            root._m3Stderr = "";
            if (root._pendingM3Command) {
                const nextCommand = root._pendingM3Command;
                root._pendingM3Command = null;
                m3Process.command = nextCommand;
                m3Process.running = true;
            }
        }
    }

    Timer {
        id: accentColorTimer
        property color accentColor
        interval: 1500
        repeat: false
        onTriggered: _dispatch("Plasma Accent Color", Utils.Helper.changePlasmaAccentColor(accentColor))
    }
}
