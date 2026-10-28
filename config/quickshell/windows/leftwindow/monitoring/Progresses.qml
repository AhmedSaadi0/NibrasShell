// windows/leftwindow/monitoring/Progresses.qml

import QtQuick
import QtQuick.Layouts

import "root:/components/monitors" // For Tempreture, Battery, Ram, Cpu
import "root:/themes"
import "root:/services" // For SystemService (power readouts)

import "root:/config/EventNames.js" as Events
import "root:/config/ConstValues.js" as C
import "root:/config"
import "root:/components"
import "root:/windows/leftwindow/base"

HeaderCard {
    id: root
    width: ThemeManager.selectedTheme.dimensions.menuWidth - (ThemeManager.selectedTheme.dimensions.menuWidgetsMargin * 2) - (App.menuStyle === C.FLOATING ? 10 : 0)

    property int monitorWidth: 70
    property int monitorHeight: 70
    property int monitorItemThickness: root.thickness
    property int monitorItemIconFontSize: root.iconFontSize

    property int thickness: 7
    property int iconFontSize: 30

    // Define the components to be loaded by MonitorWidget
    Component {
        id: tempComponent
        Tempreture {
            id: tempProgress
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            enableAnimation: true
        }
    }
    Component {
        id: batComponent
        Battery {
            glowIcon: false
            iconColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            backgroundColor: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.2)
            foregroundColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
            enableAnimation: true
        }
    }
    Component {
        id: ramComponent
        Ram {
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            enableAnimation: true
        }
    }
    Component {
        id: cpuComponent
        Cpu {
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            enableAnimation: true
        }
    }
    Component {
        id: gpuComponent
        Gpu {
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            enableAnimation: true
        }
    }
    Component {
        id: vramComponent
        Vram {
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            enableAnimation: true
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.preferredWidth: parent.width
        Layout.margins: ThemeManager.selectedTheme.dimensions.spacingSmall // Padding inside the root rectangle

        spacing: ThemeManager.selectedTheme.dimensions.spacingLarge + 8 // = 20: مسافة ثابتة بين الصفّين مشتقة من الثيم

        // --- الصف الأول: Temp / Battery / RAM ---
        // فواصل مرنة (Items) توزّع الدوائر بالتساوي عبر كامل عرض الكرت
        // الفراغ يُحسب تلقائياً = (عرض الصف - 3 * monitorWidth) / 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Item {
                Layout.minimumWidth: ThemeManager.selectedTheme.dimensions.spacingLarge + 8
            }

            MonitorWidget {
                id: tempWidget
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("Temp")
                monitorComponent: tempComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.fillWidth: true
            }

            MonitorWidget {
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("Battery")
                monitorComponent: batComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.fillWidth: true
            }

            MonitorWidget {
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("RAM")
                monitorComponent: ramComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.minimumWidth: ThemeManager.selectedTheme.dimensions.spacingLarge + 8
            }
        }

        // --- الصف الثاني: CPU / GPU / VRAM ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Item {
                Layout.minimumWidth: ThemeManager.selectedTheme.dimensions.spacingLarge + 8
            }

            MonitorWidget {
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("CPU")
                extraText: SystemService.cpuPowerW > 0 ? " · " + Math.round(SystemService.cpuPowerW) + "W" : ""
                monitorComponent: cpuComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.fillWidth: true
            }

            MonitorWidget {
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("GPU")
                extraText: SystemService.gpuPowerW > 0 ? " · " + Math.round(SystemService.gpuPowerW) + "W" : ""
                monitorComponent: gpuComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.fillWidth: true
            }

            MonitorWidget {
                Layout.preferredWidth: root.monitorWidth
                title: qsTr("VRAM")
                monitorComponent: vramComponent
                monitorItemWidth: root.monitorWidth
                monitorItemHeight: root.monitorHeight
                monitorItemThickness: root.monitorItemThickness
                monitorItemIconFontSize: root.monitorItemIconFontSize
            }

            Item {
                Layout.minimumWidth: ThemeManager.selectedTheme.dimensions.spacingLarge + 8
            }
        }
    }

    Component.onCompleted: {
        EventBus.on(Events.LEFT_MENU_IS_OPENED, function () {
            root.menuIsOpened();
        }, root);

        EventBus.on(Events.LEFT_MENU_IS_CLOSED, function () {
            root.menuIsClosed();
        }, root);
    }

    function menuIsOpened() {
        if (!tempComponent.constructor.running) {
            tempComponent.constructor.running = true;
            batComponent.constructor.running = true;
            ramComponent.constructor.running = true;
            cpuComponent.constructor.running = true;
            gpuComponent.constructor.running = true;
            vramComponent.constructor.running = true;
            console.info("Start Menu progresses");
        }
    }

    function menuIsClosed() {
        if (!tempComponent.constructor.running) {
            tempComponent.constructor.running = false;
            batComponent.constructor.running = false;
            ramComponent.constructor.running = false;
            cpuComponent.constructor.running = false;
            gpuComponent.constructor.running = false;
            vramComponent.constructor.running = false;
            console.info("Stop Menu progresses");
        }
    }
}
