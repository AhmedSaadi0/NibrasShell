import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import "root:/config"
import "root:/themes"

Rectangle {
    id: root
    color: "transparent"
    radius: ThemeManager.selectedTheme.dimensions.elementRadius

    signal navigateTo(int index)

    Layout.preferredWidth: 240
    Layout.fillHeight: true
    Layout.topMargin: 18
    Layout.bottomMargin: 18
    Layout.rightMargin: 10
    Layout.leftMargin: 10

    Text {
        id: headerTitle
        text: qsTr("Settings")
        font.bold: true
        font.pixelSize: 24
        color: ThemeManager.selectedTheme.colors.onSurface
        anchors {
            top: parent.top
        }
    }

    ListView {
        id: menuListView
        anchors.fill: parent
        anchors.topMargin: headerTitle.implicitHeight + 5
        clip: true
        currentIndex: 1
        spacing: 2

        highlightFollowsCurrentItem: true
        highlightMoveDuration: 200
        highlightMoveVelocity: -1

        highlight: Rectangle {
            width: menuListView.width - 10
            x: 5
            z: 0
            color: ThemeManager.selectedTheme.colors.primary
            radius: ThemeManager.selectedTheme.dimensions.elementRadius

            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuart
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuart
                }
            }
        }

        model: [
            {
                name: qsTr("General"),
                type: "header"
            },
            {
                name: qsTr("Personal & Region"),
                icon: "",
                type: "item",
                pageIndex: 0
            },
            {
                name: qsTr("Workspace & Layout"),
                icon: "",
                type: "item",
                pageIndex: 1
            },
            {
                name: qsTr("Intelligence & AI"),
                icon: "",
                type: "item",
                pageIndex: 2
            },
            {
                name: qsTr("System & Resources"),
                icon: "",
                type: "item",
                pageIndex: 3
            },
            {
                name: qsTr("Appearance"),
                type: "header"
            },
            {
                name: qsTr("Wallpaper Settings"),
                icon: "",
                type: "item",
                pageIndex: 4
            },
            {
                name: qsTr("Color Settings"),
                icon: "",
                type: "item",
                pageIndex: 5
            },
            {
                name: qsTr("Layout & Fonts"),
                icon: "",
                type: "item",
                pageIndex: 6
            },
            {
                name: qsTr("Desktop & CLock"),
                icon: "",
                type: "item",
                pageIndex: 7
            },
            {
                name: qsTr("Hyprland Settings"),
                icon: "",
                type: "item",
                pageIndex: 8
            },
            {
                name: qsTr("Integration"),
                icon: "󰒋",
                type: "item",
                pageIndex: 9
            },
            {
                name: qsTr("Devices"),
                type: "header"
            },
            {
                name: qsTr("Audio Devices"),
                icon: "",
                type: "item",
                pageIndex: 10
            },
            {
                name: qsTr("Monitors & Display"),
                icon: "󰍹",
                type: "item",
                pageIndex: 11
            },
            {
                name: qsTr("Lock & Idle"),
                icon: "\uf023",
                type: "item",
                pageIndex: 12
            }
        ]

        delegate: Controls.ItemDelegate {
            id: delegateItem
            width: menuListView.width
            height: model.modelData.type === "header" ? Kirigami.Units.gridUnit * 1.8 : Kirigami.Units.gridUnit * 2.5

            padding: 0
            leftPadding: model.modelData.type === "header" ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing

            enabled: model.modelData.type === "item"
            property bool isHovered: false

            readonly property bool isSelected: ListView.isCurrentItem

            // Header View
            RowLayout {
                width: parent.width
                visible: model.modelData.type === "header"
                Text {
                    text: model.modelData.name
                    font.bold: true
                    color: ThemeManager.selectedTheme.colors.onSurface
                    opacity: 0.7
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    height: 1
                    color: ThemeManager.selectedTheme.colors.onSurface
                    opacity: 0.3
                }
                spacing: 10
            }

            // Item View
            contentItem: RowLayout {
                spacing: 4
                visible: model.modelData.type === "item"

                transform: Translate {
                    x: isSelected ? 6 : 0
                    Behavior on x {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                // الأيقونة
                Text {
                    text: model.modelData.icon ? model.modelData.icon : ""
                    font.family: ThemeManager.selectedTheme.typography.iconFont
                    font.pixelSize: 18
                    Layout.leftMargin: 14
                    Layout.rightMargin: 8

                    color: isSelected ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.onSurface

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                // النص
                Text {
                    id: itemLabel
                    text: model.modelData.name
                    elide: Text.ElideLeft

                    color: isSelected ? ThemeManager.selectedTheme.colors.onPrimary : ThemeManager.selectedTheme.colors.onSurface
                    font.bold: isSelected
                    Layout.fillWidth: true

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // الخلفية
            background: Rectangle {
                color: isHovered && !isSelected ? ThemeManager.selectedTheme.colors.secondary.alpha(0.2) : "transparent"
                radius: ThemeManager.selectedTheme.dimensions.elementRadius

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: model.modelData.type === "item"
                onEntered: isHovered = true
                onExited: isHovered = false
                onClicked: {
                    if (model.modelData.type === "item") {
                        menuListView.currentIndex = index;
                        root.navigateTo(model.modelData.pageIndex);
                    }
                }
            }
        }
    }
}
