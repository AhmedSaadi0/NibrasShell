// bars/widgets/Monitors.qml

import QtQuick.Layouts
import QtQuick

import "root:/components/monitors"
import "root:/themes"
import "root:/services"
import "root:/components"

RowLayout {
    spacing: 6

    // 1. تنسيق النص الرقمي
    component ValueLabel: Text {
        color: ThemeManager.selectedTheme.colors.primary
        font.family: ThemeManager.selectedTheme.typography.bodyFont
        font.pixelSize: ThemeManager.selectedTheme.typography.small
        font.bold: true
        Layout.alignment: Qt.AlignCenter
    }

    // 2. شكل الفاصل العمودي
    component VerticalDivider: Rectangle {
        width: 1
        height: ThemeManager.selectedTheme.dimensions.barWidgetsHeight / 1.9
        color: ThemeManager.selectedTheme.colors.primary.alpha(0.3)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 2
        Layout.rightMargin: 2
    }

    // --- 1. Temperature ---
    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        Tempreture {
            id: tempMonitor
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
        }
        ValueLabel {
            // إضافة Math.round هنا لإزالة الفواصل
            text: Math.round(tempMonitor.value * 100) + " C"
            color: tempMonitor.fgNormal
        }
    }

    VerticalDivider {
        Layout.alignment: Qt.AlignVCenter
    }

    // --- 2. Battery ---

    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        visible: SystemService.hasBattery
        Battery {
            id: batteryMonitor
            glowIcon: false
            iconColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
            backgroundColor: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.2)
            foregroundColor: ThemeManager.selectedTheme.colors.onSurfaceVariant
        }
        ValueLabel {
            text: Math.round(batteryMonitor.value * 100) + "%"
            color: ThemeManager.selectedTheme.colors.onSurfaceVariant
        }
    }
    VerticalDivider {
        visible: SystemService.hasBattery
        Layout.alignment: Qt.AlignVCenter
    }

    // --- 3. RAM ---
    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        Ram {
            id: ramMonitor
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
        }
        ValueLabel {
            text: Math.round(ramMonitor.value * 100) + "%"
            color: ramMonitor.fgNormal
        }
    }

    VerticalDivider {
        Layout.alignment: Qt.AlignVCenter
    }

    // --- 4. CPU ---
    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        Cpu {
            id: cpuMonitor
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
        }
        ValueLabel {
            text: Math.round(cpuMonitor.value * 100) + "%"
            color: cpuMonitor.fgNormal
        }
        // واط المعالج — يظهر فقط عند توفر قراءة أكبر من صفر
        ValueLabel {
            visible: SystemService.cpuPowerW > 0
            text: Math.round(SystemService.cpuPowerW) + "W"
            color: cpuMonitor.fgNormal
        }
    }

    VerticalDivider {
        Layout.alignment: Qt.AlignVCenter
    }

    // --- 5. GPU ---
    // Row {
    //     spacing: 5
    //     Layout.alignment: Qt.AlignVCenter
    //     Gpu {
    //         id: gpuMonitor
    //         iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
    //     }
    //     ValueLabel {
    //         text: Math.round(gpuMonitor.value * 100) + "%"
    //         color: gpuMonitor.fgNormal
    //     }
    //     // واط كرت الشاشة — يظهر فقط عند توفر قراءة أكبر من صفر
    //     ValueLabel {
    //         visible: SystemService.gpuPowerW > 0
    //         text: Math.round(SystemService.gpuPowerW) + "W"
    //         color: gpuMonitor.fgNormal
    //     }
    // }

    // --- 5. VRAM ---
    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        Vram {
            id: vramMonitor
            iconFontFamily: ThemeManager.selectedTheme.typography.iconFont
        }
        ValueLabel {
            text: Math.round(vramMonitor.value * 100) + "%"
            color: vramMonitor.fgNormal
        }
    }

    // --- 6. Total Power ---
    // قراءة مدمجة لإجمالي استهلاك الطاقة — تظهر فقط عند توفر قراءة أكبر من صفر
    // VerticalDivider {
    //     visible: SystemService.totalPowerW > 0
    //     Layout.alignment: Qt.AlignVCenter
    // }

    Row {
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        visible: SystemService.totalPowerW > 0

        Text {
            text: ""
            // font.family: ThemeManager.selectedTheme.typography.iconFont
            font.pixelSize: ThemeManager.selectedTheme.typography.small
            color: ThemeManager.selectedTheme.colors.tertiary
        }

        ValueLabel {
            text: Math.round(SystemService.totalPowerW) + "W"
            color: ThemeManager.selectedTheme.colors.tertiary
        }
    }
}
