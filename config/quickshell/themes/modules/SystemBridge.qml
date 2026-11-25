import QtQuick
import Quickshell.Io
import "root:/config"
import "root:/utils" as Utils

Item {
    id: root

    signal m3Applied(var palette, var meta)
    signal m3Failed(string reason, var meta)

    property int _m3RequestSequence: 0
    property var _activeM3Request: null
    property var _pendingM3Request: null
    property string _m3Stdout: ""
    property string _m3Stderr: ""
    property bool _m3StdoutFinished: false
    property bool _m3StderrFinished: false
    property bool _m3ProcessExited: false
    property int _m3ExitCode: -1
    property int _m3ExitStatus: -1
    readonly property int latestM3RequestId: _m3RequestSequence

    // دالة لتطبيق الثيم العام (GTK/Qt)
    function applySystemTheme(settings, colors, typography) {
        if (!settings)
            return;

        // Qt & Plasma
        if (!settings.enableDynamicColoring)
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
    function applyM3(request) {
        if (!request || !request.enabled)
            return -1;

        const wallpaperPath = request.wallpaperPath || "";
        if (wallpaperPath === "" || wallpaperPath.indexOf("/") === -1) {
            console.warn("[SystemBridge] Skipping M3, invalid wallpaper path:", wallpaperPath);
            return -1;
        }

        const themeName = request.themeName || "";
        if (themeName === "") {
            console.warn("[SystemBridge] Skipping M3, missing theme name");
            return -1;
        }

        const meta = {
            requestId: ++root._m3RequestSequence,
            themeName: themeName,
            themeMode: request.themeMode,
            wallpaperPath: wallpaperPath,
            scheme: request.scheme,
            contrast: request.contrast,
            konsoleProfile: request.konsoleProfile || "MaterialYouAlt.profile"
        };
        const command = Utils.Helper.applyM3PlasmaColor({
            selectedWallpaperPath: wallpaperPath,
            themeMode: meta.themeMode,
            scheme: meta.scheme,
            contrast: meta.contrast
        });

        console.info("[SystemBridge] Applying M3 on:", wallpaperPath, command);

        if (m3Process.running) {
            root._pendingM3Request = {
                command: command,
                meta: meta
            };
            return meta.requestId;
        }

        root._startM3Request(command, meta);
        return meta.requestId;
    }

    function invalidateM3Requests() {
        root._m3RequestSequence++;
        root._pendingM3Request = null;
    }

    function _startM3Request(command, meta) {
        root._activeM3Request = meta;
        root._m3Stdout = "";
        root._m3Stderr = "";
        root._m3StdoutFinished = false;
        root._m3StderrFinished = false;
        root._m3ProcessExited = false;
        root._m3ExitCode = -1;
        root._m3ExitStatus = -1;

        m3Process.command = command;
        m3Process.running = true;
    }

    function _parseM3Error(output) {
        const lines = output.split(/\r?\n/);
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed.startsWith("__M3_ERROR__:"))
                continue;
            try {
                const payload = JSON.parse(trimmed.substring("__M3_ERROR__:".length));
                if (payload && typeof payload.message === "string")
                    return payload.message;
            } catch (err) {
                return trimmed.substring("__M3_ERROR__:".length);
            }
        }
        return "";
    }

    function _parseM3Output(output, request) {
        const lines = output.split(/\r?\n/);
        const paletteLines = lines
            .map(line => line.trim())
            .filter(line => line.startsWith("__M3_PALETTE__:"));

        if (paletteLines.length !== 1)
            return { ok: false, reason: "Expected exactly one Matugen palette line" };

        try {
            const envelope = JSON.parse(paletteLines[0].substring("__M3_PALETTE__:".length));
            if (!envelope || typeof envelope !== "object" || Array.isArray(envelope))
                return { ok: false, reason: "Invalid Matugen palette envelope" };
            if (envelope.mode !== request.themeMode)
                return { ok: false, reason: `Matugen mode mismatch: ${envelope.mode} !== ${request.themeMode}` };
            if (!envelope.colors || typeof envelope.colors !== "object" || Array.isArray(envelope.colors))
                return { ok: false, reason: "Matugen palette envelope is missing colors" };

            return { ok: true, palette: envelope.colors };
        } catch (err) {
            return { ok: false, reason: `Invalid Matugen palette JSON: ${err.message}` };
        }
    }

    function _finalizeMissingStreams(requestId) {
        const request = root._activeM3Request;
        if (!request || request.requestId !== requestId || !root._m3ProcessExited)
            return;

        if (!root._m3StdoutFinished) {
            root._m3Stdout = m3StdoutCollector.text.toString();
            root._m3StdoutFinished = true;
        }
        if (!root._m3StderrFinished) {
            root._m3Stderr = m3StderrCollector.text.toString();
            root._m3StderrFinished = true;
        }
        root._tryFinishM3();
    }

    function _tryFinishM3() {
        const request = root._activeM3Request;
        if (!request || !root._m3StdoutFinished || !root._m3StderrFinished || !root._m3ProcessExited)
            return;

        const stdoutText = root._m3Stdout;
        const stderrText = root._m3Stderr;
        const exitCode = root._m3ExitCode;
        const exitStatus = root._m3ExitStatus;

        root._activeM3Request = null;
        root._m3Stdout = "";
        root._m3Stderr = "";
        root._m3StdoutFinished = false;
        root._m3StderrFinished = false;
        root._m3ProcessExited = false;

        const logLines = stdoutText.split(/\r?\n/).filter(line => {
            const trimmed = line.trim();
            return trimmed !== "" && !trimmed.startsWith("__M3_PALETTE__:") && !trimmed.startsWith("__M3_ERROR__:");
        });
        if (logLines.length > 0)
            console.info("[M3] " + logLines.join("\n"));

        const nextRequest = root._pendingM3Request;
        root._pendingM3Request = null;

        const isCurrent = request.requestId === root._m3RequestSequence;
        if (nextRequest)
            root._startM3Request(nextRequest.command, nextRequest.meta);

        if (!isCurrent) {
            console.info("[SystemBridge] Ignoring stale M3 request", request.requestId);
            return;
        }

        if (exitCode !== 0 || stderrText.trim() !== "") {
            const reason = stderrText.trim() || root._parseM3Error(stdoutText) || `exit ${exitCode} (${exitStatus})`;
            console.error("[SystemBridge] M3 failed:", reason);
            root.m3Failed(reason, request);
            return;
        }

        const parsed = root._parseM3Output(stdoutText, request);
        if (!parsed.ok) {
            console.error("[SystemBridge] M3 failed:", parsed.reason);
            root.m3Failed(parsed.reason, request);
            return;
        }

        const profile = request.konsoleProfile.replace(".profile", "");
        _dispatch("Konsole M3 Refresh", Utils.Helper.applyKonsoleProfileToRunningSessions(profile));
        root.m3Applied(parsed.palette, request);
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
            id: m3StdoutCollector
            onStreamFinished: {
                if (!root._activeM3Request)
                    return;
                root._m3Stdout = this.text.toString();
                root._m3StdoutFinished = true;
                root._tryFinishM3();
            }
        }
        stderr: StdioCollector {
            id: m3StderrCollector
            onStreamFinished: {
                if (!root._activeM3Request)
                    return;
                root._m3Stderr = this.text.toString();
                root._m3StderrFinished = true;
                root._tryFinishM3();
            }
        }
        onExited: (exitCode, exitStatus) => {
            const request = root._activeM3Request;
            root._m3ExitCode = exitCode;
            root._m3ExitStatus = exitStatus;
            root._m3ProcessExited = true;
            root._tryFinishM3();

            // StdioCollector emits streamFinished even for empty streams in 0.3.2.
            // Keep a deferred fallback for builds where that notification is missing.
            if (request)
                Qt.callLater(() => root._finalizeMissingStreams(request.requestId));
        }
        onRunningChanged: {
            if (!running && root._activeM3Request && !root._m3ProcessExited) {
                root._m3ExitCode = -1;
                root._m3ExitStatus = -1;
                root._m3ProcessExited = true;
                root._m3StdoutFinished = true;
                root._m3StderrFinished = true;
                root._tryFinishM3();
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
