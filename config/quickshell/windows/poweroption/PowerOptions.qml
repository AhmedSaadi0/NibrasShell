// windows/poweroption/PowerOptions.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

import "root:/windows/smart_capsule/logic"
import "root:/config/ConstValues.js" as C
import "root:/components"
import "root:/themes"
import "root:/services"

Item {
    id: root
    anchors.fill: parent

    readonly property var theme: ThemeManager.selectedTheme

    property var pendingActionCommand: []
    property string pendingActionMessage: ""
    property string confirmActionText: ""
    property color currentAccentColor: theme.colors.primary
    property color currentAccentForeground: theme.colors.onPrimary

    signal close

    focus: true
    Keys.onEscapePressed: {
        root.close();
    }

    Process {
        id: powerActionProcess
        command: root.pendingActionCommand
        function start() {
            powerActionProcess.running = true;
        }
    }

    // الحاوية الكبرى المتوسطة في الشاشة
    ColumnLayout {
        anchors.centerIn: parent
        spacing: theme.dimensions.spacingLarge * 2
        width: parent.width

        // 1. العنوان والوصف
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: theme.dimensions.spacingSmall

            Text {
                text: viewStack.depth > 1 ? root.pendingActionMessage : qsTr("System Control")
                color: theme.colors.onSurface
                font.family: theme.typography.bodyFont
                font.pixelSize: theme.typography.heading1Size
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: viewStack.depth > 1 ? qsTr("This action cannot be undone") : qsTr("Choose an action to perform")
                color: theme.colors.onSurfaceVariant
                font.family: theme.typography.bodyFont
                font.pixelSize: theme.typography.medium
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.7
            }
        }

        // 2. منطقة الأزرار (StackView)
        StackView {
            id: viewStack
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 800
            Layout.preferredHeight: 180
            clip: false

            initialItem: mainActions

            pushEnter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.92
                    to: 1
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }
            pushExit: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 250
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            popEnter: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.95
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            popExit: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 200
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.92
                    duration: 200
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    // --- واجهة الأزرار الرئيسية مع المحدد المنزلق الذكي والمؤجل ---
    Component {
        id: mainActions
        Item {
            id: mainContainer
            width: viewStack.width
            height: viewStack.height

            // رصد حالة التحويم الحالية على الأزرار
            property var activeTile: {
                if (tileShutDown.hovered)
                    return tileShutDown;
                if (tileRestart.hovered)
                    return tileRestart;
                if (tileSuspend.hovered)
                    return tileSuspend;
                if (tileLogOut.hovered)
                    return tileLogOut;
                return null;
            }

            // تحديد إحداثيات الهدف للمحدد المنزلق
            property real targetX: lastX
            property real targetY: lastY
            property real targetWidth: lastWidth
            property real targetHeight: lastHeight

            // ذاكرة الحركة واللون الأخير
            property real lastX: 0
            property real lastY: 0
            property real lastWidth: 150
            property real lastHeight: 150
            property color lastAccentColor: theme.colors.primary

            // حالة التحكم بظهور المحدد (تظل true أثناء عبور الفراغات بفضل المؤقت)
            property bool showHighlight: false

            onActiveTileChanged: {
                if (activeTile) {
                    // إيقاف مؤقت التلاشي فوراً لأن الماوس فوق زر نشط
                    fadeDelayTimer.stop();
                    showHighlight = true;

                    // احتساب الموقع المطلق بدقة متناهية
                    var absolutePos = activeTile.mapToItem(mainContainer, 0, 0);
                    targetX = absolutePos.x;
                    targetY = absolutePos.y;
                    targetWidth = activeTile.width;
                    targetHeight = activeTile.height;
                    lastAccentColor = activeTile.accentColor;
                } else {
                    // الماوس في الفراغ البيني أو غادر المجموعة، نبدأ مؤقت المهلة قبل التلاشي
                    fadeDelayTimer.start();
                }
            }

            // مؤقت سد الفجوات: يمنح 180ms كافية جداً لعبور الفراغات دون تلاشي المحدد
            Timer {
                id: fadeDelayTimer
                interval: 180
                repeat: false
                onTriggered: mainContainer.showHighlight = false
            }

            // 1. حاوية الأزرار الأساسية (الطبقة السفلية)
            RowLayout {
                id: mainLayout
                anchors.centerIn: parent
                spacing: theme.dimensions.spacingLarge

                PowerTile {
                    id: tileShutDown
                    icon: "\uf011"
                    label: qsTr("Shut Down")
                    accentColor: theme.colors.error
                    onClicked: {
                        root.currentAccentColor = accentColor;
                        root.currentAccentForeground = theme.colors.onError;
                        root.pendingActionCommand = ["systemctl", "poweroff"];
                        root.pendingActionMessage = qsTr("Shut Down System?");
                        root.confirmActionText = qsTr("Shut Down");
                        viewStack.push(confirmActions);
                    }
                }

                PowerTile {
                    id: tileRestart
                    icon: "\uf01e"
                    label: qsTr("Restart")
                    accentColor: theme.colors.secondary
                    onClicked: {
                        root.currentAccentColor = accentColor;
                        root.currentAccentForeground = theme.colors.onSecondary;
                        root.pendingActionCommand = ["systemctl", "reboot"];
                        root.pendingActionMessage = qsTr("Restart System?");
                        root.confirmActionText = qsTr("Restart");
                        viewStack.push(confirmActions);
                    }
                }

                PowerTile {
                    id: tileSuspend
                    icon: "\uf186"
                    label: qsTr("Suspend")
                    accentColor: theme.colors.tertiary
                    onClicked: {
                        root.currentAccentColor = accentColor;
                        root.currentAccentForeground = theme.colors.onTertiary;
                        root.pendingActionCommand = ["systemctl", "suspend"];
                        root.pendingActionMessage = qsTr("Suspend System?");
                        root.confirmActionText = qsTr("Suspend");
                        viewStack.push(confirmActions);
                    }
                }

                PowerTile {
                    id: tileLogOut
                    icon: "\uf08b"
                    label: qsTr("Log Out")
                    accentColor: theme.colors.primary
                    onClicked: {
                        root.currentAccentColor = accentColor;
                        root.currentAccentForeground = theme.colors.onPrimary;
                        root.pendingActionCommand = ["hyprctl", "dispatch", "hl.dsp.exit()"];
                        root.pendingActionMessage = qsTr("Exit Session?");
                        root.confirmActionText = qsTr("Log Out");
                        viewStack.push(confirmActions);
                    }
                }
            }

            // 2. المحدد المنزلق الذكي والسينمائي (الطبقة العلوية الطافية)
            Rectangle {
                id: slidingHighlight
                x: mainContainer.targetX
                y: mainContainer.targetY
                width: mainContainer.targetWidth
                height: mainContainer.targetHeight
                radius: theme.dimensions.elementRadius

                color: Qt.rgba(mainContainer.lastAccentColor.r, mainContainer.lastAccentColor.g, mainContainer.lastAccentColor.b, 0.15)
                border.color: mainContainer.lastAccentColor
                border.width: 1.5

                enabled: false // لا يعترض نقرات الماوس لتمر للأزرار بالأسفل

                // نتحكم بالشفافية بناءً على المؤقت الذكي لسد الفجوات
                opacity: mainContainer.showHighlight ? 1.0 : 0.0

                // مزامنة دقيقة لنسبة الانكماش والاتساع التفاعلي مع الزر النشط
                scale: mainContainer.activeTile ? mainContainer.activeTile.scale : 1.0

                // انميشن الحركة الأفقية المتباطئة والأنيقة جداً لمظهر سينمائي
                // تم ربط تفعيل الانميشن (enabled) بحالة الظهور لتجنب قفزة السحب عند أول تحويم
                Behavior on x {
                    enabled: mainContainer.showHighlight
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on y {
                    enabled: mainContainer.showHighlight
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on width {
                    enabled: mainContainer.showHighlight
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on height {
                    enabled: mainContainer.showHighlight
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 250
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 250
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
            }
        }
    }

    Component {
        id: confirmActions
        Item {
            width: viewStack.width
            height: viewStack.height

            RowLayout {
                anchors.centerIn: parent
                spacing: theme.dimensions.spacingLarge * 1.5

                MButton {
                    text: qsTr("Back")
                    iconText: "\uf060"
                    iconFirst: true
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 55
                    normalBackground: Qt.rgba(theme.colors.surfaceContainer.r, theme.colors.surfaceContainer.g, theme.colors.surfaceContainer.b, 0.4)
                    onClicked: viewStack.pop()
                }

                MButton {
                    text: root.confirmActionText
                    iconText: "\uf00c"
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 55
                    normalBackground: Qt.rgba(root.currentAccentColor.r, root.currentAccentColor.g, root.currentAccentColor.b, 0.6)
                    normalForeground: root.currentAccentForeground
                    focus: true
                    Keys.onReturnPressed: clicked()
                    onClicked: {
                        enabled = false;
                        root.prepareGoodbye(root.confirmActionText);
                    }
                }
            }
        }
    }

    // --- مكون البلاطة (PowerTile) ---
    component PowerTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string label: ""
        property color accentColor: theme.colors.primary
        signal clicked
        width: 150
        height: 150

        radius: theme.dimensions.elementRadius

        readonly property bool hovered: mouseArea.containsMouse

        // خلفية ثابتة للأزرار تعمل كـ مسار (Track) ينساب المحدد المنزلق فوقه بنعومة
        color: Qt.rgba(theme.colors.surfaceContainer.r, theme.colors.surfaceContainer.g, theme.colors.surfaceContainer.b, 0.3)
        border.color: theme.colors.onSurface.alpha(0.1)
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: icon
                font.family: theme.typography.iconFont
                font.pixelSize: 40
                color: mouseArea.hovered ? accentColor : theme.colors.onSurface
                Layout.alignment: Qt.AlignHCenter
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            Text {
                text: label
                font.family: theme.typography.bodyFont
                font.pixelSize: theme.typography.medium
                color: theme.colors.onSurface
                Layout.alignment: Qt.AlignHCenter
                opacity: mouseArea.hovered ? 1.0 : 0.6

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileRoot.clicked()
        }

        scale: mouseArea.pressed ? 0.96 : (mouseArea.hovered ? 1.04 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutBack
            }
        }
    }

    Timer {
        id: executionDelayTimer
        interval: 2500
        repeat: false
        onTriggered: powerActionProcess.start()
    }

    function prepareGoodbye(actionType) {
        root.close();

        let actionKey = "";
        let fallbackEmotion = "wink";
        let fallbackText = "";
        let capsuleIcon = "";
        let capsuleColor = theme.colors.primary;

        if (actionType === qsTr("Shut Down")) {
            actionKey = "shutdown";
            fallbackEmotion = "sleeping";
            fallbackText = "System shutting down... Goodbye!";
            capsuleIcon = "\uf011";
            capsuleColor = theme.colors.error;
        } else if (actionType === qsTr("Restart")) {
            actionKey = "reboot";
            fallbackEmotion = "happy";
            fallbackText = "System is restarting...";
            capsuleIcon = "\uf01e";
            capsuleColor = theme.colors.secondary;
        } else if (actionType === qsTr("Suspend")) {
            actionKey = "suspend";
            fallbackEmotion = "sleeping";
            fallbackText = "System is going to sleep...";
            capsuleIcon = "\uf186";
            capsuleColor = theme.colors.tertiary;
        } else {
            actionKey = "logout";
            fallbackEmotion = "wink";
            fallbackText = "Logging out... See you soon!";
            capsuleIcon = "\uf08b";
        }

        const responses = SystemService.systemActionResponses;
        let finalEmotion = fallbackEmotion;
        let finalText = fallbackText;

        if (responses && responses[actionKey] && responses[actionKey].text) {
            finalEmotion = responses[actionKey].emotion || fallbackEmotion;
            finalText = responses[actionKey].text;
        }

        EyeController.showEmotion(finalEmotion, 5000);

        CapsuleManager.request({
            priority: C.NOTIFICATION,
            source: "System",
            icon: capsuleIcon,
            text: finalText,
            bgColor1: capsuleColor,
            timeout: 5000
        });

        executionDelayTimer.start();
    }
}
