pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import "root:/config"
import "root:/services"

Singleton {
    id: root

    // ============================================================
    //  SIGNALS
    // ============================================================
    signal analysisCompleted(string emotion, string comment, var tags)

    readonly property var players: Mpris.players.values
    property int activeIndex: 0
    property int timerDelayInSeconds: 5
    readonly property var activePlayer: (players.length > 0) ? players[activeIndex < players.length ? activeIndex : 0] : null
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false

    // بيانات الأغنية
    readonly property string title: (activePlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : "Unknown"
    readonly property string artist: (activePlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : ""
    readonly property string coverArt: (activePlayer && activePlayer.trackArtUrl) ? activePlayer.trackArtUrl : ""

    readonly property string fullInfo: artist ? (artist + " - " + title) : title

    property string lastProcessedSong: ""

    property string aiComment: ""
    property string aiEmotion: ""
    property var aiTags: []

    readonly property double position: activePlayer ? activePlayer.position : 0
    readonly property double length: (activePlayer && activePlayer.length > 0) ? activePlayer.length : 1
    readonly property double progress: position / length

    property var recentTracks: []

    // ============================================================
    //  مراقبة التغييرات
    // ============================================================
    onPlayersChanged: {
        if (activeIndex >= players.length)
            activeIndex = 0;
    }

    onFullInfoChanged: {
        if (fullInfo && fullInfo !== "Unknown") {
            console.info("[DEBUG] New song detected:", fullInfo);
        }

        if (isPlaying) {
            analysisDebouncer.restart();
        }
    }

    onIsPlayingChanged: {
        console.info("[DEBUG] IsPlaying changed to:", isPlaying);
        if (isPlaying) {
            if (root.fullInfo === root.lastProcessedSong) {
                root.checkRandomResumeComment();
            } else {
                analysisDebouncer.restart();
            }
        }
    }

    // ============================================================
    //  المنطق والمؤقتات
    // ============================================================
    Timer {
        id: analysisDebouncer
        interval: 1000 * root.timerDelayInSeconds
        repeat: false
        onTriggered: {
            root.processCurrentSong(false); // false تعني هذا ليس تعليق استئناف
        }
    }

    function checkRandomResumeComment() {
        if (Math.random() > 0.95) {
            console.info("[DEBUG] Random Resume Triggered!");
            root.processCurrentSong(true);
        } else {
            console.info("[DEBUG] Random Resume Skipped (Saving tokens).");
        }
    }

    function processCurrentSong(isResumeContext) {
        if (!root.fullInfo || root.fullInfo === "Unknown" || !root.isPlaying) {
            return;
        }

        root.analyzeWithAI(isResumeContext);
    }

    // ============================================================
    //  الذكاء الاصطناعي
    // ============================================================
    function analyzeWithAI(isResumeContext) {
        if (!App.scripts.python || !App.scripts.python.callMusicAi)
            return;

        // تجهيز بيانات السياق (كما كانت)
        const currentSongInfo = root.fullInfo; // حفظنا الاسم الحالي للتحقق لاحقاً
        const currentTime = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap");
        const timestamp = formatTime(root.position);
        const resumeTimeStr = isResumeContext ? `Resumed at timestamp ${timestamp}` : "Start of track";

        // تجهيز التاريخ (History)
        let historyContextMsg = "";
        let lastIndex = root.recentTracks.indexOf(root.fullInfo);
        if (lastIndex !== -1) {
            let songsAgo = lastIndex + 1;
            historyContextMsg = `User played this specific song ${songsAgo} tracks ago. Mention this repetition in the comment.`;
        }
        const historyStr = root.recentTracks.slice(0, 5).join(", ");

        // جلب مستوى الصوت من خدمة النظام
        let volume = "Unknown";
        try {
            if (typeof SystemService !== "undefined")
                volume = Math.round(SystemService.volume * 100) + "%";
        } catch (e) {}

        let player = activePlayer ? activePlayer.identity : "Unknown";

        // بناء الرسالة
        let message = "";
        if (isResumeContext) {
            message = `
[ACTION]: USER RESUMED PLAYBACK
[CURRENTLY_PLAYING]: ${root.fullInfo}
[POSITION]: ${resumeTimeStr}
[SYSTEM]: Player: ${player}, Volume: ${volume}
`;
        } else {
            message = `
[PRIMARY_FOCUS]: ${root.fullInfo} (Comment specifically on this song)
[STATE]: Playing now
[CONTEXT]: Time: ${currentTime}, Volume: ${volume}, Player: ${player}
[PLAY_HISTORY]: ${root.recentTracks.slice(0, 7).join(" -> ")}
[REPETITION_INFO]: ${historyContextMsg}
`;
        }

        console.info(`[MusicService] Requesting AI for: ${message}`);

        // =========================================================
        // الاتصال عبر AiService
        // =========================================================
        const command = App.scripts.python.callMusicAi;
        const args = ["--message", message];

        AiService.sendRequest(command, args, function (data) {
            const emotion = data.emotion ? data.emotion.toString().trim() : "thinking";
            const comment = data.comment ? data.comment.toString().trim() : "...";
            const tags = data.tags ? data.tags : [];

            root.aiEmotion = emotion;
            root.aiComment = comment;
            root.aiTags = tags;

            root.analysisCompleted(emotion, comment, tags);

            if (currentSongInfo !== "") {
                root.addToHistory(currentSongInfo);
                root.lastProcessedSong = currentSongInfo;
            }
        }, function (errorMessage) {
            console.error("[MusicService] AI Failed via Gateway: " + errorMessage);
        }, "MusicService", 2, { credential: App.musicAiCredential });
    }

    // ============================================================
    //  دوال مساعدة
    // ============================================================
    function addToHistory(trackName) {
        if (recentTracks.length > 0 && recentTracks[0] === trackName)
            return;

        const timeNow = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap");
        var newHistory = [`${trackName}:: Played at${timeNow}`];
        for (var i = 0; i < recentTracks.length && i < 19; i++) {
            newHistory.push(recentTracks[i]);
        }
        recentTracks = newHistory;
        console.info("[DEBUG] History Updated. Last played:", trackName);
    }

    function formatTime(secondsInput) {
        let totalSeconds = Math.floor(secondsInput);

        let minutes = Math.floor(totalSeconds / 60);
        let seconds = totalSeconds % 60;

        let secStr = seconds < 10 ? "0" + seconds : seconds;

        return minutes + ":" + secStr;
    }

    function next() {
        if (activePlayer)
            activePlayer.next();
    }
    function previous() {
        if (activePlayer)
            activePlayer.previous();
    }
    function toggle() {
        if (activePlayer)
            activePlayer.togglePlaying();
    }
    function stop() {
        if (activePlayer)
            activePlayer.stop();
    }
    function cyclePlayers() {
        if (players.length > 1)
            activeIndex = (activeIndex + 1) % players.length;
    }

    NibrasShellShortcut {
        name: "nextSong"
        onPressed: root.next()
    }
    NibrasShellShortcut {
        name: "previousSong"
        onPressed: previous()
    }
    NibrasShellShortcut {
        name: "togglePlaying"
        onPressed: toggle()
    }
    NibrasShellShortcut {
        name: "stopPlay"
        onPressed: stop()
    }
}
