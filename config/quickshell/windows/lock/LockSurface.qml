// windows/lock/LockSurface.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "root:/components"
import "root:/config"
import "root:/themes"

WlSessionLockSurface {
    id: surface

    // Injected by LockService to avoid a QML import loop with root:/services.
    property QtObject service: null
    property QtObject systemService: null

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool validScreen: screen && screen.name !== "" && screen.width > 0 && screen.height > 0
    readonly property bool isPrimary: service && service.authScreenName === screenName
    readonly property string wallpaperPath: ThemeManager.getCurrentWallpaper() || ""
    readonly property bool wallpaperIsVideo: /\.(mp4|mkv|webm|avi|mov|flv)$/i.test(wallpaperPath)

    color: ThemeManager.selectedTheme.colors.surface

    function isModifier(key: int): bool {
        return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
            || key === Qt.Key_Meta || key === Qt.Key_AltGr || key === Qt.Key_CapsLock;
    }

    Item {
        anchors.fill: parent
        visible: validScreen
        focus: true

        // Primary may play the video wallpaper (muted); secondary surfaces use
        // a still/solid background so the same video is never decoded twice.
        MediaItem {
            id: backgroundMedia
            anchors.fill: parent
            source: (!wallpaperIsVideo || isPrimary) ? wallpaperPath : ""
            active: source !== "" && validScreen
            muted: true
            quality: "Low"

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.7
                blurMax: 32
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ThemeManager.selectedTheme.colors.surface.alpha(0.55)
        }

        HoverHandler {
            enabled: true
            onHoveredChanged: {
                if (hovered && service)
                    service.noteActivity("pointer");
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !isPrimary
            hoverEnabled: true
            z: 3
            onEntered: {
                service.noteActivity("pointer");
                service.switchAuthScreen(screenName);
            }
            onClicked: {
                service.noteActivity("pointer");
                service.switchAuthScreen(screenName);
            }
        }

        Keys.onPressed: event => {
            if (service)
                service.noteActivity("key");
            if (isPrimary || surface.isModifier(event.key))
                return;
            const key = event.key;
            const text = event.text;
            service.switchAuthScreen(screenName);
            Qt.callLater(() => service.forwardInput(key, text));
            event.accepted = true;
        }

        // ---------------- passive view ----------------
        ColumnLayout {
            anchors.centerIn: parent
            spacing: ThemeManager.selectedTheme.dimensions.spacingLarge
            visible: !isPrimary

            SystemClock {
                id: passiveClock
                precision: SystemClock.Minutes
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: passiveClock.date.toLocaleString(Qt.locale(), "hh:mm AP")
                color: ThemeManager.selectedTheme.colors.onSurface
                font.family: ThemeManager.selectedTheme.typography.bodyFont
                font.pixelSize: 72
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: passiveClock.date.toLocaleString(Qt.locale(), "dddd, dd MMMM yyyy")
                color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                font.family: ThemeManager.selectedTheme.typography.bodyFont
                font.pixelSize: ThemeManager.selectedTheme.typography.heading3Size
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: systemService && systemService.hasBattery
                text: systemService ? (systemService.batteryIcon + "  " + Math.round(systemService.batteryPercent) + "%") : ""
                color: ThemeManager.selectedTheme.colors.primary
                font.family: ThemeManager.selectedTheme.typography.iconFont
                font.pixelSize: ThemeManager.selectedTheme.typography.heading2Size
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Locked — click or type to move the login card here")
                color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                font.family: ThemeManager.selectedTheme.typography.bodyFont
                font.pixelSize: ThemeManager.selectedTheme.typography.medium
                opacity: 0.7
            }
        }

        // ---------------- primary auth card ----------------
        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: 340
            visible: isPrimary
            radius: ThemeManager.selectedTheme.dimensions.elementRadius
            color: ThemeManager.selectedTheme.colors.surfaceContainer.alpha(0.92)
            border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.35)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: ThemeManager.selectedTheme.dimensions.spacingMedium

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    Layout.alignment: Qt.AlignHCenter
                    radius: width / 2
                    color: ThemeManager.selectedTheme.colors.primaryContainer
                    clip: true

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: App.profilePicture
                            ? Qt.resolvedUrl(App.profilePicture)
                            : Qt.resolvedUrl(App.assetsPath + "/icons/profile-modified.png")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: App.username || qsTr("User")
                    color: ThemeManager.selectedTheme.colors.onSurface
                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                    font.pixelSize: ThemeManager.selectedTheme.typography.heading3Size
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: App.subtitle !== ""
                    text: App.subtitle
                    color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                    font.pixelSize: ThemeManager.selectedTheme.typography.medium
                }

                Controls.TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    echoMode: Controls.TextField.Password
                    placeholderText: qsTr("Password")
                    focus: true
                    maximumLength: 256
                    text: service ? service.passwordBuffer : ""
                    color: ThemeManager.selectedTheme.colors.onSurface
                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                    font.pixelSize: ThemeManager.selectedTheme.typography.medium
                    onTextEdited: {
                        service.noteActivity("key");
                        service.passwordBuffer = text;
                    }
                    onAccepted: {
                        service.noteActivity("key");
                        service.submitPassword();
                    }
                    background: Rectangle {
                        radius: ThemeManager.selectedTheme.dimensions.elementRadius
                        color: ThemeManager.selectedTheme.colors.surface
                        border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.45)
                        border.width: 1
                    }

                    Component.onCompleted: passwordField.forceActiveFocus()
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: service && service.lastError !== "" ? service.lastError : (service ? service.pamStatus : "")
                    color: service && service.lastError !== ""
                        ? ThemeManager.selectedTheme.colors.error
                        : ThemeManager.selectedTheme.colors.onSurfaceVariant
                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                    font.pixelSize: ThemeManager.selectedTheme.typography.small
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ThemeManager.selectedTheme.dimensions.spacingMedium

                    MButton {
                        Layout.fillWidth: true
                        text: qsTr("Unlock")
                        onClicked: {
                            service.noteActivity("pointer");
                            service.submitPassword();
                        }
                    }

                    MButton {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        onClicked: {
                            service.noteActivity("pointer");
                            service.pamAbort();
                        }
                    }
                }
            }
        }

        Connections {
            target: service
            function onPasswordFocusRequested(name: string) {
                if (name === screenName)
                    passwordField.forceActiveFocus();
            }
        }
    }
}
