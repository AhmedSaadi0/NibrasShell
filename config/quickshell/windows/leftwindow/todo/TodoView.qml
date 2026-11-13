// windows/leftwindow/todo/TodoView.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/themes"
import "root:/components"
import "root:/services"
import "root:/config/ConstValues.js" as C
import "../base"

BaseMenuView {
    id: root

    menuTitle: qsTr("Todo")
    menuIcon: "󰄳"
    showPrimaryAction: false

    readonly property var colors: ThemeManager.selectedTheme.colors
    readonly property var dims: ThemeManager.selectedTheme.dimensions
    readonly property var typo: ThemeManager.selectedTheme.typography

    property date selectedDate: new Date()
    property int activeCalendarIndex: -1

    // Due Now section state
    property bool dueNowExpanded: true

    function addTask(title, urgent, notes) {
        TodoService.addTask(title, root.selectedDate, urgent, notes || "");
    }

    // Relative overdue label driven by the centralized service clock.
    function overdueLabel(dueAt) {
        if (!dueAt)
            return "";
        const diff = TodoService.now.getTime() - dueAt;
        if (diff < 0)
            return qsTr("pending");
        if (diff < 60000)
            return qsTr("now");

        const minutes = Math.floor(diff / 60000);
        if (minutes < 60)
            return minutes + "m " + qsTr("late");

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h " + qsTr("late");

        const days = Math.floor(hours / 24);
        return days + "d " + qsTr("late");
    }

    // Highlights a task in the list and scrolls it into view.
    function focusTask(index) {
        if (index < 0)
            return;

        tasksList.focusTask(index);
        TodoService.focusTask(index);
        scrollToTask(index);
    }

    function scrollToTask(index) {
        const flick = root.contentFlickable;
        if (!flick || index < 0 || index >= tasksList.count)
            return;

        const item = tasksList.itemAtIndex(index);
        if (!item)
            return;

        const pos = item.mapToItem(flick.contentItem, 0, 0);
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.max(0, Math.min(pos.y - 80, maxY));
    }

    headerContent: TodoHeader {
        width: root.width
        availableHeight: root.height
        selectedDate: root.selectedDate
        onOpenCalendar: {
            root.activeCalendarIndex = -1;
            calendarPopup.open();
        }
        onAddTask: (title, urgent, notes) => root.addTask(title, urgent, notes)
    }

    // المحتوى الرئيسي
    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.dims.spacingLarge

        Layout.leftMargin: root.dims.menuWidgetsMargin
        Layout.rightMargin: root.dims.menuWidgetsMargin
        Layout.topMargin: root.dims.menuWidgetsMargin

        // --- 1. كرت الذكاء الاصطناعي ---
        AISummaryCard {
            id: smartTodoCard
            Layout.fillWidth: true
            visible: TodoService.aiSummaryText !== ""

            title: TodoService.aiSummaryTitle !== "" ? TodoService.aiSummaryTitle : qsTr("المحلل الذكي")
            summaryText: TodoService.aiSummaryText
            iconText: "✨"

            showDataRefreshButton: false
            showAiRefreshButton: true

            bottomContent: Flow {
                Layout.fillWidth: true
                spacing: 3
                visible: TodoService.aiSummaryTags && TodoService.aiSummaryTags.length > 0

                Repeater {
                    id: tagsRepeater
                    model: TodoService.aiSummaryTags
                    delegate: Rectangle {
                        height: 24
                        width: tagText.contentWidth + 16
                        color: smartTodoCard.aiBorderColor.alpha(0.1)
                        property int groupRadius: ThemeManager.selectedTheme.dimensions.elementRadius / C.M3_BUTTON_RADIUS_DIVISOR
                        property int innerRadiusDiv: 4
                        topLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                        bottomLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                        topRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv
                        bottomRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv
                        border.color: smartTodoCard.aiBorderColor.alpha(0.2)
                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 11
                            color: smartTodoCard.aiTextColor
                        }
                    }
                }
            }
        }

        // --- 2. المهام العاجلة (Due Now) ---
        ColumnLayout {
            id: dueNowSection
            Layout.fillWidth: true
            visible: TodoService.dueNowModel.count > 0
            spacing: 8

            // Header: label + live count + collapse toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: qsTr("Due Now")
                    font.family: root.typo.bodyFont
                    font.pixelSize: 13
                    font.bold: true
                    color: root.colors.error
                    opacity: 0.9
                }

                // Count badge
                Rectangle {
                    width: dueCountText.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Qt.rgba(root.colors.error.r, root.colors.error.g, root.colors.error.b, 0.18)

                    Text {
                        id: dueCountText
                        anchors.centerIn: parent
                        text: TodoService.dueNowModel.count
                        font.family: root.typo.bodyFont
                        font.pixelSize: 10
                        font.bold: true
                        color: root.colors.error
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Collapse toggle
                Button {
                    id: dueNowToggle

                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    flat: true

                    onClicked: root.dueNowExpanded = !root.dueNowExpanded

                    background: Rectangle {
                        radius: root.dims.elementRadius
                        color: dueNowToggle.hovered ? Qt.rgba(root.colors.onSurface.r, root.colors.onSurface.g, root.colors.onSurface.b, 0.08) : "transparent"
                    }

                    contentItem: Text {
                        text: root.dueNowExpanded ? "▾" : "▸"
                        font.pixelSize: 14
                        color: root.colors.error
                        opacity: 0.9
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: root.dueNowExpanded ? qsTr("Collapse") : qsTr("Expand")
                    ToolTip.delay: 500
                }
            }

            // Rows: height follows the content, collapses with an animation.
            Item {
                id: dueNowRows
                Layout.fillWidth: true
                Layout.preferredHeight: root.dueNowExpanded ? rowsColumn.implicitHeight : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    id: rowsColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: TodoService.dueNowModel
                        delegate: MouseArea {
                            id: dueRoot
                            width: rowsColumn.width
                            height: dueRect.height

                            hoverEnabled: true
                            propagateComposedEvents: true

                            onClicked: mouse => {
                                root.focusTask(model.sourceIndex);
                                mouse.accepted = false;
                            }

                            Rectangle {
                                id: dueRect
                                width: parent.width
                                height: dueRowLayout.implicitHeight + 24 // margins of the row layout
                                radius: root.dims.elementRadius
                                color: Qt.rgba(root.colors.error.r, root.colors.error.g, root.colors.error.b, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(root.colors.error.r, root.colors.error.g, root.colors.error.b, 0.15)

                                RowLayout {
                                    id: dueRowLayout
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: isUrgent ? "🔥" : "⏰"
                                        font.pixelSize: 16
                                        Layout.alignment: Qt.AlignTop
                                    }

                                    // Title (markdown aware)
                                    MarkdownText {
                                        id: dueTitle
                                        source: model.title || ""
                                        baseFontSize: root.typo.small
                                        textColor: root.colors.onSurface
                                        Layout.fillWidth: true
                                    }

                                    // Live overdue chip
                                    Rectangle {
                                        id: dueChip
                                        Layout.alignment: Qt.AlignTop
                                        width: dueChipText.implicitWidth + 12
                                        height: dueChipText.implicitHeight + 4
                                        radius: root.dims.shapeExtraSmall
                                        color: Qt.rgba(root.colors.error.r, root.colors.error.g, root.colors.error.b, 0.16)

                                        Text {
                                            id: dueChipText
                                            anchors.centerIn: parent
                                            text: root.overdueLabel(model.dueAt)
                                            font.family: root.typo.bodyFont
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: root.colors.error
                                        }
                                    }

                                    // Quick actions
                                    Button {
                                        id: dueCompleteBtn

                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        Layout.alignment: Qt.AlignTop

                                        flat: true
                                        opacity: dueRoot.containsMouse ? 1 : 0
                                        enabled: dueRoot.containsMouse

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 150
                                            }
                                        }

                                        onClicked: TodoService.completeTask(model.sourceIndex)

                                        background: Rectangle {
                                            radius: root.dims.elementRadius
                                            color: dueCompleteBtn.hovered ? Qt.rgba(root.colors.tertiary.r, root.colors.tertiary.g, root.colors.tertiary.b, 0.2) : "transparent"
                                        }

                                        contentItem: Text {
                                            text: "✓"
                                            font.pixelSize: 14
                                            color: dueCompleteBtn.hovered ? root.colors.tertiary : root.colors.onSurfaceVariant
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Complete")
                                    }

                                    Button {
                                        id: dueDeleteBtn

                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        Layout.alignment: Qt.AlignTop

                                        flat: true
                                        opacity: dueRoot.containsMouse ? 1 : 0
                                        enabled: dueRoot.containsMouse

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 150
                                            }
                                        }

                                        onClicked: TodoService.removeTask(model.sourceIndex)

                                        background: Rectangle {
                                            radius: root.dims.elementRadius
                                            color: dueDeleteBtn.hovered ? Qt.rgba(root.colors.error.r, root.colors.error.g, root.colors.error.b, 0.15) : "transparent"
                                        }

                                        contentItem: Text {
                                            text: "✕"
                                            font.pixelSize: 13
                                            color: dueDeleteBtn.hovered ? root.colors.error : root.colors.onSurfaceVariant
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
            }
        }

        // --- 3. بقية المهام ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.bottomMargin: root.dims.menuWidgetsMargin

            TodoItems {
                id: tasksList
                Layout.fillWidth: true
                // TODO: -> Convert 64 to a const and use it instead
                Layout.preferredHeight: contentHeight + 4

                listModel: TodoService.tasksModel
                onRequestSave: TodoService.saveAndSort()
                onRequestCalendar: index => {
                    root.activeCalendarIndex = index;
                    calendarPopup.open();
                }
            }
        }
    }

    CustomCalendar {
        id: calendarPopup
        x: (root.width - width) / 2
        y: 80
        z: 100
        onDateSelected: date => {
            if (root.activeCalendarIndex === -1) {
                root.selectedDate = date;
            } else {
                TodoService.updateTaskDate(root.activeCalendarIndex, date);
            }
        }
    }
}
