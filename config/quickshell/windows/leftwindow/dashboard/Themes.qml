// windows/leftwindow/dashboard/Themes.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
// import QtQuick.Dialogs
// import Qt.labs.platform

import "../../../components"
import "../../../themes"
import "root:/config"
import "root:/config/EventNames.js" as Events
import "root:/config/ConstValues.js" as Consts

MenuCard {
    id: root

    title: qsTr("Themes & Customization")
    icon: ""
    cardColor: ThemeManager.selectedTheme.colors.surfaceContainer
    textColor: ThemeManager.selectedTheme.colors.onSurface

    property bool settingsExpanded: false
    property int innerRadiusDiv: 4

    ColumnLayout {
        id: mainLayout
        spacing: 7

        RowLayout {
            id: fullThemesRow
            Layout.fillWidth: true
            spacing: 7

            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Dracula")
                lightThemeName: "DraculaLight"
                darkThemeName: "DraculaDark"
                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }

            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Catppuccin")
                lightThemeName: "CatppuccinLight"
                darkThemeName: "CatppuccinDark"

                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                radius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }

            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Material")
                lightThemeName: "M3Light"
                darkThemeName: "M3Dark"

                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName

                bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }
        }

        RowLayout {
            id: fullThemesRow2
            Layout.fillWidth: true
            spacing: 7

            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Nord")
                lightThemeName: "NordLight"
                darkThemeName: "NordDark"

                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                radius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }

            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Gruvbox")
                lightThemeName: "GruvboxLight"
                darkThemeName: "GruvboxDark"

                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                radius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }
            ThemeSelectorCard {
                Layout.fillWidth: true // مهم جدًا: اجعل البطاقة تملأ العرض
                themeTitle: qsTr("Tokyo Night")
                lightThemeName: "TokyoNightLight"
                darkThemeName: "TokyoNightDark"

                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                radius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }
        }

        RowLayout {
            id: fullThemesRow3
            Layout.fillWidth: true
            spacing: 7

            ThemeSelectorCard {
                Layout.fillWidth: true
                themeTitle: qsTr("Solarized")
                lightThemeName: "SolarizedLight"
                darkThemeName: "SolarizedDark"
                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }

            ThemeSelectorCard {
                Layout.fillWidth: true
                themeTitle: qsTr("Rosé Pine")
                lightThemeName: "RosePineLight"
                darkThemeName: "RosePineDark"
                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                radius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }

            ThemeSelectorCard {
                Layout.fillWidth: true
                themeTitle: qsTr("Oxocarbon")
                lightThemeName: "OxocarbonLight"
                darkThemeName: "OxocarbonDark"
                isSelected: ThemeManager.selectedTheme.themeName === lightThemeName || ThemeManager.selectedTheme.themeName === darkThemeName
                topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
                bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isSelected ? 1 : innerRadiusDiv)
            }
        }

        Label {
            id: singleThemeLabel
            text: qsTr("Single Themes")
            font.pointSize: 10
            font.bold: true
            color: ThemeManager.selectedTheme.colors.onSurface
            opacity: 0.8
            Layout.topMargin: 5
            // Layout.horizontalCenter: parent.horizontalCenter

        }

        GridLayout {
            id: grid
            columns: 3
            Layout.fillWidth: true
            columnSpacing: 5
            rowSpacing: 7

            MButton {
                text: qsTr("Colors")
                onClicked: {
                    ThemeManager.requestLoadTheme("ColorsTheme");
                    closeMenu.start();
                }
                Layout.fillWidth: true
                Layout.preferredHeight: 25
                iconText: ""
                isActive: ThemeManager.selectedTheme.themeName === "ColorsTheme"
                normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                hoverOpacity: 0.16

                topRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                bottomRightRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
            }
            MButton {
                text: qsTr("Deer")

                onClicked: {
                    ThemeManager.requestLoadTheme("DeerTheme");
                    closeMenu.start();
                }
                Layout.fillWidth: true
                Layout.preferredHeight: 25
                iconText: ""
                isActive: ThemeManager.selectedTheme.themeName === "DeerTheme"
                normalBackground: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                hoverOpacity: 0.16

                bottomLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
                topLeftRadius: ThemeManager.selectedTheme.dimensions.elementRadius / (isActive ? Consts.M3_BUTTON_RADIUS_DIVISOR : innerRadiusDiv)
            }
        }

        Rectangle {
            id: sperator
            Layout.fillWidth: true
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            height: 1
            color: ThemeManager.selectedTheme.colors.onSurface.alpha(0.2)
        }

        Rectangle {
            id: settingsHeader
            Layout.fillWidth: true
            height: 30
            color: "transparent"
            radius: ThemeManager.selectedTheme.dimensions.shapeExtraSmall

            // خاصية إضافية للتحكم في الـ scale
            property real pressScale: 1.0
            scale: pressScale

            Behavior on pressScale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.InOutQuad
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                Label {
                    text: "Advanced Customization"
                    font.bold: true
                    color: ThemeManager.selectedTheme.colors.onSurface
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    id: expandIcon
                    text: ""
                    font.family: "FantasqueSansM Nerd Font Propo"
                    font.pixelSize: 16
                    color: ThemeManager.selectedTheme.colors.onSurface
                    rotation: root.settingsExpanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: settingsHeader.pressScale = 0.95
                onReleased: settingsHeader.pressScale = 1.0
                onClicked: {
                    EventBus.emit(Events.OPEN_SETTINGS);
                    EventBus.emit(Events.CLOSE_LEFTBAR);
                }
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
