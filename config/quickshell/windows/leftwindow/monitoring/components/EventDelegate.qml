// windows/leftwindow/monitoring/components/EventDelegate.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "root:/themes"
import "root:/components"

Item {
    id: delegateRoot
    width: parent ? parent.width : 400
    // الارتفاع الكلي للعنصر يتبع ارتفاع الكرت
    height: contentContainer.height

    property string eventId
    property string eventType
    property string eventValue
    property string eventSeverity
    property string eventTime
    property string aiText
    property string aiModelName: "System AI"
    property bool isLoading: false
    property bool isExpanded: false

    // --- حقول جديدة للتحليل المفصل ---
    property string aiTitle: ""
    property string aiNarrative: ""
    property string aiRootCause: ""
    property int aiConfidence: 0
    property string aiThermalRisk: ""
    property string aiThermalDetails: ""
    property string aiProcessName: ""
    property string aiProcessBehavior: ""
    property var aiActions: []

    // [Phase 5 — additive adapter fields | §13]
    property string aiAdapterStatus: "ANALYSIS_UNVERIFIED"
    property string aiVerificationStatus: ""
    property var aiVerificationReasons: []
    property string aiVerificationScope: ""
    property string aiRuntimeDomain: ""
    property string aiEventTransport: ""
    property var aiIdentityLimits: []
    property var aiUncertainties: []
    property var aiMissingEvidence: []
    property var aiEvidence: []
    property var aiValidationReasons: []

    function getActionsArray() {
        const type = Array.isArray(aiActions) ? "Array" : typeof aiActions;

        console.info("aiActions Value: " + JSON.stringify(aiActions));
        console.info("aiActions Type: " + type);
        console.info("Is Array: " + Array.isArray(aiActions));

        try {
            if (!aiActions || aiActions === "")
                return [];
            if (Array.isArray(aiActions))
                return aiActions;
            return JSON.parse(aiActions);
        } catch (e) {
            return [];
        }
    }

    signal expandRequested

    readonly property var theme: ThemeManager.selectedTheme
    property bool isCritical: eventSeverity === "CRITICAL"
    property color stateColor: {
        if (eventSeverity === "CRITICAL")
            return theme.colors.error;
        if (eventSeverity === "WARNING")
            return theme.colors.secondary;
        return theme.colors.tertiary;
    }

    // --- Timeline Line ---
    Rectangle {
        id: timelineLine
        width: 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: 28
        color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.2)
        z: 1
    }

    // --- Timeline Dot ---
    Rectangle {
        id: timelineDot
        width: 14
        height: 14
        radius: theme.dimensions.elementRadius
        x: 22
        y: 22
        z: 5
        color: theme.colors.surfaceContainerHigh
        border.width: 2
        border.color: stateColor
        layer.enabled: isCritical
        layer.effect: Shadow {}
    }

    // --- Main Card Content ---
    Rectangle {
        id: contentContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 48
        anchors.rightMargin: 12

        // الحساب الدقيق للارتفاع: الارتفاع الضمني للمحتوى + الهوامش
        height: mainLayout.implicitHeight + 20

        // أنيميشن الارتفاع (يجعل الكرت ينزلق بسلاسة)
        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        color: isExpanded ? theme.colors.surfaceContainer : Qt.rgba(theme.colors.surfaceContainer.r, theme.colors.surfaceContainer.g, theme.colors.surfaceContainer.b, 0.35)
        radius: theme.dimensions.elementRadius
        border.color: isExpanded ? theme.colors.primary : Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.2)
        border.width: 1
        clip: true

        ColumnLayout {
            id: mainLayout
            // نستخدم anchors لربط العرض فقط، والارتفاع يُترك للـ implicitHeight
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.leftMargin: 14
            spacing: 0

            // 1. Header Row
            EventHeader {
                Layout.fillWidth: true
                eventType: delegateRoot.eventType
                eventValue: delegateRoot.eventValue
                eventSeverity: delegateRoot.eventSeverity
                eventTime: delegateRoot.eventTime
                isExpanded: delegateRoot.isExpanded
                stateColor: delegateRoot.stateColor
                adapterStatus: delegateRoot.aiAdapterStatus
            }

            // 2. AI Analysis Section (القسم القابل للتمدد - مفصل)
            EventAnalysis {
                Layout.fillWidth: true
                isExpanded: delegateRoot.isExpanded
                isLoading: delegateRoot.isLoading
                aiTitle: delegateRoot.aiTitle
                aiConfidence: delegateRoot.aiConfidence
                aiNarrative: delegateRoot.aiNarrative
                aiRootCause: delegateRoot.aiRootCause
                aiProcessName: delegateRoot.aiProcessName
                aiProcessBehavior: delegateRoot.aiProcessBehavior
                aiThermalRisk: delegateRoot.aiThermalRisk
                aiThermalDetails: delegateRoot.aiThermalDetails
                actionsModel: delegateRoot.getActionsArray()
                adapterStatus: delegateRoot.aiAdapterStatus
                verificationStatus: delegateRoot.aiVerificationStatus
                verificationReasons: delegateRoot.aiVerificationReasons
                verificationScope: delegateRoot.aiVerificationScope
                runtimeDomain: delegateRoot.aiRuntimeDomain
                eventTransport: delegateRoot.aiEventTransport
                identityLimits: delegateRoot.aiIdentityLimits
                uncertainties: delegateRoot.aiUncertainties
                missingEvidence: delegateRoot.aiMissingEvidence
                evidenceRows: delegateRoot.aiEvidence
                validationReasons: delegateRoot.aiValidationReasons
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: delegateRoot.expandRequested()
        }
    }
}
