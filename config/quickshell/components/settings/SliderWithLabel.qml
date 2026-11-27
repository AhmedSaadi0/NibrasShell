// components/SliderWithLabel.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import "root:/themes"

ColumnLayout {
    id: root

    // --- Inputs ---
    property alias label: titleLabel.text
    property double from: 0
    property double to: 100
    property double value: 0
    property double stepSize: 1.0
    property int decimals: 0
    // Optional formatter for the displayed value; raw numbers remain unchanged.
    property var valueFormatter: null

    // --- Outputs ---
    signal currentValueChanged(double newValue)
    signal editingFinished(double finalValue)

    spacing: 4

    // 1. Label + Value row
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Controls.Label {
            id: titleLabel
            font.bold: true
            color: ThemeManager.selectedTheme.colors.onSurface
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Controls.Label {
            id: valueLabel
            text: root.valueFormatter ? root.valueFormatter(slider.value) : slider.value.toFixed(root.decimals)
            font.bold: true
            color: ThemeManager.selectedTheme.colors.primary
            Layout.minimumWidth: 40
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter

            background: Rectangle {
                color: ThemeManager.selectedTheme.colors.surfaceContainer
                radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall
                opacity: 0.5
            }

            leftPadding: 6
            rightPadding: 6
            topPadding: 2
            bottomPadding: 2
        }
    }

    // 2. Slider (full width)
    Controls.Slider {
        id: slider
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Controls.Slider.SnapAlways
        value: root.value

        onMoved: {
            var preciseValue = parseFloat(value.toFixed(root.decimals));
            root.currentValueChanged(preciseValue);
        }

        onPressedChanged: {
            if (!pressed) {
                var finalValue = parseFloat(value.toFixed(root.decimals));
                root.editingFinished(finalValue);
            }
        }

        Connections {
            target: root
            function onValueChanged() {
                if (!slider.pressed && slider.value !== root.value) {
                    slider.value = root.value;
                }
            }
        }
    }
}
