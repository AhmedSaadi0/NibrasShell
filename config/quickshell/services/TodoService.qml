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
    property ListModel tasksModel: ListModel {}
    property ListModel dueNowModel: ListModel {}

    // AI Summary
    property string aiSummaryTitle: ""
    property string aiSummaryText: ""
    property var aiSummaryTags: []
    property var aiSummaryDueSoon: []
    property bool aiSummaryReady: aiSummaryText !== ""

    signal taskDue(var task)
    signal aiSummaryUpdated(var summary)
    signal startupSummaryReady(var summary)

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

    Component.onCompleted: tasksFile.reload()

    // -----------------------------
    // Timers
    // -----------------------------
    Timer {
        id: dueTimer
        interval: 60000
        repeat: true
        running: root.isLoaded
        onTriggered: root._checkDueTasks()
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
    function addTask(title, date, urgent) {
        if (!title || title.trim() === "")
            return;

        const dueAt = _buildDueAt(date);
        const dateLabel = _formatDateLabel(date);

        tasksModel.append({
            "title": title,
            "date": dateLabel,
            "dueAt": dueAt,
            "timestamp": new Date().getTime(),
            "isUrgent": urgent,
            "completed": false,
            "lastNotifiedAt": 0
        });

        _sortTasks();
        _saveToDisk();
        _rebuildDueNowModel();
        scheduleAiSummary();
    }

    function updateTaskDate(index, date) {
        if (index < 0 || index >= tasksModel.count)
            return;

        const dueAt = _buildDueAt(date);
        const dateLabel = _formatDateLabel(date);
        tasksModel.setProperty(index, "date", dateLabel);
        tasksModel.setProperty(index, "dueAt", dueAt);
        _saveToDisk();
        _rebuildDueNowModel();
        scheduleAiSummary();
    }

    function saveAndSort() {
        _sortTasks();
        _saveToDisk();
        _rebuildDueNowModel();
        scheduleAiSummary();
    }

    function scheduleAiSummary() {
        if (!root.isLoaded)
            return;
        aiDebounce.restart();
    }

    // -----------------------------
    // Internal: Loading/Saving
    // -----------------------------
    function _loadFromDisk() {
        isLoaded = false;
        tasksModel.clear();

        if (!tasksFile.text() || tasksFile.text().trim() === "") {
            isLoaded = true;
            _rebuildDueNowModel();
            return;
        }

        try {
            let data = JSON.parse(tasksFile.text());
            for (let i = 0; i < data.length; i++) {
                tasksModel.append(_normalizeTask(data[i]));
            }
            _sortTasks();
            isLoaded = true;
            _rebuildDueNowModel();
            _checkDueTasks();
            _refreshAiSummary(true);
        } catch (e) {
            console.error("TodoService: Error loading JSON: " + e);
            isLoaded = true;
        }
    }

    function _saveToDisk() {
        let arr = [];
        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            arr.push({
                "title": item.title,
                "date": item.date,
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

    function _shouldSwap(itemA, itemB) {
        let rankA = _getTaskRank(itemA);
        let rankB = _getTaskRank(itemB);

        if (rankA > rankB)
            return true;
        if (rankA < rankB)
            return false;

        let timeA = itemA.timestamp || 0;
        let timeB = itemB.timestamp || 0;
        return timeA < timeB;
    }

    function _sortTasks() {
        let n = tasksModel.count;
        let swapped;
        do {
            swapped = false;
            for (let i = 0; i < n - 1; i++) {
                let item1 = tasksModel.get(i);
                let item2 = tasksModel.get(i + 1);
                if (_shouldSwap(item1, item2)) {
                    tasksModel.move(i, i + 1, 1);
                    swapped = true;
                }
            }
        } while (swapped)
    }

    // -----------------------------
    // Internal: Due Tracking
    // -----------------------------
    function _checkDueTasks() {
        const now = new Date().getTime();
        let needsSave = false;

        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            if (item.completed)
                continue;

            const dueAt = item.dueAt || 0;
            if (dueAt <= 0)
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
        const now = new Date().getTime();
        dueNowModel.clear();

        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            if (item.completed)
                continue;
            if (!item.dueAt || item.dueAt > now)
                continue;

            dueNowModel.append({
                "title": item.title,
                "date": item.date,
                "dueAt": item.dueAt,
                "isUrgent": item.isUrgent,
                "sourceIndex": i
            });
        }
    }

    // -----------------------------
    // Internal: AI Summary
    // -----------------------------
    function _refreshAiSummary(isStartup) {
        if (!App.scripts.python || !App.scripts.python.callTodoAi)
            return;

        if (tasksModel.count === 0) {
            aiSummaryTitle = "";
            aiSummaryText = "";
            aiSummaryTags = [];
            aiSummaryDueSoon = [];
            return;
        }

        const payload = _buildAiPayload();
        AiService.sendRequest(App.scripts.python.callTodoAi, ["--message", JSON.stringify(payload)], function (data) {
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
            console.error("[TodoService] AI Failed: " + errorMessage);
        }, "TodoService", 0, { credential: App.systemAiCredential });
    }

    function _buildAiPayload() {
        let tasks = [];
        for (let i = 0; i < tasksModel.count; i++) {
            let item = tasksModel.get(i);
            tasks.push({
                "title": item.title,
                "date": item.date,
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
    function _normalizeTask(raw) {
        let title = raw.title || "";
        let isUrgent = !!raw.isUrgent;
        let completed = !!raw.completed;
        let timestamp = raw.timestamp || new Date().getTime();

        let dateLabel = raw.date || raw.dateLabel || _formatDateLabel(new Date(timestamp));
        let dueAt = _safeNumber(raw.dueAt) || _safeNumber(raw.due_at) || _parseDateLabel(dateLabel);

        return {
            "title": title,
            "date": dateLabel,
            "dueAt": dueAt,
            "timestamp": timestamp,
            "isUrgent": isUrgent,
            "completed": completed,
            "lastNotifiedAt": raw.lastNotifiedAt || 0
        };
    }

    function _formatDateLabel(dateObj) {
        if (!dateObj)
            return "";
        return dateObj.toLocaleDateString(Qt.locale(), "MMM d");
    }

    function _parseDateLabel(label) {
        if (!label)
            return 0;
        const year = new Date().getFullYear();
        const parsed = new Date(label + " " + year);
        if (isNaN(parsed.getTime()))
            return 0;
        parsed.setHours(0, 0, 0, 0);
        return parsed.getTime();
    }

    function _buildDueAt(dateObj) {
        if (!dateObj)
            return 0;
        const d = new Date(dateObj.getTime());
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }

    function _safeNumber(value) {
        const n = Number(value);
        return isNaN(n) ? 0 : n;
    }

    function _snapshotTask(item, index) {
        return {
            "title": item.title,
            "date": item.date,
            "dueAt": item.dueAt || 0,
            "isUrgent": item.isUrgent,
            "completed": item.completed,
            "sourceIndex": index
        };
    }
}
