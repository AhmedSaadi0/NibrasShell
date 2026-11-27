// windows/settings/SettingsWindow.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import Qt.labs.platform

import "root:/themes"
import "root:/config/EventNames.js" as Events
import "root:/config"
import "root:/components"
import "root:/windows/settings/components"
import "root:/windows/settings/components/general"
import "root:/windows/settings/components/appearance"
import "./audio"
import "./monitors"

Controls.ApplicationWindow {
    id: root
    visible: false
    color: ThemeManager.selectedTheme.colors.surface

    palette.window: ThemeManager.selectedTheme.colors.surface
    palette.windowText: ThemeManager.selectedTheme.colors.onSurface
    palette.base: ThemeManager.selectedTheme.colors.surfaceContainer
    palette.alternateBase: ThemeManager.selectedTheme.colors.surfaceContainerHigh
    palette.text: ThemeManager.selectedTheme.colors.onSurface
    palette.button: ThemeManager.selectedTheme.colors.surfaceContainerHigh
    palette.buttonText: ThemeManager.selectedTheme.colors.onSurfaceVariant
    palette.highlight: ThemeManager.selectedTheme.colors.primary
    palette.highlightedText: ThemeManager.selectedTheme.colors.onPrimary

    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint
    title: "NibrasShellSettings"

    function cancelAllChanges() {
        ThemeManager.reloadTheme();
        root.visible = false;
    }

    // --- Shortcuts ---
    NibrasShellShortcut {
        name: "openSettings"
        onPressed: root.visible = !root.visible
    }

    Component.onCompleted: {
        EventBus.on(Events.OPEN_SETTINGS, () => {
            root.visible = !root.visible;
        }, root);
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0

        SidePanel {
            // التنقل يعتمد على الاندكس القادم من القائمة الجانبية
            onNavigateTo: index => contentStack.navigateTo(index)
        }

        Controls.StackView {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            clip: true
            smooth: true

            property var pages: []
            property int currentIndex: 0

            // =========================================================
            // 1. تعريف المكونات (Components Definition)
            // =========================================================

            // --- New General Pages ---
            Component {
                id: userProfileComp
                UserProfilePage {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: interfaceComp
                InterfacePage {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: aiComp
                AIPage {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: systemComp
                SystemPage {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: lockIdleComp
                LockIdlePage {
                    onCancelChanges: root.cancelAllChanges()
                }
            }

            // --- Existing Appearance Pages ---
            Component {
                id: wallpaperSettingsComp
                WallpaperSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: colorsSettingsComp
                ColorsSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: layoutFontSettingsComp
                LayoutFontSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: desktopClockComp
                DesktopClockSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: hyprlandSettingsComp
                HyprlandSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }
            Component {
                id: integrationSettingsComp
                IntegrationSettings {
                    onCancelChanges: root.cancelAllChanges()
                }
            }

            // --- Devices ---
            Component {
                id: audioDevicesComp
                AudioDevices {
                    onClose: root.visible = false
                }
            }
            Component {
                id: monitorsSettingsComp
                MonitorsSettings {
                    onClose: root.visible = false
                }
            }

            // =========================================================
            // 2. إنشاء وترتيب الصفحات (Initialization)
            // =========================================================
            Component.onCompleted: {
                // ملاحظة: الترتيب هنا يجب أن يطابق تماماً الترتيب في SidePanel.qml
                pages = [
                    // General Section
                    userProfileComp.createObject(contentStack, {
                        visible: false
                    }) // Index 0
                    , interfaceComp.createObject(contentStack, {
                        visible: false
                    })   // Index 1
                    , aiComp.createObject(contentStack, {
                        visible: false
                    })          // Index 2
                    , systemComp.createObject(contentStack, {
                        visible: false
                    })      // Index 3
                    , lockIdleComp.createObject(contentStack, {
                        visible: false
                    })       // Index 4

                    ,

                    // Appearance Section
                    wallpaperSettingsComp.createObject(contentStack, {
                        visible: false
                    }) // Index 5
                    , colorsSettingsComp.createObject(contentStack, {
                        visible: false
                    })    // Index 6
                    , layoutFontSettingsComp.createObject(contentStack, {
                        visible: false
                    })// Index 7
                    , desktopClockComp.createObject(contentStack, {
                        visible: false
                    })      // Index 8
                    , hyprlandSettingsComp.createObject(contentStack, {
                        visible: false
                    })  // Index 9
                    , integrationSettingsComp.createObject(contentStack, {
                        visible: false
                    })// Index 10

                    ,

                    // Devices Section
                    audioDevicesComp.createObject(contentStack, {
                        visible: false
                    })       // Index 11
                    , monitorsSettingsComp.createObject(contentStack, {
                        visible: false
                    })       // Index 12
                ];

                // عرض الصفحة الأولى افتراضياً
                if (pages[0])
                    contentStack.push(pages[0]);
            }

            // =========================================================
            // 3. منطق التنقل (Navigation Logic)
            // =========================================================
            function navigateTo(newIndex) {
                if (!pages[newIndex] || newIndex === contentStack.currentIndex)
                    return;

                // تحديد اتجاه الحركة بناءً على ترتيب الصفحة
                if (newIndex > contentStack.currentIndex) {
                    contentStack.replaceEnter = enterFromBottom;
                    contentStack.replaceExit = exitToTop;
                } else {
                    contentStack.replaceEnter = enterFromTop;
                    contentStack.replaceExit = exitToBottom;
                }

                contentStack.currentIndex = newIndex;
                contentStack.replace(pages[newIndex]);
            }

            // --- Animations (كما هي في الكود الأصلي) ---
            Transition {
                id: enterFromBottom
                SequentialAnimation {
                    PropertyAction {
                        property: "opacity"
                        value: 0
                    }
                    PropertyAction {
                        property: "scale"
                        value: 0.92
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            property: "y"
                            from: contentStack.height * 0.6
                            to: 0
                            duration: 420
                            easing.type: Easing.OutBack
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.92
                            to: 1.0
                            duration: 380
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
            Transition {
                id: exitToTop
                ParallelAnimation {
                    NumberAnimation {
                        property: "y"
                        from: 0
                        to: -contentStack.height * 0.3
                        duration: 300
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 280
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 1.0
                        to: 0.95
                        duration: 300
                        easing.type: Easing.InCubic
                    }
                }
            }
            Transition {
                id: enterFromTop
                SequentialAnimation {
                    PropertyAction {
                        property: "opacity"
                        value: 0
                    }
                    PropertyAction {
                        property: "scale"
                        value: 0.92
                    }
                    PropertyAction {
                        property: "y"
                        value: -contentStack.height * 0.3
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            property: "y"
                            from: -contentStack.height * 0.3
                            to: 0
                            duration: 420
                            easing.type: Easing.OutBack
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.92
                            to: 1.0
                            duration: 380
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
            Transition {
                id: exitToBottom
                ParallelAnimation {
                    NumberAnimation {
                        property: "y"
                        from: 0
                        to: contentStack.height * 0.6
                        duration: 300
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 280
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 1.0
                        to: 0.95
                        duration: 300
                        easing.type: Easing.InCubic
                    }
                }
            }
        }
    }
}
