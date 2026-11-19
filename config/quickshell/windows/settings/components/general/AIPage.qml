// windows/settings/pages/AIPage.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Qt.labs.platform

import "root:/components"
import "root:/components/settings"
import "root:/windows/settings/components"
import "root:/config"

BaseGeneralSettings {
    id: page
    title: qsTr("Intelligence & AI")
    icon: ""

    property var theme: page.selectedTheme

    // =========================================================
    // 1. الثوابت والنصوص الافتراضية
    // =========================================================
    readonly property string defaultWeatherPersona: "**ROLE**: Strategic Weather Advisor & Bio-Meteorologist.\n**MODE**: Predictive Lifestyle Analysis.\n\n**INTELLIGENCE RULES (Apply Strictly)**:\n1.  **Trajectory Analysis (CRITICAL)**: You are receiving full-day data. Do not focus only on \"Now\".\n    -   Compare *Current Temp* vs. *Forecasted Temp* for the next 4-6 hours.\n    -   Identify the *Shift*: Is it cooling down rapidly? Is rain approaching? Is the wind picking up?\n    \n2.  **Sensory Translation**: \n    -   Translate the number (e.g., 17°C) into a human feeling relative to the shift.\n    -   *Example*: \"Currently pleasant (17°C), but dropping fast.\"\n\n3.  **Layering Strategy (Wardrobe)**:\n    -   If the weather changes significantly (e.g., warm day -> cold night), advise on *layers*.\n    -   *Example*: \"Wear a t-shirt now, but absolutely bring a jacket for the evening drop.\"\n\n4.  **JSON Output Logic (`smart_summary`)**:\n    -   Construct the text in this format: [Current Feeling/Action] + [The Pivot/Future Change].\n    -   *Bad*: \"It is 17 degrees. It will be 12 later.\"\n    -   *Good*: \"Feels crisp and fresh right now. However, expect a sharp drop in temperature by sunset—keep a heavy layer nearby.\"\n\n5.  **Tagging Logic**: Use the `tags` array to highlight the *change* (e.g., [\"Cooling Down\", \"Windy Later\", \"Rain Incoming\"])."

    readonly property string defaultMusicPersona: "Role: You are \"VibeCheck,\" a chill, witty, and highly knowledgeable Audio-Visual Expert and Music Companion.\n\nExpertise: \n- Deep knowledge of Music Theory, History, and Production (Mixing/Mastering).\n- Expert in Cinematography, Video Editing, Color Grading, and Visual Aesthetics.\n- Up-to-date with Pop Culture, Memes, and Internet Media trends.\n\nPersonality & Tone:\n- Chill & Laid-back: You keep things relaxed. No stiff, robotic language.\n- Witty & Sarcastic: You enjoy clever humor and banter.\n- Brutally Honest (but Friendly): If the user shares a generic pop song or a poorly edited video, tease them about it. Call their taste \"basic\" or \"guilty pleasure\" in a fun way, but then provide genuine, high-level analysis or better recommendations.\n\nAlso make sure you do not just recommand songs, you recommand also actions like drinking coffee, reading a book, walking in calm, taking a shower ... etc, be creative. \nAlso don't ask the user to change the vibe ever, and if there is no recomandation, dont say try this song or anythink like that."
    readonly property string defaultSystemPersona: "Role: You are \"Kernel Sentinel,\" a calm, senior Linux systems analyst.\n\nStyle & Rules:\n- Evidence-first, no speculation.\n- Keep summaries short, technical, and actionable.\n- If the system is healthy, say it clearly.\n- Prefer clarity over jargon."
    readonly property string defaultTodoPersona: "Role: You are \"Focus Pilot,\" a pragmatic productivity coach.\n\nStyle & Rules:\n- Prioritize urgency and due items.\n- Keep the summary concise and decisive.\n- Highlight one next best focus.\n- Avoid motivational fluff."

    // =========================================================
    // 2. المتغيرات المحلية
    // =========================================================
    property string localProvider: "gemini"
    property string localLanguage: "English"

    // Keys
    property string localMainKey: ""
    property string localWeatherKey: ""
    property string localMusicKey: ""
    property string localSystemKey: ""

    // Models
    property string localWeatherModel: ""
    property string localMusicModel: ""
    property string localSystemModel: ""

    // Personas
    property string localWeatherPersona: ""
    property string localMusicPersona: ""
    property string localSystemPersona: ""
    property string localTodoPersona: ""

    // Memory & Context
    property int localWeatherHistoryTurns: 10
    property int localMusicHistoryTurns: 3

    // Toggle Visibility
    property bool showKeys: false

    // =========================================================
    // 3. المزامنة (Read)
    // =========================================================
    function syncFromConfig() {
        localProvider = App.aiProvider || "gemini";
        localLanguage = App.aiPreferredLanguage || "English";

        localMainKey = App.aiApiKey || "";
        localWeatherKey = App.weatherAiApiKey || "";
        localMusicKey = App.musicAiApiKey || "";
        localSystemKey = App.systemAiApiKey || "";

        localWeatherModel = App.weatherAiModel || "";
        localMusicModel = App.musicAiModel || "";
        localSystemModel = App.systemAiModel || "";

        localWeatherPersona = App.weatherPersona || defaultWeatherPersona;
        localMusicPersona = App.musicPersona || defaultMusicPersona;
        localSystemPersona = App.systemPersona || defaultSystemPersona;
        localTodoPersona = App.todoPersona || defaultTodoPersona;

        localWeatherHistoryTurns = App.weatherAiHistoryTurns !== undefined ? App.weatherAiHistoryTurns : 10;
        localMusicHistoryTurns = App.musicAiHistoryTurns !== undefined ? App.musicAiHistoryTurns : 3;

        // إذا لم تكن هناك موديلات محملة، نحاول التحديث
        if (App.availableGeminiWeatherModels.length === 0)
            App.modelsManager.refreshAll();
    }

    // =========================================================
    // 4. التجهيز للحفظ (Write)
    // =========================================================
    function serializeData() {
        return {
            "aiProvider": localProvider,
            "aiPreferredLanguage": localLanguage,
            "aiApiKey": localMainKey,
            "weatherAiApiKey": localWeatherKey,
            "musicAiApiKey": localMusicKey,
            "systemAiApiKey": localSystemKey,
            "weatherAiModel": localWeatherModel,
            "musicAiModel": localMusicModel,
            "systemAiModel": localSystemModel,
            "weatherPersona": localWeatherPersona,
            "musicPersona": localMusicPersona,
            "systemPersona": localSystemPersona,
            "todoPersona": localTodoPersona,
            "weatherAiHistoryTurns": localWeatherHistoryTurns,
            "musicAiHistoryTurns": localMusicHistoryTurns
        };
    }

    // =========================================================
    // 5. مكونات مساعدة
    // =========================================================
    // TextArea مخصص بنفس ستايل الحقول
    component StyledTextArea: Controls.ScrollView {
        id: sv
        property alias text: ta.text
        implicitHeight: 120
        clip: true

        Controls.TextArea {
            id: ta
            wrapMode: TextEdit.Wrap
            font.family: theme.typography.bodyFont
            font.pixelSize: theme.typography.small
            color: theme.colors.onSurfaceVariant
            selectedTextColor: theme.colors.onPrimary
            selectionColor: theme.colors.primary

            background: Rectangle {
                color: theme.colors.surfaceContainerHigh
                radius: theme.dimensions.baseRadius / 2
                border.color: parent.activeFocus ? theme.colors.primary : theme.colors.onSurfaceVariant
                border.width: 1
                opacity: 0.8
            }
        }
    }

    // =========================================================
    // 6. الواجهة
    // =========================================================
    ColumnLayout {
        spacing: theme.dimensions.spacingLarge
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter

        // --- FORM CONTENT ---
        ColumnLayout {
            Layout.preferredWidth: 580
            Layout.alignment: Qt.AlignHCenter
            spacing: theme.dimensions.spacingMedium

            SectionCard {
                title: qsTr("Provider & Locale")
                subtitle: qsTr("Select your AI provider and preferred language for responses.")

                GridLayout {
                    columns: 2
                    rowSpacing: 16
                    columnSpacing: 20
                    Layout.fillWidth: true

                    Controls.Label {
                        text: qsTr("AI Provider")
                        font.bold: true
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.medium
                    }
                    SettingsComboBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        model: ["gemini", "openrouter", "ollama", "local"]
                        currentIndex: {
                            var idx = model.indexOf(page.localProvider);
                            return idx !== -1 ? idx : 0;
                        }
                        onActivated: index => page.localProvider = textAt(index)
                    }

                    Controls.Label {
                        text: qsTr("Preferred Language")
                        font.bold: true
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.medium
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        EditableField {
                            Layout.fillWidth: true
                            text: page.localLanguage
                            placeholderText: "e.g. English, Arabic"
                            selectedTheme: page.theme
                            onEditingFinished: page.localLanguage = text
                        }
                        MButton {
                            text: page.showKeys ? "" : ""
                            font.family: theme.typography.iconFont
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            checkable: true
                            checked: page.showKeys
                            onClicked: page.showKeys = !page.showKeys
                        }
                    }
                }
            }

            SectionCard {
                title: qsTr("API Configuration")
                subtitle: qsTr("Enter your main API key. Leave model-specific keys empty to use this key.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Error Message
                    Text {
                        visible: App.modelsManager.lastError !== ""
                        text: "Error: " + App.modelsManager.lastError
                        color: theme.colors.error
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.small
                    }

                    RowLayout {
                        Controls.Label {
                            text: qsTr("Main API Key")
                            font.bold: true
                            font.pixelSize: theme.typography.medium
                            Layout.preferredWidth: 140
                        }
                        EditableField {
                            visible: page.localProvider !== "local"
                            Layout.fillWidth: true
                            text: page.localMainKey
                            placeholderText: "sk-..."
                            echoMode: page.showKeys ? TextInput.Normal : TextInput.Password
                            selectedTheme: page.theme
                            onEditingFinished: page.localMainKey = text
                        }
                    }
                }
            }

            SectionCard {
                title: qsTr("Models Selection")
                subtitle: qsTr("Choose the AI model for each assistant. Click refresh to update the list.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    MButton {
                        text: App.modelsManager.isLoading ? "Loading..." : "Refresh Models"
                        iconText: ""
                        enabled: !App.modelsManager.isLoading
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 140
                        onClicked: App.modelsManager.refreshAll()
                        visible: page.localProvider === "gemini"
                    }

                    // Weather Model
                    RowLayout {
                        Controls.Label {
                            text: qsTr("Weather")
                            font.bold: true
                            font.pixelSize: theme.typography.small
                            Layout.preferredWidth: 140
                        }
                        StackLayout {
                            Layout.fillWidth: true
                            currentIndex: page.localProvider === "gemini" ? 0 : 1
                            SettingsComboBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: App.availableGeminiWeatherModels
                                currentIndex: model.indexOf(page.localWeatherModel)
                                displayText: currentIndex === -1 ? (page.localWeatherModel || "Select Model") : currentText
                                onActivated: index => page.localWeatherModel = textAt(index)
                            }
                            EditableField {
                                Layout.fillWidth: true
                                placeholderText: "e.g. qwen/qwen-2-7b:free"
                                text: page.localWeatherModel
                                selectedTheme: page.theme
                                onEditingFinished: page.localWeatherModel = text
                            }
                        }
                    }

                    // Music Model
                    RowLayout {
                        Controls.Label {
                            text: qsTr("Music")
                            font.bold: true
                            font.pixelSize: theme.typography.small
                            Layout.preferredWidth: 140
                        }
                        StackLayout {
                            Layout.fillWidth: true
                            currentIndex: page.localProvider === "gemini" ? 0 : 1
                            SettingsComboBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: App.availableGeminiMusicModels
                                currentIndex: model.indexOf(page.localMusicModel)
                                displayText: currentIndex === -1 ? (page.localMusicModel || "Select Model") : currentText
                                onActivated: index => page.localMusicModel = textAt(index)
                            }
                            EditableField {
                                Layout.fillWidth: true
                                placeholderText: "e.g. anthropic/claude-3-haiku"
                                text: page.localMusicModel
                                selectedTheme: page.theme
                                onEditingFinished: page.localMusicModel = text
                            }
                        }
                    }

                    // System Model
                    RowLayout {
                        Controls.Label {
                            text: qsTr("System")
                            font.bold: true
                            font.pixelSize: theme.typography.small
                            Layout.preferredWidth: 140
                        }
                        StackLayout {
                            Layout.fillWidth: true
                            currentIndex: page.localProvider === "gemini" ? 0 : 1
                            SettingsComboBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: App.availableGeminiWeatherModels
                                currentIndex: model.indexOf(page.localSystemModel)
                                displayText: currentIndex === -1 ? (page.localSystemModel || "Select Model") : currentText
                                onActivated: index => page.localSystemModel = textAt(index)
                            }
                            EditableField {
                                Layout.fillWidth: true
                                placeholderText: "e.g. gemini-flash-lite-latest"
                                text: page.localSystemModel
                                selectedTheme: page.theme
                                onEditingFinished: page.localSystemModel = text
                            }
                        }
                    }
                }
            }

            SectionCard {
                title: qsTr("Memory & Context")
                subtitle: qsTr("How many past turns the Weather and Music AIs keep in mind. 0 disables memory; higher values give them more continuity but cost more tokens.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SliderWithLabel {
                        id: memorySlider
                        Layout.fillWidth: true
                        label: qsTr("Weather AI conversation turns")
                        from: 0
                        to: 30
                        stepSize: 1
                        decimals: 0
                        value: page.localWeatherHistoryTurns
                        onEditingFinished: finalValue => {
                            page.localWeatherHistoryTurns = Math.round(finalValue);
                        }
                    }

                    SliderWithLabel {
                        id: musicMemorySlider
                        Layout.fillWidth: true
                        label: qsTr("Music AI conversation turns")
                        from: 0
                        to: 10
                        stepSize: 1
                        decimals: 0
                        value: page.localMusicHistoryTurns
                        onEditingFinished: finalValue => {
                            page.localMusicHistoryTurns = Math.round(finalValue);
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item {
                            Layout.fillWidth: true
                        }
                        MButton {
                            text: qsTr("Reset Default (10)")
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: 140
                            flat: true
                            onClicked: {
                                page.localWeatherHistoryTurns = 10;
                                page.localMusicHistoryTurns = 3;
                            }
                        }
                    }
                }
            }

            SectionCard {
                title: qsTr("System Personas")
                subtitle: qsTr("Customize the behavior and tone of each AI assistant.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Weather Persona
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Controls.Label {
                                text: qsTr("Weather Assistant")
                                font.bold: true
                                font.pixelSize: theme.typography.medium
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            MButton {
                                text: "Reset Default"
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 120
                                flat: true
                                onClicked: page.localWeatherPersona = page.defaultWeatherPersona
                            }
                        }
                        StyledTextArea {
                            Layout.fillWidth: true
                            text: page.localWeatherPersona
                            onTextChanged: page.localWeatherPersona = text
                        }
                    }

                    // Music Persona
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Controls.Label {
                                text: qsTr("Music Assistant")
                                font.bold: true
                                font.pixelSize: theme.typography.medium
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            MButton {
                                text: "Reset Default"
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 120
                                flat: true
                                onClicked: page.localMusicPersona = page.defaultMusicPersona
                            }
                        }
                        StyledTextArea {
                            Layout.fillWidth: true
                            text: page.localMusicPersona
                            onTextChanged: page.localMusicPersona = text
                        }
                    }

                    // System Persona
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Controls.Label {
                                text: qsTr("System Analyst")
                                font.bold: true
                                font.pixelSize: theme.typography.medium
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            MButton {
                                text: "Reset Default"
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 120
                                flat: true
                                onClicked: page.localSystemPersona = page.defaultSystemPersona
                            }
                        }
                        StyledTextArea {
                            Layout.fillWidth: true
                            text: page.localSystemPersona
                            onTextChanged: page.localSystemPersona = text
                        }
                    }

                    // Todo Persona
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Controls.Label {
                                text: qsTr("Todo Assistant")
                                font.bold: true
                                font.pixelSize: theme.typography.medium
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            MButton {
                                text: "Reset Default"
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 120
                                flat: true
                                onClicked: page.localTodoPersona = page.defaultTodoPersona
                            }
                        }
                        StyledTextArea {
                            Layout.fillWidth: true
                            text: page.localTodoPersona
                            onTextChanged: page.localTodoPersona = text
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
