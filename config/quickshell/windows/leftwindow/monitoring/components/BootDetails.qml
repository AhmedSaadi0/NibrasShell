// windows/leftwindow/monitoring/components/BootDetails.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services"
import "root:/config"

Item {
    id: bootRoot
    property var theme
    property bool isOpen: false

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredHeight: isOpen ? mainLayout.implicitHeight + 30 : 0
    clip: true

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: 350
            easing.type: Easing.InOutQuint
        }
    }

    // الألوان بناءً على حالة الـ AI
    readonly property color themeStatusColor: {
        var s = SystemService.bootStatusColor; // سيتحسس QML أي تغيير هنا
        if (!s || s === "")
            return bootRoot.theme.colors.tertiary;
        if (s.startsWith("#"))
            return s;
        if (s === "red")
            return bootRoot.theme.colors.error;
        if (s === "orange" || s === "yellow")
            return bootRoot.theme.colors.secondary;
        if (s === "green")
            return bootRoot.theme.colors.tertiary;
        return bootRoot.theme.colors.info || bootRoot.theme.colors.primary;
    }

    readonly property color statusBgColor: Qt.rgba(themeStatusColor.r, themeStatusColor.g, themeStatusColor.b, bootRoot.theme.systemSettings.themeMode == "dark" ? 0.18 : 0.12)
    readonly property color statusBorderColor: Qt.rgba(themeStatusColor.r, themeStatusColor.g, themeStatusColor.b, bootRoot.theme.systemSettings.themeMode == "dark" ? 0.35 : 0.25)
    readonly property color statusTitleColor: bootRoot.theme.systemSettings.themeMode == "dark" ? themeStatusColor.lighter(1.25) : themeStatusColor.darker(1.6)
    readonly property color statusTextColor: bootRoot.theme.colors.onSurface
    readonly property color statusMutedColor: Qt.rgba(statusTitleColor.r, statusTitleColor.g, statusTitleColor.b, 0.85)

    // لون عناوين الأقسام (مثل Suggested Fixes): يُعمَّق في الوضع الفاتح ليُقرأ بوضوح
    readonly property color sectionHeaderColor: bootRoot.theme.systemSettings.themeMode == "dark" ? bootRoot.theme.colors.tertiary : bootRoot.theme.colors.tertiary.darker(1.6)

    function logDomain(item) {
        if (!item)
            return "";
        if (typeof item.domain === "string" && item.domain !== "")
            return item.domain;
        if (typeof item.runtime_domain === "string" && item.runtime_domain !== "")
            return item.runtime_domain;
        return "";
    }

    function toolDecisionColor(status) {
        if (status === "TOOL_REQUEST_ALLOWED")
            return bootRoot.theme.colors.tertiary;
        if (status === "POLICY_REJECTED")
            return bootRoot.theme.colors.error;
        return bootRoot.theme.colors.onSurfaceVariant;
    }

    function toolDecisionText(decision) {
        if (!decision)
            return "";
        var tool = decision.tool || "unknown tool";
        var requestId = decision.request_id ? " · " + decision.request_id : "";
        var reasons = Array.isArray(decision.reasons) && decision.reasons.length > 0
            ? " · " + decision.reasons.join(", ")
            : "";
        return tool + requestId + reasons;
    }

    Rectangle {
        anchors.fill: parent
        color: bootRoot.theme.systemSettings.themeMode == "dark" ? bootRoot.theme.colors.surfaceContainerHigh.lighter(1.3) : bootRoot.theme.colors.surfaceContainerHigh.darker(1.1)
    }

    // A positioner is used here instead of a ColumnLayout: sections appear and
    // disappear as backend data arrives, and explicit child widths keep the
    // panel stable across dynamic menu-width changes.
    Column {
        id: mainLayout
        x: 12
        y: 12
        width: Math.max(0, bootRoot.width - 24)
        height: implicitHeight
        spacing: 15
        enabled: bootRoot.isOpen
        opacity: bootRoot.height > 20 ? 1 : 0

        // --- Box Summary ---
        Rectangle {
            width: mainLayout.width
            implicitHeight: summaryRow.implicitHeight + 20
            color: bootRoot.statusBgColor
            border.color: bootRoot.statusBorderColor
            radius: bootRoot.theme.dimensions.shapeSmall

            RowLayout {
                id: summaryRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Text {
                    text: SystemService.bootStatusIcon || ""
                    font.family: bootRoot.theme.typography.iconFont
                    font.pixelSize: 22
                    color: bootRoot.statusTitleColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: qsTr("MODEL INTERPRETATION — NOT VERIFIED")
                        color: bootRoot.statusMutedColor
                        font.pixelSize: bootRoot.theme.typography.small - 3
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: SystemService.bootStatusTitle || "Analyzing..."
                        color: bootRoot.statusTitleColor
                        font.bold: true
                        font.pixelSize: bootRoot.theme.typography.small
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: SystemService.aiBootSummary || "Waiting for system logs analysis..."
                        color: bootRoot.statusTextColor
                        font.pixelSize: bootRoot.theme.typography.small - 1
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // --- Expandable Log Cards ---
        ColumnLayout {
            width: mainLayout.width
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 6

                Text {
                    text: qsTr("OBSERVED LOGS")
                    font.pixelSize: bootRoot.theme.typography.small - 2
                    font.bold: true
                    color: bootRoot.sectionHeaderColor
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("Captured evidence; not approval.")
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    font.pixelSize: bootRoot.theme.typography.small - 3
                    color: bootRoot.theme.colors.onSurfaceVariant
                    opacity: 0.7
                }
            }

            Repeater {
                model: SystemService.bootLogsModel
                delegate: Item {
                    id: logDelegate
                    property bool isExpanded: false

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: collapsedRow.implicitHeight + (isExpanded ? expandedBox.implicitHeight + 12 : 0) + 12
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // Card background
                    Rectangle {
                        anchors.fill: parent
                        radius: bootRoot.theme.dimensions.shapeExtraSmall
                        color: {
                            if (isExpanded && bootRoot.themeStatusColor) {
                                var c = bootRoot.themeStatusColor;
                                return Qt.rgba(c.r, c.g, c.b, bootRoot.theme.systemSettings.themeMode == "dark" ? 0.15 : 0.08);
                            }
                            return logHover.containsMouse ? bootRoot.theme.colors.onSurface.alpha(0.04) : "transparent";
                        }
                        border.color: isExpanded ? Qt.rgba(bootRoot.themeStatusColor.r, bootRoot.themeStatusColor.g, bootRoot.themeStatusColor.b, 0.25) : "transparent"
                        border.width: isExpanded ? 1 : 0

                        Behavior on color {
                            ColorAnimation {
                                duration: 250
                            }
                        }
                    }

                    ColumnLayout {
                        id: logCardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 6

                        // --- Collapsed Row (always visible) ---
                        RowLayout {
                            id: collapsedRow
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 8

                            // Expand/collapse arrow icon
                            Text {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                text: logDelegate.isExpanded ? "" : ""
                                font.family: bootRoot.theme.typography.iconFont
                                font.pixelSize: 12
                                color: bootRoot.statusMutedColor

                                Behavior on text {
                                    SequentialAnimation {
                                        PropertyAction {} // force initial
                                    }
                                }
                            }

                            // Summary text
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Text {
                                    id: processName
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: `<b>${modelData.process}</b>`
                                    color: bootRoot.theme.colors.onSurfaceVariant
                                    font.family: "Monospace"
                                    font.pixelSize: bootRoot.theme.typography.small - 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: shortMessage
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: modelData.message || ""
                                    color: bootRoot.theme.colors.onSurfaceVariant
                                    font.pixelSize: bootRoot.theme.typography.small - 3
                                    font.family: "Monospace"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: logDelegate.isExpanded ? 100 : 2
                                    elide: Text.ElideRight
                                    opacity: logDelegate.isExpanded ? 0.6 : 1.0
                                }
                            }

                            // Domain tag (Phase 5 additive field; absent is fine)
                            Rectangle {
                                visible: bootRoot.logDomain(modelData) !== ""
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                height: 16
                                width: domainLabel.implicitWidth + 10
                                radius: 8
                                color: Qt.rgba(bootRoot.theme.colors.onSurfaceVariant.r, bootRoot.theme.colors.onSurfaceVariant.g, bootRoot.theme.colors.onSurfaceVariant.b, 0.12)
                                border.color: Qt.rgba(bootRoot.theme.colors.onSurfaceVariant.r, bootRoot.theme.colors.onSurfaceVariant.g, bootRoot.theme.colors.onSurfaceVariant.b, 0.35)
                                border.width: 1

                                Text {
                                    id: domainLabel
                                    anchors.centerIn: parent
                                    text: bootRoot.logDomain(modelData)
                                    font.pixelSize: bootRoot.theme.typography.small - 3
                                    color: bootRoot.theme.colors.onSurfaceVariant
                                }
                            }
                        }

                        // --- Expanded Raw Details Box (animated) ---
                        Rectangle {
                            id: expandedBox
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.leftMargin: 20
                            implicitHeight: rawLogText.implicitHeight + 14
                            radius: bootRoot.theme.dimensions.shapeExtraSmall
                            visible: logDelegate.isExpanded
                            opacity: logDelegate.isExpanded ? 1 : 0
                            color: bootRoot.theme.colors.surface.alpha(bootRoot.theme.systemSettings.themeMode == "dark" ? 0.35 : 0.06)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            // Observed log text is evidence, not guidance. It stays
                            // plain text so the only copy path in the diagnostics UI
                            // is validated backend guidance in CommandBox.
                            Text {
                                id: rawLogText
                                anchors.fill: parent
                                anchors.margins: 7
                                text: modelData.raw_details || modelData.time + " " + modelData.process + ": " + (modelData.message || "")
                                color: bootRoot.theme.colors.onSurfaceVariant
                                font.family: "Monospace"
                                font.pixelSize: bootRoot.theme.typography.small - 2
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    // Click to expand/collapse
                    MouseArea {
                        id: logHover
                        z: -1
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: logDelegate.isExpanded = !logDelegate.isExpanded
                    }
                }
            }
        }

        // === Solutions Section ===
        ColumnLayout {
            width: mainLayout.width
            spacing: 8
            visible: SystemService.bootSolutionsModel.length > 0
                || SystemService.bootSolutionStatus === "LOADING"
                || SystemService.bootSolutionStatus === "ERROR"

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(bootRoot.theme.colors.onSurfaceVariant.r, bootRoot.theme.colors.onSurfaceVariant.g, bootRoot.theme.colors.onSurfaceVariant.b, 0.15)
            }

            // Section header
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 6

                Text {
                    text: ""
                    font.family: bootRoot.theme.typography.iconFont
                    font.pixelSize: 14
                    color: bootRoot.sectionHeaderColor
                }

                Text {
                    text: SystemService.bootSolutionAdapter === "diagnosis" ? qsTr("Diagnostic Guidance") : qsTr("Suggested Fixes")
                    font.pixelSize: bootRoot.theme.typography.small
                    font.bold: true
                    color: bootRoot.sectionHeaderColor
                }

                Item {
                    Layout.fillWidth: true
                }

                // Loading indicator
                Text {
                    visible: SystemService.bootSolutionStatus === "LOADING"
                    text: qsTr("Generating solutions...")
                    font.pixelSize: bootRoot.theme.typography.small - 2
                    color: bootRoot.theme.colors.onSurfaceVariant
                    opacity: 0.6
                }

                // Solution count
                Text {
                    visible: SystemService.bootSolutionStatus === "SUCCESS"
                    text: SystemService.bootSolutionsModel.length + " item" + (SystemService.bootSolutionsModel.length !== 1 ? "s" : "")
                    font.pixelSize: bootRoot.theme.typography.small - 2
                    color: bootRoot.theme.colors.onSurfaceVariant
                    opacity: 0.6
                }
            }

            // Adapter label gets its own muted line so the section title and
            // loading/count state always fit at the default menu width.
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: SystemService.bootSolutionAdapter !== "none"
                text: SystemService.bootSolutionAdapter === "diagnosis"
                    ? "nibras.diagnosis/v1"
                    : "LEGACY ADAPTER"
                font.pixelSize: bootRoot.theme.typography.small - 3
                color: bootRoot.theme.colors.onSurfaceVariant
                opacity: 0.75
                elide: Text.ElideRight
            }

            // Solutions loading
            Rectangle {
                visible: SystemService.bootSolutionStatus === "LOADING"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 40
                radius: bootRoot.theme.dimensions.shapeExtraSmall
                color: Qt.rgba(bootRoot.theme.colors.primary.r, bootRoot.theme.colors.primary.g, bootRoot.theme.colors.primary.b, 0.06)
                border.color: Qt.rgba(bootRoot.theme.colors.primary.r, bootRoot.theme.colors.primary.g, bootRoot.theme.colors.primary.b, 0.15)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    // Spinner animation
                    Text {
                        id: spinnerIcon
                        text: ""
                        font.family: bootRoot.theme.typography.iconFont
                        font.pixelSize: 14
                        color: bootRoot.theme.colors.primary

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1200
                            loops: Animation.Infinite
                            running: SystemService.bootSolutionStatus === "LOADING"
                        }
                    }

                    Text {
                        text: qsTr("Analyzing issues and generating fixes...")
                        font.pixelSize: bootRoot.theme.typography.small - 1
                        color: bootRoot.theme.colors.onSurfaceVariant
                        opacity: 0.7
                    }
                }
            }

            // Solutions list
            Repeater {
                model: SystemService.bootSolutionStatus === "LOADING" ? [] : SystemService.bootSolutionsModel

                delegate: SolutionCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    solutionId: modelData.id || ""
                    relatedLog: modelData.related_log || ""
                    solutionTitle: modelData.title || ""
                    difficulty: modelData.difficulty || ""
                    priority: modelData.priority || ""
                    description: modelData.description || ""
                    whyThisWorks: modelData.why_this_works || ""
                    steps: modelData.steps || []
                    diagnosisData: modelData
                }
            }

            // Error state
            Rectangle {
                visible: SystemService.bootSolutionStatus === "ERROR"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 36
                radius: bootRoot.theme.dimensions.shapeExtraSmall
                color: Qt.rgba(bootRoot.theme.colors.error.r, bootRoot.theme.colors.error.g, bootRoot.theme.colors.error.b, 0.08)
                border.color: Qt.rgba(bootRoot.theme.colors.error.r, bootRoot.theme.colors.error.g, bootRoot.theme.colors.error.b, 0.2)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: ""
                        font.family: bootRoot.theme.typography.iconFont
                        font.pixelSize: 12
                        color: bootRoot.theme.colors.error
                    }

                    Text {
                        text: qsTr("Failed to generate solutions")
                        font.pixelSize: bootRoot.theme.typography.small - 1
                        color: bootRoot.theme.colors.error
                        opacity: 0.8
                    }
                }
            }
        }

        // === Separate read-only tool decisions ===
        // Tool statuses are not guidance statuses. This section is deliberately
        // separate so TOOL_REQUEST_ALLOWED can never be read as an approved fix.
        ColumnLayout {
            width: mainLayout.width
            spacing: 6
            visible: SystemService.bootToolDecisions.length > 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(bootRoot.theme.colors.onSurfaceVariant.r, bootRoot.theme.colors.onSurfaceVariant.g, bootRoot.theme.colors.onSurfaceVariant.b, 0.15)
            }

            Text {
                text: qsTr("Read-only inspection decisions")
                font.pixelSize: bootRoot.theme.typography.small
                font.bold: true
                color: bootRoot.sectionHeaderColor
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: qsTr("Separate from guidance decisions; a tool allowance never authorizes remediation.")
                font.pixelSize: bootRoot.theme.typography.small - 2
                color: bootRoot.theme.colors.onSurfaceVariant
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: SystemService.bootToolDecisions

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: toolDecisionLayout.implicitHeight + 12
                    radius: bootRoot.theme.dimensions.shapeExtraSmall
                    color: Qt.rgba(bootRoot.toolDecisionColor(modelData.status).r, bootRoot.toolDecisionColor(modelData.status).g, bootRoot.toolDecisionColor(modelData.status).b, 0.08)
                    border.color: Qt.rgba(bootRoot.toolDecisionColor(modelData.status).r, bootRoot.toolDecisionColor(modelData.status).g, bootRoot.toolDecisionColor(modelData.status).b, 0.25)
                    border.width: 1

                    ColumnLayout {
                        id: toolDecisionLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: bootRoot.toolDecisionText(modelData)
                            font.pixelSize: bootRoot.theme.typography.small - 2
                            font.family: "Monospace"
                            color: bootRoot.toolDecisionColor(modelData.status)
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: modelData.status !== ""
                            text: modelData.status
                            font.pixelSize: bootRoot.theme.typography.small - 3
                            font.bold: true
                            color: bootRoot.toolDecisionColor(modelData.status)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
