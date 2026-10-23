// desktop/Desktop.qml

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import "root:/components"
import "root:/config"
import "root:/themes" as Theme
import "root:/config/EventNames.js" as Events
import "root:/config/ConstValues.js" as C

PanelWindow {
    id: desktopRoot

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: Theme.ThemeManager.selectedTheme.colors.surface

    aboveWindows: false
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "NibrasShell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    property bool isMenuOpened: false
    property string currentOverlay: ""
    property bool depthEffectActive: false
    property bool blurEnabled: false
    property bool _gapsApplied: false

    property int elementRadius: Theme.ThemeManager.selectedTheme.dimensions.elementRadius
    property int cornerRadius: elementRadius <= 1 ? 0 : elementRadius + 6

    // التحقق مما إذا كانت هذه الشاشة هي الشاشة النشطة
    readonly property bool isFocusedMonitor: desktopRoot.screen && Hyprland.focusedMonitor && (desktopRoot.screen.name === Hyprland.focusedMonitor.name)

    // تفعيل النوتش فقط في الشاشة النشطة
    readonly property bool notchVisible: App.showDock && !App.hasWindowsOnWorkspace && isFocusedMonitor
    readonly property real notchTargetHeight: App.dockIconSize + 48
    property real dockActualWidth: notchTargetHeight * 15
    property bool launcherVisible: false
    readonly property real launcherExtraHeight: launcherVisible ? (App.dockIconSize + 630) : 0
    readonly property real notchWidth: Math.max(dockActualWidth, launcherVisible ? App.bottomLauncherWidth : 0)

    property real notchHeight: notchVisible ? notchTargetHeight + launcherExtraHeight : 0

    Behavior on notchHeight {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: sheetContainer
        anchors.fill: parent

        anchors.topMargin: (Theme.ThemeManager.selectedTheme.dimensions.barHeight) + 3
        anchors.leftMargin: Theme.ThemeManager.selectedTheme.dimensions.leftBarWidth + 2
        anchors.rightMargin: 5
        anchors.bottomMargin: 5

        transform: Translate {
            x: App.menuStyle !== C.FLOATING && desktopRoot.isMenuOpened ? Theme.ThemeManager.selectedTheme.dimensions.menuWidth + 5 : 0

            Behavior on x {
                NumberAnimation {
                    duration: AnimationConfig.animDuration
                    easing.type: Easing.Bezier
                    easing.bezierCurve: AnimationConfig.bezierAccelerate
                }
            }
        }

        // 1. طبقة الظل الخلفية
        NotchShape {
            id: shadowRect
            anchors.fill: parent
            notchHeight: desktopRoot.notchHeight
            notchWidth: desktopRoot.notchWidth
            cornerRadius: desktopRoot.cornerRadius

            fillColor: Theme.ThemeManager.selectedTheme.colors.surface

            layer.enabled: true
            layer.smooth: true
            // تم حذف layer.samples: 4 لتخفيف العبء على كرت إنتل
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.ThemeManager.selectedTheme.colors.shadow.alpha(0.8)
                shadowBlur: 1.0
                shadowVerticalOffset: -1
                shadowHorizontalOffset: -1
                shadowScale: 1.0
            }
        }

        // 2. طبقة الخلفية والصور
        Wallpaper {
            id: wallpaper
            anchors.fill: parent

            overlaySource: desktopRoot.currentOverlay
            depthEnabled: desktopRoot.depthEffectActive
            isMenuOpen: desktopRoot.isMenuOpened
            blurEnabled: desktopRoot.blurEnabled
            blurValue: Theme.ThemeManager.selectedTheme.systemSettings.wallpaperBlurStrength

            content: Widgets {
                id: myWidgets
                anchors.fill: parent
                anchors.bottomMargin: desktopRoot.notchHeight
                dimWidgets: desktopRoot.isMenuOpened
            }

            layer.enabled: true
            layer.smooth: true
            // تم حذف layer.samples: 4 لتخفيف العبء على كرت إنتل
            layer.effect: OpacityMask {
                maskSource: maskItem
            }
        }

        // 3. عنصر القناع
        Item {
            id: maskItem
            anchors.fill: parent
            visible: false

            NotchShape {
                id: maskShape
                anchors.fill: parent
                notchHeight: desktopRoot.notchHeight
                notchWidth: desktopRoot.notchWidth
                cornerRadius: desktopRoot.cornerRadius
                fillColor: "white"
            }
        }
    }

    function updateThemeData() {
        let clockSettings = Theme.ThemeManager.selectedTheme.desktopClock;
        let isDepth = (clockSettings?.enabled && clockSettings?.depthEffectEnabled) || false;

        desktopRoot.depthEffectActive = isDepth;
        desktopRoot.currentOverlay = isDepth ? (clockSettings?.depthOverlayPath || "") : "";
        desktopRoot.blurEnabled = Theme.ThemeManager.selectedTheme.systemSettings.enableWallpaperBlur;
    }

    Connections {
        target: Theme.ThemeManager
        function onSelectedThemeUpdated() {
            desktopRoot.updateThemeData();
        }
        function onWallpaperChanged(path) {
            wallpaper.wallpaperSource = path;
        }
        function onCreatingOverlayImageFinished(newImagePath) {
            desktopRoot.currentOverlay = newImagePath;
        }
    }

    Component.onCompleted: {
        // حصر التفاعل بالشاشة النشطة فقط بشكل قطعي ومستقل
        EventBus.on(Events.LEFT_MENU_IS_OPENED, () => {
            let myScreenName = desktopRoot.screen ? desktopRoot.screen.name : "";

            if (!desktopRoot.isFocusedMonitor) {
                console.info("[Desktop]", myScreenName, "ignoring open event (not focused monitor).");
                return;
            }

            console.info("[Desktop]", myScreenName, "is focused monitor -> opening menu state.");
            changeIsMenuOpen.newValue = true;
            changeIsMenuOpen.start();
        }, desktopRoot);

        EventBus.on(Events.LEFT_MENU_IS_CLOSED, () => {
            if (desktopRoot.isMenuOpened) {
                console.info("[Desktop]", desktopRoot.screen ? desktopRoot.screen.name : "", "resetting menu state.");
                changeIsMenuOpen.newValue = false;
                changeIsMenuOpen.start();
            }
        }, desktopRoot);

        EventBus.on(Events.DOCK_WIDTH_CHANGED, w => {
            desktopRoot.dockActualWidth = w + 5;
        }, desktopRoot);

        EventBus.on(Events.BOTTOM_LAUNCHER_OPENED, () => {}, desktopRoot);

        EventBus.on(Events.BOTTOM_LAUNCHER_CLOSED, () => {
            desktopRoot.launcherVisible = false;
        }, desktopRoot);

        desktopRoot.updateThemeData();
        wallpaper.wallpaperSource = Theme.ThemeManager.currentWallpaper;
    }

    Component.onDestruction: EventBus.clearOwner(desktopRoot)

    Timer {
        id: changeIsMenuOpen
        interval: 0
        repeat: false
        property bool newValue: false
        onTriggered: {
            desktopRoot.isMenuOpened = newValue;
            if (App.menuStyle !== C.FLOATING) {
                if (newValue) {
                    addLeftSpaceDelay.restart();
                } else {
                    addLeftSpace();
                }
            }
        }
    }

    Timer {
        id: addLeftSpaceDelay
        interval: 340
        repeat: false
        onTriggered: addLeftSpace()
    }

    function addLeftSpace() {
        if (desktopRoot._gapsApplied === desktopRoot.isMenuOpened)
            return;
        desktopRoot._gapsApplied = desktopRoot.isMenuOpened;
        if (desktopRoot.isMenuOpened) {
            Theme.ThemeManager.addLeftMenuSpacing();
        } else {
            Theme.ThemeManager.resetLeftMenuSpacing();
        }
    }
}
