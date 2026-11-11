// windows/leftwindow/monitoring/SystemMonitor.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/themes"
import "root:/services"

// استيراد المكونات المحلية
import "./components"

Item {
    id: root

    // --- Layout Properties ---
    Layout.fillWidth: true
    // جعل ارتفاع العنصر يساوي ارتفاع المحتوى الداخلي (ColumnLayout)
    implicitHeight: mainLayout.implicitHeight

    // --- Theme & Props ---
    readonly property var theme: ThemeManager.selectedTheme
    property string expandedEventId: ""
    property bool showBootDetails: false

    readonly property color bootStatusColor: {
        var s = SystemService.bootStatusColor || "";
        if (s.startsWith("#"))
            return s;
        if (s === "red")
            return root.theme.colors.error;
        if (s === "orange" || s === "yellow")
            return root.theme.colors.secondary;
        if (s === "green")
            return root.theme.colors.tertiary;
        if (SystemService.bootAnalysisStatus === "LOADING")
            return root.theme.colors.primary;
        return root.theme.colors.onSurfaceVariant;
    }

    readonly property string bootStatusText: {
        if (SystemService.bootAnalysisStatus === "LOADING")
            return "ANALYZING";
        if (SystemService.bootAnalysisStatus === "ERROR")
            return "ERROR";
        var s = SystemService.bootStatusColor || "";
        if (s === "red")
            return "CRITICAL";
        if (s === "orange" || s === "yellow")
            return "WARNING";
        if (s === "green")
            return "OPTIMAL";
        if (SystemService.bootAnalysisStatus === "SUCCESS")
            return "STATUS";
        return "WAITING";
    }

    readonly property string bootStatusIcon: {
        if (SystemService.bootAnalysisStatus === "LOADING")
            return "󰞌";
        if (SystemService.bootAnalysisStatus === "ERROR")
            return "";
        var s = SystemService.bootStatusColor || "";
        if (s === "red")
            return "";
        if (s === "orange" || s === "yellow")
            return "";
        if (s === "green")
            return "";
        return "󱚣";
    }

    readonly property color bootStatusTextColor: root.theme.colors.onPrimaryContainer
    readonly property color bootStatusBgColor: root.theme.colors.primaryContainer

    // --- Data Model ---
    readonly property var eventModel: AiAnalysisService.eventsModel

    // --- Main Container ---
    Rectangle {
        // نربط ارتفاع الخلفية بارتفاع المكون الكلي
        width: parent.width
        height: root.implicitHeight

        color: root.theme.colors.surfaceContainerHigh
        radius: root.theme.dimensions.elementRadius
        clip: true

        ColumnLayout {
            id: mainLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            // 1. Header
            MonitorHeader {
                Layout.fillWidth: true
                theme: root.theme
                title: "System Guard"
                statusText: root.bootStatusText
                statusColor: root.bootStatusColor
                statusTextColor: root.bootStatusTextColor
                statusBgColor: root.bootStatusBgColor
                statusIcon: root.bootStatusIcon
                isDetailsOpen: root.showBootDetails

                onToggleDetailsClicked: root.showBootDetails = !root.showBootDetails
            }

            // 2. Boot Details
            BootDetails {
                Layout.fillWidth: true
                theme: root.theme
                isOpen: root.showBootDetails
                // المكون BootDetails يجب أن يدعم تغيير implicitHeight بناءً على isOpen داخلياً
            }

            // 3. Timeline Area
            Item {
                id: timelineWrapper
                Layout.fillWidth: true

                // حساب الارتفاع بناءً على محتوى القائمة + الهوامش (top & bottom margins)
                implicitHeight: timelineList.contentHeight + (root.theme.dimensions.spacingLarge * 2)

                clip: true

                ListView {
                    id: timelineList
                    anchors.fill: parent

                    // الهوامش
                    anchors.topMargin: root.theme.dimensions.spacingLarge
                    anchors.bottomMargin: root.theme.dimensions.spacingLarge

                    spacing: root.theme.dimensions.spacingLarge

                    // تعطيل السكرول الداخلي ليعمل السكرول الخارجي في Main.qml
                    interactive: false

                    model: eventModel

                    // الـ ScrollBar الداخلي لم يعد ضرورياً إذا كنا نستخدم سكرول خارجي
                    // لكن يمكن تركه كديكور إذا أردت، وإن كان يفضل إخفاؤه لتجنب ازدواجية السكرول بار
                    // ScrollBar.vertical: null

                    delegate: EventDelegate {
                        width: timelineList.width

                        eventId: model.eventId
                        eventType: model.type
                        eventValue: model.value
                        eventSeverity: model.severity
                        eventTime: model.timestamp
                        aiText: model.aiAnalysis
                        isLoading: model.isLoading
                        aiModelName: model.aiModel

                        // الحقول الجديدة
                        aiTitle: model.aiTitle
                        aiNarrative: model.aiNarrative
                        aiRootCause: model.aiRootCause
                        aiConfidence: model.aiConfidence
                        aiThermalRisk: model.aiThermalRisk
                        aiThermalDetails: model.aiThermalDetails
                        aiProcessName: model.aiProcessName
                        aiProcessBehavior: model.aiProcessBehavior
                        aiActions: model.aiActions

                        // [Phase 5 — additive adapter fields | §13]
                        aiAdapterStatus: model.aiAdapterStatus || "ANALYSIS_UNVERIFIED"
                        aiVerificationStatus: model.aiVerificationStatus || ""
                        aiVerificationReasons: model.aiVerificationReasons || []
                        aiVerificationScope: model.aiVerificationScope || ""
                        aiRuntimeDomain: model.aiRuntimeDomain || ""
                        aiEventTransport: model.aiEventTransport || ""
                        aiIdentityLimits: model.aiIdentityLimits || []
                        aiUncertainties: model.aiUncertainties || []
                        aiMissingEvidence: model.aiMissingEvidence || []
                        aiEvidence: model.aiEvidence || []
                        aiValidationReasons: model.aiValidationReasons || []

                        isExpanded: root.expandedEventId === model.eventId

                        onExpandRequested: {
                            root.expandedEventId = (root.expandedEventId === model.eventId) ? "" : model.eventId;
                        }
                    }
                }
            }
        }
    }
}
