import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "root:/themes"
import "root:/components"
import "root:/components/settings" // لاستدعاء SettingsComboBox
import "./components"     // لاستدعاء ChatBubble و ChatInput

ColumnLayout {
    id: root
    anchors.fill: parent
    anchors.margins: 10
    spacing: 10
    readonly property var theme: ThemeManager.selectedTheme

    // --- Configuration ---
    // مسار بايثون الافتراضي (عدله حسب مسارك الحقيقي)
    readonly property string pythonPath: "/home/ahmed/.config/quickshell/scripts/python/ai/venv/bin/python"
    readonly property string scriptPath: "/home/ahmed/.config/quickshell/scripts/python/ai/"

    property string currentModel: "gemini-2.5-flash"
    property string apiKey: "YOUR_API_KEY_HERE" // يفضل جلبها من ملف إعدادات لاحقاً

    // تخزين الـ History بصيغة JSON string للتمرير للبايثون
    property var chatHistory: []

    // ---------------------------------------------------------
    // 1. Header & Model Selection
    // ---------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "AI Assistant"
            font.pixelSize: 18
            font.bold: true
            color: root.theme.colors.onSurface
        }

        Item {
            Layout.fillWidth: true
        } // Spacer

        // قائمة اختيار المودل (تستخدم مكونك SettingsComboBox)
        SettingsComboBox {
            id: modelCombo
            Layout.preferredWidth: 180
            model: ["gemini-2.5-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
            onCurrentTextChanged: root.currentModel = currentText
        }
    }

    // ---------------------------------------------------------
    // 2. Chat Area
    // ---------------------------------------------------------
    ListView {
        id: chatList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 15

        model: ListModel {
            id: messagesModel
        }

        delegate: ChatBubble {
            messageText: model.text
            role: model.role
        }

        // التمرير التلقائي للأسفل عند وصول رسالة جديدة
        onCountChanged: {
            Qt.callLater(function () {
                chatList.positionViewAtEnd();
            });
        }
    }

    // مؤشر التحميل
    BusyIndicator {
        Layout.alignment: Qt.AlignHCenter
        running: chatProcess.running
        visible: running
    }

    // رسالة الخطأ إن وجدت
    Text {
        id: errorText
        visible: errorText.text !== ""
        color: root.theme.colors.error
        font.pixelSize: 12
        Layout.alignment: Qt.AlignHCenter
    }

    // ---------------------------------------------------------
    // 3. Input Area
    // ---------------------------------------------------------
    ChatInput {
        Layout.fillWidth: true
        isLoading: chatProcess.running

        onSendClicked: text => {
            sendMessage(text);
        }
    }

    // ---------------------------------------------------------
    // 4. Logic (Python Process)
    // ---------------------------------------------------------

    function sendMessage(msg) {
        // 1. إضافة رسالة المستخدم للواجهة فوراً
        messagesModel.append({
            "role": "user",
            "text": msg
        });
        errorText.text = "";

        // 2. تجهيز البارامترات للبايثون
        // تحويل الهيستوري إلى نص JSON
        var historyJson = JSON.stringify(root.chatHistory);

        // تشغيل العملية — المرحلة 5.3: السر يُمرَّر عبر stdin لا عبر argv
        chatProcess.command = [root.pythonPath, root.scriptPath + "advanced_chat.py", "--credential-stdin", "--model", root.currentModel, "--message", msg, "--history", historyJson];

        chatProcess.running = true;
    }

    Process {
        id: chatProcess
        running: false
        stdinEnabled: true

        onStarted: chatProcess.write(JSON.stringify({ credential: root.apiKey || "" }) + "\n")

        // تجميع المخرجات
        property string outputBuffer: ""

        onStdoutChanged: {
            outputBuffer += readAllStandardOutput();
        }

        onRunningChanged: {
            if (!running) {
                // عندما تنتهي العملية
                processResponse(outputBuffer);
                outputBuffer = ""; // تصفير البفر
            }
        }
    }

    function processResponse(jsonString) {
        try {
            var result = JSON.parse(jsonString);

            if (result.success) {
                // إضافة رد الذكاء الاصطناعي للواجهة
                messagesModel.append({
                    "role": "model",
                    "text": result.response
                });

                // تحديث الهيستوري للمرة القادمة
                root.chatHistory = result.updated_history;
            } else {
                errorText.text = "Error: " + result.error;
                // إضافة رسالة خطأ للشات أيضاً
                messagesModel.append({
                    "role": "model",
                    "text": "⚠️ Error: " + result.error
                });
            }
        } catch (e) {
            console.error("Failed to parse JSON: " + e);
            errorText.text = "Failed to parse response.";
        }
    }
}
