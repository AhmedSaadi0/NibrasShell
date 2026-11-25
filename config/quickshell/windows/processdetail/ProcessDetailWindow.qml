// windows/processdetail/ProcessDetailWindow.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "root:/themes"
import "root:/config"
import "root:/config/EventNames.js" as Events
import "root:/components"

ApplicationWindow {
    id: root

    required property int targetPid

    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowStaysOnTopHint
    title: "Process Details - PID " + targetPid

    minimumWidth: 540
    minimumHeight: 600
    width: 600
    height: 700

    property bool ready: false
    readonly property var theme: ThemeManager.selectedTheme

    // دالة آمنة لتطبيق الشفافية على ألوان الثيم
    function withAlpha(col, a) {
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    Component.onCompleted: {
        EventBus.emit(Events.CLOSE_LEFTBAR);
        x = (Screen.width - width) / 2;
        y = (Screen.height - height) / 2;
        card.scale = theme.dimensions.dialogInitialScale;
        card.opacity = 0;
        openAnim.start();
        closeDelay.restart();
    }

    Timer {
        id: closeDelay
        interval: 150
        repeat: false
        onTriggered: {
            root.ready = true;
            root.fetchProcessDetail();
        }
    }

    onTargetPidChanged: fetchProcessDetail()

    function fetchProcessDetail() {
        if (!root.ready)
            return;
        root.isLoading = true;
        root.rawBuffer = "";
        detailProcess.command = [...App.scripts.python.systemDiagnosticsCommand, "--action", "process_detail", "--pid", String(targetPid)];
        detailProcess.running = false;
        detailProcess.running = true;
    }

    property bool isLoading: true
    property string rawBuffer: ""
    property var detail: ({
            name: "",
            pid: 0,
            status: "",
            username: "",
            create_time: "",
            cpu_percent: 0,
            memory_percent: 0,
            memory_rss_mb: 0,
            memory_vms_mb: 0,
            exe: "",
            cmdline: "",
            cwd: "",
            num_threads: 0,
            ppid: 0,
            parent_name: "",
            children: []
        })

    function statusColor() {
        var s = root.detail.status || "";
        if (s === "running")
            return theme.colors.tertiary;
        if (s === "sleeping")
            return theme.colors.primary;
        if (s === "zombie")
            return theme.colors.error;
        return theme.colors.onSurfaceVariant;
    }

    function statusIcon() {
        var s = root.detail.status || "";
        if (s === "running")
            return "󰐊";
        if (s === "sleeping")
            return "󰒲";
        if (s === "zombie")
            return "󰚌";
        return "󰣆";
    }

    function formatBytes(mb) {
        if (mb >= 1024)
            return (mb / 1024).toFixed(1) + " GB";
        return mb.toFixed(1) + " MB";
    }

    function copyToClipboard(text) {
        copyProc.command = ["wl-copy", text];
        copyProc.running = false;
        copyProc.running = true;
    }

    Process {
        id: copyProc
        command: ["wl-copy"]
        running: false
    }

    Process {
        id: detailProcess
        command: []
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var trimmed = data.trim();
                if (trimmed.length > 0)
                    root.rawBuffer += trimmed;
            }
        }
        stderr: SplitParser {
            onRead: data => console.error("ProcessDetail error:", data)
        }
        onExited: (code, status) => {
            if (rawBuffer.length > 0) {
                try {
                    detail = JSON.parse(rawBuffer);
                } catch (e) {
                    console.error("ProcessDetail parse error:", e.message);
                }
            }
            rawBuffer = "";
            isLoading = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: card
            property: "scale"
            to: 1.0
            duration: theme.dimensions.dialogOpenScaleDuration
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 1.0
            duration: theme.dimensions.dialogOpenOpacityDuration
            easing.type: Easing.OutQuad
        }
    }

    // ─── Scrim (Background Overlay) ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.withAlpha(theme.colors.scrim, 0.60) // استخدام scrim من الثيم
        MouseArea {
            anchors.fill: parent
            onClicked: if (root.ready)
                root.close()
        }
    }

    // ─── Main M3 Dialog Card ────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        // anchors.margins: 24
        // radius: theme.dimensions.shapeFull
        color: theme.colors.surfaceContainer

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        // زر الإغلاق العائم
        Rectangle {
            z: 10
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16
            width: theme.dimensions.iconButtonSize
            height: theme.dimensions.iconButtonSize
            radius: theme.dimensions.iconButtonRadius
            color: closeMouse.containsMouse ? theme.colors.errorContainer : theme.colors.surfaceContainerHighest

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 14
                font.bold: true
                color: closeMouse.containsMouse ? theme.colors.onErrorContainer : theme.colors.onSurfaceVariant
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ─── M3 Prominent Header ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                color: "transparent"

                // خلفية متدرجة تعتمد على حالة العملية
                Rectangle {
                    anchors.fill: parent
                    color: root.isLoading ? theme.colors.surfaceContainerHigh : root.withAlpha(root.statusColor(), 0.08)

                    // إخفاء الزوايا السفلية لدمج الهيدر
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: theme.dimensions.shapeFull
                        color: parent.color
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20

                    // أيقونة التطبيق/العملية
                    Rectangle {
                        width: theme.dimensions.dialogIconSize
                        height: theme.dimensions.dialogIconSize
                        radius: theme.dimensions.shapeExtraLarge
                        color: root.isLoading ? theme.colors.surfaceContainerHighest : root.withAlpha(root.statusColor(), 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: root.isLoading ? "󰔛" : root.statusIcon()
                            font.family: theme.typography.iconFont
                            font.pixelSize: 36
                            color: root.isLoading ? theme.colors.onSurfaceVariant : root.statusColor()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: root.isLoading ? "Loading Data..." : (root.detail.name || "Unknown Process")
                            font.pixelSize: theme.typography.heading2Size
                            font.bold: true
                            color: theme.colors.onSurface
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // M3 Chips
                        RowLayout {
                            spacing: 8

                            M3Chip {
                                icon: "󰆼"
                                text: "PID: " + (root.detail.pid || root.targetPid)
                                bgColor: theme.colors.surfaceContainerHighest
                                fgColor: theme.colors.onSurfaceVariant
                            }

                            M3Chip {
                                visible: !root.isLoading && !!root.detail.status
                                icon: "󰐊"
                                text: String(root.detail.status).charAt(0).toUpperCase() + String(root.detail.status).slice(1)
                                bgColor: root.withAlpha(root.statusColor(), 0.15)
                                fgColor: root.statusColor()
                            }

                            M3Chip {
                                visible: !root.isLoading && root.detail.username
                                icon: ""
                                text: root.detail.username
                                bgColor: theme.colors.surfaceContainerHighest
                                fgColor: theme.colors.onSurfaceVariant
                            }
                        }
                    }
                }
            }

            // ─── States (Loading / Error) ───────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.isLoading || (!root.isLoading && !!root.detail.error)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    BusyIndicator {
                        visible: root.isLoading
                        Layout.alignment: Qt.AlignHCenter
                        width: 56
                        height: 56
                    }

                    Text {
                        visible: !root.isLoading && !!root.detail.error
                        text: "󰀦"
                        font.family: theme.typography.iconFont
                        font.pixelSize: 48
                        color: theme.colors.error
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.isLoading ? "Analyzing Process..." : (root.detail.error || "Unknown Error")
                        font.pixelSize: theme.typography.medium
                        color: root.isLoading ? theme.colors.onSurfaceVariant : theme.colors.error
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // ─── Content Area (Safe ScrollView) ─────────────────────────────
            Item {
                id: scrollContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.isLoading && !root.detail.error
                Layout.margins: 12

                Flickable {
                    id: contentFlick
                    anchors.fill: parent
                    anchors.rightMargin: 16 // مساحة آمنة لشريط التمرير دون أخطاء Padding
                    contentWidth: width
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: contentCol
                        width: contentFlick.width
                        spacing: 16

                        // مساحة الإحصائيات (Stat Cards)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            M3StatCard {
                                Layout.fillWidth: true
                                title: "CPU Usage"
                                value: (root.detail.cpu_percent || 0).toFixed(1) + "%"
                                icon: "󰍛"
                                highlightColor: theme.colors.tertiary
                            }
                            M3StatCard {
                                Layout.fillWidth: true
                                title: "Memory (RSS)"
                                value: root.formatBytes(root.detail.memory_rss_mb || 0)
                                subValue: (root.detail.memory_percent || 0).toFixed(1) + "%"
                                icon: "󰘚"
                                highlightColor: theme.colors.primary
                            }
                            M3StatCard {
                                Layout.fillWidth: true
                                title: "Threads"
                                value: String(root.detail.num_threads || 0)
                                icon: "󰓷"
                                highlightColor: theme.colors.secondary
                            }
                        }

                        // قائمة التفاصيل (M3 List)
                        M3ListContainer {
                            title: "Execution Details"
                            icon: "󰜎"

                            M3DetailRow {
                                label: "Command Line"
                                value: root.detail.cmdline || "N/A"
                                icon: "󰞷"
                                isCopyable: true
                            }
                            M3DetailRow {
                                label: "Executable Path"
                                value: root.detail.exe || "N/A"
                                icon: "󰝰"
                                isCopyable: true
                            }
                            M3DetailRow {
                                label: "Working Directory"
                                value: root.detail.cwd || "N/A"
                                icon: "󰉖"
                                isCopyable: true
                                showDivider: false
                            }
                        }

                        // التدرج الهرمي
                        M3ListContainer {
                            title: "Process Tree"
                            icon: ""
                            visible: !!root.detail.ppid || (root.detail.children && root.detail.children.length > 0)

                            M3DetailRow {
                                visible: !!root.detail.ppid
                                label: "Parent Process"
                                value: (root.detail.parent_name || "Unknown") + " (PID: " + (root.detail.ppid || 0) + ")"
                                icon: "󰁝"
                                showDivider: root.detail.children && root.detail.children.length > 0
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: childrenLayout.implicitHeight + 16
                                visible: root.detail.children && root.detail.children.length > 0

                                ColumnLayout {
                                    id: childrenLayout
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    Text {
                                        text: "Child Processes (" + root.detail.children.length + ")"
                                        font.pixelSize: theme.typography.small
                                        font.bold: true
                                        color: theme.colors.onSurfaceVariant
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: root.detail.children
                                            delegate: M3Chip {
                                                icon: "󰠭"
                                                text: modelData.name + " (" + modelData.pid + ")"
                                                bgColor: theme.colors.secondaryContainer
                                                fgColor: theme.colors.onSecondaryContainer
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.preferredHeight: 16
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // M3 Components
    // ─────────────────────────────────────────────────────────────────────────

    component M3Chip: Rectangle {
        property string text: ""
        property string icon: ""
        property color bgColor: "transparent"
        property color fgColor: theme.colors.onSurfaceVariant

        height: theme.dimensions.chipHeight
        implicitWidth: chipRow.implicitWidth + 24
        radius: theme.dimensions.shapeSmall
        color: bgColor

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: parent.icon !== ""
                text: icon
                font.family: theme.typography.iconFont
                font.pixelSize: 14
                color: fgColor
            }
            Text {
                text: parent.parent.text
                font.pixelSize: theme.typography.small
                font.bold: true
                color: fgColor
            }
        }
    }

    component M3StatCard: Rectangle {
        property string title: ""
        property string value: ""
        property string subValue: ""
        property string icon: ""
        property color highlightColor: theme.colors.primary

        height: theme.dimensions.statCardHeight
        radius: theme.dimensions.statCardRadius
        color: theme.colors.surfaceContainerHighest // أغمق قليلاً من البطاقة لتمييزها

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 4

            RowLayout {
                spacing: 8
                Rectangle {
                    width: theme.dimensions.chipHeight
                    height: theme.dimensions.chipHeight
                    radius: theme.dimensions.shapeSmall
                    color: root.withAlpha(highlightColor, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: icon
                        font.family: theme.typography.iconFont
                        font.pixelSize: 14
                        color: highlightColor
                    }
                }
                Text {
                    text: title
                    font.pixelSize: theme.typography.small
                    color: theme.colors.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                spacing: 8
                Text {
                    text: value
                    font.pixelSize: theme.typography.heading3Size
                    font.bold: true
                    color: theme.colors.onSurface
                }
                Text {
                    visible: subValue !== ""
                    text: subValue
                    font.pixelSize: theme.typography.small
                    color: theme.colors.onSurfaceVariant
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 2
                }
            }
        }
    }

    component M3ListContainer: Rectangle {
        property string title: ""
        property string icon: ""
        default property alias content: contentArea.data

        Layout.fillWidth: true
        implicitHeight: layout.implicitHeight
        radius: theme.dimensions.shapeExtraLarge
        color: theme.colors.surfaceContainerLow

        ColumnLayout {
            id: layout
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 12
                Text {
                    text: icon
                    font.family: theme.typography.iconFont
                    font.pixelSize: 18
                    color: theme.colors.primary
                }
                Text {
                    text: title
                    font.pixelSize: theme.typography.medium
                    font.bold: true
                    color: theme.colors.primary
                }
            }

            ColumnLayout {
                id: contentArea
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    component M3DetailRow: Item {
        property string label: ""
        property string value: ""
        property string icon: "󰍉"
        property bool isCopyable: false
        property bool showDivider: true

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 24

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16

            Text {
                text: icon
                font.family: theme.typography.iconFont
                font.pixelSize: 20
                color: root.withAlpha(theme.colors.onSurfaceVariant, 0.7)
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: label
                    font.pixelSize: theme.typography.small
                    color: theme.colors.onSurfaceVariant
                }
                Text {
                    text: value
                    font.pixelSize: theme.typography.small
                    color: theme.colors.onSurface
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                    maximumLineCount: 5
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: isCopyable && value !== "N/A"
                width: theme.dimensions.iconButtonSize
                height: theme.dimensions.iconButtonSize
                radius: theme.dimensions.iconButtonRadius
                color: copyMouse.containsMouse ? root.withAlpha(theme.colors.primary, 0.1) : "transparent"
                Layout.alignment: Qt.AlignTop

                Text {
                    id: copyIcon
                    anchors.centerIn: parent
                    text: ""
                    font.family: theme.typography.iconFont
                    font.pixelSize: 16
                    color: theme.colors.primary
                }
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.copyToClipboard(value);
                        copyIcon.text = "";
                        copyReset.start();
                    }
                }
                Timer {
                    id: copyReset
                    interval: 1500
                    onTriggered: copyIcon.text = ""
                }
            }
        }

        Rectangle {
            visible: showDivider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 56
            height: 1
            color: theme.colors.outlineVariant // استخدام outlineVariant كفاصل
        }
    }
}
