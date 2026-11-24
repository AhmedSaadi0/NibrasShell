// wallpaper/Wallpaper.qml

import QtQuick
import QtQuick.Effects
import QtMultimedia

import "root:/components"

Item {
    id: root

    // --- Public Configuration ---
    property string wallpaperSource: ""
    property string overlaySource: ""
    property bool depthEnabled: false
    property bool blurEnabled: false
    property bool isMenuOpen: false
    property real blurValue: 0.9
    property string graphicsQuality: "High"
    property real bottomMargin: 0
    // Forwarded to every MediaItem; desktop callers keep the defaults.
    property bool muted: false
    property bool syncLoad: false

    Behavior on bottomMargin {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    default property alias content: widgetsContainer.data

    // --- Internal State ---
    property bool bgShowChannel1: true
    property bool fgShowChannel1: true

    // --- Helper Functions ---
    function toFileUrl(path) {
        if (!path)
            return "";
        const str = path.toString();
        return (str.startsWith("file://") || str.startsWith("http")) ? str : "file://" + str;
    }

    function isVideo(path) {
        if (!path)
            return false;
        const p = path.toString().toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".mkv") || p.endsWith(".webm") || p.endsWith(".avi") || p.endsWith(".mov");
    }

    // --- Layer 1: Background ---
    Item {
        id: backgroundLayer
        z: 0
        anchors.fill: parent
        transformOrigin: Item.Center
        scale: root.isMenuOpen ? 1.03 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 520
                easing.type: Easing.OutCubic
            }
        }

        // =========================================================
        // التعديل هنا: منطق التحريك السلس للتضبيب والألوان
        // =========================================================

        // 1. خاصية محلية متحركة تتبع حالة فتح القائمة وخيار البلر
        property real animatedBlur: (root.blurEnabled && root.isMenuOpen) ? root.blurValue : 0

        Behavior on animatedBlur {
            NumberAnimation {
                duration: 480
                easing.type: Easing.OutCubic
            }
        }

        // 2. تفعيل الطبقة طالما أن الأنيميشن مستمر (لم يصل للصفر بعد) لمنع الاختفاء المفاجئ
        layer.enabled: root.blurEnabled && (root.isMenuOpen || animatedBlur > 0.01)

        layer.effect: MultiEffect {
            blurEnabled: root.blurEnabled
            blurMax: 32
            blur: backgroundLayer.animatedBlur

            // 3. تحريك إشباع الألوان تدريجياً ليتناسق بصرياً مع درجة البلر (من 1.0 إلى 0.2)
            // saturation: root.blurValue > 0 ? (1.0 - (0.8 * (backgroundLayer.animatedBlur / root.blurValue))) : 1.0
        }

        MediaItem {
            id: bg1
            anchors.fill: parent
            active: opacity > 0

            quality: root.graphicsQuality
            muted: root.muted
            syncLoad: root.syncLoad

            state: root.bgShowChannel1 ? "active" : "inactive"

            states: [
                State {
                    name: "active"
                    PropertyChanges {
                        target: bg1
                        opacity: 1.0
                        z: 2
                    }
                },
                State {
                    name: "inactive"
                    PropertyChanges {
                        target: bg1
                        opacity: 0.0
                        z: 1
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "inactive"
                    to: "active"
                    NumberAnimation {
                        property: "opacity"
                        duration: root.syncLoad ? 0 : 520
                        easing.type: Easing.OutCubic
                    }
                },
                Transition {
                    from: "active"
                    to: "inactive"
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 520
                        }
                        PropertyAction {
                            property: "opacity"
                            value: 0.0
                        }
                    }
                }
            ]
        }

        MediaItem {
            id: bg2
            anchors.fill: parent
            active: opacity > 0

            quality: root.graphicsQuality
            muted: root.muted
            syncLoad: root.syncLoad

            state: !root.bgShowChannel1 ? "active" : "inactive"

            states: [
                State {
                    name: "active"
                    PropertyChanges {
                        target: bg2
                        opacity: 1.0
                        z: 2
                    }
                },
                State {
                    name: "inactive"
                    PropertyChanges {
                        target: bg2
                        opacity: 0.0
                        z: 1
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "inactive"
                    to: "active"
                    NumberAnimation {
                        property: "opacity"
                        duration: root.syncLoad ? 0 : 520
                        easing.type: Easing.OutCubic
                    }
                },
                Transition {
                    from: "active"
                    to: "inactive"
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 520
                        }
                        PropertyAction {
                            property: "opacity"
                            value: 0.0
                        }
                    }
                }
            ]
        }
    }

    // --- Layer 2: Widgets Content ---
    Item {
        id: widgetsContainer
        z: 1
        anchors.fill: parent
        anchors.bottomMargin: root.bottomMargin
    }

    // --- Layer 3: Depth Foreground ---
    Item {
        id: foregroundLayer
        z: 2
        anchors.fill: parent

        property bool isActive: root.depthEnabled && root.overlaySource !== ""
        opacity: isActive ? 1.0 : 0.0
        visible: opacity > 0

        transformOrigin: Item.Center
        scale: root.isMenuOpen ? 1.08 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 540
                easing.type: Easing.OutCubic
            }
        }

        MediaItem {
            id: fg1
            anchors.fill: parent
            active: opacity > 0
            quality: root.graphicsQuality
            muted: root.muted
            syncLoad: root.syncLoad

            opacity: root.fgShowChannel1 ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.syncLoad ? 0 : 520
                    easing.type: Easing.OutCubic
                }
            }
        }

        MediaItem {
            id: fg2
            anchors.fill: parent
            active: opacity > 0
            quality: root.graphicsQuality
            muted: root.muted
            syncLoad: root.syncLoad

            opacity: !root.fgShowChannel1 ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.syncLoad ? 0 : 520
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // --- Controller Logic ---
    Timer {
        id: cleanupTimer
        interval: 620
        repeat: false
        onTriggered: {
            if (root.bgShowChannel1)
                bg2.source = "";
            else
                bg1.source = "";
            if (root.fgShowChannel1)
                fg2.source = "";
            else
                fg1.source = "";
        }
    }

    Timer {
        id: readinessChecker
        interval: 300
        repeat: false
        running: false
        onTriggered: {
            const pendingBg = root.bgShowChannel1 ? bg2 : bg1;
            const pendingFg = root.fgShowChannel1 ? fg2 : fg1;
            const needOverlay = root.depthEnabled && (root.overlaySource !== "");

            const bgOk = pendingBg.isReady || pendingBg.isError;
            const fgOk = !needOverlay || (pendingFg.isReady || pendingFg.isError);

            if (bgOk && fgOk) {
                root.bgShowChannel1 = !root.bgShowChannel1;
                root.fgShowChannel1 = !root.fgShowChannel1;
                cleanupTimer.restart();
                readinessChecker.stop();
            }
        }
    }

    function updateSources() {
        const targetBg = root.bgShowChannel1 ? bg2 : bg1;
        const targetFg = root.fgShowChannel1 ? fg2 : fg1;

        targetBg.source = root.wallpaperSource;
        targetFg.source = root.overlaySource;
        readinessChecker.start();
    }

    onWallpaperSourceChanged: updateSources()
    onOverlaySourceChanged: updateSources()

    Component.onCompleted: {
        if (root.bgShowChannel1)
            bg1.source = root.wallpaperSource;
        if (root.fgShowChannel1)
            fg1.source = root.overlaySource;
    }
}
