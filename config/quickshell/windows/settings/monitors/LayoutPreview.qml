// windows/settings/monitors/LayoutPreview.qml
// خريطة مصغّرة نسبية لترتيب الشاشات (يمين/يسار/فوق/تحت) حسب إحداثيات Hyprland

import QtQuick
import QtQuick.Layouts

import "root:/themes"

Rectangle {
    id: root

    property var monitors: []
    property var selectedTheme: ThemeManager.selectedTheme

    // الشاشات المستقلة: مفعلة وليست شاشة مرآة (mirrorOf إما غير معرف أو "none")
    readonly property var usable: Array.isArray(monitors) ? monitors.filter(m => !m.disabled && (!m.mirrorOf || m.mirrorOf === "none")) : []

    // الأبعاد المنطقية (المساحة الفعلية على سطح المكتب): البكسل ÷ المقياس،
    // مع تبديل العرض/الارتفاع في الدوران الرأسي (transform = 1/3/5/7)
    function logicalWidth(m) {
        if (!m || !m.width)
            return 0;
        const swapped = (Number(m.transform) || 0) % 2 === 1;
        return Math.max(0, (swapped ? m.height : m.width) / Math.max(0.25, Number(m.scale) || 1));
    }
    function logicalHeight(m) {
        if (!m || !m.height)
            return 0;
        const swapped = (Number(m.transform) || 0) % 2 === 1;
        return Math.max(0, (swapped ? m.width : m.height) / Math.max(0.25, Number(m.scale) || 1));
    }

    // المواضع (x/y) منطقية، لذا حدود المشهد يجب أن تحسب بالأبعاد المنطقية أيضاً
    readonly property int minX: usable.length ? Math.min(...usable.map(m => m.x)) : 0
    readonly property int minY: usable.length ? Math.min(...usable.map(m => m.y)) : 0
    readonly property real maxX: usable.length ? Math.max(...usable.map(m => m.x + logicalWidth(m))) : 1
    readonly property real maxY: usable.length ? Math.max(...usable.map(m => m.y + logicalHeight(m))) : 1

    // عامل تصغير يناسب المساحة المتاحة مع حد أقصى 4x
    readonly property real scaleFactor: {
        if (!usable.length)
            return 1;
        const availW = Math.max(1, width - 24);
        const availH = Math.max(1, height - 24);
        return Math.min(availW / (maxX - minX), availH / (maxY - minY), 4);
    }

    Layout.fillWidth: true
    color: selectedTheme.colors.surfaceContainer.alpha(0.6)
    radius: selectedTheme.dimensions.elementRadius
    border.color: selectedTheme.colors.primary.alpha(0.12)
    border.width: 1
    implicitHeight: 150

    Text {
        anchors.centerIn: parent
        visible: root.usable.length === 0
        text: qsTr("No active displays detected")
        color: selectedTheme.colors.onSurfaceVariant
        font.pixelSize: 12
    }

    Item {
        id: canvas
        anchors.fill: parent
        anchors.margins: 12
        clip: true

        Repeater {
            model: root.usable

            delegate: Rectangle {
                required property var modelData

                readonly property int leW: Math.round(root.logicalWidth(modelData))
                readonly property int leH: Math.round(root.logicalHeight(modelData))

                readonly property int pw: Math.max(10, Math.round(leW * root.scaleFactor))
                readonly property int ph: Math.max(10, Math.round(leH * root.scaleFactor))

                x: Math.round((modelData.x - root.minX) * root.scaleFactor)
                y: Math.round((modelData.y - root.minY) * root.scaleFactor)
                width: pw
                height: ph

                radius: 6
                clip: true
                color: modelData.focused ? selectedTheme.colors.primary.alpha(0.35) : selectedTheme.colors.surfaceContainerHigh
                border.width: modelData.focused ? 2 : 1
                border.color: modelData.focused ? selectedTheme.colors.primary : selectedTheme.colors.secondary.alpha(0.5)

                Text {
                    anchors.centerIn: parent
                    text: modelData.name + "\n" + leW + "x" + leH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: modelData.focused ? selectedTheme.colors.onPrimary : selectedTheme.colors.onSurface
                    font.pixelSize: 9
                    font.bold: modelData.focused
                }
            }
        }
    }
}
