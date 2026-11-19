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
    property int _requestSeq: 0

    // ============================================================
    //  سجل اقتراحات الذكاء الاصطناعي + ذاكرة المحادثة
    //  كل اقتراح يُسجَّل مع حالته: pending / opened / played
    // ============================================================
    property var suggestionLog: []
    property var _aiHistory: []
    readonly property int maxSuggestionLog: 12
    readonly property int suggestionExpiryMinutes: 45

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

        // هل الأغنية التي تعمل الآن هي أحد اقتراحاتنا؟ -> status = played
        root.matchSuggestionsWithNowPlaying();

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
        } else {
            analysisDebouncer.stop();
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

        // تجهيز بيانات السياق
        const currentSongInfo = root.fullInfo; // حفظنا الاسم الحالي للتحقق لاحقاً
        const currentTitle = root.title;
        const currentArtist = root.artist;
        const requestId = ++root._requestSeq;
        const currentTime = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap");
        const timestamp = formatTime(root.position);
        const resumeTimeStr = isResumeContext ? `Resumed at timestamp ${timestamp}` : "Start of track";

        // تجهيز التاريخ وحساب عدد مرات التشغيل بدقة
        let historyContextMsg = "";
        let lastIndex = -1;
        let previousPlays = 0;
        for (let i = 0; i < root.recentTracks.length; i++) {
            if (root.recentTracks[i].title === currentSongInfo) {
                if (lastIndex === -1)
                    lastIndex = i;
                previousPlays++;
            }
        }
        if (lastIndex !== -1) {
            const songsAgo = lastIndex + 1;
            const totalPlayCount = previousPlays + 1;
            const lastTime = root.recentTracks[lastIndex].time;
            historyContextMsg = `User replayed this specific song. Total plays in recent history: ${totalPlayCount} (this is play #${totalPlayCount}). Last played ${songsAgo} tracks ago at ${lastTime}. Do NOT confuse "${songsAgo} tracks ago" with total play count.`;
        }

        const playHistoryStr = root.recentTracks.slice(0, 7).map(item => `${item.title}:: Played at ${item.time}`).join(" -> ");

        // تجهيز تغذية راجعة عن اقتراحاتنا السابقة (هل فتحها المستخدم؟)
        const suggestionFeedback = root.buildSuggestionFeedback();

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
[CURRENTLY_PLAYING]: ${currentSongInfo}
[POSITION]: ${resumeTimeStr}
[SYSTEM]: Player: ${player}, Volume: ${volume}
${suggestionFeedback}
`;
        } else {
            message = `
[PRIMARY_FOCUS]: ${currentSongInfo} (Comment specifically on this song)
[STATE]: Playing now
[CONTEXT]: Time: ${currentTime}, Volume: ${volume}, Player: ${player}
[PLAY_HISTORY]: ${playHistoryStr}
[REPETITION_INFO]: ${historyContextMsg}
${suggestionFeedback}
`;
        }

        root.logAiPayload(message, isResumeContext);

        // =========================================================
        // الاتصال عبر AiService
        // =========================================================
        const command = App.scripts.python.callMusicAi;
        const args = ["--message", message];

        AiService.sendRequest(command, args, function (data) {
            // تجاهل الرد المتأخر إذا تغيرت الأغنية أو صدر طلب أحدث
            if (requestId !== root._requestSeq || root.fullInfo !== currentSongInfo) {
                console.info("[MusicService] Ignoring stale AI response for:", currentSongInfo);
                return;
            }

            const emotion = data.emotion ? data.emotion.toString().trim() : "thinking";
            const comment = data.comment ? data.comment.toString().trim() : "...";
            const tags = data.tags ? data.tags : [];

            root.aiEmotion = emotion;
            root.aiComment = comment;
            root.aiTags = tags;

            console.info(`[MusicService] AI response -> emotion: "${emotion}" | comment: "${comment}" | tags: ${JSON.stringify(tags)}`);

            // تسجيل اقتراحنا الجديد ليُتابع لاحقاً (هل فتحه المستخدم؟)
            root.registerSuggestions(tags, currentSongInfo, currentTitle, currentArtist);

            root.analysisCompleted(emotion, comment, tags);

            // عدم إضافة سجل جديد عند تعليق الاستئناف لنفس الأغنية
            if (!isResumeContext && currentSongInfo !== "") {
                root.addToHistory(currentSongInfo);
                root.lastProcessedSong = currentSongInfo;
            }
        }, function (errorMessage) {
            console.error("[MusicService] AI Failed via Gateway: " + errorMessage);
        }, "MusicService", 2, {
            // ذاكرة المحادثة: يشارك الذكاء الاصطناعي اقتراحاته السابقة وتعليقاتنا
            history: JSON.stringify(root._aiHistory),
            historyCap: App.musicAiHistoryTurns,
            onHistoryUpdated: function (newHistory) {
                root._aiHistory = newHistory;
            }
        });
    }

    // ============================================================
    //  نظام تتبع الاقتراحات وتغذية راجعة المستخدم
    // ============================================================

    // تطبيع النص للمقارنة: إزالة التشكيل والرموز والكلمات الزخرفية
    function normalizeForMatch(text) {
        if (!text)
            return "";

        let s = String(text).toLowerCase();

        // إزالة التشكيل (العربية واللاتينية)
        s = s.replace(/[\u064B-\u0652\u0670\u0640]/g, "");
        s = s.replace(/[\u0300-\u036f]/g, "");

        // الرموز -> مسافات (مع الحفاظ على الحروف العربية واللاتينية والأرقام)
        s = s.replace(/[^a-z0-9\u00C0-\u024F\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]+/g, " ");

        // كلمات زخرفية لا مهمة للمطابقة
        const noise = ["official", "video", "audio", "lyric", "lyrics", "remix", "remaster", "remastered", "hd", "hq", "4k", "1080p", "mv", "ft", "feat", "featuring", "live", "radio", "edit", "extended", "visualizer", "with", "the", "a"];

        let tokens = s.split(/\s+/).filter(t => t.length > 0 && noise.indexOf(t) === -1);
        return tokens.join(" ");
    }

    // التوكنات الأساسية (بدون أرقام مثل سنوات الإصدار 2011)
    function coreTokens(tokens) {
        let core = tokens.filter(t => !/^[0-9]+$/.test(t));
        if (core.length === 0)
            core = tokens;
        return core;
    }

    // هل الكلمة مميزة بما يكفي للمطابقة؟ (نستبعد الكلمات العامة)
    function isDistinctiveToken(token) {
        if (!token || token.length < 3)
            return false;

        const generic = ["song", "songs", "track", "tracks", "music", "video", "audio", "theme", "single", "album", "part", "vol", "volume", "mix", "version", "session", "remix", "live", "radio", "edit", "featuring", "with", "and", "the", "for", "from", "into", "out", "over", "under", "that", "this", "you", "your", "love"];
        return generic.indexOf(token) === -1;
    }

    // عدد التوكنات المشتركة بين قائمتين
    function countSharedTokens(tokensA, tokensB) {
        let hits = 0;
        for (let i = 0; i < tokensA.length; i++) {
            if (tokensB.indexOf(tokensA[i]) !== -1)
                hits++;
        }
        return hits;
    }

    // هل الأغنية الحالية هي نفس الاقتراح؟ (مطابقة تقريبية آمنة)
    function matchSuggestion(trackFullInfo, trackTitle, suggestionText, trackArtist) {
        const s = root.normalizeForMatch(suggestionText);
        if (!s)
            return false;

        const candidates = [root.normalizeForMatch(trackFullInfo)];
        if (!trackArtist)
            candidates.push(root.normalizeForMatch(trackTitle));

        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i];
            if (!c)
                continue;

            const sCore = root.coreTokens(s.split(" "));
            const cCore = root.coreTokens(c.split(" "));
            if (sCore.length === 0 || cCore.length === 0)
                continue;

            // 1) تغطية الاقتراح داخل الأغنية
            const hits = root.countSharedTokens(sCore, cCore);
            if (hits / sCore.length >= 0.8)
                return true;

            // 2) تغطية الأغنية داخل الاقتراح (الاقتراح يحمل تفاصيل زائدة مثل السنة أو الفيديو)
            if (cCore.length >= 2) {
                const hits2 = root.countSharedTokens(cCore, sCore);
                if (hits2 / cCore.length >= 0.8)
                    return true;
            }

            // 3) مطابقة الكلمة الأخيرة (الكلمة المميزة في اسم الأغنية)
            //    مثال: "Ummi (أمي)"  vs  "Ommi (with Lyrics) / أمي"
            if (sCore.length >= 2 && cCore.length >= 2) {
                const lastSuggested = sCore[sCore.length - 1];
                const lastCurrent = cCore[cCore.length - 1];

                if (lastSuggested === lastCurrent && root.isDistinctiveToken(lastSuggested) && hits / sCore.length >= 0.5)
                    return true;
            }
        }

        return false;
    }

    // تسجيل اقتراحات الذكاء الاصطناعي الجديدة
    function registerSuggestions(tags, forTrack, forTitle, forArtist) {
        if (!tags || tags.length === 0)
            return;

        const now = Date.now();
        let log = root.suggestionLog.slice();
        let registered = [];
        const trackToCheck = forTrack || root.fullInfo;
        const titleToCheck = forTitle !== undefined ? forTitle : root.title;
        const artistToCheck = forArtist !== undefined ? forArtist : root.artist;

        for (let i = 0; i < tags.length; i++) {
            const title = String(tags[i]).trim();
            if (!title)
                continue;

            // لا نسجّل اقتراح مطابق للأغنية الحالية (الممنوع في البرومبت)
            if (root.matchSuggestion(trackToCheck, titleToCheck, title, artistToCheck))
                continue;

            log.push({
                title: title,
                suggestedFor: forTrack || "",
                suggestedAt: now,
                status: "pending"
            });
            registered.push(title);
        }

        if (log.length > root.maxSuggestionLog)
            log = log.slice(log.length - root.maxSuggestionLog);

        root.suggestionLog = log;

        if (registered.length > 0)
            console.info("[MusicService] Registered suggestion(s): " + registered.join(", "));
        else
            console.info("[MusicService] No new suggestion to register (tags matched the current track)");
    }

    // المستخدم فتح الاقتراح (نقر على الكبسولة/الوسم)
    function markSuggestionOpened(suggestionText) {
        if (!suggestionText)
            return;

        const norm = root.normalizeForMatch(suggestionText);
        if (!norm)
            return;

        const log = root.suggestionLog.slice();

        for (let i = log.length - 1; i >= 0; i--) {
            const rec = log[i];
            if (rec.status !== "pending")
                continue;

            const recNorm = root.normalizeForMatch(rec.title);
            if (recNorm === norm || root.matchSuggestion(suggestionText, suggestionText, rec.title, "")) {
                rec.status = "opened";
                rec.openedAt = Date.now();
                root.suggestionLog = log;
                console.info("[MusicService] Suggestion opened by user:", rec.title);
                return;
            }
        }
    }

    // الأغنية التي تعمل الآن تطابق أحد اقتراحاتنا -> played
    function matchSuggestionsWithNowPlaying() {
        if (!root.title || root.title === "Unknown")
            return;

        const log = root.suggestionLog.slice();
        let changed = false;

        for (let i = log.length - 1; i >= 0; i--) {
            const rec = log[i];
            if (rec.status === "played")
                continue;

            if (root.matchSuggestion(root.fullInfo, root.title, rec.title, root.artist)) {
                rec.status = "played";
                rec.playedAt = Date.now();
                changed = true;
                console.info("[MusicService] Suggestion played by user:", rec.title);
            }
        }

        if (changed)
            root.suggestionLog = log;
    }

    // بناء كتلة التغذية الراجعة التي تُرسل مع كل طلب
    function buildSuggestionFeedback() {
        if (!root.suggestionLog || root.suggestionLog.length === 0)
            return "[SUGGESTION_FEEDBACK]: (none yet - you have not made any recommendation yet)";

        const now = Date.now();
        const expiryMs = root.suggestionExpiryMinutes * 60 * 1000;
        const recent = root.suggestionLog.slice(-6);
        const lines = [];

        for (let i = 0; i < recent.length; i++) {
            const rec = recent[i];
            let status;

            if (rec.status === "played")
                status = "PLAYED (user opened it and started playing it)";
            else if (rec.status === "opened")
                status = "OPENED (user opened it; playback not confirmed)";
            else if (now - rec.suggestedAt > expiryMs)
                status = "EXPIRED (suggested earlier and never opened)";
            else
                status = "PENDING (recently suggested, not opened yet)";

            const time = new Date(rec.suggestedAt).toLocaleTimeString(Qt.locale(), "hh:mm ap");
            lines.push(`- "${rec.title}" -> ${status} | suggested after: "${rec.suggestedFor || "unknown"}" at ${time}`);
        }

        return "[SUGGESTION_FEEDBACK]:\n" + lines.join("\n");
    }

    // ============================================================
    //  دوال مساعدة
    // ============================================================

    // طباعة البيانات المرسلة للذكاء الاصطناعي بشكل واضح في اللوج
    function logAiPayload(message, isResumeContext) {
        const kind = isResumeContext ? "RESUME" : "NEW TRACK";
        const status = root.suggestionStatusSummary();

        console.info("\n╔══════════════ [MusicService] AI PAYLOAD (" + kind + ") ══════════════");
        console.info(message);
        console.info("╚══════════════ [MusicService] END PAYLOAD ══════════════");
        console.info("[MusicService] Suggestion log: " + status);
    }

    // ملخص مختصر لحالات الاقتراحات (للتشخيص السريع)
    function suggestionStatusSummary() {
        if (!root.suggestionLog || root.suggestionLog.length === 0)
            return "empty";

        let played = 0, opened = 0, pending = 0;
        for (let i = 0; i < root.suggestionLog.length; i++) {
            const st = root.suggestionLog[i].status;
            if (st === "played")
                played++;
            else if (st === "opened")
                opened++;
            else
                pending++;
        }
        return `${root.suggestionLog.length} record(s) | played=${played}, opened=${opened}, pending=${pending}`;
    }

    function addToHistory(trackName) {
        if (!trackName)
            return;

        if (recentTracks.length > 0 && recentTracks[0].title === trackName)
            return;

        const timeNow = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap");
        var newHistory = [
            {
                title: trackName,
                time: timeNow
            }
        ];
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
