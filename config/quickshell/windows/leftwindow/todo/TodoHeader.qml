// windows/leftwindow/todo/TodoHeader.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/themes"
import "root:/components"
import "root:/windows/leftwindow/base"

HeaderCard {
    id: headerRoot

    // --- Signals ---
    signal addTask(string title, bool urgent, string notes)
    signal openCalendar

    // --- Properties ---
    property date selectedDate

    // Height of the page the header lives in. The editor grows with its
    // content but never uses more than its share of that space.
    property int availableHeight: 0

    // Toggles
    property bool notesOpen: false
    property bool previewEnabled: false

    // Theme Helpers
    readonly property var colors: ThemeManager.selectedTheme.colors
    readonly property var dims: ThemeManager.selectedTheme.dimensions
    readonly property var typo: ThemeManager.selectedTheme.typography

    // --- Layout Settings ---
    Layout.fillWidth: true

    // --- Input sizing ---
    // The editor follows its content: a short title keeps the field compact,
    // a long one grows until it reaches its share of the available space.
    // Beyond that the TextArea scrolls internally instead of pushing the
    // whole menu down.
    //
    // The minimum is three lines (the field is a multi line editor, Enter
    // adds a line instead of sending the task).
    readonly property int minInputHeight: 78
    readonly property int maxInputHeight: availableHeight > 0
        ? Math.max(140, Math.min(400, Math.round(availableHeight * 0.40)))
        : 200
    readonly property int maxNotesHeight: availableHeight > 0
        ? Math.max(100, Math.min(260, Math.round(availableHeight * 0.25)))
        : 190

    // --- Toggle animations ---
    // Animations are only used for discrete toggles (notes / preview).
    // While typing the heights are updated immediately, animating them would
    // fight the layout and make the text cursor jitter.
    property real notesExpand: 0
    property real previewMix: 0

    Behavior on notesExpand {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on previewMix {
        NumberAnimation {
            duration: 180
            easing.type: Easing.InOutQuad
        }
    }

    // --- Functions ---
    // Height the editor needs for its current content, clamped to the
    // allowed range. TextArea has no implicitContentHeight, paintedHeight
    // already includes the padding.
    function editorHeight(area, minHeight, maxHeight) {
        var needed = area.paintedHeight;
        if (!needed || needed <= 0)
            needed = area.contentHeight + area.topPadding + area.bottomPadding;
        return Math.max(minHeight, Math.min(maxHeight, needed));
    }

    // دالة لجمع منطق الإضافة من الزر ومن مفتاح Enter
    function submitNewTask() {
        const title = taskInput.text.trim();
        if (title === "") {
            return;
        }
        headerRoot.addTask(title, urgentBtn.checked, notesInput.text.trim());
        taskInput.text = "";
        notesInput.text = "";
        urgentBtn.checked = false;
        headerRoot.notesOpen = false;
        headerRoot.notesExpand = 0;
    }

    function toggleNotes() {
        headerRoot.notesOpen = !headerRoot.notesOpen;
        headerRoot.notesExpand = headerRoot.notesOpen ? 1 : 0;
        if (headerRoot.notesOpen) {
            notesInput.forceActiveFocus();
        } else {
            taskInput.forceActiveFocus();
        }
    }

    function togglePreview() {
        headerRoot.previewEnabled = !headerRoot.previewEnabled;
        headerRoot.previewMix = headerRoot.previewEnabled ? 1 : 0;
        if (!headerRoot.previewEnabled) {
            taskInput.forceActiveFocus();
        }
    }

    ColumnLayout {
        id: headerColumn

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        Layout.bottomMargin: 10

        spacing: 10

        // --- Editor / Live Markdown Preview ---
        Item {
            id: editorStack
            Layout.fillWidth: true
            Layout.preferredHeight: headerRoot.previewEnabled
                ? previewColumn.implicitHeight
                : headerRoot.editorHeight(taskInput, headerRoot.minInputHeight, headerRoot.maxInputHeight)

            // Live preview of what the task will look like in the list.
            Column {
                id: previewColumn
                anchors.fill: parent
                spacing: 8
                visible: headerRoot.previewEnabled
                opacity: headerRoot.previewMix
                clip: true

                MarkdownText {
                    id: titlePreview
                    width: previewColumn.width
                    source: taskInput.text
                    baseFontSize: 15
                    textColor: headerRoot.colors.onSurface
                }

                MarkdownText {
                    id: notesPreview
                    width: previewColumn.width
                    visible: notesInput.text.trim() !== ""
                    source: notesInput.text
                    baseFontSize: 13
                    textColor: headerRoot.colors.onSurfaceVariant
                }
            }

            // Title Input
            TextArea {
                id: taskInput

                anchors.fill: parent
                opacity: 1 - headerRoot.previewMix
                visible: opacity > 0.01
                enabled: !headerRoot.previewEnabled

                placeholderText: "Add a new task... (markdown supported)"
                placeholderTextColor: headerRoot.colors.onSurfaceVariant
                color: headerRoot.colors.onSurface
                font.family: headerRoot.typo.bodyFont
                font.pixelSize: 15
                wrapMode: Text.Wrap
                selectByMouse: true

                background: Rectangle {
                    radius: headerRoot.dims.elementRadius
                    color: Qt.rgba(headerRoot.colors.onSurface.r, headerRoot.colors.onSurface.g, headerRoot.colors.onSurface.b, 0.04)
                    border.width: taskInput.activeFocus ? 1.5 : 1
                    border.color: taskInput.activeFocus
                        ? headerRoot.colors.primary
                        : Qt.rgba(headerRoot.colors.onSurface.r, headerRoot.colors.onSurface.g, headerRoot.colors.onSurface.b, 0.08)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                // Enter / Shift+Enter add a new line, Ctrl+Enter sends the task.
                Keys.onPressed: event => {
                    const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                    const isModifier = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;

                    if (isReturn && isModifier) {
                        headerRoot.submitNewTask();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape && headerRoot.previewEnabled) {
                        headerRoot.togglePreview();
                        event.accepted = true;
                    }
                }
            }
        }

        // --- Notes (optional, markdown) ---
        Item {
            id: notesSection
            Layout.fillWidth: true
            Layout.preferredHeight: headerRoot.notesExpand * (headerRoot.editorHeight(notesInput, 40, headerRoot.maxNotesHeight) + 2)
            visible: headerRoot.notesExpand > 0.01
            clip: true

            TextArea {
                id: notesInput

                anchors.fill: parent

                placeholderText: "Add details... (markdown supported)"
                placeholderTextColor: headerRoot.colors.onSurfaceVariant
                color: headerRoot.colors.onSurface
                font.family: headerRoot.typo.bodyFont
                font.pixelSize: 13
                wrapMode: Text.Wrap
                selectByMouse: true

                background: Rectangle {
                    radius: headerRoot.dims.elementRadius
                    color: Qt.rgba(headerRoot.colors.onSurface.r, headerRoot.colors.onSurface.g, headerRoot.colors.onSurface.b, 0.03)
                    border.width: notesInput.activeFocus ? 1.5 : 1
                    border.color: notesInput.activeFocus
                        ? headerRoot.colors.primary
                        : Qt.rgba(headerRoot.colors.onSurface.r, headerRoot.colors.onSurface.g, headerRoot.colors.onSurface.b, 0.06)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                // Enter adds a line, Ctrl+Enter closes the notes.
                Keys.onPressed: event => {
                    const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                    const isModifier = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;

                    if (isReturn && isModifier) {
                        headerRoot.notesOpen = false;
                        headerRoot.notesExpand = 0;
                        taskInput.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        headerRoot.notesOpen = false;
                        headerRoot.notesExpand = 0;
                        taskInput.forceActiveFocus();
                        event.accepted = true;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            // The row may shrink below the width of its buttons so the menu
            // can be resized to a small width without the header sticking
            // out of the card.
            Layout.minimumWidth: 0
            spacing: 12

            // Date Selector
            Button {
                id: dateBtn
                text: "📅 " + headerRoot.selectedDate.toLocaleDateString(Qt.locale(), "MMM d")

                Layout.preferredHeight: 34
                // May shrink with the menu width.
                Layout.minimumWidth: 0
                leftPadding: 14
                rightPadding: 14
                flat: true

                onClicked: headerRoot.openCalendar()

                background: Rectangle {
                    radius: dims.elementRadius
                    color: dateBtn.hovered ? Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.08) : Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.04)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    font.family: typo.bodyFont
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: colors.onSurface
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    opacity: 0.8
                    elide: Text.ElideRight
                }
            }

            // Urgent Toggle
            Button {
                id: urgentBtn
                checkable: true

                Layout.preferredHeight: 36
                Layout.preferredWidth: checked ? 100 : 90
                // May shrink with the menu width.
                Layout.minimumWidth: 0

                // Button Animations
                scale: pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 200
                    }
                }

                background: Rectangle {
                    radius: dims.elementRadius
                    color: urgentBtn.checked ? colors.error : "transparent"
                    border.width: urgentBtn.checked ? 0 : 1.5
                    border.color: urgentBtn.checked ? colors.error : colors.onSurfaceVariant

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: urgentBtn.checked ? "🔥" : "🏳️"
                        font.pixelSize: 14
                        color: urgentBtn.checked ? colors.onError : colors.onSurfaceVariant
                        Layout.leftMargin: 6

                        rotation: urgentBtn.checked ? 0 : -15
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    Text {
                        text: urgentBtn.checked ? "URGENT" : "Normal"
                        font.family: typo.bodyFont
                        font.pixelSize: 12
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        color: urgentBtn.checked ? colors.onError : colors.onSurfaceVariant
                        Layout.rightMargin: 6
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }

            // Submit Button
            Button {
                id: addTaskBtn

                Layout.preferredHeight: 34
                Layout.preferredWidth: 34

                onClicked: headerRoot.submitNewTask()

                background: Rectangle {
                    radius: dims.elementRadius
                    color: addTaskBtn.pressed ? Qt.darker(colors.primary, 1.1) : colors.primary
                    layer.enabled: true
                }

                contentItem: Text {
                    text: "➤"
                    font.pixelSize: 16
                    color: colors.onPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    bottomPadding: 2
                }

                ToolTip.visible: hovered
                ToolTip.text: qsTr("Add Task (Ctrl+Enter)")
                ToolTip.delay: 500
            }
        }

        // Second row: the optional tools. They live on their own row so the
        // main row stays narrow and the menu can be resized to a small width.
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.topMargin: -4
            spacing: 6

            // Notes Toggle
            Button {
                id: notesBtn

                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                flat: true

                onClicked: headerRoot.toggleNotes()

                background: Rectangle {
                    radius: dims.elementRadius
                    color: headerRoot.notesOpen
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.18)
                        : notesBtn.hovered
                            ? Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.08)
                            : "transparent"
                    border.width: headerRoot.notesOpen ? 1 : 0
                    border.color: colors.primary

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                contentItem: Text {
                    text: "📝"
                    font.pixelSize: 14
                    color: headerRoot.notesOpen ? colors.primary : colors.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ToolTip.visible: hovered
                ToolTip.text: qsTr("Details")
                ToolTip.delay: 500
            }

            // Live Preview Toggle
            Button {
                id: previewBtn

                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                flat: true

                onClicked: headerRoot.togglePreview()

                background: Rectangle {
                    radius: dims.elementRadius
                    color: headerRoot.previewEnabled
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.18)
                        : previewBtn.hovered
                            ? Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.08)
                            : "transparent"
                    border.width: headerRoot.previewEnabled ? 1 : 0
                    border.color: colors.primary

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                contentItem: Text {
                    text: "👁"
                    font.pixelSize: 14
                    color: headerRoot.previewEnabled ? colors.primary : colors.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ToolTip.visible: hovered
                ToolTip.text: qsTr("Preview")
                ToolTip.delay: 500
            }

            // Shortcut hint (lives in this row so the header height never
            // changes while typing)
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                horizontalAlignment: Text.AlignRight
                text: qsTr("Ctrl+Enter to add")
                font.family: headerRoot.typo.bodyFont
                font.pixelSize: 10
                color: headerRoot.colors.onSurfaceVariant
                opacity: 0.55
                elide: Text.ElideRight
            }
        }
    }
}
