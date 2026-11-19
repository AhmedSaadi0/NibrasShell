// windows/smart_capsule/ui/IdleBar.qml

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "root:/themes"
import "root:/config"
import "root:/services"
import "root:/windows/smart_capsule/ui/components"
import "root:/windows/smart_capsule/logic"
import "root:/config/ConstValues.js" as C

Item {
    id: root

    readonly property color p1_start: ThemeManager.selectedTheme.colors.primary
    readonly property color p1_mid: ThemeManager.selectedTheme.colors.secondary
    readonly property color p1_end: ThemeManager.selectedTheme.colors.tertiary
    readonly property color p2_start: ThemeManager.selectedTheme.colors.error
    readonly property color p2_mid: ThemeManager.selectedTheme.colors.secondary
    readonly property color p2_end: ThemeManager.selectedTheme.colors.primary
    readonly property color p3_start: ThemeManager.selectedTheme.colors.tertiary
    readonly property color p3_mid: ThemeManager.selectedTheme.colors.tertiary
    readonly property color p3_end: ThemeManager.selectedTheme.colors.secondary
    readonly property int colorCycleDuration: 2000

    signal requestExpand(string mode)

    readonly property bool isMusicPlaying: MusicService.isPlaying
    readonly property bool showInfo: CapsuleManager.currentPriority > C.IDLE

    readonly property color themeColor: CapsuleManager.fgColor
    readonly property color contentColor: isMusicPlaying ? ThemeManager.selectedTheme.colors.onPrimary : themeColor

    property bool isEyesHovered: false
    property bool hoverActive: false
    property bool hoverLocked: false
    property int hoverHoldMs: 2500
    function startHoverHold() {
        hoverHoldTimer.stop();
        hoverHoldTimer.interval = hoverHoldMs;
        hoverHoldTimer.start();
    }

    property real requiredWidth: {
        if (!showInfo)
            return Math.max(clockRow.implicitWidth + 100, 312);
        if (!CapsuleManager.changeWidth)
            return 312;

        return Math.max(mainColumn.width + 100, 312);
    }

    property real requiredHeight: {
        const minHeight = ThemeManager.selectedTheme.dimensions.barWidgetsHeight;

        const eyesH = (EyeController.currentEmotion === "idle" || "music") ? 0 : (aiEyes.implicitHeight + 20);

        var contentH = 0;
        if (showInfo && CapsuleManager.changeHeight) {
            contentH = mainColumn.height + 25;
        }

        return Math.max(minHeight, eyesH, contentH);
    }

    implicitHeight: requiredHeight
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            HoverResponseManager.ensureHoverResponses();
        });
    }

    HoverHandler {
        id: capsuleHoverHandler
        acceptedDevices: PointerDevice.Mouse
        onHoveredChanged: {
            root.hoverActive = hovered;
            if (hovered)
                hoverHoldTimer.stop();
            else
                startHoverHold();
        }
    }

    Connections {
        target: CapsuleManager
        function onCurrentPriorityChanged() {
            if (CapsuleManager.currentPriority !== C.HOVER && !root.hoverActive)
                root.hoverLocked = false;
        }
    }

    Timer {
        id: hoverHoldTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.hoverActive)
                return;
            if (CapsuleManager.currentPriority > C.HOVER)
                return;
            root.hoverLocked = false;
            CapsuleManager.reset();
        }
    }

    Connections {
        target: HoverResponseManager
        function onFreshResponseReady(item) {
            if (!root.isEyesHovered)
                return;
            if (CapsuleManager.currentPriority > C.HOVER)
                return;
            if (root.isMusicPlaying)
                return;
            CapsuleManager.request({
                priority: C.HOVER,
                source: C.SRC_MUSIC,
                icon: "󰒋",
                text: item.text,
                timeout: 0,
                changeW: true
            });
            EyeController.showEmotion(item.emotion || "happy", 2000);
        }
    }

    Rectangle {
        id: musicAnimatedBg
        anchors.fill: parent
        radius: ThemeManager.selectedTheme.dimensions.elementRadius
        opacity: root.isMusicPlaying ? 1.0 : 0.0
        visible: opacity > 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                id: gradStart
                position: 0.0
                color: root.p1_start
            }
            GradientStop {
                id: gradMid
                position: 0.5
                color: root.p1_mid
            }
            GradientStop {
                id: gradEnd
                position: 1.0
                color: root.p1_end
            }
        }
        SequentialAnimation {
            running: root.isMusicPlaying && parent.visible
            loops: Animation.Infinite
            ParallelAnimation {
                ColorAnimation {
                    target: gradStart
                    property: "color"
                    to: root.p2_start
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradMid
                    property: "color"
                    to: root.p2_mid
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradEnd
                    property: "color"
                    to: root.p2_end
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
            }
            ParallelAnimation {
                ColorAnimation {
                    target: gradStart
                    property: "color"
                    to: root.p3_start
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradMid
                    property: "color"
                    to: root.p3_mid
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradEnd
                    property: "color"
                    to: root.p3_end
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
            }
            ParallelAnimation {
                ColorAnimation {
                    target: gradStart
                    property: "color"
                    to: root.p1_start
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradMid
                    property: "color"
                    to: root.p1_mid
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
                ColorAnimation {
                    target: gradEnd
                    property: "color"
                    to: root.p1_end
                    duration: root.colorCycleDuration
                    easing.type: Easing.InOutSine
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }
        }
    }

    Rectangle {
        id: progressBar
        height: parent.height
        radius: ThemeManager.selectedTheme.dimensions.elementRadius
        color: ThemeManager.selectedTheme.colors.onSurface
        opacity: 0.4
        anchors.left: parent.left
        visible: CapsuleManager.showProgress && root.showInfo
        width: parent.width * CapsuleManager.progressValue
        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    Item {
        id: leftIconArea
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        width: 24

        state: CapsuleManager.currentPriority > C.HOVER ? "INFO_MODE" : "WEATHER_MODE"

        Item {
            id: weatherContainer
            anchors.centerIn: parent
            width: parent.width
            height: parent.height

            opacity: 0
            scale: 0.5
            visible: opacity > 0

            WeatherIcon {
                anchors.centerIn: parent
                contentColor: root.contentColor

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    enabled: parent.parent.opacity > 0.5

                    onClicked: root.requestExpand("weather")
                    onEntered: {
                        if (root.hoverLocked)
                            return;
                        if (Weather) {
                            hoverHoldTimer.stop();
                            root.hoverLocked = true;
                            CapsuleManager.request({
                                priority: C.HOVER,
                                source: C.SRC_WEATHER,
                                icon: Weather.weatherIcon,
                                text: Weather.currentTemp + "° - " + Weather.weatherDescription,
                                timeout: 0,
                                changeW: false
                            });
                        }
                    }
                    onExited: {
                        startHoverHold();
                    }
                }
            }
        }

        Text {
            id: infoIcon
            anchors.centerIn: parent

            text: CapsuleManager.displayIcon
            font.family: ThemeManager.selectedTheme.typography.iconFont
            font.pixelSize: 18
            color: root.contentColor

            opacity: 0
            scale: 0.5
            visible: opacity > 0
        }

        states: [
            State {
                name: "WEATHER_MODE"
                PropertyChanges {
                    target: weatherContainer
                    opacity: 1
                    scale: 1
                }
                PropertyChanges {
                    target: infoIcon
                    opacity: 0
                    scale: 0.5
                }
            },
            State {
                name: "INFO_MODE"
                PropertyChanges {
                    target: weatherContainer
                    opacity: 0
                    scale: 0.5
                }
                PropertyChanges {
                    target: infoIcon
                    opacity: 1
                    scale: 1
                }
            }
        ]

        transitions: [
            Transition {
                from: "*"
                to: "*"
                ParallelAnimation {
                    NumberAnimation {
                        properties: "opacity, scale"
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        ]
    }

    Item {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: 10
        AIEyes {
            id: aiEyes
            eyeColor: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenterOffset: root.isMusicPlaying && EyeController.currentEmotion === "music" ? 0 : 3
            MouseArea {
                anchors.fill: parent
                onClicked: root.requestExpand("media")
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: {
                    root.isEyesHovered = true;
                    if (root.hoverLocked)
                        return;
                    if (CapsuleManager.currentPriority > C.HOVER)
                        return;

                    // TODO: -> send request to ai to give good response if no music is found
                    let infoText = MusicService.activePlayer !== null ? MusicService.activePlayer.identity : "Hi";

                    if (root.isMusicPlaying) {
                        infoText = MusicService.fullInfo;
                    }

                    if (root.isMusicPlaying) {
                        CapsuleManager.request({
                            priority: C.HOVER,
                            source: C.SRC_MUSIC,
                            icon: "󰝚",
                            text: infoText,
                            timeout: 0,
                            changeW: false,
                            progress: (MusicService.progress * 100),
                            showProgress: true
                        });
                        root.hoverLocked = true;
                        EyeController.showEmotion("happy", 2000);
                        return;
                    }

                    let response = HoverResponseManager.pickHoverResponse();
                    CapsuleManager.request({
                        priority: C.HOVER,
                        source: C.SRC_MUSIC,
                        icon: "󰒋",
                        text: response.text,
                        timeout: 0,
                        changeW: true
                    });
                    root.hoverLocked = true;
                    EyeController.showEmotion(response.emotion, 2000);

                    HoverResponseManager.scheduleExtraIfAny(response);
                    HoverResponseManager.requestFreshResponseIfAllowed();
                }
                onExited: {
                    root.isEyesHovered = false;
                    if (CapsuleManager.currentPriority > C.HOVER)
                        return;

                    startHoverHold();
                }
            }
        }
    }

    Item {
        id: centerItem
        anchors.centerIn: parent

        clip: false

        width: showInfo ? mainColumn.width : clockRow.implicitWidth
        height: showInfo ? mainColumn.height : clockRow.implicitHeight

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 5
            visible: !root.showInfo
            opacity: !root.showInfo ? 1 : 0

            transform: Translate {
                y: !root.showInfo ? 0 : -20
                Behavior on y {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutBack
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                }
            }

            SystemClock {
                id: sysClock
                precision: SystemClock.Minutes
            }
            Text {
                id: clockText
                text: sysClock.date.toLocaleString(Qt.locale(), "hh:mm AP - dddd, dd MMMM yyyy")
                font.bold: true
                font.pixelSize: 14
                color: root.contentColor
            }
        }

        Item {
            id: contentContainer

            anchors.centerIn: parent
            width: mainColumn.width
            height: mainColumn.height

            visible: root.showInfo
            opacity: root.showInfo ? 1 : 0

            transform: Translate {
                y: root.showInfo ? 0 : 20
                Behavior on y {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutBack
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                }
            }

            MouseArea {
                anchors.fill: parent

                hoverEnabled: true

                onEntered: {
                    CapsuleManager.stopRestTimer();
                    hoverHoldTimer.stop();
                }

                onExited: {
                    if (CapsuleManager.currentPriority <= C.HOVER) {
                        startHoverHold();
                    } else {
                        CapsuleManager.startRestTimer(3000);
                    }
                }
                preventStealing: true
                property real pressY: 0
                property bool swipeTriggered: false

                onPressed: mouse => {
                    pressY = mouse.y;
                    swipeTriggered = false;
                }

                onPositionChanged: mouse => {
                    if (swipeTriggered)
                        return;
                    if (!(mouse.buttons & Qt.LeftButton))
                        return;
                    if (mouse.y - pressY < -28) {
                        swipeTriggered = true;
                        hoverHoldTimer.stop();
                        CapsuleManager.stopRestTimer();
                        CapsuleManager.reset();
                    }
                }
            }

            Text {
                id: dummyTextMeasurement
                visible: false
                text: CapsuleManager.displayText
                font.bold: true
            }

            Column {
                id: mainColumn
                spacing: 4

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                width: {
                    if (!CapsuleManager.changeWidth)
                        return 220;
                    var contentNeeded = dummyTextMeasurement.implicitWidth + 30;
                    return Math.max(220, Math.min(contentNeeded, 500));
                }

                Row {
                    id: infoRow
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width

                    Text {
                        id: infoText
                        text: CapsuleManager.displayText
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.contentColor

                        width: parent.width - (infoIcon.implicitWidth + infoRow.spacing)

                        wrapMode: CapsuleManager.changeHeight ? Text.Wrap : Text.NoWrap
                        elide: CapsuleManager.changeHeight ? Text.ElideNone : Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }
                }

                Flow {
                    id: tagsFlow
                    spacing: 3
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    flow: Flow.LeftToRight

                    visible: CapsuleManager.tagsModel.length > 0

                    Repeater {
                        id: tagsRepeater
                        model: CapsuleManager.tagsModel
                        delegate: Rectangle {
                            id: tagsRectangle
                            height: 18
                            width: Math.min(tagText.implicitWidth + 16, tagsFlow.width)
                            property int groupRadius: ThemeManager.selectedTheme.dimensions.elementRadius / C.M3_BUTTON_RADIUS_DIVISOR
                            property int innerRadiusDiv: 4
                            topLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                            bottomLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                            topRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv
                            bottomRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv

                            opacity: mouseArea.pressed ? 0.7 : 0.9
                            property var colors: [ThemeManager.selectedTheme.colors.primary, ThemeManager.selectedTheme.colors.secondary, ThemeManager.selectedTheme.colors.tertiary, ThemeManager.selectedTheme.colors.tertiary, ThemeManager.selectedTheme.colors.secondary, ThemeManager.selectedTheme.colors.error]
                            property var textColors: [ThemeManager.selectedTheme.colors.onPrimary, ThemeManager.selectedTheme.colors.onSecondary, ThemeManager.selectedTheme.colors.onTertiary, ThemeManager.selectedTheme.colors.onTertiary, ThemeManager.selectedTheme.colors.onSecondary, ThemeManager.selectedTheme.colors.onError]
                            color: colors[index % colors.length]

                            Text {
                                id: tagText
                                text: modelData
                                anchors.centerIn: parent
                                color: tagsRectangle.textColors[index % tagsRectangle.textColors.length]
                                font.pixelSize: 10
                                font.bold: true
                                // font.family: ThemeManager.selectedTheme.typography.mainFont
                                elide: Text.ElideRight
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    // إشعار الموسيقى بأن المستخدم فتح اقتراح الذكاء الاصطناعي
                                    if (CapsuleManager.tagsSource === C.SRC_MUSIC)
                                        MusicService.markSuggestionOpened(modelData);

                                    var searchQuery = encodeURIComponent(modelData);
                                    var youtubeUrl = "https://www.youtube.com/results?search_query=" + searchQuery;

                                    Qt.openUrlExternally(youtubeUrl);
                                }
                            }
                            // ------------------
                        }
                    }
                }
            }
        }
    }
}
