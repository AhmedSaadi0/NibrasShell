import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "root:/themes"
import "root:/config/EventNames.js" as Events
import "root:/config"
import "root:/components"

// TODO: -> Improve this and seprat in into several files
PanelWindow {
    id: root
    visible: false
    implicitWidth: 1400
    implicitHeight: 900
    color: "transparent"

    Process {
        id: getBindings
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(data);
                    hyprBinds = response;
                } catch (e) {
                    console.error("Wifi Action JSON Parse Error:", e);
                    root.loadingBssid = "";
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                console.error("Wifi Action Stderr:", data);
                root.loadingBssid = "";
            }
        }

        function startAction(fullCommand) {
            this.running = true;
        }
    }

    Component.onCompleted: {
        root.rebuildCategories();
        getBindings.startAction();
        EventBus.on(Events.OPEN_CHEATSHEET, function () {
            root.visible = !root.visible;
        }, root);
    }

    NibrasShellShortcut {
        id: openCheatsheet
        name: "openCheatsheet"
        onPressed: root.visible = !root.visible
    }

    property var hyprBinds: []

    // دالة لتحويل modmask إلى اسم مفهوم
    // TODO: -> make sure to cover all modmask
    function getModmaskName(modmask) {
        switch (modmask) {
        case 0:
            return "No Modifier";
        case 1:
            return "Shift";
        case 4:
            return "Ctrl";
        case 8:
            return "Alt";
        case 64:
            return "Super";
        case 65:
            return "Super + Shift";
        case 68:
            return "Super + Ctrl";
        case 72:
            return "Super + Alt";
        case 9:
            return "Ctrl + Alt";
        default:
            return "Modifier " + modmask;
        }
    }

    // دالة لتحويل modmask إلى لون مميز باستخدام ألوان الثيم
    function getModmaskColor(modmask) {
        var theme = ThemeManager.selectedTheme;
        switch (modmask) {
        case 0:
            return theme.colors.onSurfaceVariant;
        case 64:
            return theme.colors.primary;
        case 65:
            return Qt.lighter(theme.colors.primary, 1.2);
        case 68:
            return Qt.darker(theme.colors.primary, 1.1);
        case 72:
            return theme.colors.surfaceContainerHigh;
        case 9:
            return theme.colors.primaryContainer;
        default:
            return theme.colors.secondary;
        }
    }

    function getModmaskTextColor(modmask) {
        var theme = ThemeManager.selectedTheme;
        switch (modmask) {
        case 0:
            return theme.colors.onSurface;
        case 64:
        case 65:
        case 68:
            return theme.colors.onPrimary;
        case 72:
            return theme.colors.onSurfaceVariant;
        case 9:
            return theme.colors.onPrimaryContainer;
        default:
            return theme.colors.onSecondary;
        }
    }

    // تجميع البيانات (يُحسب مرة واحدة عند تغيير binds)
    property var categorizedShortcuts: []

    function rebuildCategories() {
        var categories = {};
        var filtered = hyprBinds;

        filtered.forEach(function (bind) {
            if (!categories[bind.modmask]) {
                categories[bind.modmask] = [];
            }
            categories[bind.modmask].push(bind);
        });

        var result = [];
        for (var modmask in categories) {
            if (categories.hasOwnProperty(modmask)) {
                result.push({
                    modmaskValue: parseInt(modmask),
                    modmaskName: getModmaskName(parseInt(modmask)),
                    shortcuts: categories[modmask],
                    color: getModmaskColor(parseInt(modmask))
                });
            }
        }
        root.categorizedShortcuts = result;
    }

    onHyprBindsChanged: rebuildCategories()

    Rectangle {
        anchors.fill: parent
        color: ThemeManager.selectedTheme.colors.surfaceContainer
        radius: ThemeManager.selectedTheme.dimensions.elementRadius

        MButton {
            id: closeBtn
            anchors {
                top: parent.top
                right: parent.right
                margins: 20
            }
            width: 45
            height: 45
            text: "󰅖"
            cursorShape: Qt.PointingHandCursor
            normalBackground: "transparent"
            hoveredBackground: ThemeManager.selectedTheme.colors.error.alpha(0.5)
            onClicked: root.visible = false
            z: 100 // ليكون فوق كل شيء
            font: ThemeManager.selectedTheme.typography.iconFont
        }

        // تأثير خلفية
        Rectangle {
            anchors.fill: parent
            opacity: 0.03
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: ThemeManager.selectedTheme.colors.primary
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // العنوان الرئيسي
        Text {
            id: title
            text: "🎯 Hyprland Shortcuts Cheat Sheet"
            font.pixelSize: ThemeManager.selectedTheme.typography.heading1Size
            font.family: ThemeManager.selectedTheme.typography.bodyFont
            font.bold: true
            color: ThemeManager.selectedTheme.colors.primary
            anchors {
                top: parent.top
                topMargin: 30
                horizontalCenter: parent.horizontalCenter
            }
        }

        // إحصائيات
        Text {
            id: stats
            text: "📊 " + hyprBinds.filter(bind => bind.has_description).length + " shortcuts available • " + categorizedShortcuts.length + " modifier groups"
            font.pixelSize: ThemeManager.selectedTheme.typography.small
            font.family: ThemeManager.selectedTheme.typography.bodyFont
            color: ThemeManager.selectedTheme.colors.onSurfaceVariant
            anchors {
                top: title.bottom
                topMargin: ThemeManager.selectedTheme.dimensions.spacingMedium
                horizontalCenter: parent.horizontalCenter
            }
        }

        // الشبكة الرئيسية
        Flickable {
            id: mainFlickable
            anchors {
                top: stats.bottom
                topMargin: 30
                bottom: parent.bottom
                bottomMargin: 30
                left: parent.left
                leftMargin: 30
                right: parent.right
                rightMargin: 30
            }
            contentWidth: flow.width
            contentHeight: flow.height
            clip: true

            Flow {
                id: flow
                width: mainFlickable.width
                spacing: 25

                Repeater {
                    model: categorizedShortcuts

                    Rectangle {
                        id: categoryCard
                        width: Math.min(flow.width, 430)
                        height: 500
                        color: ThemeManager.selectedTheme.colors.surfaceContainerHigh
                        radius: ThemeManager.selectedTheme.dimensions.baseRadius
                        border.width: 1
                        border.color: Qt.rgba(ThemeManager.selectedTheme.colors.primary.r, ThemeManager.selectedTheme.colors.primary.g, ThemeManager.selectedTheme.colors.primary.b, 0.1)

                        Column {
                            id: categoryContent
                            width: parent.width - 30
                            anchors.centerIn: parent
                            spacing: ThemeManager.selectedTheme.dimensions.spacingLarge

                            // رأس القسم
                            Rectangle {
                                width: parent.width
                                height: 55
                                color: modelData.color
                                radius: ThemeManager.selectedTheme.dimensions.elementRadius

                                // تأثير تدرج لرأس القسم
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: modelData.color
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: Qt.darker(modelData.color, 1.1)
                                    }
                                }

                                Text {
                                    text: modelData.modmaskName
                                    font.pixelSize: ThemeManager.selectedTheme.typography.heading3Size
                                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                                    font.bold: true
                                    color: getModmaskTextColor(modelData.modmask)
                                    anchors.centerIn: parent
                                }

                                Text {
                                    text: modelData.shortcuts.length + " shortcuts"
                                    font.pixelSize: ThemeManager.selectedTheme.typography.small
                                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                                    color: getModmaskTextColor(modelData.modmask)
                                    anchors {
                                        right: parent.right
                                        rightMargin: 15
                                        verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // قائمة الاختصارات مع تمرير داخلي
                            ListView {
                                id: shortcutsListView
                                width: parent.width
                                height: 400
                                clip: true
                                spacing: ThemeManager.selectedTheme.dimensions.spacingMedium
                                model: modelData.shortcuts

                                delegate: Rectangle {
                                    width: shortcutsListView.width
                                    height: Math.max(75, shortcutColumn.height + 20)
                                    color: ThemeManager.selectedTheme.colors.surfaceContainer
                                    radius: ThemeManager.selectedTheme.dimensions.elementRadius
                                    border.width: 1
                                    border.color: Qt.rgba(ThemeManager.selectedTheme.colors.primary.r, ThemeManager.selectedTheme.colors.primary.g, ThemeManager.selectedTheme.colors.primary.b, 0.05)

                                    Column {
                                        id: shortcutColumn
                                        width: parent.width - 20
                                        anchors.centerIn: parent
                                        spacing: ThemeManager.selectedTheme.dimensions.spacingSmall

                                        Text {
                                            text: formatKey(modelData)
                                            font.pixelSize: ThemeManager.selectedTheme.typography.medium
                                            font.family: ThemeManager.selectedTheme.typography.bodyFont
                                            font.bold: true
                                            color: ThemeManager.selectedTheme.colors.primary
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            text: modelData.description ? modelData.description : qsTr("No description — document with { desc = ... } in hyprland.lua")
                                            font.pixelSize: ThemeManager.selectedTheme.typography.baseFontSize
                                            font.family: ThemeManager.selectedTheme.typography.bodyFont
                                            color: ThemeManager.selectedTheme.colors.onSurface
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            lineHeight: 1.2
                                        }

                                        Row {
                                            width: parent.width
                                            spacing: ThemeManager.selectedTheme.dimensions.spacingMedium
                                            topPadding: 4

                                            Rectangle {
                                                width: dispatcherText.width + 8
                                                height: dispatcherText.height + 4
                                                radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall
                                                color: Qt.rgba(ThemeManager.selectedTheme.colors.primary.r, ThemeManager.selectedTheme.colors.primary.g, ThemeManager.selectedTheme.colors.primary.b, 0.1)

                                                Text {
                                                    id: dispatcherText
                                                    // On Lua configs Hyprland reports dispatcher="__lua" with a
                                                    // numeric id arg — both meaningless to users, so show the
                                                    // description-first label instead.
                                                    text: modelData.dispatcher === "__lua" ? qsTr("⚡ Lua bind") : "⚡ " + modelData.dispatcher
                                                    font.pixelSize: ThemeManager.selectedTheme.typography.small
                                                    font.family: ThemeManager.selectedTheme.typography.bodyFont
                                                    color: ThemeManager.selectedTheme.colors.primary
                                                    anchors.centerIn: parent
                                                }
                                            }

                                            Text {
                                                width: parent.width - dispatcherText.width - 20
                                                text: (modelData.dispatcher === "__lua" || !modelData.arg) ? "" : "📁 " + (modelData.arg.length > 50 ? modelData.arg.substring(0, 50) + "..." : modelData.arg)
                                                font.pixelSize: ThemeManager.selectedTheme.typography.small
                                                font.family: ThemeManager.selectedTheme.typography.bodyFont
                                                color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // شريط التمرير الداخلي للقائمة
                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    width: ThemeManager.selectedTheme.dimensions.scrollbarWidth
                                    background: Rectangle {
                                        color: "transparent"
                                        radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall
                                    }
                                    contentItem: Rectangle {
                                        color: ThemeManager.selectedTheme.colors.onSurfaceVariant
                                        radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // شريط التمرير الرئيسي

    }

    // دالة لتنسيق المفتاح بشكل جميل
    function formatKey(bindData) {
        var key = bindData.key;
        var modmask = bindData.modmask;

        // تنسيق المفاتيح الخاصة
        if (key.includes("XF86")) {
            key = key.replace("XF86", "").replace(/([A-Z])/g, ' $1').trim();
        }
        if (key.includes("mouse:")) {
            key = key.replace("mouse:", "Mouse ");
        }
        if (key === "mouse_down")
            key = "Mouse Wheel Down";
        if (key === "mouse_up")
            key = "Mouse Wheel Up";
        if (key === "mouse:272")
            key = "Mouse Left";
        if (key === "mouse:273")
            key = "Mouse Right";

        // إضافة الموديفايرز
        var modifiers = [];
        if (modmask & 1)
            modifiers.push("Shift");
        if (modmask & 4)
            modifiers.push("Ctrl");
        if (modmask & 8)
            modifiers.push("Alt");
        if (modmask & 64)
            modifiers.push("Super");

        if (modifiers.length > 0) {
            return "🔹 " + modifiers.join(" + ") + " + " + key;
        } else {
            return "🔹 " + key;
        }
    }
}
