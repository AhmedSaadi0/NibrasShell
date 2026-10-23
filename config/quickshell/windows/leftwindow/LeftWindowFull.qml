import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/themes"
import "root:/components"
import "root:/windows/leftwindow/base"
import "root:/utils"
import "root:/config/EventNames.js" as Events
import "root:/config/ConstValues.js" as C
import "root:/config"

PanelWindow {
    id: root

    property bool isShown: false
    property string menuStyle: App.menuStyle

    color: "transparent"
    visible: false

    exclusionMode: ExclusionMode.Ignore
    focusable: menus.currentIndex == C.APPLICATIONS_MENU_INDEX || menus.currentIndex == C.NETWORK_MENU_INDEX || menus.currentIndex == C.CLIPBOARD_MENU_INDEX || menus.currentIndex == C.TODO_MENU_INDEX || menus.currentIndex == C.MONIROTS_MENU_INDEX
    implicitWidth: ThemeManager.selectedTheme.dimensions.menuWidth

    anchors {
        top: true
        left: true
        bottom: true
    }

    margins {
        left: {
            switch (root.menuStyle) {
            case C.DOCKED_FIXED_BAR:
                return ThemeManager.selectedTheme.dimensions.leftBarWidth;
            case C.DOCKED_MOVING_BAR:
                return 0;
            case C.FLOATING:
                return ThemeManager.selectedTheme.dimensions.leftBarWidth;
            }
        }
        top: ThemeManager.selectedTheme.dimensions.barHeight + 13
        bottom: root.menuStyle === C.FLOATING ? 15 : 0
    }

    onIsShownChanged: {
        if (isShown) {
            if (root.visible && contentContainer.opacity > 0) {
                contentContainer.state = "visible";
                return;
            }

            contentContainer.x = -root.width;
            contentContainer.opacity = 0;

            root.visible = true;
            startOpenAnimTimer.restart();
        } else {
            startOpenAnimTimer.stop();
            contentContainer.state = "hidden";
        }
    }

    Timer {
        id: startOpenAnimTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.isShown) {
                contentContainer.state = "visible";
            }
        }
    }

    CorneredBox {
        id: contentContainer

        width: root.menuStyle === C.FLOATING ? parent.width - 10 : parent.width
        height: parent.height
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        layer.enabled: root.visible && opacity === 0
        layer.smooth: true

        radius: root.menuStyle === C.FLOATING ? ThemeManager.selectedTheme.dimensions.elementRadius * 1.3 : 0
        border.color: root.menuStyle === C.FLOATING ? ThemeManager.selectedTheme.colors.primary : "transparent"
        border.width: root.menuStyle === C.FLOATING ? 2 : 0
        boxColor: root.menuStyle === C.FLOATING ? ThemeManager.selectedTheme.colors.surface : "transparent"

        Item {
            id: layoutRoot
            anchors.fill: parent
            anchors.bottomMargin: root.menuStyle === C.FLOATING ? 4 : 0

            Menus {
                id: menus
                anchors.fill: parent
            }
        }

        transformOrigin: Item.Left

        states: [
            State {
                name: "visible"
                PropertyChanges {
                    target: contentContainer
                    x: root.menuStyle === C.FLOATING ? 10 : 0
                    opacity: 1.0
                }
            },
            State {
                name: "hidden"
                PropertyChanges {
                    target: contentContainer
                    x: -root.width
                    opacity: 0.9
                }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"
                to: "visible"
                ParallelAnimation {
                    NumberAnimation {
                        properties: "x"
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        properties: "opacity"
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
            },
            Transition {
                from: "visible"
                to: "hidden"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation {
                            target: contentContainer
                            property: "x"
                            to: -root.width
                            duration: 200
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: contentContainer
                            property: "opacity"
                            to: 0
                            duration: 160
                            easing.type: Easing.InQuad
                        }
                    }
                    PropertyAction {
                        target: root
                        property: "visible"
                        value: false
                    }
                }
            }
        ]
    }

    Component.onCompleted: {
        contentContainer.x = -root.width;
        contentContainer.state = "hidden";
        root.visible = false;

        EventBus.on(Events.CLOSE_LEFTBAR, function () {
            isShown = false;
            EventBus.emit(Events.LEFT_MENU_IS_CLOSED);
        }, root);

        EventBus.on(Events.OPEN_LEFTBAR, function (newIndex) {
            if (newIndex === -1) {
                isShown = false;
            } else {
                isShown = true;
                // الاسم الاعتمادي هو مرقّب Hyprland النشِط مباشرة —
                // root.screen لا يُجسّد تغيير الشاشة النشطة ديناميكياً في Quickshell
                let activeMonitorName = (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor)
                                        ? Hyprland.focusedMonitor.name
                                        : (root.screen ? root.screen.name : "");
                console.info("[LeftWindowFull] Emitting LEFT_MENU_IS_OPENED for active monitor:", activeMonitorName);
                EventBus.emit(Events.LEFT_MENU_IS_OPENED, newIndex, activeMonitorName);
            }
        }, root);
    }

    Connections {
        target: LeftMenuStatus
        function onSelectedIndexTargeted(newIndex) {
            if (newIndex === -1) {
                isShown = false;
                EventBus.emit(Events.LEFT_MENU_IS_CLOSED);
            } else {
                isShown = true;
                let activeMonitorName = (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor)
                                        ? Hyprland.focusedMonitor.name
                                        : (root.screen ? root.screen.name : "");
                console.info("[LeftWindowFull] Emitting LEFT_MENU_IS_OPENED for active monitor:", activeMonitorName);
                EventBus.emit(Events.LEFT_MENU_IS_OPENED, newIndex, activeMonitorName);
            }
        }
    }
}
