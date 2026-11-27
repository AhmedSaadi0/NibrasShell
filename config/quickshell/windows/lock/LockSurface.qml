// windows/lock/LockSurface.qml

import QtQuick
import QtQuick.Window
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

    // Identical cache key to Desktop.qml: physical screen pixels, static per screen.
    readonly property real wallpaperDpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property size wallpaperMaxSourceSize: Qt.size(Math.round((screen ? screen.width : Screen.width) * wallpaperDpr), Math.round((screen ? screen.height : Screen.height) * wallpaperDpr))

    color: ThemeManager.selectedTheme.colors.surface

    function isModifier(key: int): bool {
        return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt || key === Qt.Key_Meta || key === Qt.Key_AltGr || key === Qt.Key_CapsLock;
    }

    function isForwardableKey(event): bool {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            return true;
        const text = event.text || "";
        if (text.length === 0)
            return false;
        const code = text.charCodeAt(0);
        // تجاهل أحرف التحكم ASCII (مثل Escape \x1b و Tab \t و Delete \x7f)
        return code >= 32 && code !== 127;
    }

    function focusPasswordField(): void {
        if (!root.isPrimary || !root.authCardVisible || !passwordField)
            return;
        passwordField.forceActiveFocus();
        passwordField.deselect();
        passwordField.cursorPosition = passwordField.text.length;
    }

    function syncPasswordFieldFromService(): void {
        if (!passwordField || !service)
            return;
        const buf = service.passwordBuffer || "";
        if (passwordField.text !== buf) {
            passwordField.text = buf;
            passwordField.cursorPosition = buf.length;
        }
    }

    function updateThemeData(): void {
        const theme = ThemeManager.selectedTheme;
        const clockSettings = theme ? theme.desktopClock : null;
        const isDepth = Boolean(clockSettings && clockSettings.enabled && clockSettings.depthEffectEnabled);
        root.depthEnabled = isDepth;
        root.currentOverlay = isDepth ? (clockSettings.depthOverlayPath || "") : "";
    }

    function revealAuthCard(source: string): void {
        if (!root.isPrimary)
            return;
        const wasVisible = root.authCardVisible;
        root.authCardVisible = true;
        autoHideTimer.restart();
        if (!wasVisible)
            console.info("[LockSurface] auth card revealed (" + source + ") screen=" + screenName);
        Qt.callLater(root.focusPasswordField);
    }

    Component.onCompleted: {
        root.updateThemeData();
        root.syncPasswordFieldFromService();
        pointerSettleTimer.start();
        if (root.isPrimary)
            console.info("[LockSurface] primary=" + screenName + " depthActive=" + root.depthActive + " overlay=" + (root.currentOverlay !== "") + " auth=" + root.authCardVisible);
    }

    // Component.onCompleted fires before the compositor maps the lock surface.
    onVisibleChanged: {
        if (visible) {
            if (!service || !service.unlocking)
                expandDelay.restart();
        } else {
            expandDelay.stop();
        }
    }

    onIsPrimaryChanged: {
        if (!root.isPrimary) {
            autoHideTimer.stop();
            root.authCardVisible = false;
        } else {
            root.syncPasswordFieldFromService();
            if (root.authCardVisible)
                Qt.callLater(root.focusPasswordField);
        }
    }

    onDepthActiveChanged: {
        if (root.isPrimary)
            console.info("[LockSurface] depthActive=" + root.depthActive + " screen=" + screenName);
    }

    Connections {
        target: ThemeManager
        function onSelectedThemeUpdated() {
            root.updateThemeData();
        }
        function onCreatingOverlayImageFinished(path) {
            if (root.depthEnabled)
                root.currentOverlay = path || "";
        }
    }

    Timer {
        id: expandDelay
        interval: 16
        repeat: false
        onTriggered: {
            if (root.visible && (!service || !service.unlocking))
                root.frameExpanded = true;
        }
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
                    Behavior on xScale {
                        NumberAnimation {
                            duration: root.frameExpanded ? 280 : 240
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: root.frameExpanded ? 280 : 240
                            easing.type: Easing.OutCubic
                        }
                    }
                },
                Translate {
                    id: expandTranslate
                    x: root.frameExpanded ? 0 : root.initialTranslateX
                    y: root.frameExpanded ? 0 : root.initialTranslateY
                    Behavior on x {
                        NumberAnimation {
                            duration: root.frameExpanded ? 280 : 240
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: root.frameExpanded ? 280 : 240
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            ]

            // Exact desktop wallpaper + Widgets/DesktopClock, no branching.
            Wallpaper {
                anchors.fill: parent

                wallpaperSource: ThemeManager.currentWallpaper
                overlaySource: root.depthActive ? root.currentOverlay : ""
                maxSourceSize: root.wallpaperMaxSourceSize
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
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
                root.revealAuthCard("pointer-enter");
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
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
                root.revealAuthCard("pointer");
            }

            onPressed: mouse => {
                mouse.accepted = false;
                if (service)
                    service.noteActivity("pointer");
                if (!root.isPrimary && service)
                    service.switchAuthScreen(screenName);
                root.revealAuthCard("pointer");
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
            if (root.isModifier(event.key))
                return;
            if (event.key === Qt.Key_Escape) {
                if (root.authCardVisible && (!service || !service.pamVerifying)) {
                    root.authCardVisible = false;
                    autoHideTimer.stop();
                }
                event.accepted = true;
                return;
            }
            if (!root.isForwardableKey(event)) {
                event.accepted = true;
                return;
            }
            if (!root.isPrimary && service)
                service.switchAuthScreen(screenName);
            root.revealAuthCard("key");
            const key = event.key;
            const text = event.text;
            if (service)
                Qt.callLater(() => service.forwardInput(key, text));
            event.accepted = true;
        }

        Rectangle {
            id: authCard
            anchors.centerIn: parent
            width: 420
            height: 340
            z: 30
            visible: root.isPrimary && (root.authCardVisible || opacity > 0)
            enabled: root.isPrimary && root.authCardVisible
            opacity: root.authCardVisible ? 1 : 0
            scale: root.authCardVisible ? 1 : 0.96
            radius: ThemeManager.selectedTheme.dimensions.elementRadius
            color: ThemeManager.selectedTheme.colors.surfaceContainer.alpha(0.92)
            border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.35)
            border.width: 1

            transform: Translate {
                y: root.authCardVisible ? 0 : 16
                Behavior on y {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                enabled: root.pointerReady && root.authCardVisible
                onHoveredChanged: {
                    if (hovered) {
                        if (service)
                            service.noteActivity("pointer");
                        root.revealAuthCard("card-hover");
                    }
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
                        source: App.profilePicture ? Qt.resolvedUrl(App.profilePicture) : Qt.resolvedUrl(App.assetsPath + "/icons/profile-modified.png")
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
                    color: ThemeManager.selectedTheme.colors.onSurface
                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                    font.pixelSize: ThemeManager.selectedTheme.typography.medium

                    Keys.onPressed: event => {
                        if (service)
                            service.noteActivity("key");
                        root.revealAuthCard("field-key");
                    }
                    Keys.onEscapePressed: event => {
                        if (!service || !service.pamVerifying) {
                            root.authCardVisible = false;
                            autoHideTimer.stop();
                            Qt.callLater(() => lockContent.forceActiveFocus());
                        }
                        event.accepted = true;
                    }

                    onTextEdited: {
                        if (service)
                            service.noteActivity("key");
                        root.revealAuthCard("typing");
                        if (service && service.passwordBuffer !== text)
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

                    Component.onCompleted: {
                        root.syncPasswordFieldFromService();
                        Qt.callLater(root.focusPasswordField);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: service && service.lastError !== "" ? service.lastError : (service ? service.pamStatus : "")
                    color: service && service.lastError !== "" ? ThemeManager.selectedTheme.colors.error : ThemeManager.selectedTheme.colors.onSurfaceVariant
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
                        enabled: !service || !service.pamVerifying
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
            function onPasswordBufferChanged() {
                root.syncPasswordFieldFromService();
            }
            function onPasswordFocusRequested(name: string) {
                // Focus only: do not force the card visible on initial lock.
                if (name === screenName && root.authCardVisible)
                    Qt.callLater(root.focusPasswordField);
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
                if (service.unlocking) {
                    expandDelay.stop();
                    autoHideTimer.stop();
                    root.authCardVisible = false;
                    root.frameExpanded = false;
                } else if (service.lockRequested) {
                    root.frameExpanded = true;
                }
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
