// bars/LeftBar.qml
// pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import Quickshell.Wayland

import "../themes"
import "../components"
import "root:/utils"
import "root:/services"
import "root:/config"
import "root:/config/EventNames.js" as Events
import "root:/config/ConstValues.js" as Consts

PanelWindow {
    id: root

    implicitWidth: ThemeManager.selectedTheme.dimensions.leftBarWidth
    // color: ThemeManager.selectedTheme.colors.surface
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "NibrasShell:leftbar"

    anchors {
        top: true
        left: true
        bottom: true
    }

    margins {
        top: ThemeManager.selectedTheme.dimensions.barHeight
    }

    // --- Properties ---
    property bool panelOpen: false
    property int activeMenuIndex: LeftMenuStatus.selectedIndex
    property int notificationMenuIndex: -1

    Behavior on margins.left {
        NumberAnimation {
            duration: AnimationConfig.barExpandDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: AnimationConfig.bezierAccelerate
        }
    }

    // ---------------------------------------------------------
    // 1. MODELS (البيانات)
    // ---------------------------------------------------------

    // [المجموعة العلوية - النظام]
    ListModel {
        id: topModel
        ListElement {
            icon: "󰨝"
            activeIcon: "󰕮"
            name: "Dashboard"
        }
        ListElement {
            icon: ""
            activeIcon: ""
            name: "Notifications"
            notificationCount: 0
        }
        ListElement {
            icon: ""
            activeIcon: "󰅟"
            name: "Weather"
        }
        ListElement {
            icon: ""
            activeIcon: ""
            name: "Monitors"
        }
        ListElement {
            icon: "󰤯"
            activeIcon: "󰤨"
            name: "Network"
        }
    }

    // [المجموعة الوسطى - الإنتاجية]
    ListModel {
        id: middleModel
        ListElement {
            icon: "󰅌"
            activeIcon: "󰅇"
            name: "Clipboard"
            notificationCount: 0
        }
        ListElement {
            icon: "󰢨"
            activeIcon: "󰅎"
            name: "Todo"
            notificationCount: 0
        }
        // ListElement {
        //     icon: "󰊿"
        //     activeIcon: "󰗊"
        //     name: "Translator"
        //     notificationCount: 0
        // }
        // ListElement {
        //     icon: "󱙺"
        //     activeIcon: "󰚩"
        //     name: "AI Bot"
        //     notificationCount: 0
        // }
    }

    // [المجموعة السفلية - التطبيقات]
    ListModel {
        id: bottomModel
        // ListElement {
        //     icon: ""
        //     activeIcon: ""
        //     name: "Favorites"
        //     notificationCount: 0
        // }
        // --- ADDED POWER OPTION HERE ---
        ListElement {
            icon: ""           // Standard Power Icon
            activeIcon: ""
            name: "Power"
            notificationCount: 0
        }
    }

    // ---------------------------------------------------------
    // 2. LOGIC (المنطق)
    // ---------------------------------------------------------

    // حسابات الإزاحة (Offsets) لتوحيد الاندكس
    readonly property int middleOffset: topModel.count
    readonly property int bottomOffset: topModel.count + middleModel.count

    Connections {
        target: NotifManager
        function onNotificationCountChanged() {
            if (root.notificationMenuIndex !== -1) {
                topButtonGroup.model.set(root.notificationMenuIndex, {
                    "notificationCount": NotifManager.notificationCount
                });
            }
        }
    }

    Component.onCompleted: {
        // ربط الإشعارات
        for (let i = 0; i < topModel.count; i++) {
            if (topModel.get(i).name === "Notifications") {
                root.notificationMenuIndex = i;
                topModel.set(i, {
                    "notificationCount": NotifManager.notificationCount
                });
                break;
            }
        }

        EventBus.on(Events.LEFT_MENU_IS_CLOSED, function () {
            try {
                closePanel();
            } catch (error) {
                LeftMenuStatus.changeIndex(-1);
            }
            changeIsMenuOpen.start();
        }, root);
    }

    // تنظيف صريح عند تدمير النافذة (فصل الشاشة) لمنع المستمعات القديمة من إطلاق أخطاء
    Component.onDestruction: EventBus.clearOwner(root)

    // استقبال التغيير من الخارج وتوزيعه على المجموعة الصحيحة
    Connections {
        target: LeftMenuStatus
        function onSelectedIndexTargeted(newIndex) {
            if (newIndex === -1) {
                topButtonGroup.currentIndex = -1;
                middleButtonGroup.currentIndex = -1;
                bottomButtonGroup.currentIndex = -1;
            } else
            // النطاق العلوي
            if (newIndex < root.middleOffset) {
                topButtonGroup.currentIndex = newIndex;
                middleButtonGroup.currentIndex = -1;
                bottomButtonGroup.currentIndex = -1;
            } else
            // النطاق الأوسط
            if (newIndex < root.bottomOffset) {
                topButtonGroup.currentIndex = -1;
                middleButtonGroup.currentIndex = newIndex - root.middleOffset;
                bottomButtonGroup.currentIndex = -1;
            } else
            // النطاق السفلي
            {
                topButtonGroup.currentIndex = -1;
                middleButtonGroup.currentIndex = -1;
                bottomButtonGroup.currentIndex = newIndex - root.bottomOffset;
            }
        }
    }

    // دالة مساعدة لتحديث الحالة
    function updateGlobalState(localIndex, offset, groupName) {
        if (localIndex !== -1) {
            // Reset other groups
            if (groupName !== "top")
                topButtonGroup.currentIndex = -1;
            if (groupName !== "middle")
                middleButtonGroup.currentIndex = -1;
            if (groupName !== "bottom")
                bottomButtonGroup.currentIndex = -1;

            const globalIndex = offset + localIndex;

            // Power Button Logic (Index 0)
            if (groupName === "bottom" && localIndex === 0) {
                // Deselect visually
                bottomButtonGroup.currentIndex = -1;

                // Trigger the external PanelWindow
                EventBus.emit(Events.TOGGLE_POWER_MENU);

                // Stop the side panel from expanding
                return;
            }

            // 3. Normal Sidebar Navigation
            root.activeMenuIndex = globalIndex;

            if (!root.panelOpen) {
                root.panelOpen = true;
                closePanelTimer.stop();
            }
            LeftMenuStatus.changeIndex(globalIndex);
        } else {
            // إذا ألغينا التحديد، نتأكد أن المجموعات الأخرى أيضاً غير محددة قبل الإغلاق
            if (topButtonGroup.currentIndex === -1 && middleButtonGroup.currentIndex === -1 && bottomButtonGroup.currentIndex === -1) {
                root.panelOpen = false;
                root.activeMenuIndex = -1;
                LeftMenuStatus.changeIndex(-1);
            }
        }

        changeIsMenuOpen.start();
    }

    // ---------------------------------------------------------
    // 3. UI GROUPS (الواجهات)
    // ---------------------------------------------------------

    // --- Column Wrapper (دمج الظلال في طبقة واحدة) ---
    Item {
        id: buttonColumnRoot
        anchors.fill: parent

        layer.enabled: true
        layer.effect: Shadow {
            shadowBlur: 0.6
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 2
        }

        // --- Top Group (System) ---
        ButtonGroup {
            id: topButtonGroup
            theme: ThemeManager.selectedTheme
            implicitWidth: 30

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 20
            anchors.leftMargin: 5
            anchors.rightMargin: 5

            useHand: true
            model: topModel

            onCurrentIndexChanged: updateGlobalState(topButtonGroup.currentIndex, 0, "top")
        }

        // --- Middle Group (Productivity) ---
        ButtonGroup {
            id: middleButtonGroup
            theme: ThemeManager.selectedTheme
            implicitWidth: 30

            anchors.centerIn: parent
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.rightMargin: 5

            useHand: true
            model: middleModel

            onCurrentIndexChanged: updateGlobalState(middleButtonGroup.currentIndex, root.middleOffset, "middle")
        }

        // --- Bottom Group (Apps) ---
        ButtonGroup {
            id: bottomButtonGroup
            theme: ThemeManager.selectedTheme
            implicitWidth: 30

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 20
            anchors.leftMargin: 5
            anchors.rightMargin: 5

            useHand: true
            model: bottomModel

            onCurrentIndexChanged: updateGlobalState(bottomButtonGroup.currentIndex, root.bottomOffset, "bottom")
        }
    }

    function closePanel() {
        if (closePanelTimer !== undefined) {
            closePanelTimer.start();
        } else {
            LeftMenuStatus.changeIndex(-1);
        }
    }

    Timer {
        id: closePanelTimer
        interval: 20
        repeat: false
        onTriggered: LeftMenuStatus.changeIndex(-1)
    }

    Timer {
        id: changeIsMenuOpen
        interval: 2
        repeat: false
        onTriggered: {
            root.margins.left = panelOpen && App.menuStyle === Consts.DOCKED_MOVING_BAR ? ThemeManager.selectedTheme.dimensions.menuWidth : 0;
        }
    }
}
