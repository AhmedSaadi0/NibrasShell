// windows/lock/LockSurface.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland

import "root:/components"
import "root:/config"
import "root:/desktop"
import "root:/themes"

WlSessionLockSurface {
    id: root

    // Injected by LockService to avoid a QML import loop with root:/services.
    property QtObject service: null
    property QtObject systemService: null

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool validScreen: screen && screen.name !== "" && screen.width > 0 && screen.height > 0
    readonly property bool isPrimary: service && service.authScreenName === screenName

    // Same source of truth as Desktop.qml.
    property bool depthEnabled: false
    property string currentOverlay: ""
    readonly property bool depthActive: depthEnabled && currentOverlay !== ""

    property bool authCardVisible: false
    property bool pointerReady: false
    property bool frameExpanded: false
    property bool wasDpmsOff: false

    readonly property int sheetTopMargin: ThemeManager.selectedTheme.dimensions.barHeight + 3
    readonly property int sheetLeftMargin: ThemeManager.selectedTheme.dimensions.leftBarWidth + 2
    readonly property int sheetRightMargin: 5
    readonly property int sheetBottomMargin: 5

    readonly property real initialXScale: width > 0 ? (width - sheetLeftMargin - sheetRightMargin) / width : 1
    readonly property real initialYScale: height > 0 ? (height - sheetTopMargin - sheetBottomMargin) / height : 1
    readonly property real initialTranslateX: (sheetLeftMargin - sheetRightMargin) / 2
    readonly property real initialTranslateY: (sheetTopMargin - sheetBottomMargin) / 2

    color: ThemeManager.selectedTheme.colors.surface

    function isModifier(key: int): bool {
        return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
            || key === Qt.Key_Meta || key === Qt.Key_AltGr || key === Qt.Key_CapsLock;
    }

    function updateThemeData(): void {
        const clockSettings = ThemeManager.selectedTheme.desktopClock;
        const isDepth = (clockSettings && clockSettings.enabled && clockSettings.depthEffectEnabled) || false;
        root.depthEnabled = isDepth;
        root.currentOverlay = isDepth ? (clockSettings.depthOverlayPath || "") : "";
    }

    function revealAuthCard(source: string): void {
        const wasVisible = root.authCardVisible;
        root.authCardVisible = true;
        autoHideTimer.restart();
        if (!wasVisible && root.isPrimary)
            console.info("[LockSurface] auth card revealed (" + source + ") screen=" + screenName);
        if (root.isPrimary && passwordField)
            Qt.callLater(() => passwordField.forceActiveFocus());
    }

    Component.onCompleted: {
        root.updateThemeData();
        pointerSettleTimer.start();
        if (root.isPrimary)
            console.info("[LockSurface] primary=" + screenName + " depthActive=" + root.depthActive + " overlay=" + (root.currentOverlay !== "") + " auth=" + root.authCardVisible);
    }

    // Component.onCompleted fires before the compositor maps the lock surface.
    onVisibleChanged: {
        if (visible)
            expandDelay.restart();
    }

    onDepthActiveChanged: {
        if (root.isPrimary)
            console.info("[LockSurface] depthActive=" + root.depthActive + " screen=" + screenName);
    }

    Connections {
        target: ThemeManager
        function onSelectedThemeUpdated() { root.updateThemeData(); }
        function onCreatingOverlayImageFinished(path) { root.currentOverlay = path; }
    }

    Timer {
        id: expandDelay
        interval: 16
        repeat: false
        onTriggered: root.frameExpanded = true
    }

    Timer {
        id: pointerSettleTimer
        interval: 350
        repeat: false
        onTriggered: root.pointerReady = true
    }

    Timer {
        id: autoHideTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (service && service.pamVerifying) {
                autoHideTimer.restart();
                return;
            }
            root.authCardVisible = false;
            console.info("[LockSurface] auth card hidden screen=" + screenName);
            Qt.callLater(() => lockContent.forceActiveFocus());
        }
    }

    Item {
        id: lockContent
        anchors.fill: parent
        visible: root.validScreen
        focus: true

        // GPU-only expand: fixed fullscreen geometry, animated transform only.
        Item {
            id: wallFrame
            anchors.fill: parent
            transformOrigin: Item.Center

            transform: [
                Scale {
                    id: expandScale
                    xScale: root.frameExpanded ? 1 : root.initialXScale
                    yScale: root.frameExpanded ? 1 : root.initialYScale
                    Behavior on xScale { NumberAnimation { duration: root.frameExpanded ? 280 : 240; easing.type: Easing.OutCubic } }
                    Behavior on yScale { NumberAnimation { duration: root.frameExpanded ? 280 : 240; easing.type: Easing.OutCubic } }
                },
                Translate {
                    id: expandTranslate
                    x: root.frameExpanded ? 0 : root.initialTranslateX
                    y: root.frameExpanded ? 0 : root.initialTranslateY
                    Behavior on x { NumberAnimation { duration: root.frameExpanded ? 280 : 240; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: root.frameExpanded ? 280 : 240; easing.type: Easing.OutCubic } }
                }
            ]

            // Exact desktop wallpaper + Widgets/DesktopClock, no branching.
            Wallpaper {
                anchors.fill: parent

                wallpaperSource: ThemeManager.currentWallpaper
                overlaySource: root.depthActive ? root.currentOverlay : ""
                depthEnabled: root.depthActive
                isMenuOpen: false
                blurEnabled: ThemeManager.selectedTheme.systemSettings.enableWallpaperBlur
                blurValue: ThemeManager.selectedTheme.systemSettings.wallpaperBlurStrength
                muted: true
                syncLoad: true
                // Always High: reuse Desktop's warm texture cache, no re-decode on monitor switch.
                graphicsQuality: "High"

                content: Widgets {
                    anchors.fill: parent
                    enabled: false
                    dimWidgets: false
                }
            }
        }

        MouseArea {
            id: pointerArea
            anchors.fill: parent
            hoverEnabled: true
            z: 20
            propagateComposedEvents: true

            property point lastPos: Qt.point(-1000, -1000)

            onEntered: {
                pointerArea.lastPos = Qt.point(mouseX, mouseY);
                if (!root.pointerReady)
                    return;
                if (service)
                    service.noteActivity("pointer");
                root.revealAuthCard("pointer-enter");
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
            }
            onExited: pointerArea.lastPos = Qt.point(-1000, -1000)

            onPositionChanged: mouse => {
                const current = Qt.point(mouse.x, mouse.y);
                if (pointerArea.lastPos.x < -900) {
                    pointerArea.lastPos = current;
                    return;
                }
                const dx = current.x - pointerArea.lastPos.x;
                const dy = current.y - pointerArea.lastPos.y;
                pointerArea.lastPos = current;
                if (!root.pointerReady || (dx * dx + dy * dy) <= 9)
                    return;
                if (service)
                    service.noteActivity("pointer");
                root.revealAuthCard("pointer");
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
            }

            onPressed: mouse => {
                mouse.accepted = false;
                if (service)
                    service.noteActivity("pointer");
                root.revealAuthCard("pointer");
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
            }

            onReleased: mouse.accepted = false
            onClicked: mouse.accepted = false
            onDoubleClicked: mouse.accepted = false
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            width: 46
            height: 32
            z: 25
            radius: 16
            visible: root.isPrimary && !root.authCardVisible
            color: ThemeManager.selectedTheme.colors.surfaceContainer.alpha(0.8)
            border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.35)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "\uf023"
                font.family: ThemeManager.selectedTheme.typography.iconFont
                font.pixelSize: 16
                color: ThemeManager.selectedTheme.colors.primary
            }
        }

        Keys.onPressed: event => {
            if (service)
                service.noteActivity("key");
            root.revealAuthCard("key");
            if (root.isModifier(event.key))
                return;
            const key = event.key;
            const text = event.text;
            if (!root.isPrimary && service) {
                service.switchAuthScreen(screenName);
                Qt.callLater(() => service.forwardInput(key, text));
            } else if (service) {
                service.forwardInput(key, text);
            }
            event.accepted = true;
        }

        Rectangle {
            id: authCard
            anchors.centerIn: parent
            width: 420
            height: 340
            z: 30
            visible: root.isPrimary
            opacity: root.authCardVisible ? 1 : 0
            scale: root.authCardVisible ? 1 : 0.96
            radius: ThemeManager.selectedTheme.dimensions.elementRadius
            color: ThemeManager.selectedTheme.colors.surfaceContainer.alpha(0.92)
            border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.35)
            border.width: 1

            transform: Translate {
                y: root.authCardVisible ? 0 : 16
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        root.revealAuthCard("card-hover");
                }
            }

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

                    Keys.onPressed: event => root.revealAuthCard("field-key")

                    onTextEdited: {
                        if (service)
                            service.noteActivity("key");
                        root.revealAuthCard("typing");
                        if (service)
                            service.passwordBuffer = text;
                    }
                    onAccepted: {
                        if (service)
                            service.noteActivity("key");
                        if (service)
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
                            if (service)
                                service.noteActivity("pointer");
                            root.revealAuthCard("pointer");
                            if (service)
                                service.submitPassword();
                        }
                    }

                    MButton {
                        Layout.fillWidth: true
                        text: qsTr("Cancel")
                        onClicked: {
                            if (service)
                                service.noteActivity("pointer");
                            root.revealAuthCard("pointer");
                            if (service)
                                service.pamAbort();
                        }
                    }
                }
            }
        }

        Connections {
            target: service
            function onPasswordFocusRequested(name: string) {
                // Focus only: do not force the card visible on initial lock.
                if (name === screenName && passwordField)
                    Qt.callLater(() => passwordField.forceActiveFocus());
            }
            function onPamVerifyingChanged() {
                if (service.pamVerifying)
                    root.revealAuthCard("pam-verifying");
            }
            function onLastErrorChanged() {
                if (service.lastError !== "")
                    root.revealAuthCard("pam-error");
            }
            function onUnlockingChanged() {
                if (!service.unlocking)
                    return;
                root.authCardVisible = false;
                root.frameExpanded = false;
            }
            function onDpmsOffChanged() {
                if (service.dpmsOff) {
                    root.wasDpmsOff = true;
                } else if (root.wasDpmsOff) {
                    root.wasDpmsOff = false;
                    root.revealAuthCard("dpms-wake");
                }
            }
        }
    }
}
