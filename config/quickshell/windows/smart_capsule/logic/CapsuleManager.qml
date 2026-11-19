// windows/smart_capsule/logic/CapsuleManager.qml
pragma Singleton

import QtQuick
import Quickshell
import "root:/services"
import "root:/config"
import "root:/themes"
import "root:/config/ConstValues.js" as C
import "root:/utils/helpers.js" as Helper

Singleton {
    id: root

    // --- State ---
    property int currentPriority: C.IDLE
    property string activeSource: ""
    property string displayIcon: ""
    property string displayText: ""
    property real progressValue: 0.0
    property bool showProgress: false
    property bool changeWidth: true
    property bool changeHeight: false
    property int _lastAlertLevel: -1

    property color bgColor1: ThemeManager.selectedTheme.colors.primary
    property color bgColor2: ThemeManager.selectedTheme.colors.secondary
    property color fgColor: ThemeManager.selectedTheme.colors.onPrimary
    property var tagsModel: []
    // مصدر الوسوم الحالية (يبقى بعد انتهاء المهلة لأن الوسوم تبقى مرئية)
    property string tagsSource: ""

    Timer {
        id: resetTimer
        interval: 4000 // Default timeout
        repeat: false
        onTriggered: root.reset()
    }

    // --- Core Function ---
    function request({
        priority,
        source,
        icon,
        text,
        progress = null,
        withProgress = false,
        timeout = 4000,
        changeW = true,
        changeH = null,
        playTone = true,
        tone = null,
        bgColor1 = ThemeManager.selectedTheme.colors.primary,
        bgColor2 = ThemeManager.selectedTheme.colors.secondary,
        fgColor = ThemeManager.selectedTheme.colors.onPrimary,
        tags = []
    }) {
        if (priority >= currentPriority || currentPriority === C.IDLE) {
            root.currentPriority = priority;
            root.activeSource = source;
            root.displayIcon = icon;
            root.displayText = text;
            root.progressValue = progress;
            root.showProgress = withProgress;
            root.changeWidth = changeW;
            root.bgColor1 = bgColor1;
            root.bgColor2 = bgColor2;
            root.fgColor = fgColor;
            root.tagsModel = tags;
            root.tagsSource = source;

            if (priority > C.TRANSIENT) {
                changeHeight = changeH ? changeH : true;
            } else {
                changeHeight = false;
            }

            resetTimer.stop();
            if (timeout > 0) {
                resetTimer.interval = timeout;
                resetTimer.start();
            }

            if (playTone) {
                playSmartCapsuleTone(priority, tone);
            }
        }
    }

    function playSmartCapsuleTone(priority, tone) {
        const nibrasAudio = App.assets.audio;
        if (tone)
            nibrasAudio.playTone(tone);
        else if (priority === C.NOTIFICATION) {
            nibrasAudio.playTone(nibrasAudio.smartCapsuleNotification);
        } else if (priority === C.WARNING) {
            nibrasAudio.playTone(nibrasAudio.smartCapsuleWarning);
        } else if (priority === C.CRITICAL) {
            nibrasAudio.playTone(nibrasAudio.smartCapsuleCritical);
        }
    }

    // --- Reset Function ---
    function reset() {
        currentPriority = C.IDLE;
        activeSource = "";
        showProgress = false;
        changeWidth = true;
        changeHeight = false;

        bgColor1 = Qt.binding(function () {
            return ThemeManager.selectedTheme.colors.primary;
        });
        bgColor2 = Qt.binding(function () {
            return ThemeManager.selectedTheme.colors.secondary;
        });
        fgColor = Qt.binding(function () {
            return ThemeManager.selectedTheme.colors.onPrimary;
        });
    }

    function stopRestTimer() {
        resetTimer.stop();
    }

    function startRestTimer(newTimer = null) {
        if (newTimer) {
            resetTimer.interval = newTimer;
        }

        resetTimer.start();
    }

    function restartRestTimer() {
        resetTimer.restart();
    }
}
