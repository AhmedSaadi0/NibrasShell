//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQml
import QtQuick.Window
import Quickshell.Io
import Quickshell.Hyprland

import "root:/windows/leftwindow"
import "root:/windows/smart_capsule"
import "root:/windows/settings"
import "root:/windows/cheatsheet"
import "root:/windows/bottomlauncher"
import "root:/windows/dock"
import "root:/windows/poweroption"
import "root:/windows/overlay"
import "root:/bars"
import "root:/osd"
import "root:/utils"
import "root:/config"
import "root:/desktop"
import "root:/themes"
import "root:/services"
import "root:/windows/smart_capsule/logic"
import "root:/config/ConstValues.js" as Consts
import "root:/config/EventNames.js" as Events

ShellRoot {
    id: shellRoot

    // --- Properties ---
    property var settingsWindowInstance: null
    property var notificationsInstance: null
    readonly property var _networkService: NetworkService
    readonly property var _selectedTheme: ThemeManager.selectedTheme

    signal openLeftPanelRequested(int selectedIndex)

    Component.onCompleted: {
        Qt.uiLanguage = "ar";
        NetworkService.syncTimers();
    }

    Connections {
        target: ThemeManager
        function onInitialThemeReady() {
            startComp.start();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "openwindow") {
                Hyprland.refreshToplevels();
            }
        }
    }

    // مؤقت الإقلاع المبدئي لبدء تحميل مكونات الواجهة
    Timer {
        id: startComp
        interval: 1000
        repeat: false
        onTriggered: {
            activateMainUI();
        }
    }

    function activateMainUI() {
        if (mainUiLoader.active)
            return;

        mainUiLoader.active = true;
        initializeGlobalWindows();
    }

    function initializeGlobalWindows() {
        const createGlobalWindowAsync = (component, name, callback) => {
            const incubator = component.incubateObject(shellRoot);

            if (incubator.status === Component.Ready) {
                callback(incubator.object);
            } else {
                incubator.onStatusChanged = function (status) {
                    if (status === Component.Ready) {
                        callback(incubator.object);
                    } else if (status === Component.Error) {
                        console.error(`CRITICAL: Failed to asynchronously create ${name}!`);
                    }
                };
            }
        };

        if (!settingsWindowInstance) {
            createGlobalWindowAsync(settingsWindowComponent, "Settings Window", instance => {
                settingsWindowInstance = instance;
            });
        }

        if (!notificationsInstance) {
            createGlobalWindowAsync(notificationsComponent, "Notifications", instance => {
                notificationsInstance = instance;
            });
        }
    }

    SplashScreen {
        id: splashScreen
        active: true // تبدأ نشطة وتظهر المحتوى
    }

    // مؤقت ذكي يعطي مهلة قصيرة (300 مللي ثانية) لكرت الشاشة ليرسم الواجهة الخلفية قبل إخفاء الـ Splash
    Timer {
        id: hideSplashDelay
        interval: 300
        repeat: false
        onTriggered: {
            mainUiLoader.opacity = 1.0;
            splashScreen.active = false; // تفعيل تلاشي المحتوى داخلياً بنعومة تمهيداً للإغلاق
        }
    }

    // --- Main UI Loader ---
    Loader {
        id: mainUiLoader
        anchors.fill: parent
        active: false
        asynchronous: true // تحميل خلفي ذكي خفيف على المعالج
        opacity: 0.0
        sourceComponent: mainUiComponent

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        onStatusChanged: {
            if (status === Loader.Ready) {
                console.log("Main UI Loaded and Ready in memory.");
                hideSplashDelay.start(); // الواجهة جاهزة بالكامل، لنبدأ الآن عملية الانتقال السلس
            } else if (status === Loader.Error) {
                console.error("CRITICAL: Failed to load Main UI!");
            }
        }
    }

    // --- Components Definitions ---
    Component {
        id: settingsWindowComponent
        Main {}
    }

    Component {
        id: notificationsComponent
        Notifications {}
    }

    // --- Main UI Structure ---
    Component {
        id: mainUiComponent
        Item {

            Variants {
                model: Quickshell.screens
                Desktop {
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            // 1. Dynamic Island
            Variants {
                model: Quickshell.screens
                SmartCapsule {
                    id: dynamicIsland
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            // 3. Bars
            Variants {
                model: Quickshell.screens
                Topbar {
                    id: topBarWindow
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            Variants {
                model: Quickshell.screens
                LeftBar {
                    id: leftBar
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            Variants {
                model: Quickshell.screens
                OverlayWindow {
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            // 4. Global Panels (Single instance)
            LeftWindowFull {
                id: leftPanelFull
            }
            //
            Cheatsheet {
                id: cheatsheetPanel
            }

            BottomLauncher {
                id: bottomLauncherPanel
            }

            Variants {
                model: Quickshell.screens
                Dock {
                    id: dockPanel
                    required property ShellScreen modelData
                    screen: modelData
                }
            }

            PowerMenuWindow {
                id: powerMenuWindow
            }

            // Event listener for bottom launcher toggle from LeftBar
            Connections {
                target: null
                Component.onCompleted: {
                    EventBus.on(Events.TOGGLE_BOTTOM_LAUNCHER, () => {
                        bottomLauncherPanel.toggle(true);
                    }, shellRoot);

                    EventBus.on(Events.TOGGLE_DOCK, () => {
                        App.showDock = !App.showDock;
                    }, shellRoot);
                }
            }

            // 5. IPC Handler
            property int openedMenu: LeftMenuStatus.selectedIndex

            IpcHandler {
                id: handler
                target: "LeftBar"

                function toggleMenu(targetIndex: int) {
                    let index = Number(targetIndex);
                    let menuToOpen = index;

                    if (index === openedMenu) {
                        menuToOpen = -1;
                    }

                    LeftMenuStatus.changeIndex(menuToOpen);
                    EventBus.emit(Events.OPEN_LEFTBAR, menuToOpen);
                }

                function toggleDashboardMenu() {
                    toggleMenu(Consts.DASHBOARD_MENU_INDEX);
                }
                function toggleNotificationsMenu() {
                    toggleMenu(Consts.NOTIFICATION_MENU_INDEX);
                }
                function toggleWeatherMenu() {
                    toggleMenu(Consts.WEATHER_MENU_INDEX);
                }
                function toggleMonitoringMenu() {
                    toggleMenu(Consts.MONIROTS_MENU_INDEX);
                }
                function toggleNetworkingMenu() {
                    toggleMenu(Consts.NETWORK_MENU_INDEX);
                }
                function toggleClipboardMenu() {
                    toggleMenu(Consts.CLIPBOARD_MENU_INDEX);
                }
                function toggleTodoMenu() {
                    toggleMenu(Consts.TODO_MENU_INDEX);
                }
                function toggleAiMenu() {
                    toggleMenu(Consts.AI_BOT_MENU_INDEX);
                }
                function toggleApplauncherMenu() {
                    bottomLauncherPanel.toggle();
                }
                function togglePowerMenu() {
                    EventBus.emit(Events.TOGGLE_POWER_MENU);
                }
                function toggleDock() {
                    EventBus.emit(Events.TOGGLE_DOCK);
                }
            }
        }
    }
}
