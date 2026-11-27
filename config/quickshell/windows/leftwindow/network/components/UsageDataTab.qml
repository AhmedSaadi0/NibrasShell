import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "root:/themes"

ColumnLayout {
    id: root

    property string receivedData: "..."
    property string sentData: "..."
    property string totalData: "..."
    property string dailyReceivedData: "..."
    property string dailySentData: "..."
    property string dailyTotalData: "..."

    property int innerRadiusDiv: 4
    property int groupRadius: ThemeManager.selectedTheme.dimensions.elementRadius / 1.3

    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: [
            {
                title: qsTr("Received"),
                icon: "󰁅",
                day: root.dailyReceivedData,
                month: root.receivedData
            },
            {
                title: qsTr("Sent"),
                icon: "󰁝",
                day: root.dailySentData,
                month: root.sentData
            },
            {
                title: qsTr("Total"),
                icon: "󰯙",
                day: root.dailyTotalData,
                month: root.totalData
            }
        ]

        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 90
            radius: ThemeManager.selectedTheme.dimensions.elementRadius
            color: ThemeManager.selectedTheme.colors.surfaceContainerHigh.alpha(0.35)
            border.color: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.12)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: modelData.icon
                        font.family: ThemeManager.selectedTheme.typography.iconFont
                        font.pixelSize: 18
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData.title
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: ThemeManager.selectedTheme.colors.surfaceContainerHighest
                        border.color: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.15)
                        border.width: 1

                        topLeftRadius: root.groupRadius
                        bottomLeftRadius: root.groupRadius
                        topRightRadius: root.groupRadius / root.innerRadiusDiv
                        bottomRightRadius: root.groupRadius / root.innerRadiusDiv

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Label {
                                text: qsTr("Today")
                                font.pixelSize: ThemeManager.selectedTheme.typography.small - 1
                                color: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.75)
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.day
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: ThemeManager.selectedTheme.colors.primary.alpha(0.12)
                        border.color: ThemeManager.selectedTheme.colors.primary.alpha(0.28)
                        border.width: 1

                        topLeftRadius: root.groupRadius / root.innerRadiusDiv
                        bottomLeftRadius: root.groupRadius / root.innerRadiusDiv
                        topRightRadius: root.groupRadius
                        bottomRightRadius: root.groupRadius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Label {
                                text: qsTr("This Month")
                                font.pixelSize: ThemeManager.selectedTheme.typography.small - 1
                                color: ThemeManager.selectedTheme.colors.onSurfaceVariant.alpha(0.75)
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.month
                                font.bold: true
                                color: ThemeManager.selectedTheme.colors.primary
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
