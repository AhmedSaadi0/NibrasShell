// ../../../components/monitors/MonitorWidget.qml
import QtQuick
import QtQuick.Layouts

import "../../themes"

ColumnLayout {
    id: monitorUnitRoot

    // Properties to be set by the parent (Progresses.qml)
    property string title: "Title"
    property string valueText: "100%" // This will be static or updated if your monitor component exposes its value

    // The component (e.g., Tempreture, Battery) to instantiate
    property var monitorComponent

    // Properties to pass down to the loaded monitorComponent
    property int monitorItemWidth: 70
    property int monitorItemHeight: 70
    // Add these if your TopbarCircularProgress (or Tempreture.qml) accepts them
    property int monitorItemThickness: 8
    property int monitorItemIconFontSize: 28

    // Alias to access the loaded monitor item if needed (e.g., to read its progress value)
    property alias actualMonitor: monitorLoader.item

    // نص إضافي يُلحق بنسبة القيمة (مثل: " · 12W") — اختياري ولا يؤثر على بقية الشاشات
    property string extraText: ""

    // تحديث نص القيمة بشكل موحّد (النسبة + النص الإضافي)
    function _refreshValueLabel(item) {
        valueLabel.text = Math.round(item.value * 100) + "%" + monitorUnitRoot.extraText;
    }

    // ضمان التفاعل عندما يتغير النص الإضافي دون تغيّر النسبة
    onExtraTextChanged: {
        if (monitorLoader.item && "value" in monitorLoader.item) {
            monitorUnitRoot._refreshValueLabel(monitorLoader.item);
        }
    }

    spacing: ThemeManager.selectedTheme.dimensions.spacingSmall / 3

    Layout.alignment: Qt.AlignHCenter

    Row {
        spacing: ThemeManager.selectedTheme.dimensions.spacingSmall
        Layout.alignment: Qt.AlignHCenter

        Text {
            id: titleLabel
            text: monitorUnitRoot.title
            font.bold: true
            font.pixelSize: ThemeManager.selectedTheme.typography.heading4Size   // 18 — كما هو
            color: ThemeManager.selectedTheme.colors.onSurface
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: valueLabel
            text: monitorUnitRoot.valueText
            font.pixelSize: ThemeManager.selectedTheme.typography.medium         // 14 — أصغر قليلاً
            color: ThemeManager.selectedTheme.colors.onSurfaceVariant            // مطفأ للمفارقة
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Loader {
        id: monitorLoader
        sourceComponent: monitorUnitRoot.monitorComponent
        Layout.alignment: Qt.AlignHCenter // Center the loaded monitor

        // Pass properties to the loaded item (e.g., Tempreture.qml)
        // These properties must exist on the loaded components or their base (TopbarCircularProgress)
        onLoaded: {
            item.width = monitorUnitRoot.monitorItemWidth;
            item.height = monitorUnitRoot.monitorItemHeight + 2;

            // Safely set properties if they exist on the loaded item
            if ("thickness" in item) {
                item.thickness = monitorUnitRoot.monitorItemThickness;
            }
            if ("iconFontSize" in item) {
                item.iconFontSize = monitorUnitRoot.monitorItemIconFontSize;
            }

            // Update value label now that monitorLoader.item is available
            if ("value" in item) {
                monitorUnitRoot._refreshValueLabel(item);
                if (item.valueChanged) {
                    item.valueChanged.connect(function () {
                        monitorUnitRoot._refreshValueLabel(item);
                    });
                }
            }
        }
    }
}
