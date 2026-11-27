// windows/settings/pages/UserProfilePage.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Qt.labs.platform

import "root:/components"
import "root:/components/settings"
import "root:/windows/settings/components"
import "root:/config"

BaseGeneralSettings {
    id: page
    title: qsTr("Personal & Regional Info")
    icon: ""
    alwaysCollapsed: true

    property var theme: page.selectedTheme

    // =========================================================
    // 1. المتغيرات المحلية
    // =========================================================
    // Identity
    property string localUsername: ""
    property string localSubtitle: ""
    property string localAvatar: ""

    // Region
    property string localCountry: ""
    property string localCity: ""
    property string localWeatherLocation: ""
    property int localFirstDayOfWeek: 0
    property bool localUsePrayerTimes: false

    readonly property var daysOfWeek: [qsTr("Sunday"), qsTr("Monday"), qsTr("Tuesday"), qsTr("Wednesday"), qsTr("Thursday"), qsTr("Friday"), qsTr("Saturday")]

    // =========================================================
    // 2. المزامنة
    // =========================================================
    function syncFromConfig() {
        localUsername = App.username || "User";
        localSubtitle = App.subtitle || "Welcome back";
        localAvatar = App.profilePicture || "";

        localCountry = App.country || "";
        localCity = App.city || "";
        localWeatherLocation = App.weatherLocation || "";
        localFirstDayOfWeek = App.firstDayOfWeek !== undefined ? App.firstDayOfWeek : 6;
        localUsePrayerTimes = App.usePrayerTimes;
    }

    // =========================================================
    // 3. التجهيز للحفظ
    // =========================================================
    function serializeData() {
        return {
            "username": localUsername,
            "subtitle": localSubtitle,
            "profilePicture": localAvatar,
            "country": localCountry,
            "city": localCity,
            "weatherLocation": localWeatherLocation,
            "firstDayOfWeek": localFirstDayOfWeek,
            "usePrayerTimes": localUsePrayerTimes
        };
    }

    // =========================================================
    // 4. FileDialog
    // =========================================================
    FileDialog {
        id: avatarDialog
        title: "Select Profile Picture"
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: ["Image files (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            var path = file.toString();
            if (path.startsWith("file://")) {
                path = path.substring(7);
            }
            page.localAvatar = path;
        }
    }

    // =========================================================
    // 5. الواجهة
    // =========================================================
    ColumnLayout {
        spacing: theme.dimensions.spacingLarge
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter

        // -----------------------------------------------------
        // SECTION 1: HERO CARD
        // -----------------------------------------------------
        Rectangle {
            Layout.preferredWidth: 615
            Layout.preferredHeight: 150
            Layout.alignment: Qt.AlignHCenter
            radius: theme.dimensions.baseRadius
            color: theme.colors.primaryContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // Avatar
                Item {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 100

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: theme.colors.surfaceContainer
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: page.localAvatar ? "file://" + page.localAvatar : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: page.localAvatar !== ""
                            cache: false
                        }
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            visible: page.localAvatar === ""
                            font.family: theme.typography.iconFont
                            font.pixelSize: 45
                            color: theme.colors.onSurfaceVariant
                        }
                    }
                    MButton {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 32
                        height: 32
                        background: Rectangle {
                            radius: width / 2
                            color: theme.colors.tertiary
                            border.width: 2
                            border.color: theme.colors.onTertiary
                        }
                        text: ""
                        font.family: theme.typography.iconFont
                        font.pixelSize: 14
                        normalForeground: theme.colors.onTertiary
                        onClicked: avatarDialog.open()
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Info Preview
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5
                    Text {
                        text: page.localUsername || "Your Name"
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.heading1Size
                        font.bold: true
                        color: theme.colors.onPrimaryContainer
                    }
                    Text {
                        text: page.localSubtitle || "Your subtitle or bio will appear here."
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.medium
                        color: theme.colors.onPrimaryContainer
                        opacity: 0.8
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        visible: page.localCity !== "" || page.localCountry !== ""
                        spacing: 8
                        Layout.topMargin: 5
                        Text {
                            text: ""
                            font.family: theme.typography.iconFont
                            color: theme.colors.onPrimaryContainer
                            font.pixelSize: theme.typography.medium
                        }
                        Text {
                            text: (page.localCity ? page.localCity + ", " : "") + page.localCountry
                            font.family: theme.typography.bodyFont
                            font.pixelSize: theme.typography.small
                            color: theme.colors.onPrimaryContainer
                            opacity: 0.7
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 600
            Layout.alignment: Qt.AlignHCenter
            height: 1
            color: theme.colors.onSurfaceVariant
            opacity: 0.2
            Layout.topMargin: 10
            Layout.bottomMargin: 10
        }

        // -----------------------------------------------------
        // SECTION 2: INPUT FIELDS
        // -----------------------------------------------------
        GridLayout {
            Layout.preferredWidth: 600
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            rowSpacing: 15
            columnSpacing: 20

            // --- Identity ---
            Controls.Label {
                text: qsTr("Display Name")
                font.bold: true
                font.family: theme.typography.bodyFont
                font.pixelSize: theme.typography.medium
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.topMargin: 6
            }
            EditableField {
                Layout.fillWidth: true
                text: page.localUsername
                placeholderText: "Enter your name"
                selectedTheme: page.theme
                onEditingFinished: page.localUsername = text
            }

            Controls.Label {
                text: qsTr("Subtitle / Bio")
                font.bold: true
                font.family: theme.typography.bodyFont
                font.pixelSize: theme.typography.medium
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.topMargin: 6
            }
            EditableField {
                Layout.fillWidth: true
                text: page.localSubtitle
                placeholderText: "Short bio or quote"
                selectedTheme: page.theme
                onEditingFinished: page.localSubtitle = text
            }

            // --- Spacer ---
            Item {
                Layout.columnSpan: 2
                height: 15
            }

            // --- Converted to SectionCard: Regional Settings ---
            SectionCard {
                Layout.columnSpan: 2
                title: qsTr("Regional Settings")
                Layout.fillWidth: true

                // --- Location Fields ---
                Controls.Label {
                    text: qsTr("Country")
                    font.bold: true
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.medium
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.topMargin: 6
                }
                EditableField {
                    Layout.fillWidth: true
                    text: page.localCountry
                    placeholderText: "e.g. Yemen"
                    selectedTheme: page.theme
                    onEditingFinished: page.localCountry = text
                }

                Controls.Label {
                    text: qsTr("City")
                    font.bold: true
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.medium
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.topMargin: 6
                }
                EditableField {
                    Layout.fillWidth: true
                    text: page.localCity
                    placeholderText: "e.g. Sanaa"
                    selectedTheme: page.theme
                    onEditingFinished: page.localCity = text
                }

                Controls.Label {
                    text: qsTr("Weather API")
                    font.bold: true
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.medium
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.topMargin: 6
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    EditableField {
                        Layout.fillWidth: true
                        text: page.localWeatherLocation
                        placeholderText: "e.g. Sanaa,YE"
                        selectedTheme: page.theme
                        onEditingFinished: page.localWeatherLocation = text
                    }
                    Text {
                        text: "Specific location for weather service (City,Code)"
                        font.family: theme.typography.bodyFont
                        font.pixelSize: theme.typography.small
                        color: theme.colors.onSurfaceVariant
                    }
                }

                // --- Time & Calendar ---
                Controls.Label {
                    text: qsTr("First Day")
                    font.bold: true
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.medium
                    Layout.alignment: Qt.AlignVCenter
                }

                SettingsComboBox {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    model: page.daysOfWeek

                    currentIndex: page.localFirstDayOfWeek

                    editable: false

                    onActivated: index => page.localFirstDayOfWeek = index
                }

                Controls.Label {
                    text: qsTr("Prayer Times")
                    font.bold: true
                    font.family: theme.typography.bodyFont
                    font.pixelSize: theme.typography.medium
                    Layout.alignment: Qt.AlignVCenter
                    visible: false
                }

                SettingSwitch {
                    label: qsTr("Enable Prayer Times")
                    isChecked: page.localUsePrayerTimes
                    onIsCheckedChanged: page.localUsePrayerTimes = isChecked
                    Layout.alignment: Qt.AlignLeft
                    visible: false
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}