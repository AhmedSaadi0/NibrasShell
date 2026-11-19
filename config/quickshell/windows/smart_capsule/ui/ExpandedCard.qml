import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/themes"
import "root:/components"
import "root:/config/ConstValues.js" as C
import "root:/windows/smart_capsule/logic"
import "root:/windows/smart_capsule/ui/components"
import "root:/services"

Item {
    id: root

    property string currentTab: "media"
    property bool showAiOverlay: false

    signal closeRequested

    readonly property int minWidth: 410
    readonly property int minHeight: 220

    implicitWidth: minWidth
    implicitHeight: showAiOverlay ? Math.max(minHeight, aiContentLayout.implicitHeight + 80) : minHeight

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutBack
        }
    }

    onVisibleChanged: {
        if (!root.visible) {
            showAiOverlay = false;
        }
    }

    // زر الإغلاق
    MButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 15
        anchors.rightMargin: 15
        anchors.leftMargin: 15
        text: "✕"
        font: ThemeManager.selectedTheme.typography.iconFont
        implicitWidth: 34
        implicitHeight: 30
        onClicked: root.closeRequested()
        normalBackground: CapsuleManager.fgColor.alpha(0.1)
        normalForeground: CapsuleManager.fgColor
        hoveredBackground: CapsuleManager.fgColor.alpha(0.2)
        downForeground: CapsuleManager.fgColor
        cursorShape: Qt.PointingHandCursor
        z: 20
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 15
        spacing: 0

        // 1. المبدل (Switcher)
        IslandSwitcher {
            Layout.alignment: Qt.AlignHCenter
            fgColor: CapsuleManager.fgColor
            currentTab: root.currentTab
            onTabClicked: tab => {
                root.currentTab = tab;
                if (root.showAiOverlay)
                    updateAiEmotion();
            }
        }

        // 2. منطقة المحتوى
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- المحتوى العادي (Media / Weather) ---
            Item {
                anchors.fill: parent
                opacity: root.showAiOverlay ? 0.1 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }

                MediaExpanded {
                    anchors.fill: parent
                    opacity: root.currentTab === "media" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    transform: Translate {
                        x: root.currentTab === "media" ? 0 : 50
                        Behavior on x {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                WeatherExpanded {
                    anchors.fill: parent
                    opacity: root.currentTab === "weather" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    transform: Translate {
                        x: root.currentTab === "weather" ? 0 : -50
                        Behavior on x {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------
            // 3. طبقة الذكاء الاصطناعي (AI Overlay)
            // ---------------------------------------------------------
            // TODO: -> Move to new component file
            Rectangle {
                id: aiOverlay
                anchors.fill: parent

                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 10
                anchors.bottomMargin: 10

                radius: ThemeManager.selectedTheme.dimensions.shapeMedium
                color: "transparent"
                border.color: CapsuleManager.fgColor.alpha(0.2)
                border.width: 1

                visible: root.showAiOverlay
                opacity: visible ? 1 : 0
                scale: visible ? 1 : 0.95

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: CapsuleManager.bgColor1.alpha(0.80)
                        Behavior on color {
                            ColorAnimation {
                                duration: 500
                            }
                        }
                    }
                    GradientStop {
                        position: 1.0
                        color: CapsuleManager.bgColor2.alpha(0.80)
                        Behavior on color {
                            ColorAnimation {
                                duration: 500
                            }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.showAiOverlay = false
                    propagateComposedEvents: false
                }

                ColumnLayout {
                    id: aiContentLayout

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 15

                    spacing: 10

                    // العنوان + Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "✨ AI Insight"
                            font.bold: true
                            font.pixelSize: 12
                            color: CapsuleManager.fgColor.alpha(0.6)
                        }

                        Rectangle {
                            visible: root.currentTab === "weather" && Weather.aiTrendBadge !== ""
                            color: CapsuleManager.fgColor.alpha(0.1)
                            radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: badgeText.implicitWidth + 10
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: Weather.aiTrendBadge
                                color: CapsuleManager.fgColor
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // النص الأساسي
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 4

                        text: {
                            if (root.currentTab === "weather")
                                return Weather.aiSummaryText || "Analyzing weather patterns ... ";
                            return MusicService.aiComment || "Vibing to the rhythm ... ";
                        }
                        color: CapsuleManager.fgColor
                        font.pixelSize: 14
                        lineHeight: 1.2
                    }

                    Text {
                        visible: root.currentTab === "weather" && Weather.aiSmartPollingDetails !== ""
                        Layout.fillWidth: true
                        text: "⏱ " + Weather.aiSmartPollingDetails
                        color: CapsuleManager.fgColor.alpha(0.5)
                        font.pixelSize: 10

                        wrapMode: Text.Wrap
                    }

                    // الوسوم
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredWidth: parent.width
                        spacing: 3

                        property var currentTags: {
                            if (root.currentTab === "weather")
                                return Weather.aiTags;
                            else
                                return MusicService.aiTags;
                        }

                        Repeater {
                            id: tagsRepeater
                            model: parent.currentTags

                            delegate: Rectangle {
                                id: tagRect
                                height: 20
                                width: tagTxt.implicitWidth + 16
                                property int groupRadius: ThemeManager.selectedTheme.dimensions.elementRadius / C.M3_BUTTON_RADIUS_DIVISOR
                                property int innerRadiusDiv: 4
                                topLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                                bottomLeftRadius: index === 0 ? groupRadius : groupRadius / innerRadiusDiv
                                topRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv
                                bottomRightRadius: index === tagsRepeater.count - 1 ? groupRadius : groupRadius / innerRadiusDiv

                                readonly property bool isClickable: root.currentTab === "media"

                                color: isClickable && tagMouseArea.containsMouse ? CapsuleManager.fgColor.alpha(0.3) : CapsuleManager.fgColor.alpha(0.1)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }

                                Text {
                                    id: tagTxt
                                    text: modelData
                                    anchors.centerIn: parent
                                    color: CapsuleManager.fgColor
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: tagMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: parent.isClickable
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                    onClicked: {
                                        // إشعار الموسيقى بأن المستخدم فتح اقتراح الذكاء الاصطناعي
                                        if (root.currentTab === "media")
                                            MusicService.markSuggestionOpened(modelData);

                                        Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + encodeURIComponent(modelData));
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredHeight: 5
                    }
                }
            }
        }
    }

    // العيون
    AIEyes {
        id: mainEyes
        eyeColor: CapsuleManager.fgColor
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 20
        anchors.rightMargin: 10
        anchors.leftMargin: 10

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                root.showAiOverlay = !root.showAiOverlay;
                if (root.showAiOverlay) {
                    root.updateAiEmotion();
                } else {
                    EyeController.showEmotion("wink", 1000);
                }
            }
            onEntered: parent.scale = 1.1
            onExited: parent.scale = 1.0
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutBack
            }
        }
    }

    function updateAiEmotion() {
        let emotion = "";
        if (root.currentTab === "weather")
            emotion = Weather.aiEmotion;
        else
            emotion = MusicService.aiEmotion;

        if (emotion === "" || emotion === undefined)
            emotion = "happy";
        EyeController.showEmotion(emotion, 5000);
    }
}
