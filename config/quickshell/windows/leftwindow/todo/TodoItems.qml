// windows/leftwindow/todo/TodoItems.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/themes"
import "root:/components"

ListView {
    id: todoList

    // --- Signals ---
    signal requestSave
    signal requestCalendar(int index)

    // --- Properties ---
    property var listModel

    // Theme Helpers
    readonly property var colors: ThemeManager.selectedTheme.colors
    readonly property var dims: ThemeManager.selectedTheme.dimensions
    readonly property var typo: ThemeManager.selectedTheme.typography

    clip: true
    interactive: false

    spacing: dims.spacingMedium
    topMargin: dims.spacingSmall
    bottomMargin: dims.spacingLarge

    // --- Model ---
    model: listModel

    // --- Functions ---
    // Height the notes editor needs for its current content.
    function editorHeight(area, minHeight, maxHeight) {
        var needed = area.paintedHeight;
        if (!needed || needed <= 0)
            needed = area.contentHeight + area.topPadding + area.bottomPadding;
        return Math.max(minHeight, Math.min(maxHeight, needed));
    }

    // Highlights a task (used when jumping from the "Due Now" section).
    function focusTask(index) {
        if (index < 0 || index >= count)
            return;
        currentIndex = index;
    }

    // --- Transitions ---
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 400
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            property: "y"
            from: -50
            duration: 400
            easing.type: Easing.OutBack
        }
    }
    remove: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 300
            }
            NumberAnimation {
                property: "height"
                to: 0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
    }
    displaced: Transition {
        NumberAnimation {
            property: "y"
            duration: 400
            easing.type: Easing.OutQuint
        }
    }

    // --- Delegate ---
    delegate: MouseArea {
        id: itemRoot
        width: todoList.width

        // حساب الارتفاع: المحتوى + هوامش
        height: bgRect.height

        hoverEnabled: true
        propagateComposedEvents: true
        onClicked: mouse => mouse.accepted = false

        property bool isEditing: false
        property bool isEditingNotes: false

        ListView.onRemove: removeAnim.start()

        SequentialAnimation {
            id: removeAnim
            PropertyAction {
                target: itemRoot
                property: "ListView.delayRemove"
                value: true
            }
            NumberAnimation {
                target: itemRoot
                property: "height"
                to: 0
                duration: 250
                easing.type: Easing.InOutQuad
            }
            PropertyAction {
                target: itemRoot
                property: "ListView.delayRemove"
                value: false
            }
        }

        // --- Background Card (Original Styles) ---
        Rectangle {
            id: bgRect
            width: parent.width
            height: mainLayout.implicitHeight + 24 // Dynamic height based on content
            radius: dims.elementRadius

            // 1. Original Border Logic
            border.width: 1
            border.color: {
                if (isEditing || isEditingNotes)
                    return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.5);
                if (todoList.currentIndex === index)
                    return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45);
                return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05);
            }

            // 2. Original Color Logic
            color: {
                if (model.completed)
                    return Qt.rgba(colors.primaryContainer.r, colors.primaryContainer.g, colors.primaryContainer.b, 0.5);
                if (itemRoot.containsMouse || isEditing)
                    return Qt.lighter(colors.surfaceContainerHigh, 1.2);
                return colors.surfaceContainer;
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            // 3. Original Side Bar
            Rectangle {
                width: 4
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 8
                anchors.leftMargin: 6
                radius: dims.shapeExtraSmall
                color: {
                    if (model.completed)
                        return colors.onSurfaceVariant;
                    if (model.isUrgent)
                        return colors.error;
                    return colors.primary;
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }

            // --- Main Content Column ---
            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.leftMargin: 20 // Space for side bar
                anchors.rightMargin: dims.spacingLarge
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 8 // Space between Title Row and Footer Row

                // --- TOP ROW: Checkbox + Title ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: dims.spacingLarge
                    Layout.alignment: Qt.AlignTop

                    // Checkbox (Original Style)
                    CheckBox {
                        id: completionCheck
                        checked: model.completed
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        enabled: !isEditing && !isEditingNotes

                        onClicked: {
                            model.completed = checked;
                            if (checked)
                                isEditing = false;
                            todoList.requestSave();
                        }

                        indicator: Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: dims.shapeSmall
                            color: completionCheck.checked ? colors.tertiary : "transparent"
                            border.width: 1.5
                            border.color: completionCheck.checked ? colors.tertiary : colors.onSurfaceVariant
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: colors.onTertiary
                                font.pixelSize: 14
                                font.bold: true
                                visible: completionCheck.checked
                                scale: visible ? 1 : 0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                    }

                    // Title Text (View Mode - markdown aware)
                    MarkdownText {
                        id: titleView
                        visible: !isEditing
                        source: model.title || ""
                        baseFontSize: typo.medium
                        strikeThrough: model.completed
                        textColor: model.completed ? colors.onSurfaceVariant : colors.onSurface
                        Layout.fillWidth: true
                    }

                    // Title Input (Edit Mode - raw markdown source)
                    TextArea {
                        id: editInput
                        visible: isEditing
                        Layout.fillWidth: true
                        text: model.title
                        font.family: typo.bodyFont
                        font.pixelSize: typo.medium
                        font.bold: true
                        wrapMode: Text.Wrap
                        color: colors.onSurface
                        // Original Edit Background
                        background: Rectangle {
                            color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05)
                            radius: dims.shapeExtraSmall
                        }
                        // Enter / Shift+Enter add a new line, Ctrl+Enter saves.
                        Keys.onPressed: event => {
                            const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                            const isModifier = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;

                            if (isReturn && isModifier) {
                                if (editInput.text.trim() !== "") {
                                    model.title = editInput.text;
                                    isEditing = false;
                                    todoList.requestSave();
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                editInput.text = model.title;
                                isEditing = false;
                                event.accepted = true;
                            }
                        }
                    }
                }

                // --- NOTES (View Mode - markdown aware) ---
                MarkdownText {
                    id: notesView
                    visible: !isEditingNotes && (model.notes || "") !== ""
                    source: model.notes || ""
                    baseFontSize: typo.small
                    textColor: colors.onSurfaceVariant
                    Layout.fillWidth: true
                    Layout.leftMargin: 34 // aligns with the title text
                    Layout.topMargin: -2
                }

                // --- NOTES (Edit Mode) ---
                ColumnLayout {
                    id: notesEditArea
                    visible: isEditingNotes
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    spacing: 6

                    TextArea {
                        id: notesInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: todoList.editorHeight(notesInput, 46, 190)
                        font.family: typo.bodyFont
                        font.pixelSize: typo.small
                        wrapMode: Text.Wrap
                        color: colors.onSurface
                        selectByMouse: true
                        background: Rectangle {
                            color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05)
                            radius: dims.shapeExtraSmall
                        }

                        Keys.onPressed: event => {
                            const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                            const isModifier = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;

                            if (isReturn && isModifier) {
                                model.notes = notesInput.text;
                                isEditingNotes = false;
                                todoList.requestSave();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                isEditingNotes = false;
                                event.accepted = true;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: qsTr("Save")
                            flat: true
                            implicitHeight: 28
                            font.pixelSize: typo.small
                            onClicked: {
                                model.notes = notesInput.text;
                                isEditingNotes = false;
                                todoList.requestSave();
                            }
                        }

                        Button {
                            text: qsTr("Cancel")
                            flat: true
                            implicitHeight: 28
                            font.pixelSize: typo.small
                            onClicked: {
                                notesInput.text = model.notes || "";
                                isEditingNotes = false;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                // --- BOTTOM ROW: Metadata & Actions ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // --- Left Side: Date & Urgent Badge ---

                    // Date (View Mode)
                    Text {
                        visible: !isEditing
                        text: model.date
                        font.family: typo.bodyFont
                        font.pixelSize: typo.small - 1
                        color: colors.onSurfaceVariant
                        opacity: 0.8
                    }

                    // Urgent Badge (View Mode)
                    Rectangle {
                        visible: !isEditing && model.isUrgent && !model.completed
                        width: urgentText.implicitWidth + 10
                        height: urgentText.implicitHeight + 4
                        radius: dims.shapeExtraSmall
                        color: Qt.rgba(colors.error.r, colors.error.g, colors.error.b, 0.15)
                        Text {
                            id: urgentText
                            anchors.centerIn: parent
                            text: "URGENT"
                            font.family: typo.bodyFont
                            font.pixelSize: 9
                            font.bold: true
                            color: colors.error
                        }
                    }

                    // Date Button (Edit Mode - Original Style reused)
                    Button {
                        id: dateBtnItem
                        visible: isEditing
                        text: "📅 " + model.date
                        Layout.preferredHeight: 30 // Slightly smaller for footer
                        leftPadding: 10
                        rightPadding: 10
                        flat: true
                        onClicked: todoList.requestCalendar(index)

                        background: Rectangle {
                            radius: dims.elementRadius
                            color: dateBtnItem.hovered ? Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.08) : Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.04)
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
                        }
                    }

                    // Urgent Toggle (Edit Mode - Original Style reused)
                    Button {
                        id: urgentBtnItem
                        visible: isEditing
                        checkable: true
                        checked: model.isUrgent
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: checked ? 90 : 80
                        onClicked: model.isUrgent = !model.isUrgent

                        background: Rectangle {
                            radius: dims.shapeLarge
                            color: urgentBtnItem.checked ? colors.error : "transparent"
                            border.width: urgentBtnItem.checked ? 0 : 1.5
                            border.color: urgentBtnItem.checked ? colors.error : colors.onSurfaceVariant
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: urgentBtnItem.checked ? "🔥" : "🏳️"
                                font.pixelSize: 12
                                color: urgentBtnItem.checked ? colors.onError : colors.onSurfaceVariant
                            }
                            Text {
                                text: urgentBtnItem.checked ? "URGENT" : "Normal"
                                font.family: typo.bodyFont
                                font.pixelSize: 10
                                font.bold: true
                                color: urgentBtnItem.checked ? colors.onError : colors.onSurfaceVariant
                            }
                        }
                    }

                    // Spacer to push buttons to right
                    Item {
                        Layout.fillWidth: true
                    }

                    // --- Right Side: Action Buttons (Original Logic) ---

                    // Notes Toggle
                    Button {
                        id: notesBtnItem

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !model.completed && !isEditing

                        flat: true
                        opacity: (model.notes || "") !== "" ? 1 : (isEditingNotes || itemRoot.containsMouse || notesBtnItem.hovered ? 1 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: {
                            notesInput.text = model.notes || "";
                            isEditingNotes = !isEditingNotes;
                            if (isEditingNotes)
                                notesInput.forceActiveFocus();
                        }

                        background: Rectangle {
                            radius: dims.elementRadius
                            color: notesBtnItem.hovered ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.1) : "transparent"
                        }

                        contentItem: Text {
                            text: "📝"
                            color: (model.notes || "") !== "" ? colors.primary : (notesBtnItem.hovered ? colors.primary : colors.onSurfaceVariant)
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: (model.notes || "") !== "" ? qsTr("Edit details") : qsTr("Add details")
                    }

                    // Edit/Save Button
                    Button {
                        id: editBtn
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !model.completed

                        // Original Opacity Logic
                        flat: true
                        opacity: isEditing || itemRoot.containsMouse || editBtn.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: {
                            if (isEditing) {
                                if (editInput.text.trim() !== "") {
                                    model.title = editInput.text;
                                    isEditing = false;
                                    todoList.requestSave();
                                }
                            } else {
                                editInput.text = model.title;
                                isEditing = true;
                                editInput.forceActiveFocus();
                            }
                        }

                        background: Rectangle {
                            radius: dims.elementRadius
                            color: editBtn.hovered ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.1) : "transparent"
                        }

                        contentItem: Text {
                            text: isEditing ? "✓" : "✎"
                            color: editBtn.hovered ? colors.primary : colors.onSurfaceVariant
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: isEditing ? "Save" : "Edit"
                    }

                    // Delete Button
                    Button {
                        id: deleteBtn
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !isEditing

                        // Original Opacity Logic
                        flat: true
                        opacity: itemRoot.containsMouse || deleteBtn.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: {
                            todoList.listModel.remove(index);
                            todoList.requestSave();
                        }

                        background: Rectangle {
                            radius: dims.elementRadius
                            color: deleteBtn.hovered ? Qt.rgba(colors.error.r, colors.error.g, colors.error.b, 0.1) : "transparent"
                        }

                        contentItem: Text {
                            text: "✕"
                            color: deleteBtn.hovered ? colors.error : colors.onSurfaceVariant
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "Delete"
                    }
                }
            }
        }
    }
}
