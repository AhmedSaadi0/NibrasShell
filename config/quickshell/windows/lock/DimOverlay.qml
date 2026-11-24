// windows/lock/DimOverlay.qml

import QtQuick
import Quickshell
import Quickshell.Wayland

import "root:/config"
import "root:/services"

PanelWindow {
    id: root

    // screen is bound by the Variants delegate in shell.qml.
    readonly property bool validScreen: screen && screen.name !== "" && screen.width > 0 && screen.height > 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Keep the Wayland surface transparent; fade the inner rectangle instead.
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.namespace: "NibrasShell:dim"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Click-through. If input is still captured in the Phase 2 live test, use
    // Region { item: dimRect; intersection: Intersection.Xor } instead.
    mask: Region {}

    Rectangle {
        id: dimRect
        anchors.fill: parent
        color: "black"
        opacity: LockService.dimActive ? App.dimOverlayOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 320
        repeat: false
        onTriggered: {
            if (!LockService.dimActive) {
                console.info("[DimOverlay] hide screen=" + (screen ? screen.name : "null"));
                root.visible = false;
            }
        }
    }

    function updateVisible(): void {
        // An unmapped PanelWindow has width/height 0 until visible; use the
        // screen geometry only, otherwise the overlay can never be shown.
        if (!root.validScreen) {
            hideTimer.stop();
            root.visible = false;
            return;
        }
        if (LockService.dimActive) {
            hideTimer.stop();
            if (!root.visible)
                console.info("[DimOverlay] show screen=" + screen.name);
            root.visible = true;
        } else {
            hideTimer.start();
        }
    }

    Component.onCompleted: root.updateVisible()

    Connections {
        target: LockService
        function onDimActiveChanged() {
            root.updateVisible();
        }
    }

    Connections {
        target: screen
        function onGeometryChanged() {
            root.updateVisible();
        }
    }
}
