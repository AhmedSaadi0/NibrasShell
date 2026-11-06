// windows/leftwindow/monitoring/components/EventAnalysis.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/themes"

ColumnLayout {
    id: root

    property bool isExpanded: false
    property bool isLoading: false
    property string aiTitle: ""
    property int aiConfidence: 0
    property string aiNarrative: ""
    property string aiRootCause: ""
    property string aiProcessName: ""
    property string aiProcessBehavior: ""
    property string aiThermalRisk: ""
    property string aiThermalDetails: ""
    property var actionsModel: []

    // [Phase 5 — additive adapter fields | §13]
    property string adapterStatus: "ANALYSIS_UNVERIFIED"
    property string verificationStatus: ""
    property var verificationReasons: []
    property string verificationScope: ""
    property string runtimeDomain: ""
    property string eventTransport: ""
    property var identityLimits: []
    property var uncertainties: []
    property var missingEvidence: []
    property var evidenceRows: []
    property var validationReasons: []

    readonly property var theme: ThemeManager.selectedTheme

    readonly property var uncertaintyRows: {
        var rows = [];
        for (var i = 0; i < identityLimits.length; i++)
            rows.push({ label: "Identity limit", text: identityLimits[i] });
        for (var j = 0; j < uncertainties.length; j++)
            rows.push({ label: "Uncertainty", text: uncertainties[j] });
        for (var k = 0; k < missingEvidence.length; k++)
            rows.push({ label: "Missing evidence", text: missingEvidence[k] });
        for (var m = 0; m < validationReasons.length; m++)
            rows.push({ label: "Validation reason", text: validationReasons[m] });
        if (verificationStatus !== "")
            rows.push({ label: "Verification status", text: verificationStatus });
        for (var n = 0; n < verificationReasons.length; n++)
            rows.push({ label: "Verification reason", text: verificationReasons[n] });
        if (verificationScope !== "")
            rows.push({ label: "Verification scope", text: verificationScope });
        return rows;
    }

    function statusColor() {
        if (adapterStatus === "GUIDANCE_VALIDATED")
            return theme.colors.tertiary;
        if (adapterStatus === "POLICY_REJECTED")
            return theme.colors.error;
        if (adapterStatus === "ANALYSIS_UNVERIFIED")
            return theme.colors.secondary;
        return theme.colors.onSurfaceVariant;
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

    // ألوان مقروءة: تُعمَّق في الوضع الفاتح
    readonly property color accentTertiary: theme.systemSettings.themeMode == "dark" ? theme.colors.tertiary : theme.colors.tertiary.darker(1.6)
    readonly property color accentSecondary: theme.systemSettings.themeMode == "dark" ? theme.colors.secondary : theme.colors.secondary.darker(1.6)
    readonly property color narrativeColor: theme.systemSettings.themeMode == "dark" ? Qt.lighter(theme.colors.onSurfaceVariant, 1.4) : theme.colors.onSurfaceVariant.darker(1.2)
    readonly property color actionTextColor: theme.systemSettings.themeMode == "dark" ? Qt.lighter(theme.colors.onSurfaceVariant, 1.3) : theme.colors.onSurfaceVariant.darker(1.1)

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    clip: true
    enabled: isExpanded
    opacity: isExpanded ? 1 : 0
    Layout.preferredHeight: isExpanded ? -1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 300
        }
    }

    Item {
        Layout.preferredHeight: 12
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
    }

    Item {
        Layout.preferredHeight: 12
    }

    // --- العنوان والثقة ---
    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 8

        Text {
            text: ""
            font.family: theme.typography.iconFont
            color: root.accentTertiary
            font.pixelSize: 16
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: isLoading ? qsTr("Analyzing...") : aiTitle
            font.pixelSize: theme.typography.small + 2
            font.bold: true
            color: root.accentSecondary
            elide: Text.ElideRight
        }

        Rectangle {
            visible: !isLoading && aiConfidence > 0
            width: 64
            height: 10
            radius: theme.dimensions.shapeSmall
            color: Qt.rgba(theme.colors.primary.r, theme.colors.primary.g, theme.colors.primary.b, 0.18)
            border.color: theme.colors.primary
            border.width: 1

            Rectangle {
                width: (aiConfidence / 100) * parent.width
                height: parent.height
                radius: theme.dimensions.shapeSmall
                color: theme.colors.primary
            }

            Text {
                anchors.centerIn: parent
                text: aiConfidence + "%"
                font.pixelSize: 9
                font.bold: true
                color: theme.colors.primary
                z: 1
            }
        }
    }

    // --- Runtime metadata (evidence context, never an approval) ---
    // The adapter status and metadata chips wrap as a group so narrow cards
    // never push the event analysis past the timeline width.
    Flow {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.topMargin: 6
        spacing: 6
        visible: root.adapterStatus !== "" || root.runtimeDomain !== "" || root.eventTransport !== ""

        Rectangle {
            visible: root.adapterStatus !== ""
            height: 16
            radius: 8
            width: adapterLabel.implicitWidth + 10
            color: Qt.rgba(root.statusColor().r, root.statusColor().g, root.statusColor().b, 0.16)
            border.color: Qt.rgba(root.statusColor().r, root.statusColor().g, root.statusColor().b, 0.45)
            border.width: 1

            Text {
                id: adapterLabel
                anchors.centerIn: parent
                text: root.adapterStatus
                font.pixelSize: 8
                font.bold: true
                color: root.statusColor()
            }
        }

        Rectangle {
            visible: root.runtimeDomain !== ""
            height: 16
            radius: 8
            width: domainChip.implicitWidth + 10
            color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
            border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.35)
            border.width: 1
            Text {
                id: domainChip
                anchors.centerIn: parent
                text: root.runtimeDomain
                font.pixelSize: 8
                color: theme.colors.onSurfaceVariant
            }
        }

        Rectangle {
            visible: root.eventTransport !== ""
            height: 16
            radius: 8
            width: transportChip.implicitWidth + 10
            color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
            border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.35)
            border.width: 1
            Text {
                id: transportChip
                anchors.centerIn: parent
                text: root.eventTransport
                font.pixelSize: 8
                color: theme.colors.onSurfaceVariant
            }
        }
    }

    Item {
        Layout.preferredHeight: 10
    }

    // --- السرد التحليلي ---
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 6

        Text {
            text: qsTr("Forensic Analysis — model-authored, unverified")
            font.pixelSize: theme.typography.small - 1
            font.bold: true
            color: theme.colors.onSurfaceVariant
            opacity: 0.7
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: isLoading ? qsTr("Gathering data from system logs...") : aiNarrative
            wrapMode: Text.WordWrap
            font.family: theme.typography.bodyFont
            font.pixelSize: theme.typography.small + 1
            color: root.narrativeColor
            lineHeight: 1.3
            textFormat: Text.PlainText
        }
    }

    Item {
        Layout.preferredHeight: 12
    }

    // --- السبب الجذري + العملية + التأثير الحراري (لوحة موحدة) ---
    EventInsightPanel {
        Layout.fillWidth: true
        isLoading: root.isLoading
        rootCause: root.aiRootCause
        processName: root.aiProcessName
        processBehavior: root.aiProcessBehavior
        thermalRisk: root.aiThermalRisk
        thermalDetails: root.aiThermalDetails
    }

    Item {
        Layout.preferredHeight: 12
    }

    // --- Uncertainty / identity limits (explicit, never an approved fix) ---
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 6
        visible: root.uncertaintyRows.length > 0

        Text {
            text: qsTr("UNCERTAINTY / IDENTITY LIMITS")
            font.pixelSize: theme.typography.small - 1
            font.bold: true
            color: root.accentSecondary
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
                    font.pixelSize: theme.typography.small - 1
                    font.bold: true
                    color: theme.colors.onSurfaceVariant
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData.text
                    wrapMode: Text.WordWrap
                    font.pixelSize: theme.typography.small - 1
                    color: root.narrativeColor
                    textFormat: Text.PlainText
                }
            }
        }
    }

    Item {
        Layout.preferredHeight: 12
    }

    // --- Evidence rows (backend/incident supplied) ---
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 6
        visible: root.evidenceRows.length > 0

        Text {
            text: qsTr("EVIDENCE")
            font.pixelSize: theme.typography.small - 1
            font.bold: true
            color: root.accentTertiary
        }

        Repeater {
            model: root.evidenceRows

            delegate: Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "• " + root.evidenceText(modelData)
                wrapMode: Text.WordWrap
                font.pixelSize: theme.typography.small - 1
                color: root.narrativeColor
                textFormat: Text.PlainText
            }
        }
    }

    Item {
        Layout.preferredHeight: 12
    }

    // --- الإجراءات المقترحة ---
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 6

        Text {
            text: qsTr("Model-suggested considerations — unverified")
            font.pixelSize: theme.typography.small - 1
            font.bold: true
            color: root.accentTertiary
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: actionsModel.length > 0
            text: qsTr("These are model-authored strings, not backend-validated guidance. Nothing here is copyable or executed.")
            font.pixelSize: theme.typography.small - 2
            color: theme.colors.onSurfaceVariant
            wrapMode: Text.WordWrap
            opacity: 0.75
        }

        Repeater {
            model: isLoading ? [] : actionsModel

            delegate: RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: theme.dimensions.shapeSmall
                    color: Qt.rgba(root.accentTertiary.r, root.accentTertiary.g, root.accentTertiary.b, 0.18)
                    border.color: root.accentTertiary
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 11
                        color: root.accentTertiary
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: modelData
                    wrapMode: Text.WordWrap
                    font.pixelSize: theme.typography.small + 1
                    color: root.actionTextColor
                    textFormat: Text.PlainText
                }
            }
        }

        Text {
            visible: isLoading || actionsModel.length === 0
            text: isLoading ? qsTr("Generating recommendations...") : qsTr("No specific actions required.")
            font.pixelSize: theme.typography.small
            color: theme.colors.onSurfaceVariant
            opacity: 0.7
        }
    }

    Item {
        Layout.preferredHeight: 8
    }
}
