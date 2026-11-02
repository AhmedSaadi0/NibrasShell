// windows/leftwindow/monitoring/components/CommandBox.qml

import QtQuick
import QtQuick.Layouts
import "root:/config"
import "root:/themes"

Rectangle {
    id: root

    property string command: ""
    property string warning: ""

    // [Phase 0 — احتواء أوامر النموذج الوراثية | docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md ‎§13، ‎§16.4]
    // في هذه المرحلة لا شيء يضع validated = true، لذا كل أمر وارد عبر السلوك القديم
    // يُعرض معزولاً: زر النسخ مخفي ومُعطَّل، والتحديد اليدوي (Ctrl+C) مقفول،
    // وشارة "unvalidated (legacy)" ظاهرة مكان الزر. المُهايئ الجديد (مرحلة 5)
    // وحده من يملأ validated بعد اعتماد العقد nibras.diagnosis/v1.
    property bool validated: false
    readonly property bool quarantined: !validated

    readonly property var theme: ThemeManager.selectedTheme

    // ألوان مميزة مقروءة: تُعمَّق في الوضع الفاتح
    readonly property color accentColor: theme.systemSettings.themeMode == "dark" ? theme.colors.tertiary : theme.colors.tertiary.darker(1.6)
    readonly property color warningColor: theme.systemSettings.themeMode == "dark" ? theme.colors.secondary : theme.colors.secondary.darker(1.6)

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 14

    radius: theme.dimensions.shapeExtraSmall
    color: Qt.rgba(theme.colors.surface.r, theme.colors.surface.g, theme.colors.surface.b, theme.systemSettings.themeMode == "dark" ? 0.45 : 0.08)
    border.color: Qt.rgba(theme.colors.onSurfaceVariant.r, theme.colors.onSurfaceVariant.g, theme.colors.onSurfaceVariant.b, 0.15)
    border.width: 1

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextEdit {
                id: commandText
                Layout.fillWidth: true
                text: root.command
                color: root.accentColor
                font.family: "Monospace"
                font.pixelSize: theme.typography.small - 1
                wrapMode: TextEdit.Wrap
                selectByMouse: root.validated
                readOnly: true
                selectionColor: root.accentColor
                selectedTextColor: theme.colors.onPrimary
            }

            Rectangle {
                visible: root.validated
                width: 24
                height: 24
                radius: theme.dimensions.shapeExtraSmall
                color: copyMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2) : "transparent"

                Text {
                    id: copyIcon
                    anchors.centerIn: parent
                    text: ""
                    font.family: theme.typography.iconFont
                    font.pixelSize: 13
                    color: root.accentColor
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.validated
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        App.dispatchCommand("Copy solution command", ["wl-copy", root.command]);
                        copyIcon.text = "";
                        copyResetTimer.start();
                    }
                }

                Timer {
                    id: copyResetTimer
                    interval: 1500
                    onTriggered: copyIcon.text = ""
                }
            }

            // [Phase 0] شارة العزل الظاهرة مكان زر النسخ للأوامر المعزولة.
            Rectangle {
                visible: root.quarantined
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 18
                Layout.preferredWidth: quarantineLabel.implicitWidth + 12
                radius: theme.dimensions.shapeExtraSmall
                color: "transparent"
                border.color: root.warningColor
                border.width: 1

                Text {
                    id: quarantineLabel
                    anchors.centerIn: parent
                    text: "unvalidated (legacy)"
                    color: root.warningColor
                    font.pixelSize: theme.typography.small - 3
                }
            }
        }

        Text {
            visible: root.warning !== "" && root.warning !== "null"
            Layout.fillWidth: true
            text: root.warning
            color: root.warningColor
            font.pixelSize: theme.typography.small - 2
            wrapMode: Text.WordWrap
            opacity: 0.9
        }
    }
}
