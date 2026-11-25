// windows/leftwindow/network/HiddenNetworkSection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "root:/themes"
import "root:/components"
import "root:/components/settings"

ColumnLayout {
    id: root

    signal connectRequested(string ssid, string password)

    Layout.fillWidth: true
    spacing: 0

    MButton {
        id: hiddenToggleBtn
        Layout.fillWidth: true
        text: qsTr("Connect to Hidden Network") + "  󰤨"
        normalBackground: hiddenNetworkContainer.isOpen ? ThemeManager.selectedTheme.colors.primary : ThemeManager.selectedTheme.colors.surfaceContainerHigh
        normalForeground: hiddenNetworkContainer.isOpen ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.onSurface
        onClicked: hiddenNetworkContainer.isOpen = !hiddenNetworkContainer.isOpen
    }

    Item {
        id: hiddenNetworkContainer
        Layout.fillWidth: true
        Layout.topMargin: isOpen ? 10 : 0
        property bool isOpen: false
        implicitHeight: isOpen ? contentRect.implicitHeight : 0
        clip: true
        opacity: isOpen ? 1.0 : 0.0

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on Layout.topMargin {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        Rectangle {
            id: contentRect
            width: parent.width
            implicitHeight: hiddenFormLayout.implicitHeight + 24
            color: ThemeManager.selectedTheme.colors.surfaceContainerHigh.alpha(0.5)
            radius: ThemeManager.selectedTheme.dimensions.elementRadius
            border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.2)
            border.width: 1

            ColumnLayout {
                id: hiddenFormLayout
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 12
                }
                spacing: 12

                EditableField {
                    id: hiddenSsidField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Network Name (SSID)")
                    font.pixelSize: 14
                    color: ThemeManager.selectedTheme.colors.onSurface
                    placeholderTextColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
                    background: Rectangle {
                        color: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                        radius: ThemeManager.selectedTheme.dimensions.elementRadius
                        border.color: ThemeManager.selectedTheme.colors.onSurface.alpha(0.1)
                        border.width: 1
                    }
                }

                EditableField {
                    id: hiddenPasswordField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password (Optional)")
                    echoMode: TextInput.Password
                    font.pixelSize: 14
                    color: ThemeManager.selectedTheme.colors.onSurface
                    placeholderTextColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
                    background: Rectangle {
                        color: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                        radius: ThemeManager.selectedTheme.dimensions.elementRadius
                        border.color: ThemeManager.selectedTheme.colors.onSurface.alpha(0.1)
                        border.width: 1
                    }
                }

                MButton {
                    Layout.fillWidth: true
                    text: qsTr("Connect")
                    normalBackground: ThemeManager.selectedTheme.colors.primary
                    normalForeground: ThemeManager.selectedTheme.colors.onPrimary
                    enabled: hiddenSsidField.text.length > 0
                    onClicked: {
                        root.connectRequested(hiddenSsidField.text, hiddenPasswordField.text);
                        hiddenSsidField.text = "";
                        hiddenPasswordField.text = "";
                        hiddenNetworkContainer.isOpen = false;
                    }
                }
            }
        }
    }
}
