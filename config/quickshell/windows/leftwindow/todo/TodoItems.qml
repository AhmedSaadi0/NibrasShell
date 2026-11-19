// windows/leftwindow/todo/TodoItems.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/themes"
import "root:/components"
import "root:/services"

ListView {
    id: todoList

    // --- Signals ---
    signal requestSave
    signal requestCalendar(int index)
    signal requestRemove(int index)

    // --- Properties ---
    property var listModel

    // Theme Helpers
    readonly property var colors: ThemeManager.selectedTheme.colors
    readonly property var dims: ThemeManager.selectedTheme.dimensions
    readonly property var typo: ThemeManager.selectedTheme.typography

    clip: true
    interactive: false

    // The service owns the short-lived highlight so it clears on its timer.
    currentIndex: TodoService.focusedTaskIndex

    spacing: dims.spacingMedium
    topMargin: dims.spacingSmall
    bottomMargin: dims.spacingLarge

    // --- Model ---
    model: listModel

    // --- Functions ---
    // implicitHeight is the text height plus field padding, which is what the
    // ScrollView needs. paintedHeight leaves a permanent padding gap.
    function editorHeight(area, minHeight, maxHeight) {
        var needed = area.implicitHeight;
        if (!needed || needed <= 0)
            needed = area.contentHeight + area.topPadding + area.bottomPadding;
        return Math.max(minHeight, Math.min(maxHeight, needed));
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
    displaced: Transition {
        NumberAnimation {
            property: "y"
            duration: 400
            easing.type: Easing.OutQuint
        }
    }

    // --- Delegate ---
    delegate: Item {
        id: itemRoot
        width: todoList.width
        height: bgRect.height

        // The card keeps its height while the delegate collapses; clipping
        // prevents the content from bleeding out during the remove animation.
        clip: true

        // HoverHandler avoids stealing pointer events from child links and
        // buttons, which a delegate-level MouseArea used to do.
        HoverHandler {
            id: cardHover
            acceptedButtons: Qt.NoButton
        }

        Keys.onPressed: event => itemRoot.handleEditKeys(event)

        property bool isEditing: false
        property bool isEditingNotes: false
        property bool draftUrgent: model.isUrgent
        property bool taskCompleted: model.completed

        ListView.onRemove: removeAnim.start()

        SequentialAnimation {
            id: removeAnim
            PropertyAction {
                target: itemRoot
                property: "ListView.delayRemove"
                value: true
            }
            ParallelAnimation {
                NumberAnimation {
                    target: itemRoot
                    property: "height"
                    to: 0
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: itemRoot
                    property: "opacity"
                    to: 0
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }
            PropertyAction {
                target: itemRoot
                property: "ListView.delayRemove"
                value: false
            }
        }

        function beginEdit() {
            draftUrgent = model.isUrgent;
            editInput.text = model.title || "";
            isEditing = true;
        }

        function commitEdit() {
            if (!isEditing || editInput.text.trim() === "")
                return false;
            model.title = editInput.text;
            model.isUrgent = draftUrgent;
            isEditing = false;
            return true;
        }

        function cancelEdit() {
            editInput.text = model.title || "";
            draftUrgent = model.isUrgent;
            isEditing = false;
        }

        function commitNotes() {
            if (!isEditingNotes)
                return false;
            model.notes = notesInput.text;
            isEditingNotes = false;
            return true;
        }

        function cancelNotes() {
            notesInput.text = model.notes || "";
            isEditingNotes = false;
        }

        function saveAll() {
            const titleChanged = commitEdit();
            const notesChanged = commitNotes();
            if (titleChanged || notesChanged)
                todoList.requestSave();
        }

        function cancelAll() {
            cancelEdit();
            cancelNotes();
        }

        // Key events from any focused child (buttons, ScrollViews, TextAreas)
        // bubble up to the delegate, so Escape/Ctrl+Enter keep working after
        // focus moves away from a TextArea.
        function handleEditKeys(event) {
            if (!isEditing && !isEditingNotes)
                return;

            const isReturn = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
            const isModifier = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;

            if (event.key === Qt.Key_Escape) {
                cancelAll();
                event.accepted = true;
            } else if (isReturn && isModifier) {
                saveAll();
                event.accepted = true;
            }
        }

        // Externally completed tasks (e.g. from Due Now) must not leave stale
        // editors open on this delegate.
        onTaskCompletedChanged: {
            if (taskCompleted)
                cancelAll();
        }

        // --- Background Card ---
        Rectangle {
            id: bgRect
            width: parent.width
            height: mainLayout.implicitHeight + 24
            radius: dims.elementRadius

            border.width: 1
            border.color: {
                if (isEditing || isEditingNotes)
                    return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.5);
                if (todoList.currentIndex === index)
                    return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45);
                return Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05);
            }

            color: {
                if (taskCompleted)
                    return Qt.rgba(colors.primaryContainer.r, colors.primaryContainer.g, colors.primaryContainer.b, 0.5);
                if (cardHover.hovered || isEditing)
                    return Qt.lighter(colors.surfaceContainerHigh, 1.2);
                return colors.surfaceContainer;
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }

            // Side bar
            Rectangle {
                width: 4
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 8
                anchors.leftMargin: 6
                radius: dims.shapeExtraSmall
                color: {
                    if (taskCompleted)
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

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: dims.spacingLarge
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 8

                // --- TOP ROW: Checkbox + Title ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: dims.spacingLarge
                    Layout.alignment: Qt.AlignTop

                    CheckBox {
                        id: completionCheck
                        checked: taskCompleted
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        enabled: !isEditing && !isEditingNotes

                        onClicked: {
                            model.completed = checked;
                            if (checked)
                                cancelAll();
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

                    MarkdownText {
                        id: titleView
                        visible: !isEditing
                        source: model.title || ""
                        baseFontSize: typo.medium
                        strikeThrough: taskCompleted
                        textColor: taskCompleted ? colors.onSurfaceVariant : colors.onSurface
                        Layout.fillWidth: true
                    }

                    ScrollView {
                        id: editScroll
                        visible: isEditing
                        Layout.fillWidth: true
                        Layout.preferredHeight: todoList.editorHeight(editInput, 46, 160)
                        clip: true

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextArea {
                            id: editInput
                            width: editScroll.width
                            text: model.title || ""
                            font.family: typo.bodyFont
                            font.pixelSize: typo.medium
                            font.bold: true
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            color: colors.onSurface

                            background: Rectangle {
                                color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05)
                                radius: dims.shapeExtraSmall
                            }

                            // Intercept before TextArea can insert a newline.
                            Keys.onPressed: event => itemRoot.handleEditKeys(event)
                        }
                    }
                }

                // --- NOTES (View Mode) ---
                MarkdownText {
                    id: notesView
                    visible: !isEditingNotes && (model.notes || "") !== ""
                    source: model.notes || ""
                    baseFontSize: typo.small
                    textColor: colors.onSurfaceVariant
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    Layout.topMargin: -2
                }

                // --- NOTES (Edit Mode) ---
                ScrollView {
                    id: notesScroll
                    visible: isEditingNotes
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    Layout.preferredHeight: todoList.editorHeight(notesInput, 46, 190)
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: notesInput
                        width: notesScroll.width
                        text: model.notes || ""
                        font.family: typo.bodyFont
                        font.pixelSize: typo.small
                        wrapMode: Text.Wrap
                        selectByMouse: true
                        color: colors.onSurface

                        background: Rectangle {
                            color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.05)
                            radius: dims.shapeExtraSmall
                        }

                        // Intercept before TextArea can insert a newline.
                        Keys.onPressed: event => itemRoot.handleEditKeys(event)
                    }
                }

                RowLayout {
                    visible: isEditingNotes
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    spacing: 8

                    Button {
                        text: qsTr("Save")
                        flat: true
                        implicitHeight: 28
                        font.pixelSize: typo.small
                        onClicked: itemRoot.saveAll()
                    }

                    Button {
                        text: qsTr("Cancel")
                        flat: true
                        implicitHeight: 28
                        font.pixelSize: typo.small
                        onClicked: itemRoot.cancelAll()
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                // --- BOTTOM ROW: Metadata & Actions ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        visible: !isEditing
                        text: model.date
                        font.family: typo.bodyFont
                        font.pixelSize: typo.small - 1
                        color: colors.onSurfaceVariant
                        opacity: 0.8
                    }

                    Rectangle {
                        visible: !isEditing && model.isUrgent && !taskCompleted
                        width: urgentText.implicitWidth + 10
                        height: urgentText.implicitHeight + 4
                        radius: dims.shapeExtraSmall
                        color: Qt.rgba(colors.error.r, colors.error.g, colors.error.b, 0.15)
                        Text {
                            id: urgentText
                            anchors.centerIn: parent
                            text: qsTr("URGENT")
                            font.family: typo.bodyFont
                            font.pixelSize: 9
                            font.bold: true
                            color: colors.error
                        }
                    }

                    Button {
                        id: dateBtnItem
                        visible: isEditing
                        text: "📅 " + model.date
                        Layout.preferredHeight: 30
                        leftPadding: 10
                        rightPadding: 10
                        flat: true
                        onClicked: todoList.requestCalendar(index)

                        background: Rectangle {
                            radius: dims.elementRadius
                            color: dateBtnItem.hovered
                                ? Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.08)
                                : Qt.rgba(colors.onSurface.r, colors.onSurface.g, colors.onSurface.b, 0.04)
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

                    Button {
                        id: urgentBtnItem
                        visible: isEditing
                        checkable: true
                        checked: itemRoot.draftUrgent
                        Layout.preferredHeight: 30
                        onClicked: itemRoot.draftUrgent = !itemRoot.draftUrgent

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
                            spacing: 5
                            Text {
                                text: urgentBtnItem.checked ? "🔥" : "🏳️"
                                font.pixelSize: 12
                                color: urgentBtnItem.checked ? colors.onError : colors.onSurfaceVariant
                            }
                            Text {
                                text: urgentBtnItem.checked ? qsTr("URGENT") : qsTr("Normal")
                                font.family: typo.bodyFont
                                font.pixelSize: 10
                                font.bold: true
                                color: urgentBtnItem.checked ? colors.onError : colors.onSurfaceVariant
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        id: notesBtnItem

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !taskCompleted && !isEditing
                        enabled: opacity > 0.1

                        flat: true
                        opacity: (model.notes || "") !== "" ? 1 : (isEditingNotes || cardHover.hovered || notesBtnItem.hovered ? 1 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: {
                            if (isEditingNotes) {
                                itemRoot.cancelNotes();
                            } else {
                                notesInput.text = model.notes || "";
                                isEditingNotes = true;
                                notesInput.forceActiveFocus();
                            }
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

                    Button {
                        id: editBtn
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !taskCompleted
                        enabled: opacity > 0.1

                        flat: true
                        opacity: isEditing || cardHover.hovered || editBtn.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: {
                            if (isEditing) {
                                if (editInput.text.trim() !== "")
                                    itemRoot.saveAll();
                            } else {
                                itemRoot.beginEdit();
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
                        ToolTip.text: isEditing ? qsTr("Save") : qsTr("Edit")
                    }

                    Button {
                        id: deleteBtn
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        visible: !isEditing
                        enabled: opacity > 0.1

                        flat: true
                        opacity: cardHover.hovered || deleteBtn.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        onClicked: todoList.requestRemove(index)

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
                        ToolTip.text: qsTr("Delete")
                    }
                }
            }
        }
    }
}
