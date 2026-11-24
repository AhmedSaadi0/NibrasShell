// services/LockService.qml

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

import "root:/config"
import "root:/config/EventNames.js" as Events
import "root:/services"
import "root:/windows/lock"

Singleton {
    id: root

    readonly property bool killSwitch: Quickshell.env("NIBRAS_LOCK_DISABLE") === "1"
    readonly property bool testGate: Quickshell.env("NIBRAS_LOCK_TEST") === "1" || root.killSwitch
    readonly property bool dimEnabled: App.lockEnabled && App.dimTimeoutSec > 0 && !root.killSwitch
    readonly property bool lockMonitorTarget: App.lockEnabled && App.autoLockEnabled && !root.killSwitch
    readonly property bool suspendMonitorTarget: App.lockEnabled && App.autoSuspendSec > 0 && !root.killSwitch
    readonly property bool sleepInhibitEnabled: App.lockEnabled && App.lockOnSuspend && !root.killSwitch
    readonly property int effectiveLockTimeout: App.dimTimeoutSec > 0
        ? Math.max(App.lockTimeoutSec, App.dimTimeoutSec + 60)
        : App.lockTimeoutSec

    property bool dimActive: false
    property bool dimMonitorEnabled: false
    property bool lockMonitorEnabled: false
    property bool suspendMonitorEnabled: false
    property bool lockRequested: false
    property bool unlocking: false
    property string authScreenName: ""
    property string passwordBuffer: ""
    readonly property string state: lockRequested ? "locked" : (dimActive ? "dimmed" : "awake")

    // --- logind / suspend / DPMS state ---
    property string logindSessionPath: ""
    property bool dpmsOff: false
    property var dpmsPendingScreens: []
    property string dpmsAction: ""
    property bool dpmsFallback: false
    property bool _dpmsCancelled: false
    property bool _sleepInFlight: false
    property bool _suspendPending: false
    property bool _inhibitIntentionalStop: false

    // --- shared PAM state (one context, never inside a lock surface) ---
    property string pamUser: Quickshell.env("USER") || ""
    property bool pamBusy: false
    // True only while PAM is actually verifying a submitted response, not while waiting for input.
    property bool pamVerifying: false
    property int failedAttempts: 0
    property string lastError: ""
    property string pamStatus: qsTr("Ready")
    property bool _testMode: false
    property string _pendingTestPassword: ""

    signal passwordFocusRequested(string screenName)

    IdleMonitor {
        id: dimMonitor
        enabled: root.dimMonitorEnabled && !root.lockRequested
        timeout: App.dimTimeoutSec
        respectInhibitors: App.respectIdleInhibitors

        onIsIdleChanged: {
            console.info("[LockService] dimMonitor.isIdle -> " + isIdle + " (timeout=" + dimMonitor.timeout + "s)");
            if (!isIdle) {
                root.dpmsOn("dim-active");
                root.stopDim();
                return;
            }
            if (dimMonitor.enabled)
                root.startDim();
        }
    }

    IdleMonitor {
        id: lockMonitor
        enabled: root.lockMonitorEnabled && !root.lockRequested
        timeout: root.effectiveLockTimeout
        respectInhibitors: App.respectIdleInhibitors

        onIsIdleChanged: {
            console.info("[LockService] lockMonitor.isIdle -> " + isIdle + " (timeout=" + lockMonitor.timeout + "s)");
            if (!isIdle) {
                root.dpmsOn("lock-active");
                return;
            }
            if (lockMonitor.enabled)
                root.lock();
        }
    }

    IdleMonitor {
        id: suspendMonitor
        enabled: root.suspendMonitorEnabled
        timeout: App.autoSuspendSec
        respectInhibitors: App.respectIdleInhibitors

        onIsIdleChanged: {
            console.info("[LockService] suspendMonitor.isIdle -> " + isIdle + " (timeout=" + suspendMonitor.timeout + "s)");
            if (!isIdle) {
                root.dpmsOn("suspend-active");
                return;
            }
            if (suspendMonitor.enabled)
                root.requestAutoSuspend();
        }
    }

    WlSessionLock {
        id: lock
        locked: root.lockRequested && !root.killSwitch
        surface: lockSurfaceComponent

        onSecureChanged: {
            console.info("[LockService] WlSessionLock.secure=" + secure);
            if (!secure)
                return;
            root.restartDpmsTimer();
            if (root._sleepInFlight) {
                if (root._suspendPending) {
                    root.doAutoSuspend();
                } else {
                    root.releaseSleepInhibit("secure");
                    suspendSafety.stop();
                    root._sleepInFlight = false;
                }
            }
        }
    }

    Component {
        id: lockSurfaceComponent
        LockSurface {
            service: root
            systemService: SystemService
        }
    }

    PamContext {
        id: pam
        config: "nibras-lock"
        configDirectory: Qt.resolvedUrl("../config").toString().replace("file://", "")
        // user is assigned only from the OS identity, never App.username.
    }

    Process {
        id: osUserProc
        command: ["id", "-un"]
        stdout: SplitParser {
            onRead: data => {
                const name = data.trim();
                if (name && !root.pamUser)
                    root.pamUser = name;
            }
        }
    }

    Process {
        id: sessionByEnvProc
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.GetSession", String(Quickshell.env("XDG_SESSION_ID") || "")]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/\/org\/freedesktop\/login1\/session\/[A-Za-z0-9_]+/);
                if (match) {
                    root.logindSessionPath = match[0];
                    console.info("[LockService] logind session path=" + root.logindSessionPath);
                }
            }
        }
        onExited: {
            if (!root.logindSessionPath)
                sessionByPidProc.running = true;
        }
    }

    Process {
        id: sessionByPidProc
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.GetSessionByPID", String(Quickshell.processId)]
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/\/org\/freedesktop\/login1\/session\/[A-Za-z0-9_]+/);
                if (match) {
                    root.logindSessionPath = match[0];
                    console.info("[LockService] logind session path (by pid)=" + root.logindSessionPath);
                }
            }
        }
        onExited: {
            if (!root.logindSessionPath)
                console.warn("[LockService] could not resolve logind session path");
        }
    }

    Process {
        id: logindMonitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        running: !root.killSwitch
        stdout: SplitParser {
            onRead: data => root.handleLogindLine(data.trim())
        }
    }

    Process {
        id: sleepInhibitProc
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=NibrasShell", "--why=Lock screen before suspend", "cat"]
        onExited: exitCode => {
            if (exitCode !== 0 && !root._inhibitIntentionalStop)
                console.warn("[LockService] systemd-inhibit failed (exit=" + exitCode + "); suspend will not be delayed");
        }
    }

    // Give the compositor a few frames to map the lock surfaces before PAM spawns.
    Timer {
        id: pamStartTimer
        interval: 180
        repeat: false
        onTriggered: root.pamStart()
    }

    Timer {
        id: unlockCommitTimer
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.unlocking)
                return;
            root.lockRequested = false;
            root.unlocking = false;
            EventBus.emit(Events.LOCK_STATE_CHANGED, false);
        }
    }

    Timer {
        id: dpmsTimer
        interval: Math.max(1, App.dpmsOffAfterLockSec) * 1000
        repeat: false
        onTriggered: {
            if (root.lockRequested && lock.secure && !root.killSwitch)
                root.setDpms("off");
        }
    }

    Timer {
        id: suspendSafety
        interval: 2500
        repeat: false
        onTriggered: {
            if (!root._sleepInFlight)
                return;
            console.warn("[LockService] suspend safety timeout: releasing inhibit without secure lock");
            root._suspendPending = false;
            root._sleepInFlight = false;
            root.releaseSleepInhibit("safety-timeout");
        }
    }

    // Coalesce burst config changes (e.g. saving Settings) into one re-arm.
    Timer {
        id: rearmTimer
        interval: 50
        repeat: false
        onTriggered: {
            root.dimMonitorEnabled = root.dimEnabled;
            root.lockMonitorEnabled = root.lockMonitorTarget && !root.lockRequested;
            root.suspendMonitorEnabled = root.suspendMonitorTarget;
            root.restartDpmsTimer();
            root.acquireSleepInhibit("rearm");
            console.info("[LockService] idle monitors armed: dim=" + dimMonitor.timeout + "s lock=" + lockMonitor.timeout + "s suspend=" + suspendMonitor.timeout + "s");
        }
    }

    Process {
        id: dpmsProc
        onExited: exitCode => {
            if (root._dpmsCancelled) {
                root._dpmsCancelled = false;
                console.info("[LockService] DPMS off sequence cancelled (intentional)");
                return;
            }
            if (exitCode !== 0)
                root.dpmsFallback = true;
            root.nextDpmsCommand();
        }
    }

    Component.onCompleted: {
        console.info("[LockService] PAM config=" + pam.config + " dir=" + pam.configDirectory);
        root.resolvePamUser();
        root.chooseAuthScreen();
        root.rearmDimMonitor("startup");
        sessionByEnvProc.running = true;
        root.acquireSleepInhibit("startup");
    }

    Component.onDestruction: {
        root.releaseSleepInhibit("destruction");
        // Best effort only: ext-session-lock keeps the display locked if we die.
        try {
            lock.unlock();
            lock.locked = false;
        } catch (e) {}
    }

    onPamUserChanged: {
        if (root.pamUser && !pam.active) {
            pam.user = root.pamUser;
            console.info("[LockService] PAM user set from OS identity (not App.username)");
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.chooseAuthScreen();
        }
    }

    Connections {
        target: pam

        function onPamMessage() {
            const required = pam.responseRequired;
            root.lastError = pam.messageIsError ? pam.message : "";
            root.pamStatus = required
                ? (pam.responseVisible ? qsTr("Password required") : qsTr("Authenticating…"))
                : (pam.message || root.pamStatus);
            console.info("[LockService] PAM message: required=" + required + " visible=" + pam.responseVisible + " error=" + pam.messageIsError + " test=" + root._testMode);

            if (required && root._testMode && root._pendingTestPassword !== "") {
                const password = root._pendingTestPassword;
                root._pendingTestPassword = "";
                root.pamVerifying = true;
                pam.respond(password);
            } else if (required && !root._testMode && root.passwordBuffer !== "") {
                const answer = root.passwordBuffer;
                root.passwordBuffer = "";
                root.pamVerifying = true;
                pam.respond(answer);
            }
        }

        function onCompleted(result) {
            root.pamBusy = false;
            root.pamVerifying = false;
            root._testMode = false;
            root._pendingTestPassword = "";
            let outcome = "error";
            switch (result) {
            case PamResult.Success:
                root.failedAttempts = 0;
                root.lastError = "";
                root.pamStatus = qsTr("Authentication successful");
                outcome = "success";
                if (root.lockRequested)
                    root.finishUnlock("pam-success");
                break;
            case PamResult.Failed:
                root.failedAttempts++;
                root.lastError = qsTr("Authentication failed");
                root.pamStatus = root.lastError;
                outcome = "failed";
                break;
            case PamResult.MaxTries:
                root.lastError = qsTr("Too many authentication attempts");
                root.pamStatus = root.lastError;
                outcome = "maxTries";
                break;
            case PamResult.Error:
            default:
                root.lastError = qsTr("Authentication error");
                root.pamStatus = root.lastError;
                outcome = "error";
                break;
            }
            console.info("[LockService] PAM completed: " + PamResult.toString(result));
            EventBus.emit(Events.PAM_TEST_RESULT, outcome);
        }

        function onError(error) {
            root.pamVerifying = false;
            console.warn("[LockService] PAM error: " + PamError.toString(error));
            root.lastError = qsTr("PAM error: %1").arg(PamError.toString(error));
            root.pamStatus = root.lastError;
        }
    }

    // --- helpers ---
    function validScreens(): var {
        return Quickshell.screens.filter(s => s && s.name !== "" && s.width > 0 && s.height > 0);
    }

    function validScreenName(name: string): bool {
        return root.validScreens().some(s => s.name === name);
    }

    function chooseAuthScreen(): void {
        const screens = root.validScreens();
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        root.authScreenName = (focused && screens.some(s => s.name === focused))
            ? focused
            : (screens.length > 0 ? screens[0].name : "");
    }

    function resolvePamUser(): void {
        if (root.pamUser) {
            if (!pam.active)
                pam.user = root.pamUser;
            console.info("[LockService] PAM user resolved from OS environment");
        } else {
            osUserProc.running = true;
        }
    }

    function handleLogindLine(raw: string): void {
        const line = String(raw || "").trim();
        if (!line)
            return;
        // gdbus monitor: "/path: org.freedesktop.Interface.Signal (args)"
        const match = line.match(/^(\/\S+):\s+([^\s(]+)\s*(.*)$/);
        if (!match)
            return;
        const path = match[1];
        const sig = match[2];
        const args = match[3] || "";

        if (sig === "org.freedesktop.login1.Manager.PrepareForSleep") {
            root.onPrepareForSleep(/\btrue\b/.test(args));
            return;
        }
        if (path !== root.logindSessionPath)
            return;
        if (sig === "org.freedesktop.login1.Session.Lock") {
            console.info("[LockService] logind Session.Lock -> lock now");
            root.lock();
        } else if (sig === "org.freedesktop.login1.Session.Unlock") {
            console.info("[LockService] logind Session.Unlock (PAM still required)");
        }
    }

    function onPrepareForSleep(active: bool): void {
        console.info("[LockService] logind PrepareForSleep=" + active);
        if (active) {
            if (!App.lockOnSuspend || !App.lockEnabled || root.killSwitch)
                return;
            root._sleepInFlight = true;
            root._suspendPending = false;
            suspendSafety.restart();
            root.acquireSleepInhibit("prepare-sleep");
            root.lock();
            if (lock.secure) {
                root.releaseSleepInhibit("secure");
                suspendSafety.stop();
                root._sleepInFlight = false;
            }
            return;
        }
        root._sleepInFlight = false;
        root._suspendPending = false;
        suspendSafety.stop();
        root.dpmsOn("resume");
        root.restartDpmsTimer();
        if (root.dimActive)
            Brightness.restoreDim();
        root.restorePasswordFocus();
        root.acquireSleepInhibit("resume");
    }

    function acquireSleepInhibit(reason: string): void {
        if (!root.sleepInhibitEnabled) {
            console.info("[LockService] sleep inhibit disabled (" + reason + ")");
            return;
        }
        if (!sleepInhibitProc.running) {
            root._inhibitIntentionalStop = false;
            sleepInhibitProc.running = true;
            console.info("[LockService] sleep inhibit acquired (" + reason + ")");
        }
    }

    function releaseSleepInhibit(reason: string): void {
        if (!sleepInhibitProc.running)
            return;
        root._inhibitIntentionalStop = true;
        sleepInhibitProc.running = false;
        console.info("[LockService] sleep inhibit released (" + reason + ")");
    }

    function requestAutoSuspend(): void {
        if (!root.suspendMonitorTarget || root.killSwitch || root._sleepInFlight)
            return;
        console.info("[LockService] auto-suspend requested");
        root._sleepInFlight = true;
        root._suspendPending = true;
        suspendSafety.restart();
        root.acquireSleepInhibit("auto-suspend");
        if (!root.lockRequested)
            root.lock();
        if (lock.secure)
            root.doAutoSuspend();
    }

    function doAutoSuspend(): void {
        if (!root._suspendPending)
            return;
        root._suspendPending = false;
        root._sleepInFlight = false;
        suspendSafety.stop();
        root.releaseSleepInhibit("auto-suspend-secure");
        console.info("[LockService] systemctl suspend");
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    // --- DPMS ---
    function restartDpmsTimer(): void {
        const interval = Math.max(1, App.dpmsOffAfterLockSec) * 1000;
        if (!root.lockRequested || !lock.secure || App.dpmsOffAfterLockSec <= 0 || root.killSwitch) {
            if (dpmsTimer.running)
                dpmsTimer.stop();
            return;
        }
        if (dpmsTimer.running && dpmsTimer.interval === interval)
            return;
        dpmsTimer.stop();
        dpmsTimer.interval = interval;
        console.info("[LockService] DPMS timer armed: " + App.dpmsOffAfterLockSec + "s");
        dpmsTimer.restart();
    }

    function setDpms(action: string): void {
        const wasOff = root.dpmsOff;
        if (action === "on")
            root.dpmsOff = false; // suppress burst wake events while monitors light up

        if (dpmsProc.running) {
            if (root.dpmsAction === action)
                return; // never restart an already running on/off sequence
            if (action === "on") {
                // Wake wins over an in-flight off sequence. Mark the abort as
                // intentional so onExited never treats it as a Lua failure.
                root._dpmsCancelled = true;
                root.dpmsAction = "on";
                root.dpmsPendingScreens = [];
                root.dpmsFallback = false;
                dpmsProc.running = false;
                console.info("[LockService] DPMS wake cancelled in-flight off sequence");
                root.finishDpmsOn();
                return;
            }
            return; // off requested while waking: let the on sequence finish
        }

        if (action === "on" && !wasOff) {
            if (root.lockRequested) {
                root.restorePasswordFocus();
                root.restartDpmsTimer();
            }
            return;
        }
        if (action === "off" && wasOff)
            return;

        dpmsTimer.stop();
        root.dpmsAction = action;
        root.dpmsFallback = false;
        root.dpmsPendingScreens = root.validScreens().map(s => s.name);
        console.info("[LockService] DPMS " + action + " for " + root.dpmsPendingScreens.length + " screen(s)");
        root.nextDpmsCommand();
    }

    function finishDpmsOn(): void {
        console.info("[LockService] DPMS on");
        root.restorePasswordFocus();
        if (root.lockRequested)
            root.restartDpmsTimer();
    }

    function nextDpmsCommand(): void {
        if (root.dpmsPendingScreens.length > 0) {
            const monitor = root.dpmsPendingScreens.shift();
            dpmsProc.command = ["hyprctl", "dispatch", `hl.dsp.dpms({ action = "${root.dpmsAction}", monitor = "${monitor}" })`];
            dpmsProc.running = true;
            return;
        }
        if (root.dpmsFallback) {
            console.info("[LockService] DPMS Lua dispatch failed; using plain hyprctl fallback");
            Quickshell.execDetached(["hyprctl", "dispatch", "dpms", root.dpmsAction]);
        }
        root.dpmsOff = (root.dpmsAction === "off");
        if (root.dpmsOff) {
            console.info("[LockService] DPMS off");
        } else {
            root.finishDpmsOn();
        }
    }

    function dpmsOn(source: string): void {
        if (!root.dpmsOff)
            return;
        console.info("[LockService] DPMS wake (" + source + ")");
        root.setDpms("on");
    }

    function noteActivity(source: string): void {
        if (!root.dpmsOff)
            return;
        root.dpmsOn("activity:" + source);
    }

    // --- PAM API shared with lock surfaces ---
    function beginAuth(isTest: bool): bool {
        if (pam.active) {
            root.pamStatus = qsTr("Authentication already in progress");
            return false;
        }
        root._testMode = isTest;
        root.failedAttempts = 0;
        root.lastError = "";
        root.pamStatus = isTest ? qsTr("Testing PAM…") : qsTr("Enter password");
        root.pamBusy = true;
        root.pamVerifying = false;
        if (!pam.start()) {
            root.pamBusy = false;
            root._testMode = false;
            root._pendingTestPassword = "";
            root.lastError = qsTr("PAM could not start");
            root.pamStatus = root.lastError;
            return false;
        }
        return true;
    }

    function pamStart(): void {
        root.beginAuth(false);
    }

    function pamRespond(text: string): bool {
        if (!pam.responseRequired)
            return false;
        root.pamVerifying = true;
        pam.respond(text);
        return true;
    }

    function pamAbort(): void {
        if (pam.active)
            pam.abort();
        root.pamBusy = false;
        root.pamVerifying = false;
        root._testMode = false;
        root._pendingTestPassword = "";
        root.passwordBuffer = "";
        if (root.lockRequested)
            root.pamStatus = qsTr("Enter password");
        else
            root.pamStatus = qsTr("Authentication cancelled");
    }

    function submitPassword(): void {
        if (!root.lockRequested)
            return;
        if (!root.pamBusy)
            root.pamStart();
        const answer = root.passwordBuffer;
        if (root.pamRespond(answer))
            root.passwordBuffer = "";
    }

    function switchAuthScreen(name: string): void {
        if (!root.lockRequested || !root.validScreenName(name) || root.authScreenName === name)
            return;
        root.authScreenName = name;
        console.info("[LockService] auth screen -> " + name);
        Qt.callLater(root.restorePasswordFocus);
    }

    function restorePasswordFocus(): void {
        if (!root.lockRequested || !root.authScreenName)
            return;
        passwordFocusRequested(root.authScreenName);
    }

    function forwardInput(key: int, text: string): void {
        if (!root.lockRequested)
            return;
        if (key === Qt.Key_Backspace) {
            root.passwordBuffer = root.passwordBuffer.slice(0, -1);
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.submitPassword();
        } else if (text && text.length > 0 && text !== "\r" && text !== "\n") {
            root.passwordBuffer += text;
        }
        Qt.callLater(root.restorePasswordFocus);
    }

    // --- lock / unlock ---
    function lock(): void {
        if (root.killSwitch || !App.lockEnabled || root.lockRequested || root.unlocking) {
            console.warn("[LockService] lock refused (killSwitch=" + root.killSwitch + " enabled=" + App.lockEnabled + " locked=" + root.lockRequested + ")");
            return;
        }
        root.stopDim();
        pamStartTimer.stop();
        unlockCommitTimer.stop();
        root.chooseAuthScreen();
        root.unlocking = false;
        root.lockRequested = true;
        root.passwordBuffer = "";
        root.pamVerifying = false;
        root.failedAttempts = 0;
        root.lastError = "";
        root.pamStatus = qsTr("Enter password");
        console.info("[LockService] lock: screen=" + root.authScreenName);
        EventBus.emit(Events.REQUEST_LOCK);
        EventBus.emit(Events.LOCK_STATE_CHANGED, true);
        Qt.callLater(root.restartDpmsTimer);
        pamStartTimer.start();
        Qt.callLater(root.restorePasswordFocus);
    }

    function finishUnlock(reason: string): void {
        if (!root.lockRequested || root.unlocking)
            return;
        console.info("[LockService] unlock (" + reason + ")");
        dpmsTimer.stop();
        pamStartTimer.stop();
        root.dpmsOn("unlock");
        Brightness.restoreDim();
        root.passwordBuffer = "";
        root.pamBusy = false;
        root.pamVerifying = false;
        root._testMode = false;
        root._pendingTestPassword = "";
        root.lastError = "";
        root.pamStatus = qsTr("Ready");
        root.unlocking = true;
        EventBus.emit(Events.REQUEST_UNLOCK);
        unlockCommitTimer.start();
    }

    function unlock(): void {
        if (!root.testGate) {
            console.warn("[LockService] unlock refused: test env not set");
            return;
        }
        root.finishUnlock("ipc-test");
    }

    // --- test-only PAM entry point ---
    function testPam(password: string): void {
        if (!root.testGate) {
            root.pamStatus = qsTr("PAM test disabled");
            return;
        }
        root._pendingTestPassword = password || "";
        if (!root.beginAuth(true))
            root._pendingTestPassword = "";
    }

    function abortTestPam(): void {
        if (!root.testGate)
            return;
        root.pamAbort();
        root.pamStatus = qsTr("PAM test aborted");
    }

    // ext-idle-notify-v1 may not refresh active notifications when timeout or
    // inhibitor flags change, so toggle enabled off/on to force a re-arm.
    function rearmDimMonitor(reason): void {
        console.info("[LockService] rearm idle monitors (" + reason + "): dim=" + App.dimTimeoutSec + "s lock=" + root.effectiveLockTimeout + "s suspend=" + App.autoSuspendSec + "s lockEnabled=" + root.lockMonitorTarget + " suspendEnabled=" + root.suspendMonitorTarget);
        root.dimMonitorEnabled = false;
        root.lockMonitorEnabled = false;
        root.suspendMonitorEnabled = false;
        rearmTimer.restart();
    }

    function startDim(): void {
        if (!root.dimEnabled || root.dimActive || root.lockRequested)
            return;
        console.info("[LockService] startDim: percent=" + App.dimBacklightPercent + " timeout=" + App.dimTimeoutSec + "s");
        root.dimActive = true;
        Brightness.applyDim(App.dimBacklightPercent);
    }

    function stopDim(): void {
        if (!root.dimActive)
            return;
        console.info("[LockService] stopDim: restoring backlight before overlay fade-out");
        // Restore the backlight before the overlay starts fading out.
        Brightness.restoreDim();
        root.dimActive = false;
    }

    Connections {
        target: App
        function onDimTimeoutSecChanged() {
            root.rearmDimMonitor("dimTimeoutSec changed");
            if (!root.dimEnabled)
                root.stopDim();
        }
        function onLockTimeoutSecChanged() {
            root.rearmDimMonitor("lockTimeoutSec changed");
        }
        function onAutoSuspendSecChanged() {
            root.rearmDimMonitor("autoSuspendSec changed");
        }
        function onRespectIdleInhibitorsChanged() {
            root.rearmDimMonitor("respectIdleInhibitors changed");
        }
        function onAutoLockEnabledChanged() {
            root.rearmDimMonitor("autoLockEnabled changed");
        }
        function onLockEnabledChanged() {
            root.rearmDimMonitor("lockEnabled changed");
            if (!root.dimEnabled)
                root.stopDim();
        }
        function onLockOnSuspendChanged() {
            root.acquireSleepInhibit("lockOnSuspend changed");
        }
        function onDpmsOffAfterLockSecChanged() {
            root.restartDpmsTimer();
        }
    }
}
