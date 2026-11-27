// windows/leftwindow/dashboard/PowerProfiles.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import org.kde.kirigami as Kirigami

import "root:/windows/smart_capsule/logic"
import "root:/themes"
import "root:/components"
import "root:/config/ConstValues.js" as Consts

MenuCard {
    id: root

    // --- Texts & Content ---
    title: qsTr("Power Profiles") // "وضع الاداء"
    icon: ""
    cardColor: ThemeManager.selectedTheme.colors.surfaceContainer
    textColor: ThemeManager.selectedTheme.colors.onSurface

    property int defaultButtonWidth: 100
    property int defaultButtonHeight: 30

    property int buttonsRowSpacing: 7
    property int innerRadiusDiv: 3

    property string highPerformanceButtonLabel: qsTr("High")
    property string balancedButtonLabel: qsTr("Balanced")
    property string lowButtonLabel: qsTr("Low")

    // --- Power Profile Enums (from Quickshell.Services.UPower) ---
    readonly property int profileIndexPerformance: PowerProfile.Performance
    readonly property int profileIndexBalanced: PowerProfile.Balanced
    readonly property int profileIndexPowerSaver: PowerProfile.PowerSaver

    // -------------------------------------------------------------------------
    // --- State Properties
    // -------------------------------------------------------------------------
    property var selectedProfile: PowerProfiles.profile // Comes from UPower
    property bool _readyForNotifications: false
    property int _lastNotifiedProfile: -1
    property int _pendingProfile: -1
    property bool _pendingUserChange: false

    function _notifyProfileChange(profile) {
        CapsuleCoordinator.handlePowerProfileChange(profile);
    }

    function _notifyProfileError(message) {
        CapsuleCoordinator.handlePowerProfileError(message);
    }

    function _requestProfileChange(profile) {
        if (PowerProfiles.profile === profile)
            return;

        _pendingProfile = profile;
        _pendingUserChange = true;
        PowerProfiles.profile = profile;
        profileChangeTimer.restart();
    }

    onSelectedProfileChanged: {
        if (!_readyForNotifications) {
            _lastNotifiedProfile = selectedProfile;
            return;
        }

        if (selectedProfile === _lastNotifiedProfile)
            return;

        _lastNotifiedProfile = selectedProfile;

        if (_pendingUserChange && selectedProfile === _pendingProfile) {
            _pendingUserChange = false;
            profileChangeTimer.stop();
        }

        _notifyProfileChange(selectedProfile);
    }

    Component.onCompleted: {
        _readyForNotifications = true;
        _lastNotifiedProfile = selectedProfile;

        // تهيئة إحداثيات البداية فوراً لتجنب أي انزلاق عشوائي عند إقلاع البرنامج لأول مرة
        if (segmentedContainer.activeButton) {
            segmentedContainer.lastLeft = segmentedContainer.activeButton.x;
            segmentedContainer.previousLeft = segmentedContainer.activeButton.x;
            segmentedContainer.lastWidth = segmentedContainer.activeButton.width;
            segmentedContainer.lastHeight = segmentedContainer.activeButton.height;
            segmentedContainer.lastY = segmentedContainer.activeButton.y;
        }
    }

    Timer {
        id: profileChangeTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (_pendingUserChange && PowerProfiles.profile !== _pendingProfile) {
                _pendingUserChange = false;
                _notifyProfileError(qsTr("Failed to change power profile. Check system permissions."));
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        spacing: 6

        // -------------------------------------------------------------
        // حاوية الأزرار المنقسمة الموحدة (Segmented Buttons Container)
        // -------------------------------------------------------------
        Item {
            id: segmentedContainer
            Layout.fillWidth: true
            Layout.preferredHeight: root.defaultButtonHeight

            // رصد الزر النشط حالياً بناءً على وضع الطاقة الفعلي للنظام
            property var activeButton: {
                if (root.selectedProfile === root.profileIndexPerformance)
                    return highPerformanceButton;
                if (root.selectedProfile === root.profileIndexBalanced)
                    return balancedButton;
                if (root.selectedProfile === root.profileIndexPowerSaver)
                    return batterySavingButton;
                return null;
            }

            // إحداثيات الهدف للطرف الأيسر والطرف الأيمن للمحدد
            property real targetLeft: activeButton ? activeButton.x : lastLeft
            property real targetRight: activeButton ? (activeButton.x + activeButton.width) : (lastLeft + lastWidth)
            property real targetY: activeButton ? activeButton.y : lastY
            property real targetHeight: activeButton ? activeButton.height : lastHeight

            // متغيرات الذاكرة وتخزين الموقع السابق لتحديد اتجاه الحركة بدقة
            property real lastLeft: 0
            property real lastWidth: 100
            property real lastHeight: 30
            property real lastY: 0
            property real previousLeft: 0
            property bool showHighlight: activeButton !== null

            onActiveButtonChanged: {
                if (activeButton) {
                    previousLeft = lastLeft; // تذكر آخر موقع لمعرفة اتجاه السحب (يمين أم يسار)

                    lastLeft = activeButton.x;
                    lastWidth = activeButton.width;
                    lastHeight = activeButton.height;
                    lastY = activeButton.y;
                }
            }

            // -----------------------------------------------------------------
            // 1. خلفية التحديد الهلامي المرن (Jelly Selection Highlight)
            // -----------------------------------------------------------------
            Rectangle {
                id: selectionHighlight

                // [حل المشكلة]: تعريف الخصائص محلياً هنا لتصبح تابعة للـ Rectangle مباشرة
                property real animLeft: segmentedContainer.targetLeft
                property real animRight: segmentedContainer.targetRight

                x: animLeft
                y: segmentedContainer.targetY

                // العرض هو ناتج الفرق الديناميكي بين حركة الطرف الأيمن والأيسر
                width: Math.max(10, animRight - animLeft)
                height: segmentedContainer.targetHeight

                color: ThemeManager.selectedTheme.colors.primary

                // ربط الزوايا ديناميكياً لتتشكل وتتأقلم بسلاسة مع زوايا الزر النشط حالياً
                topLeftRadius: segmentedContainer.activeButton ? segmentedContainer.activeButton.topLeftRadius : 0
                topRightRadius: segmentedContainer.activeButton ? segmentedContainer.activeButton.topRightRadius : 0
                bottomLeftRadius: segmentedContainer.activeButton ? segmentedContainer.activeButton.bottomLeftRadius : 0
                bottomRightRadius: segmentedContainer.activeButton ? segmentedContainer.activeButton.bottomRightRadius : 0

                opacity: segmentedContainer.showHighlight ? 1.0 : 0.0

                // مزامنة انكماش الحركة والتفاعل مع الزر النشط عند النقرة الفورية
                scale: segmentedContainer.activeButton ? segmentedContainer.activeButton.scale : 1.0

                // -----------------------------------------------------------------
                // ذكاء التحكم بتمدد وتقلص الأطراف (Elastic Behavior Engine)
                // -----------------------------------------------------------------
                Behavior on animLeft {
                    enabled: segmentedContainer.showHighlight
                    NumberAnimation {
                        // إذا كنا نتحرك يساراً، فالطرف الأيسر هو القائد (يتحرك بسرعة 240ms)
                        // إذا كنا نتحرك يميناً، فالطرف الأيسر هو الذيل المتأخر (يتحرك ببطء 360ms)
                        duration: (segmentedContainer.targetLeft < segmentedContainer.previousLeft) ? 240 : 360
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on animRight {
                    enabled: segmentedContainer.showHighlight
                    NumberAnimation {
                        // إذا كنا نتحرك يميناً، فالطرف الأيمن هو القائد (يتحرك بسرعة 240ms)
                        // إذا كنا نتحرك يساراً، فالطرف الأيمن هو الذيل المتأخر (يتحرك ببطء 360ms)
                        duration: (segmentedContainer.targetLeft > segmentedContainer.previousLeft) ? 240 : 360
                        easing.type: Easing.OutQuint
                    }
                }
                // -----------------------------------------------------------------

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                // انميشن تشكل وتحول زوايا المحدد بنعومة هندسية أثناء الانتقال
                Behavior on topLeftRadius {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on topRightRadius {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on bottomLeftRadius {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on bottomRightRadius {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            // 2. توزيع الأزرار الأصلي (الطبقة الأمامية)
            RowLayout {
                id: widgetsRow
                anchors.fill: parent
                spacing: root.buttonsRowSpacing

                MButton {
                    id: highPerformanceButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25
                    height: root.defaultButtonHeight
                    text: root.highPerformanceButtonLabel
                    iconFirst: true
                    iconText: "󰓅"
                    iconSize: 16
                    onClicked: {
                        _requestProfileChange(PowerProfile.Performance);
                    }
                    enabled: PowerProfiles.hasPerformanceProfile
                    isActive: root.selectedProfile === root.profileIndexPerformance

                    normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                    normalForeground: ThemeManager.selectedTheme.colors.onSurface
                    hoverOpacity: 0.16

                    topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                    bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                }

                MButton {
                    id: balancedButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25
                    height: root.defaultButtonHeight
                    text: root.balancedButtonLabel
                    iconFirst: true
                    iconText: "󰾅"
                    iconSize: 16
                    onClicked: {
                        _requestProfileChange(PowerProfile.Balanced);
                    }
                    isActive: root.selectedProfile === root.profileIndexBalanced

                    normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                    normalForeground: ThemeManager.selectedTheme.colors.onSurface
                    hoverOpacity: 0.16

                    topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                    topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                    bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                    bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                }

                MButton {
                    id: batterySavingButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25
                    height: root.defaultButtonHeight
                    text: root.lowButtonLabel
                    iconFirst: true
                    iconText: "󰾆"
                    iconSize: 16
                    onClicked: {
                        _requestProfileChange(PowerProfile.PowerSaver);
                    }
                    isActive: root.selectedProfile === root.profileIndexPowerSaver

                    normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                    normalForeground: ThemeManager.selectedTheme.colors.onSurface
                    hoverOpacity: 0.16

                    bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                    topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: !PowerProfiles.hasPerformanceProfile

            Text {
                text: ""
                font.family: ThemeManager.selectedTheme.typography.iconFont
                font.pixelSize: 12
                color: ThemeManager.selectedTheme.colors.onSurfaceVariant
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("High performance profile is not available on this device.")
                font.family: ThemeManager.selectedTheme.typography.bodyFont
                font.pixelSize: 11
                color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                wrapMode: Text.Wrap
            }
        }
    }
}
