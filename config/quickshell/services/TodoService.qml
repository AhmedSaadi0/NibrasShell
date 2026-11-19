// services/TodoService.qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/services"

Singleton {
    id: root

    // -----------------------------
    // Public State
    // -----------------------------
    property bool isLoaded: false
    property bool hasLoadError: false
    property ListModel tasksModel: ListModel {}
    property ListModel dueNowModel: ListModel {}

    // Centralized clock. Every UI element that needs a live timestamp reads
    // this property instead of running its own timer - one timer for the
    // whole application, no per delegate timers.
    property date now: new Date()

    // Index of the task the user jumped to from the "Due Now" section.
    property int focusedTaskIndex: -1

    // AI Summary
    property string aiSummaryTitle: ""
    property string aiSummaryText: ""
    property var aiSummaryTags: []
    property var aiSummaryDueSoon: []
    property bool aiSummaryReady: aiSummaryText !== ""

    // Guards against stale AiService callbacks arriving after a mutation.
    property int _aiRequestSeq: 0

    signal taskDue(var task)
    signal aiSummaryUpdated(var summary)
    signal startupSummaryReady(var summary)
    signal loadFailed(string reason)

    // -----------------------------
    // Storage
    // -----------------------------
    FileView {
        id: tasksFile
        path: App.todoFilePath
        onLoaded: {
            root._loadFromDisk();
        }
        onSaved: console.info("TodoService: tasks saved")
        onSaveFailed: error => console.error("TodoService: save failed: " + error)
    }

    FileView {
        id: tasksBackupFile
        path: App.todoFilePath + ".bak"
        watchChanges: false
        onSaved: console.info("TodoService: corrupt todo backup saved")
        onSaveFailed: error => console.error("TodoService: backup save failed: " + error)
    }

    Component.onCompleted: tasksFile.reload()

    // -----------------------------
    // Timers
    // -----------------------------
    // One timer drives both the live clock and due checks. Due notifications
    // only fire once a due date is in the past (see _isBeforeToday).
    Timer {
        id: clockTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.now = new Date();
            if (root.isLoaded)
                root._checkDueTasks();
        }
    }

    // Clears the focus highlight after a short while.
    Timer {
        id: focusClearTimer
        interval: 1800
        repeat: false
        onTriggered: root.focusedTaskIndex = -1
    }

    Timer {
        id: aiDebounce
        interval: 2500
        repeat: false
        onTriggered: root._refreshAiSummary(false)
    }

    // -----------------------------
    // Public API
    // -----------------------------
    function addTask(title, date, urgent, notes) {
        if (root.hasLoadError)
            return;
        if (!title || title.trim() === "")
            return;

        const dueAt = _buildDueAt(date);
        const dateLabel = _formatDateLabel(date);

        tasksModel.append({
            "_uid": _makeUid(new Date().getTime(), title),
            "title": title,
            "notes": notes || "",
            "date": dateLabel,
            "dueDate": _toIsoDate(date),
            "dueAt": dueAt,
            "timestamp": new Date().getTime(),
            "isUrgent": urgent,
            "completed": false,
            "lastNotifiedAt": 0
        });

        _sortTasks();
        _saveToDisk();
        _rebuildDueNowModel();
        _invalidateAiSummary();
        scheduleAiSummary();
    }

    function updateTaskDate(index, date) {
        if (root.hasLoadError)
            return;
        if (index < 0 || index >= tasksModel.count)
            return;

        const dueAt = _buildDueAt(date);
        const dateLabel = _formatDateLabel(date);
        tasksModel.setProperty(index, "date", dateLabel);
        tasksModel.setProperty(index, "dueDate", _toIsoDate(date));
        tasksModel.setProperty(index, "dueAt", dueAt);
        _saveToDisk();
        _rebuildDueNowModel();
        _invalidateAiSummary();
        scheduleAiSummary();
    }

    function completeTask(index) {
        if (root.hasLoadError)
            return;
        if (index < 0 || index >= tasksModel.count)
            return;
        tasksModel.setProperty(index, "completed", true);
        saveAndSort();
    }

    function removeTask(index) {
        if (root.hasLoadError)
            return;
        if (index < 0 || index >= tasksModel.count)
            return;
        tasksModel.remove(index);
        // Removal preserves the existing order - no sort needed here.
        _saveToDisk();
        _rebuildDueNowModel();
        _invalidateAiSummary();
        scheduleAiSummary();
    }

    // Highlights a task in the list for a short while.
    function focusTask(index) {
        if (index < 0 || index >= tasksModel.count)
            return;
        focusedTaskIndex = index;
        focusClearTimer.restart();
    }

    function saveAndSort() {
        if (root.hasLoadError)
            return;
        _sortTasks();
        _saveToDisk();
        _rebuildDueNowModel();
        _invalidateAiSummary();
        scheduleAiSummary();
    }

    function scheduleAiSummary() {
        if (!root.isLoaded || root.hasLoadError)
            return;
        aiDebounce.restart();
    }

    // -----------------------------
    // Internal: Loading/Saving
    // -----------------------------
    function _loadFromDisk() {
        isLoaded = false;
        hasLoadError = false;
        tasksModel.clear();

        let raw = "";
        try {
            try {
                raw = tasksFile.text() || "";
            } catch (e) {
                throw new Error("Cannot read todo file: " + e);
            }

            if (raw.trim() === "") {
                isLoaded = true;
                _rebuildDueNowModel();
                return;
            }

            const data = JSON.parse(raw);
            if (!Array.isArray(data))
                throw new Error("Expected an array of tasks");

            for (let i = 0; i < data.length; i++)
                tasksModel.append(_normalizeTask(data[i]));

            _sortTasks();
            // Persist date/uid normalization only after the input is trusted.
            _saveToDisk();
            isLoaded = true;
            _rebuildDueNowModel();
            _checkDueTasks();
            _refreshAiSummary(true);
        } catch (e) {
            const message = e && e.message ? e.message : String(e);
            console.error("TodoService: Error loading JSON: " + message);
            hasLoadError = true;
            isLoaded = true;
            _clearAiSummaryFields();
            _invalidateAiSummary();
            _rebuildDueNowModel();
            loadFailed(message);
            _backupCorruptFile(raw);
        }
    }

    function _backupCorruptFile(raw) {
        if (!raw || raw.trim() === "")
            return;

        let existing = "";
        try {
            existing = tasksBackupFile.text() || "";
        } catch (e) {
            existing = "";
        }
        if (existing.trim() !== "")
            return;

        try {
            tasksBackupFile.setText(raw);
        } catch (e) {
            console.warn("TodoService: could not write backup: " + e);
        }
    }

    function _saveToDisk() {
        if (root.hasLoadError) {
            console.warn("TodoService: save skipped - todo file failed to load");
            return;
        }

        let arr = [];
        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            arr.push({
                "_uid": item._uid,
                "title": item.title,
                "notes": item.notes || "",
                "date": item.date,
                "dueDate": item.dueDate || "",
                "dueAt": item.dueAt || 0,
                "timestamp": item.timestamp || 0,
                "isUrgent": item.isUrgent,
                "completed": item.completed,
                "lastNotifiedAt": item.lastNotifiedAt || 0
            });
        }
        tasksFile.setText(JSON.stringify(arr, null, 2));
    }

    // -----------------------------
    // Internal: Sorting & Ranking
    // -----------------------------
    function _getTaskRank(item) {
        if (item.completed)
            return 2;
        if (item.isUrgent)
            return 0;
        return 1;
    }

    function _taskKey(item) {
        return String(item._uid || ((item.timestamp || 0) + "-" + (item.title || "")));
    }

    function _compareTasks(itemA, itemB) {
        const rankDiff = _getTaskRank(itemA) - _getTaskRank(itemB);
        if (rankDiff !== 0)
            return rankDiff;

        const timeDiff = _safeNumber(itemB.timestamp) - _safeNumber(itemA.timestamp);
        if (timeDiff !== 0)
            return timeDiff;

        return _taskKey(itemA).localeCompare(_taskKey(itemB));
    }

    // Native sort plus at most one ListModel.move() per task. The key is a
    // stable uid so equal timestamps keep a deterministic order.
    function _sortTasks() {
        const n = tasksModel.count;
        if (n < 2)
            return;

        const sorted = [];
        for (let i = 0; i < n; i++)
            sorted.push(tasksModel.get(i));
        sorted.sort(_compareTasks);

        for (let i = 0; i < n; i++) {
            const wanted = _taskKey(sorted[i]);
            if (_taskKey(tasksModel.get(i)) === wanted)
                continue;

            for (let j = i + 1; j < n; j++) {
                if (_taskKey(tasksModel.get(j)) === wanted) {
                    tasksModel.move(j, i, 1);
                    break;
                }
            }
        }
    }

    // -----------------------------
    // Internal: Due Tracking
    // -----------------------------
    function _checkDueTasks() {
        const now = root.now.getTime();
        let needsSave = false;

        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            if (item.completed)
                continue;

            const dueAt = item.dueAt || 0;
            if (dueAt <= 0 || !_isBeforeToday(dueAt))
                continue;

            if (now >= dueAt && (item.lastNotifiedAt || 0) < dueAt) {
                tasksModel.setProperty(i, "lastNotifiedAt", now);
                needsSave = true;
                taskDue(_snapshotTask(item, i));
            }
        }

        if (needsSave)
            _saveToDisk();

        _rebuildDueNowModel();
    }

    function _rebuildDueNowModel() {
        // Date-only tasks are due at the end of their local day, so compare
        // against today's end-of-day to keep today's tasks visible here.
        const horizon = _endOfLocalDay(root.now);
        dueNowModel.clear();

        const pending = [];
        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            if (item.completed)
                continue;
            if (!item.dueAt || item.dueAt > horizon)
                continue;

            pending.push({
                "title": item.title,
                "notes": item.notes || "",
                "date": item.date,
                "dueDate": item.dueDate || "",
                "dueAt": item.dueAt,
                "isUrgent": item.isUrgent,
                "sourceIndex": i
            });
        }

        // Most overdue first, so the worst offender is always on top.
        pending.sort(function (a, b) {
            return a.dueAt - b.dueAt;
        });

        for (let i = 0; i < pending.length; i++)
            dueNowModel.append(pending[i]);
    }

    // -----------------------------
    // Internal: AI Summary
    // -----------------------------
    function _invalidateAiSummary() {
        root._aiRequestSeq++;
        aiDebounce.stop();
    }

    function _clearAiSummaryFields() {
        aiSummaryTitle = "";
        aiSummaryText = "";
        aiSummaryTags = [];
        aiSummaryDueSoon = [];
    }

    function _refreshAiSummary(isStartup) {
        if (!App.scripts.python || !App.scripts.python.callTodoAi)
            return;

        const seq = ++root._aiRequestSeq;

        if (tasksModel.count === 0) {
            _clearAiSummaryFields();
            return;
        }

        const payload = _buildAiPayload();
        AiService.sendRequest(App.scripts.python.callTodoAi, ["--message", JSON.stringify(payload)], function (data) {
            if (seq !== root._aiRequestSeq)
                return;

            aiSummaryTitle = data.title || "Todo Summary";
            aiSummaryText = data.summary || "";
            aiSummaryTags = data.tags || [];
            aiSummaryDueSoon = data.due_soon || [];

            aiSummaryUpdated({
                title: aiSummaryTitle,
                summary: aiSummaryText,
                tags: aiSummaryTags,
                due_soon: aiSummaryDueSoon
            });

            if (isStartup) {
                startupSummaryReady({
                    title: aiSummaryTitle,
                    summary: aiSummaryText,
                    tags: aiSummaryTags,
                    due_soon: aiSummaryDueSoon
                });
            }
        }, function (errorMessage) {
            if (seq !== root._aiRequestSeq)
                return;
            console.error("[TodoService] AI Failed: " + errorMessage);
        }, "TodoService", 0);
    }

    function _buildAiPayload() {
        let tasks = [];
        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            tasks.push({
                "title": item.title,
                "notes": item.notes || "",
                "date": item.date,
                "dueDate": item.dueDate || "",
                "dueAt": item.dueAt || 0,
                "isUrgent": item.isUrgent,
                "completed": item.completed
            });
        }
        return {
            "generated_at": new Date().toISOString(),
            "tasks": tasks
        };
    }

    // -----------------------------
    // Internal: Helpers
    // -----------------------------
    function _normalizeTask(rawValue) {
        let raw = rawValue && typeof rawValue === "object" ? rawValue : {};
        let title = raw.title || "";
        let notes = raw.notes || "";
        let isUrgent = !!raw.isUrgent;
        let completed = !!raw.completed;
        let timestamp = _safeNumber(raw.timestamp) || new Date().getTime();

        let dateLabel = raw.date || raw.dateLabel || _formatDateLabel(new Date(timestamp));
        let dueAt = _safeNumber(raw.dueAt) || _safeNumber(raw.due_at) || _parseDateLabel(dateLabel);
        let lastNotifiedAt = _safeNumber(raw.lastNotifiedAt);

        // Legacy date-only tasks used local midnight. Move them to the end of
        // their day; if they had already notified, suppress a duplicate.
        if (dueAt > 0 && _isMidnight(dueAt)) {
            dueAt = _endOfLocalDay(dueAt);
            if (lastNotifiedAt > 0)
                lastNotifiedAt = dueAt;
        }

        let dueDate = raw.dueDate || (dueAt > 0 ? _toIsoDate(dueAt) : _toIsoDate(timestamp));

        return {
            "_uid": raw._uid || _makeUid(timestamp, title),
            "title": title,
            "notes": notes,
            "date": dateLabel,
            "dueDate": dueDate,
            "dueAt": dueAt,
            "timestamp": timestamp,
            "isUrgent": isUrgent,
            "completed": completed,
            "lastNotifiedAt": lastNotifiedAt
        };
    }

    function _makeUid(timestamp, title) {
        return timestamp.toString(36) + "-" + Math.random().toString(36).slice(2, 10) + "-" + String(title).length.toString(36);
    }

    // Date-only selections are due at the end of their local day, not
    // midnight, so a task created for today is not instantly overdue.
    function _buildDueAt(dateObj) {
        if (!dateObj)
            return 0;
        return _endOfLocalDay(dateObj);
    }

    function _formatDateLabel(dateObj) {
        if (!dateObj)
            return "";
        return dateObj.toLocaleDateString(Qt.locale(), "MMM d");
    }

    function _normalizeDigits(text) {
        return String(text)
            .replace(/[\u0660-\u0669]/g, ch => String.fromCharCode(0x30 + ch.charCodeAt(0) - 0x0660))
            .replace(/[\u06F0-\u06F9]/g, ch => String.fromCharCode(0x30 + ch.charCodeAt(0) - 0x06F0));
    }

    function _monthLookup() {
        const locale = Qt.locale();
        const shortEnglish = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const longEnglish = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const names = [];

        for (let i = 0; i < 12; i++) {
            names.push([locale.monthName(i, Locale.ShortFormat), i]);
            names.push([locale.monthName(i, Locale.LongFormat), i]);
            names.push([shortEnglish[i], i]);
            names.push([longEnglish[i], i]);
        }
        names.sort((a, b) => String(b[0] || "").length - String(a[0] || "").length);

        const lookup = {};
        for (let i = 0; i < names.length; i++) {
            if (names[i][0])
                lookup[String(names[i][0]).toLowerCase()] = names[i][1];
        }
        return lookup;
    }

    function _nearestYear(month, day) {
        const today = new Date(root.now.getTime());
        const thisYear = today.getFullYear();
        let best = thisYear;
        let bestDiff = Infinity;

        for (let year = thisYear - 1; year <= thisYear + 1; year++) {
            const diff = Math.abs(new Date(year, month, day).getTime() - today.getTime());
            if (diff < bestDiff) {
                bestDiff = diff;
                best = year;
            }
        }
        return best;
    }

    // Legacy labels are locale-formatted and yearless. Parse them against
    // both Qt locale month names and English names instead of Date parsing.
    function _parseDateLabel(label) {
        if (!label)
            return 0;

        const text = _normalizeDigits(String(label).trim());
        if (text === "")
            return 0;

        const iso = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(text);
        if (iso)
            return new Date(Number(iso[1]), Number(iso[2]) - 1, Number(iso[3])).getTime();

        const lower = text.toLowerCase();
        const months = _monthLookup();
        let month = -1;
        for (const name in months) {
            if (lower.indexOf(name) >= 0) {
                month = months[name];
                break;
            }
        }
        if (month < 0)
            return 0;

        const numbers = text.match(/\d{1,4}/g) || [];
        let day = 0;
        let year = 0;
        for (let i = 0; i < numbers.length; i++) {
            const value = Number(numbers[i]);
            if (value > 31 && value <= 9999)
                year = value;
            else if (value >= 1 && value <= 31 && day === 0)
                day = value;
        }
        if (day === 0)
            return 0;
        if (year === 0)
            year = _nearestYear(month, day);

        return new Date(year, month, day).getTime();
    }

    function _asDate(value) {
        return typeof value === "number" ? new Date(value) : new Date(value.getTime());
    }

    function _startOfLocalDay(value) {
        const d = _asDate(value);
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }

    function _endOfLocalDay(value) {
        const d = _asDate(value);
        d.setHours(23, 59, 59, 999);
        return d.getTime();
    }

    function _isMidnight(value) {
        const d = _asDate(value);
        return d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() === 0 && d.getMilliseconds() === 0;
    }

    function _isBeforeToday(dueAt) {
        return dueAt < _startOfLocalDay(root.now);
    }

    function _pad2(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function _toIsoDate(value) {
        const d = _asDate(value);
        return d.getFullYear() + "-" + _pad2(d.getMonth() + 1) + "-" + _pad2(d.getDate());
    }

    function _safeNumber(value) {
        const n = Number(value);
        return isNaN(n) ? 0 : n;
    }

    function _snapshotTask(item, index) {
        return {
            "title": item.title,
            "notes": item.notes || "",
            "date": item.date,
            "dueDate": item.dueDate || "",
            "dueAt": item.dueAt || 0,
            "isUrgent": item.isUrgent,
            "completed": item.completed,
            "sourceIndex": index
        };
    }
}
