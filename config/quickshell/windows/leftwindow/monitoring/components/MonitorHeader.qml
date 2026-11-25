import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import "root:/themes"
import "root:/components"

Item {
    id: headerRoot

    // =========================================================================
    //  Public Properties
    // =========================================================================
    property var theme: ThemeManager.selectedTheme
    property string title: "AI System Analysis"
    property string statusText: "AI AGENT ACTIVE"
    property string statusIcon: "󱚣"
    property bool isDetailsOpen: false

    property color statusColor: _colors.tertiary
    property color statusTextColor: _colors.onSurface
    property color statusBgColor: _colors.surfaceContainerHigh

    // =========================================================================
    //  Internal Helpers (Clean Code & Performance)
    // =========================================================================
    // اختصارات للوصول السريع للثيم ومنع التكرار في الأسفل
    readonly property var _colors: theme?.colors
    readonly property var _dims: theme?.dimensions
    readonly property var _typo: theme?.typography

    readonly property bool isDarkMode: theme?.systemSettings?.themeMode === "dark"

    // ثوابت التصميم المحسوبة مسبقاً
    readonly property color aiColorStart: _colors.primary
    readonly property color aiColorEnd: _colors.secondary
    readonly property real mainRadius: _dims.elementRadius
    readonly property real hSpacing: _dims.spacingLarge * 1.5

    // =========================================================================
    //  Signals
    // =========================================================================
    signal toggleDetailsClicked

    // =========================================================================
    //  Layout Configuration
    // =========================================================================
    Layout.fillWidth: true
    Layout.preferredHeight: 64

    // 1. Background
    Rectangle {
        anchors.fill: parent
        color: _colors.primaryContainer
        opacity: isDarkMode ? 0.8 : 0.9

        // التعامل مع الحواف: دائرية من الأعلى ومربعة من الأسفل
        radius: mainRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        // الفاصل السفلي
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: parent.color // نفس لون الخلفية لدمج الحافة
        }
    }

    // 2. Main Content
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: hSpacing
        anchors.rightMargin: hSpacing
        spacing: _dims.spacingMedium

        // --- AI Icon Section ---
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: _dims.shapeMedium

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: headerRoot.aiColorStart
                }
                GradientStop {
                    position: 1.0
                    color: headerRoot.aiColorEnd
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                // shadowColor: palette.shadow
                shadowColor: theme.colors.shadow.alpha(0.6)
                shadowBlur: 0.6
                shadowOpacity: isDarkMode ? 0.5 : 0.3
            }

            Text {
                anchors.centerIn: parent
                text: headerRoot.statusIcon
                font.family: _typo.iconFont
                font.pixelSize: 22
                color: _colors.onPrimary
            }
        }

        // --- Info Section ---
        ColumnLayout {
            spacing: 2

            Text {
                text: headerRoot.title
                color: _colors.onPrimaryContainer
                font.pixelSize: 16
                font.weight: Font.Bold
            }

            RowLayout {
                spacing: 6

                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: statusTextItem.implicitWidth + 28
                    radius: _dims.shapeSmall
                    color: headerRoot.statusBgColor

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 8
                            height: 8
                            radius: _dims.shapeExtraSmall
                            color: headerRoot.statusColor
                        }

                        Text {
                            id: statusTextItem
                            text: headerRoot.statusText
                            color: headerRoot.statusTextColor
                            font.pixelSize: 11
                            font.letterSpacing: 1.1
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // --- Spacer ---
        Item {
            Layout.fillWidth: true
        }

        // --- Action Button ---
        MButton {
            id: terminalButton
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            text: ""
            cursorShape: Qt.PointingHandCursor
            font.family: ThemeManager.selectedTheme.typography.iconFont // أو استخدام _typo إذا كان متاحاً
            isActive: headerRoot.isDetailsOpen

            onClicked: headerRoot.toggleDetailsClicked()

            ToolTip.visible: hovered
            ToolTip.text: "Open Terminal Logs"
            ToolTip.delay: 500
        }
    }
}
