// windows/leftwindow/monitoring/components/EventHeader.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/themes"

Item {
    id: root

    property string eventType
    property string eventValue
    property string eventSeverity
    property string eventTime
    property bool isExpanded: false
    property color stateColor

    // [Phase 5 — adapter label stays visible even when collapsed]
    property string adapterStatus: ""

    readonly property var theme: ThemeManager.selectedTheme

    function adapterStatusColor() {
        if (adapterStatus === "GUIDANCE_VALIDATED")
            return theme.colors.tertiary;
        if (adapterStatus === "POLICY_REJECTED")
            return theme.colors.error;
        if (adapterStatus === "ANALYSIS_UNVERIFIED")
            return theme.colors.secondary;
        return theme.colors.onSurfaceVariant;
    }

    implicitHeight: headerLayout.implicitHeight

    Layout.fillWidth: true
    Layout.minimumWidth: 0

    ColumnLayout {
        id: headerLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 12

            // Icon Box
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: theme.dimensions.elementRadius
                color: theme.colors.surfaceContainerHigh
                border.width: 1
                border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: (eventType === "CPU") ? "" : (eventType === "RAM") ? "" : (eventType === "TEMP") ? "" : ""
                    font.family: theme.typography.iconFont
                    font.pixelSize: 18
                    color: stateColor
                }
            }

            // Text Info
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: eventType + " Spike"
                    color: theme.colors.secondary
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.small + 2
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("Value") + ": " + eventValue
                    color: theme.colors.onSurfaceVariant
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.small + 1
                    wrapMode: Text.WordWrap
                }
            }

            // Time and Expand Icon
            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: eventTime
                    color: theme.colors.onSurfaceVariant
                    font.family: "Monospace"
                    font.pixelSize: theme.typography.small
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: ""
                    font.family: theme.typography.iconFont
                    font.pixelSize: 16
                    color: isExpanded ? theme.colors.primary : theme.colors.onSurfaceVariant
                    rotation: isExpanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 250
                        }
                    }
                }
            }
        }

        // Badges span the card below the header row so long adapter status
        // labels and severity chips can wrap without widening the timeline.
        Flow {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 52
            spacing: 6
            visible: adapterStatus !== "" || eventSeverity === "CRITICAL"

            Rectangle {
                visible: adapterStatus !== ""
                height: 18
                radius: theme.dimensions.shapeSmall
                color: Qt.rgba(adapterStatusColor().r, adapterStatusColor().g, adapterStatusColor().b, 0.16)
                border.color: Qt.rgba(adapterStatusColor().r, adapterStatusColor().g, adapterStatusColor().b, 0.45)
                border.width: 1
                width: adapterLabel.implicitWidth + 12
                Text {
                    id: adapterLabel
                    anchors.centerIn: parent
                    text: adapterStatus
                    color: adapterStatusColor()
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            Rectangle {
                visible: eventSeverity === "CRITICAL"
                height: 18
                radius: theme.dimensions.shapeSmall
                color: Qt.rgba(theme.colors.error.r, theme.colors.error.g, theme.colors.error.b, 0.18)
                border.color: Qt.rgba(theme.colors.error.r, theme.colors.error.g, theme.colors.error.b, 0.5)
                border.width: 1
                width: 54
                Text {
                    anchors.centerIn: parent
                    text: "CRITICAL"
                    color: theme.colors.error
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }
}
