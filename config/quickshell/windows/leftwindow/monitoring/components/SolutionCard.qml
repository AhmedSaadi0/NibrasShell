// windows/leftwindow/monitoring/components/SolutionCard.qml

import QtQuick
import QtQuick.Layouts
import "root:/themes"

Rectangle {
    id: root

    property string solutionId: ""
    property string relatedLog: ""
    property string solutionTitle: ""
    property string difficulty: ""
    property string priority: ""
    property string description: ""
    property string whyThisWorks: ""
    property var steps: []

    // [Phase 5 — explicit adapters | §13]
    // `diagnosisData` is the normalized adapter record from BootAnalyzer.qml.
    // Legacy consumers can keep passing the individual properties above.
    property var diagnosisData: ({})
    property bool isExpanded: false

    readonly property var record: (diagnosisData && typeof diagnosisData === "object") ? diagnosisData : ({})
    readonly property string adapter: (record.adapter === "diagnosis" || record.schema_version === "nibras.diagnosis/v1") ? "diagnosis" : "legacy"
    readonly property bool isDiagnosisAdapter: adapter === "diagnosis"
    readonly property string validationStatus: typeof record.validation_status === "string" ? record.validation_status : ""
    readonly property var validationReasons: Array.isArray(record.validation_reasons) ? record.validation_reasons : []
    readonly property string verificationStatus: typeof record.verification_status === "string" ? record.verification_status : ""
    readonly property var verificationReasons: Array.isArray(record.verification_reasons) ? record.verification_reasons : []
    readonly property string verificationScope: {
        if (typeof record.verification_time_scope === "string")
            return record.verification_time_scope;
        if (record.verification && typeof record.verification === "object" && typeof record.verification.time_scope === "string")
            return record.verification.time_scope;
        return "";
    }
    readonly property string runtimeDomain: typeof record.runtime_domain === "string" ? record.runtime_domain : ""
    readonly property string eventTransport: typeof record.event_transport === "string" ? record.event_transport : ""
    readonly property var identityLimits: Array.isArray(record.identity_limits) ? record.identity_limits : []
    readonly property var uncertainties: Array.isArray(record.uncertainties) ? record.uncertainties : []
    readonly property var missingEvidence: Array.isArray(record.missing_evidence) ? record.missing_evidence : []
    readonly property var evidenceRows: Array.isArray(record.evidence) ? record.evidence : []
    readonly property var guidanceLines: Array.isArray(record.guidance_lines) ? record.guidance_lines : []
    readonly property var findings: Array.isArray(record.findings) ? record.findings : []
    readonly property var possibleCauses: Array.isArray(record.possible_causes) ? record.possible_causes : []
    readonly property var diagnosticQuestions: Array.isArray(record.diagnostic_questions) ? record.diagnostic_questions : []
    readonly property string confidenceNote: typeof record.confidence_note === "string" ? record.confidence_note : ""

    // Copy is possible only for backend-authored text whose artifact-level
    // decision is GUIDANCE_VALIDATED. Policy rejection, analysis-only output,
    // legacy model commands, and missing status are all non-copyable.
    readonly property bool canCopyGuidance: isDiagnosisAdapter && validationStatus === "GUIDANCE_VALIDATED" && guidanceLines.length > 0
    readonly property bool hasUncertainty: identityLimits.length > 0 || uncertainties.length > 0 || missingEvidence.length > 0 || verificationReasons.length > 0 || verificationScope !== ""

    readonly property var theme: ThemeManager.selectedTheme

    readonly property var uncertaintyRows: {
        var rows = [];
        for (var i = 0; i < identityLimits.length; i++)
            rows.push({ label: "Identity limit", text: identityLimits[i] });
        for (var j = 0; j < uncertainties.length; j++)
            rows.push({ label: "Uncertainty", text: uncertainties[j] });
        for (var k = 0; k < missingEvidence.length; k++)
            rows.push({ label: "Missing evidence", text: missingEvidence[k] });
        for (var m = 0; m < verificationReasons.length; m++)
            rows.push({ label: "Verification reason", text: verificationReasons[m] });
        if (verificationScope !== "")
            rows.push({ label: "Verification scope", text: verificationScope });
        return rows;
    }

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: collapsedRow.implicitHeight + (isExpanded ? expandedContent.implicitHeight + 12 : 0) + 12

    radius: theme.dimensions.shapeExtraSmall
    color: isExpanded ? Qt.rgba(cardStatusColor().r, cardStatusColor().g, cardStatusColor().b, theme.systemSettings.themeMode == "dark" ? 0.12 : 0.06) : (hoverArea.containsMouse ? theme.colors.onSurface.alpha(0.04) : "transparent")
    border.color: isExpanded ? Qt.rgba(cardStatusColor().r, cardStatusColor().g, cardStatusColor().b, 0.3) : "transparent"
    border.width: isExpanded ? 1 : 0
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 280
            easing.type: Easing.InOutQuad
        }
    }

    function readableAccent(c) {
        return theme.systemSettings.themeMode == "dark" ? c : c.darker(1.6);
    }

    function unlabeled(value) {
        return (typeof value === "string" && value !== "" && value !== "null") ? value : "unlabeled";
    }

    function difficultyColor() {
        if (difficulty === "hard")
            return theme.colors.error;
        if (difficulty === "medium")
            return theme.colors.secondary;
        if (difficulty === "easy")
            return theme.colors.tertiary;
        return theme.colors.onSurfaceVariant;
    }

    function priorityColor() {
        if (priority === "critical")
            return theme.colors.error;
        if (priority === "important")
            return theme.colors.secondary;
        if (priority === "optional")
            return theme.colors.onSurfaceVariant;
        return theme.colors.onSurfaceVariant;
    }

    function statusLabel() {
        if (!isDiagnosisAdapter)
            return "QUARANTINED_LEGACY";
        return validationStatus !== "" ? validationStatus : "STATUS_ABSENT";
    }

    function cardStatusColor() {
        var status = statusLabel();
        if (status === "GUIDANCE_VALIDATED")
            return theme.colors.tertiary;
        if (status === "POLICY_REJECTED")
            return theme.colors.error;
        if (status === "ANALYSIS_UNVERIFIED" || status === "QUARANTINED_LEGACY")
            return theme.colors.secondary;
        return theme.colors.onSurfaceVariant;
    }

    function verificationColor() {
        if (verificationStatus === "VERIFIED")
            return theme.colors.tertiary;
        if (verificationStatus === "AMBIGUOUS")
            return theme.colors.secondary;
        if (verificationStatus === "UNAVAILABLE")
            return theme.colors.onSurfaceVariant;
        return theme.colors.onSurfaceVariant;
    }

    function stepsCountText() {
        if (guidanceLines.length > 0)
            return guidanceLines.length + " guidance line" + (guidanceLines.length > 1 ? "s" : "");
        if (steps && steps.length > 0)
            return steps.length + " step" + (steps.length > 1 ? "s" : "");
        return "No actionable text";
    }

    function hasRebootWarning() {
        if (!steps)
            return false;
        for (var i = 0; i < steps.length; i++) {
            if (steps[i].warning && steps[i].warning.toLowerCase().indexOf("reboot") !== -1)
                return true;
        }
        return false;
    }

    function evidenceText(item) {
        if (typeof item === "string")
            return item;
        if (!item || typeof item !== "object")
            return "";
        var parts = [];
        if (item.id)
            parts.push(item.id);
        if (item.origin)
            parts.push(item.origin);
        if (item.strength)
            parts.push(item.strength);
        if (item.desc)
            parts.push(item.desc);
        return parts.join(" · ");
    }

    function findingText(item) {
        if (!item || typeof item !== "object")
            return typeof item === "string" ? item : "";
        var severity = item.severity ? "[" + item.severity + "] " : "";
        return severity + (item.text || "");
    }

    function modelStepLabel(item) {
        if (!item || typeof item !== "object")
            return "";
        return item.label || "";
    }

    // --- Collapsed Row (always visible) ---
    ColumnLayout {
        id: collapsedRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 8

            // Expand arrow
            Text {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                text: root.isExpanded ? "" : ""
                font.family: theme.typography.iconFont
                font.pixelSize: 11
                color: theme.colors.onSurfaceVariant
                opacity: 0.6
            }

            // Badges wrap so narrow panels never clip a status or domain label.
            Flow {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                spacing: 4

                // Adapter/policy status — always visible when a card renders.
                Rectangle {
                    width: statusText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(cardStatusColor().r, cardStatusColor().g, cardStatusColor().b, 0.18)
                    border.color: Qt.rgba(readableAccent(cardStatusColor()).r, readableAccent(cardStatusColor()).g, readableAccent(cardStatusColor()).b, 0.4)
                    border.width: 1
                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.statusLabel()
                        font.pixelSize: 8
                        font.bold: true
                        color: readableAccent(root.cardStatusColor())
                    }
                }

                // Difficulty badge — absent field renders explicitly as unlabeled.
                Rectangle {
                    width: diffText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(difficultyColor().r, difficultyColor().g, difficultyColor().b, 0.18)
                    border.color: Qt.rgba(readableAccent(difficultyColor()).r, readableAccent(difficultyColor()).g, readableAccent(difficultyColor()).b, 0.4)
                    border.width: 1
                    Text {
                        id: diffText
                        anchors.centerIn: parent
                        text: root.unlabeled(root.difficulty).toUpperCase()
                        font.pixelSize: 8
                        font.bold: true
                        color: readableAccent(root.difficultyColor())
                    }
                }

                // Priority badge — absent field renders explicitly as unlabeled.
                Rectangle {
                    width: priText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(priorityColor().r, priorityColor().g, priorityColor().b, 0.18)
                    border.color: Qt.rgba(readableAccent(priorityColor()).r, readableAccent(priorityColor()).g, readableAccent(priorityColor()).b, 0.4)
                    border.width: 1
                    Text {
                        id: priText
                        anchors.centerIn: parent
                        text: root.unlabeled(root.priority).toUpperCase()
                        font.pixelSize: 8
                        font.bold: true
                        color: readableAccent(root.priorityColor())
                    }
                }

                // Backend verification outcome, shown verbatim.
                Rectangle {
                    visible: root.verificationStatus !== ""
                    width: verifyText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(verificationColor().r, verificationColor().g, verificationColor().b, 0.18)
                    border.color: Qt.rgba(readableAccent(verificationColor()).r, readableAccent(verificationColor()).g, readableAccent(verificationColor()).b, 0.4)
                    border.width: 1
                    Text {
                        id: verifyText
                        anchors.centerIn: parent
                        text: root.verificationStatus
                        font.pixelSize: 8
                        font.bold: true
                        color: readableAccent(root.verificationColor())
                    }
                }

                // Runtime domain / transport are evidence metadata, never a fix.
                Rectangle {
                    visible: root.runtimeDomain !== ""
                    width: domainText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
                    border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.35)
                    border.width: 1
                    Text {
                        id: domainText
                        anchors.centerIn: parent
                        text: root.runtimeDomain
                        font.pixelSize: 8
                        color: theme.colors.onSurfaceVariant
                    }
                }

                Rectangle {
                    visible: root.eventTransport !== ""
                    width: transportText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
                    border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.35)
                    border.width: 1
                    Text {
                        id: transportText
                        anchors.centerIn: parent
                        text: root.eventTransport
                        font.pixelSize: 8
                        color: theme.colors.onSurfaceVariant
                    }
                }
            }

            // Steps/guidance count
            Text {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                Layout.minimumWidth: 0
                Layout.maximumWidth: Math.max(0, Math.min(implicitWidth, root.width * 0.35))
                text: stepsCountText() + (hasRebootWarning() ? " · Reboot" : "")
                font.pixelSize: theme.typography.small - 3
                color: theme.colors.onSurfaceVariant
                opacity: 0.6
                elide: Text.ElideRight
            }
        }

        // Title
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 19
            text: root.solutionTitle
            font.pixelSize: theme.typography.small + 1
            font.bold: true
            color: theme.colors.onSurface
            elide: Text.ElideRight
        }

        // Description (collapsed only)
        Text {
            visible: !root.isExpanded
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 19
            text: root.description
            font.pixelSize: theme.typography.small - 1
            color: theme.colors.onSurfaceVariant
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            opacity: 0.95
            textFormat: Text.PlainText
        }
    }

    // --- Expanded Content ---
    ColumnLayout {
        id: expandedContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: collapsedRow.bottom
        anchors.leftMargin: 19
        anchors.rightMargin: 8
        spacing: 10
        enabled: root.isExpanded
        opacity: root.isExpanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(cardStatusColor().r, cardStatusColor().g, cardStatusColor().b, 0.2)
        }

        // Explicit adapter explanation — no status is inferred by the UI.
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.isDiagnosisAdapter
                ? qsTr("New Diagnosis Adapter — policy status is shown exactly as reported by the backend. No status implies execution.")
                : qsTr("Legacy Adapter — model-generated commands are quarantined; copy and manual selection are disabled.")
            font.pixelSize: theme.typography.small - 2
            color: readableAccent(root.cardStatusColor())
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }

        // Full description — model-authored analysis, never operational text.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.description !== ""

            Text {
                text: qsTr("MODEL ANALYSIS — UNVERIFIED")
                font.pixelSize: theme.typography.small - 2
                font.bold: true
                color: theme.colors.onSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.description
                font.pixelSize: theme.typography.small
                color: theme.colors.onSurface
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                textFormat: Text.PlainText
            }
        }

        // Why this works — explanation only, not verification.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.whyThisWorks !== ""

            Text {
                text: qsTr("MODEL EXPLANATION — NOT VERIFICATION")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: readableAccent(theme.colors.tertiary)
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.whyThisWorks
                font.pixelSize: theme.typography.small - 1
                color: theme.colors.onSurface
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                textFormat: Text.PlainText
            }
        }

        // Backend-rendered guidance. Copy is enabled only for a validated
        // nibras.diagnosis/v1 card; rejected/unverified text stays visible but
        // non-actionable.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 6
            visible: root.guidanceLines.length > 0

            Text {
                text: root.canCopyGuidance
                    ? qsTr("BACKEND GUIDANCE — VALIDATED TEXT")
                    : qsTr("BACKEND GUIDANCE — NOT COPYABLE")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: root.canCopyGuidance ? readableAccent(theme.colors.tertiary) : readableAccent(theme.colors.secondary)
            }

            Repeater {
                model: root.guidanceLines
                delegate: CommandBox {
                    Layout.fillWidth: true
                    command: modelData || ""
                    copyText: modelData || ""
                    copyLabel: "Copy backend guidance"
                    validated: root.canCopyGuidance
                    quarantineLabel: root.canCopyGuidance ? "" : "not copyable"
                }
            }
        }

        // Legacy/model steps are always quarantined. They are shown for
        // context only; no command execution path exists in this UI.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 6
            visible: root.steps.length > 0

            Text {
                text: qsTr("MODEL-PROPOSED STEPS — QUARANTINED")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: readableAccent(theme.colors.secondary)
            }

            Repeater {
                model: root.steps
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: root.modelStepLabel(modelData) !== ""
                        text: root.modelStepLabel(modelData)
                        font.pixelSize: theme.typography.small - 2
                        color: theme.colors.onSurfaceVariant
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }

                    CommandBox {
                        Layout.fillWidth: true
                        command: modelData.command || ""
                        warning: modelData.warning || ""
                        validated: false
                        quarantineLabel: root.isDiagnosisAdapter ? "unvalidated (model text)" : "unvalidated (legacy)"
                    }
                }
            }
        }

        // Evidence rows supplied by the backend/incident.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.evidenceRows.length > 0

            Text {
                text: qsTr("EVIDENCE")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: readableAccent(theme.colors.tertiary)
            }

            Repeater {
                model: root.evidenceRows
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "• " + root.evidenceText(modelData)
                    font.pixelSize: theme.typography.small - 2
                    color: theme.colors.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        // Model findings stay labeled as analysis.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.findings.length > 0

            Text {
                text: qsTr("MODEL FINDINGS — UNVERIFIED")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: theme.colors.onSurfaceVariant
            }

            Repeater {
                model: root.findings
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "• " + root.findingText(modelData)
                    font.pixelSize: theme.typography.small - 2
                    color: theme.colors.onSurface
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        // Optional model analysis details.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.possibleCauses.length > 0 || root.diagnosticQuestions.length > 0

            Text {
                text: qsTr("MODEL ANALYSIS DETAILS — UNVERIFIED")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: theme.colors.onSurfaceVariant
            }

            Repeater {
                model: root.possibleCauses
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "• Possible cause: " + modelData
                    font.pixelSize: theme.typography.small - 2
                    color: theme.colors.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }

            Repeater {
                model: root.diagnosticQuestions
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "• Diagnostic question: " + modelData
                    font.pixelSize: theme.typography.small - 2
                    color: theme.colors.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        // Rejected proposals must remain visible with their reasons.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.validationReasons.length > 0

            Text {
                text: qsTr("POLICY DECISION REASONS")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: readableAccent(root.cardStatusColor())
            }

            Repeater {
                model: root.validationReasons
                delegate: Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "• " + modelData
                    font.pixelSize: theme.typography.small - 2
                    color: root.readableAccent(root.cardStatusColor())
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        // Explicit uncertainty / identity limits.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4
            visible: root.hasUncertainty

            Text {
                text: qsTr("UNCERTAINTY / IDENTITY LIMITS")
                font.pixelSize: theme.typography.small - 1
                font.bold: true
                color: readableAccent(theme.colors.secondary)
            }

            Repeater {
                model: root.uncertaintyRows
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: modelData.label + ":"
                        font.pixelSize: theme.typography.small - 2
                        color: theme.colors.onSurfaceVariant
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.text
                        font.pixelSize: theme.typography.small - 2
                        color: theme.colors.onSurfaceVariant
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // Model confidence is not verification.
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: root.confidenceNote !== ""
            text: qsTr("Model confidence note (not verification): ") + root.confidenceNote
            font.pixelSize: theme.typography.small - 2
            color: theme.colors.onSurfaceVariant
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
    }

    // Click to expand/collapse
    MouseArea {
        id: hoverArea
        z: -1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.isExpanded = !root.isExpanded
    }
}
