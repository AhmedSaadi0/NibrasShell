// components/ThemeSelectorCard.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/themes"
import "root:/components"
import "root:/config/EventNames.js" as Events
import "root:/config"
import "root:/config/ConstValues.js" as Consts

Rectangle {
    id: card

    property string themeTitle: "Theme"
    property string lightThemeName: ""
    property string darkThemeName: ""

    property bool isSelected: false
    property int innerRadiusDiv: 4

    width: parent.width
    radius: ThemeManager.selectedTheme.dimensions.elementRadius
    color: {
        let base = ThemeManager.selectedTheme.colors.surfaceContainerLow;
        return ThemeManager.selectedTheme._themeMode === "dark" ? Qt.darker(base, 1.05) : Qt.lighter(base, 1.05);
    }
    height: columnLayout.implicitHeight + 20

    border.width: isSelected ? 2 : 0
    border.color: isSelected ? ThemeManager.selectedTheme.colors.primary : "transparent"

    Behavior on border.width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: card.themeTitle
            font.bold: true
            font.pixelSize: ThemeManager.selectedTheme.typography.medium * 1.2
            color: ThemeManager.selectedTheme.colors.onSurface
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.bottomMargin: 4
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 3

            MButton {
                text: ""
                Layout.fillWidth: true
                Layout.preferredHeight: 25
                isActive: ThemeManager.selectedTheme.themeName === card.lightThemeName
                normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                hoverOpacity: 0.16
                font.family: ThemeManager.selectedTheme.typography.iconFont
                onClicked: {
                    ThemeManager.requestLoadTheme(card.lightThemeName);
                    closeMenu.start();
                    // EventBus.emit(Events.CLOSE_LEFTBAR);
                }

                topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
            }

            MButton {
                text: "󰖔"
                Layout.fillWidth: true
                Layout.preferredHeight: 25
                font.family: ThemeManager.selectedTheme.typography.iconFont
                normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                hoverOpacity: 0.16
                isActive: ThemeManager.selectedTheme.themeName === card.darkThemeName
                onClicked: {
                    ThemeManager.requestLoadTheme(card.darkThemeName);
                    closeMenu.start();
                }

                bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
            }
        }
    }

    Timer {
        id: closeMenu
        interval: 600
        repeat: false
        onTriggered: {
            EventBus.emit(Events.CLOSE_LEFTBAR);
        }
    }
}
