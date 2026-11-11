// services/AiTask.qml
//
// Phase 6 (§10.3): every AI child gets an independent 310 s watchdog
// (> the 300 s incident budget).  On expiry we ask QProcess for SIGTERM via
// the Quickshell Process.signal(int) method, escalate to SIGKILL after a
// short grace period, and settle the task as failed exactly once so
// AiService can release its queue slot and cooldown.  The exact in-process
// termination behaviour of Quickshell 0.3.1 is not documented in-repo, so
// this is intentionally a best-effort signal path plus a fail-closed result.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: task

    property var command: []
    // Phase 5.3: credential transport. The value is written once to the
    // child's stdin and never appears in argv or the process environment.
    property string credential: ""
    // Optional extra environment variables for this child only.  Quickshell's
    // Process merges these with the inherited parent environment, so the
    // diagnostics process can receive NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE=1
    // without changing the environment of any other AI workflow.
    property var environment: ({})
    property int watchdogMs: 310000
    property int terminationGraceMs: 1000

    property bool _timedOut: false
    property bool _settled: false

    signal success(var data)
    signal failed(string error)

    function _handleOutput(rawText) {
        if (_timedOut || _settled)
            return;

        const text = String(rawText || "");
        if (!text) {
            _failOnce("AI process exited without output");
            return;
        }

        // Do not dump the raw envelope (it can contain model text);
        // only a byte count goes to the console.
        console.info(`[AiTask] AI Process Result received (bytes=${text.length})`);

        // نُمرّر الـ envelope كاملاً (success/response/updated_history/error)
        // إلى AiService ليقوم بالتنظيف وإدارة التاريخ
        var envelope = null;
        try {
            envelope = JSON.parse(text);
        } catch (e) {
            _failOnce("Invalid JSON envelope: " + e.message);
            return;
        }

        if (envelope && envelope.success) {
            _succeed(envelope);
        } else {
            _failOnce(envelope && envelope.error ? envelope.error : "Empty AI response");
        }
    }

    function _succeed(envelope) {
        if (_settled)
            return;
        _settled = true;
        watchdogTimer.stop();
        killTimer.stop();
        settleTimer.stop();
        exitCheckTimer.stop();
        success(envelope);
    }

    function _failOnce(message) {
        if (_settled)
            return;
        _settled = true;
        watchdogTimer.stop();
        killTimer.stop();
        settleTimer.stop();
        exitCheckTimer.stop();
        failed(message);
    }

    function _onWatchdog() {
        if (_settled || !aiProcess.running)
            return;
        _timedOut = true;
        console.warn(`[AiTask] watchdog: AI child exceeded ${watchdogMs} ms; terminating`);
        aiProcess.signal(15); // SIGTERM
        killTimer.restart();
        settleTimer.restart();
    }

    function start() {
        if (!command || command.length === 0) {
            _failOnce("Empty command");
            return;
        }
        _timedOut = false;
        _settled = false;
        aiProcess.command = task.command;
        if (task.environment && Object.keys(task.environment).length > 0)
            aiProcess.environment = task.environment;
        aiProcess.running = true;
        watchdogTimer.restart();
    }

    property Process aiProcess: Process {
        stdinEnabled: true

        onStarted: {
            if (task._settled || task._timedOut)
                return;
            aiProcess.write(JSON.stringify({ credential: task.credential || "" }) + "\n");
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (task._timedOut || task._settled)
                    return;
                task._handleOutput(this.text);
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("[AiTask Process Stderr]:", data)
        }

        onRunningChanged: {
            if (running)
                return;

            watchdogTimer.stop();
            killTimer.stop();
            settleTimer.stop();

            if (task._timedOut) {
                task._failOnce(`AI request exceeded ${task.watchdogMs} ms watchdog; child terminated`);
                return;
            }
            if (task._settled)
                return;
            // Do not parse synchronously here: StdioCollector may deliver the
            // final chunk just after runningChanged.  A short grace timer
            // handles the genuine "child exited with no output" case.
            exitCheckTimer.restart();
        }
    }

    property Timer watchdogTimer: Timer {
        interval: task.watchdogMs
        repeat: false
        onTriggered: task._onWatchdog()
    }

    property Timer killTimer: Timer {
        interval: task.terminationGraceMs
        repeat: false
        onTriggered: {
            if (aiProcess.running)
                aiProcess.signal(9); // SIGKILL escalation
        }
    }

    // Guarantees queue/cooldown restoration even if a platform ignores the
    // kill signal; the task is settled once, so normal exit races are safe.
    property Timer settleTimer: Timer {
        interval: task.terminationGraceMs + 250
        repeat: false
        onTriggered: {
            if (task._timedOut)
                task._failOnce(`AI request exceeded ${task.watchdogMs} ms watchdog; child termination requested`);
        }
    }

    property Timer exitCheckTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            if (!task._settled && !task._timedOut)
                task._handleOutput(task.aiProcess.stdout.text);
        }
    }
}
