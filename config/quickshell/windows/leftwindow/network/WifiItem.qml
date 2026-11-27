import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/themes"
import "root:/components"
import "root:/components/settings"

Item {
    id: root

    width: parent.width
    // implicitHeight: mainColumn.implicitHeight
    height: expanded ? mainColumn.implicitHeight : infoContainer.height
    clip: true

    property int collapsedHeight: 70
    property int expandedHeight: 200

    property string ssid: "SSID"
    property string bssid: "00:00:00:00:00:00"
    property int signal: 0
    property string security: "None"
    property bool in_use: false
    property bool is_saved: false
    property bool expanded: false
    property bool isLoading: false
    property int innerRadiusDiv: 4

    signal itemToggled
    signal connectClicked(string ssid, string password)
    signal disconnectClicked(string ssid)
    signal forgetClicked(string ssid)

    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        radius: ThemeManager.selectedTheme.dimensions.elementRadius

        color: {
            if (root.expanded)
                return ThemeManager.selectedTheme.colors.primary;
            if (infoArea.containsMouse)
                return ThemeManager.selectedTheme.colors.secondary.alpha(0.15);
            if (root.in_use)
                return ThemeManager.selectedTheme.colors.primary.alpha(0.3);
            return "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: ThemeManager.selectedTheme.dimensions.spacingMedium + 5

        spacing: 12

        /* استبدل infoContainer بالنسخة التالية */
        Item {
            id: infoContainer
            Layout.fillWidth: true
            implicitHeight: infoGrid.implicitHeight

            GridLayout {
                id: infoGrid
                anchors.fill: parent
                columns: 3
                columnSpacing: 12
                rowSpacing: 0

                // ----- عمود ثابت للأيقونة (مساحة محجوزة دائماً) -----
                Item {
                    Layout.column: 0
                    Layout.preferredWidth: 48
                    Layout.minimumWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter

                    Label {
                        id: signalIcon
                        anchors.centerIn: parent
                        // font.family: "Symbols Nerd Font"    // إذا تحب تستبدلها بصور: استخدم Image
                        font.family: ThemeManager.selectedTheme.typography.iconFont
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.onSurfaceVariant
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        text: {
                            const isLocked = root.security !== "None";
                            if (root.signal > 75)
                                return isLocked ? "󰤪" : "󰤨";
                            if (root.signal > 50)
                                return isLocked ? "󰤧" : "󰤥";
                            if (root.signal > 25)
                                return isLocked ? "󰤤" : "󰤢";
                            if (root.signal > 0)
                                return isLocked ? "󱛋" : "󰤟";
                            return isLocked ? "󰤬" : "󰤯";
                        }
                    }
                }

                // ----- العمود الأوسط القابل للتمدد للنصوص -----
                ColumnLayout {
                    Layout.column: 1
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: ThemeManager.selectedTheme.dimensions.spacingSmall
                    Layout.bottomMargin: ThemeManager.selectedTheme.dimensions.spacingSmall

                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Text {
                            id: ssidText
                            Layout.fillWidth: true
                            text: root.ssid
                            font.bold: true
                            font.pixelSize: 16
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            // textDirection: Qt.LeftToRight          // <<< مهم: يجبر بداية النص من اليسار
                            color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.onSurfaceVariant
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        Text {
                            text: root.in_use ? qsTr(" (Connected)") : ""
                            visible: root.in_use
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            // textDirection: Qt.LeftToRight
                            color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Text {
                            id: securityText
                            visible: root.security !== "None"
                            text: root.security
                            font.pixelSize: 12
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignLeft
                            // textDirection: Qt.LeftToRight
                            color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary.alpha(0.8) : ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.7)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        Text {
                            id: bssidText
                            text: root.bssid
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignLeft
                            // textDirection: Qt.LeftToRight
                            color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary.alpha(0.8) : ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.7)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }
                }

                // ----- عمود ثابت للأيقونة الثانوية (المحفوظ) - المساحة محفوظة دائماً -----
                Item {
                    Layout.column: 2
                    Layout.preferredWidth: 48
                    Layout.minimumWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter

                    /* نغيّر opacity بدلاً من visible لكي لا تنهار المساحة */
                    Label {
                        id: savedIcon
                        anchors.centerIn: parent
                        // font.family: "Symbols Nerd Font"
                        font.family: ThemeManager.selectedTheme.typography.iconFont
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        color: root.expanded ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.primary
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        text: "󱣫"
                        opacity: (root.is_saved && !root.in_use) ? 1.0 : 0.0
                        // keep enabled false when not used if you rely على enabled elsewhere
                    }
                }
            }

            MouseArea {
                id: infoArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.itemToggled()
            }
        }

        Item {
            id: controlsWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: controlsColumn.implicitHeight * expandProgress
            Layout.bottomMargin: (ThemeManager.selectedTheme.dimensions.spacingMedium + 5) * expandProgress
            clip: true
            opacity: expandProgress
            visible: expandProgress > 0

            property real expandProgress: (root.expanded && !root.isLoading) ? 1 : 0

            Behavior on expandProgress {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: controlsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 12
                enabled: controlsWrapper.expandProgress > 0.99

                EditableField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password ... ")
                    echoMode: TextInput.Password
                    visible: root.security !== "None" && !root.in_use && !root.is_saved
                    font.pixelSize: 14
                    color: ThemeManager.selectedTheme.colors.onPrimary
                    placeholderTextColor: ThemeManager.selectedTheme.colors.onPrimary.alpha(0.6)
                    background: Rectangle {
                        color: ThemeManager.selectedTheme.colors.onPrimary.alpha(0.1)
                        radius: ThemeManager.selectedTheme.dimensions.elementRadius
                        border.color: ThemeManager.selectedTheme.colors.onPrimary.alpha(0.5)
                        border.width: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    MButton {
                        Layout.fillWidth: true
                        text: root.is_saved || root.in_use ? qsTr("Forget") : qsTr("Cancel")
                        topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / root.innerRadiusDiv
                        bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / root.innerRadiusDiv
                        onClicked: {
                            if (root.is_saved || root.in_use) {
                                root.forgetClicked(root.ssid);
                            } else {
                                root.itemToggled();
                            }
                        }
                    }

                    MButton {
                        Layout.fillWidth: true
                        text: root.in_use ? qsTr("Disconnect") : qsTr("Connect")
                        normalBackground: ThemeManager.selectedTheme.colors.primary
                        normalForeground: ThemeManager.selectedTheme.colors.onPrimary
                        topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / root.innerRadiusDiv
                        bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / root.innerRadiusDiv
                        onClicked: {
                            if (root.in_use) {
                                root.disconnectClicked(root.ssid);
                            } else {
                                root.connectClicked(root.ssid, passwordField.text);
                            }
                        }
                        enabled: root.in_use || root.is_saved || root.security === "None" || (passwordField.visible && passwordField.text.length > 0)
                    }
                }
            }
        }

        BusyIndicator {
            Layout.fillWidth: true
            Layout.fillHeight: true
            running: root.expanded && root.isLoading
            visible: running
        }
    }
}
