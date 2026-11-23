// windows/settings/WallpaperSettings.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import Qt.labs.platform

import "root:/components"
import "root:/components/settings"
import "root:/config"
import "root:/themes"
import "root:/windows/settings/components"

BaseThemeSettings {
    id: root
    title: qsTr("Wallpaper & Colors")
    icon: ""
    showApplyButton: true

    property int preferredWidth: 600

    // ========================================================================
    // Local State
    // ========================================================================
    property bool localEnableDynamic: false
    property bool localEnableColoring: false

    // إعدادات الضبابية (Blur)
    property bool localEnableWallpaperBlur: false
    property real localWallpaperBlurStrength: 0.8 // القيمة الافتراضية

    property string localDynamicPath: ""
    property int localInterval: 60
    property int localWallpaperIndex: 0
    property string localStaticWallpaper: ""

    // New Color Engine Variables
    property int localSchemeVariant: 2
    property real localContrast: 0.0

    // ========================================================================
    // Logic
    // ========================================================================
    function syncFromTheme() {
        let s = (theme && theme.systemSettings) ? theme.systemSettings : {};

        localEnableDynamic = s.enableDynamicWallpapers ?? false;
        localEnableColoring = s.enableDynamicColoring ?? false;

        // قراءة إعدادات الضبابية
        localEnableWallpaperBlur = s.enableWallpaperBlur ?? false;
        localWallpaperBlurStrength = s.wallpaperBlurStrength !== undefined ? s.wallpaperBlurStrength : 0.8;

        localDynamicPath = s.dynamicWallpapersPath || "";
        localInterval = (s.dynamicWallpapersInterval || 60000) / 1000;
        localWallpaperIndex = s.selectedWallpaperIndex || 0;
        localStaticWallpaper = s.wallpaper || "";

        localSchemeVariant = s.dynamicColoringSchemeVariant !== undefined ? s.dynamicColoringSchemeVariant : 2;
        localContrast = s.dynamicColoringContrast !== undefined ? s.dynamicColoringContrast : 0.0;
    }

    function serializeData() {
        return {
            "_enableDynamicWallpapers": localEnableDynamic,
            "_enableDynamicColoring": localEnableColoring,

            // حفظ إعدادات الضبابية
            "_enableWallpaperBlur": localEnableWallpaperBlur,
            "_wallpaperBlurStrength": localWallpaperBlurStrength,
            "_dynamicWallpapersPath": localDynamicPath,
            "_dynamicWallpapersInterval": localInterval * 1000,
            "_selectedWallpaperIndex": localWallpaperIndex,
            "_wallpaper": localStaticWallpaper,
            "_dynamicColoringSchemeVariant": localSchemeVariant,
            "_dynamicColoringContrast": localContrast
        };
    }

    // ========================================================================
    // Dialogs
    // ========================================================================
    FolderDialog {
        id: dirDialog
        title: "Select Wallpapers Folder"
        onAccepted: {
            var path = folder.toString().replace("file://", "");
            root.localDynamicPath = path;
            root.applySingleProperty("_dynamicWallpapersPath", path);
        }
    }

    FileDialog {
        id: fileDialog
        title: "Select Wallpaper Image"
        nameFilters: ["Image files or a video (*.jpg *.png *.webp *.bmp *.jfi *.mp4)"]
        onAccepted: {
            var path = file.toString().replace("file://", "");
            root.localStaticWallpaper = path;
            root.applySingleProperty("_wallpaper", path);
            root.applySingleProperty("_desktopClockDepthEffectEnabled", false);
        }
    }

    // ========================================================================
    // Helper Component for Descriptions
    // ========================================================================
    component DescriptionLabel: Controls.Label {
        font.pixelSize: root.typ("small", 12)
        color: root.theme.colors.onSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: 20 // Indentation for better hierarchy
        Layout.rightMargin: 10
    }

    // ========================================================================
    // Main UI
    // ========================================================================
    ColumnLayout {
        id: mainLayout
        spacing: 15
        Layout.preferredWidth: 590

        // --------------------------------------------------------------------
        // SECTION 1: ACTIVATION MODES
        // --------------------------------------------------------------------
        SectionCard {
            title: qsTr("Modes & Activation")
            Layout.fillWidth: true

            // Dynamic Switch
            SettingSwitch {
                label: qsTr("Enable Dynamic Wallpapers")
                isChecked: root.localEnableDynamic
                onIsCheckedChanged: {
                    if (!root.isLoading) {
                        root.localEnableDynamic = isChecked;
                        root.applySingleProperty("_enableDynamicWallpapers", isChecked);
                    }
                }
            }
            DescriptionLabel {
                text: qsTr("When enabled, the system will automatically cycle through a collection of images from a folder instead of using a single static image.")
            }

            // Coloring Switch
            SettingSwitch {
                label: qsTr("Enable Material You Coloring")
                isChecked: root.localEnableColoring
                onIsCheckedChanged: {
                    if (!root.isLoading) {
                        root.localEnableColoring = isChecked;
                        root.applySingleProperty("_enableDynamicColoring", isChecked);
                    }
                }
            }
            DescriptionLabel {
                text: qsTr("Extracts dominant colors from the current wallpaper to generate a matching system theme. Requires 'matugen'.")
            }

            // Blur Switch & Slider
            SettingSwitch {
                label: qsTr("Enable Wallpaper Blur")
                isChecked: root.localEnableWallpaperBlur
                onIsCheckedChanged: {
                    if (!root.isLoading) {
                        root.localEnableWallpaperBlur = isChecked;
                        root.applySingleProperty("_enableWallpaperBlur", isChecked);
                    }
                }
            }

            // شريط التحكم بالضبابية يظهر فقط عند التفعيل
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.localEnableWallpaperBlur
                Layout.leftMargin: 20

                SliderWithLabel {
                    label: qsTr("Blur Strength")
                    from: 0.1
                    to: 1.0
                    stepSize: 0.05
                    decimals: 2
                    value: root.localWallpaperBlurStrength
                    onEditingFinished: val => {
                        root.localWallpaperBlurStrength = val;
                        root.applySingleProperty("_wallpaperBlurStrength", val);
                    }
                }
            }

            DescriptionLabel {
                text: qsTr("Adds a blur effect to the wallpaper when menus or overlays are active. Adjust the slider to control intensity.")
            }
        }

        // --------------------------------------------------------------------
        // SECTION 2: COLOR ENGINE CONFIGURATION
        // --------------------------------------------------------------------
        SectionCard {
            title: qsTr("Dynamic Color Engine")
            Layout.fillWidth: true
            visible: root.localEnableColoring

            // 1. Scheme Variant
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Controls.Label {
                    text: qsTr("Color Scheme:")
                    font.bold: true
                    Layout.preferredWidth: 100
                }
                SettingsComboBox {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    model: ["Content", "Expressive", "Fidelity", "Monochrome", "Neutral", "TonalSpot", "Vibrant", "Rainbow", "FruitSalad"]
                    currentIndex: root.localSchemeVariant
                    onActivated: index => {
                        root.localSchemeVariant = index;
                        root.applySingleProperty("_dynamicColoringSchemeVariant", index);
                    }
                }
            }
            DescriptionLabel {
                text: qsTr("Defines the algorithm used to generate the palette. 'Vibrant' creates punchy colors, 'Neutral' is desaturated, and 'Fidelity' tries to match the image exactly.")
            }

            // 2. matugen Contrast
            SliderWithLabel {
                label: qsTr("Contrast")
                from: -1.0
                to: 1.0
                stepSize: 0.05
                decimals: 2
                value: root.localContrast
                onEditingFinished: val => {
                    root.localContrast = val;
                    root.applySingleProperty("_dynamicColoringContrast", val);
                }
            }
            DescriptionLabel {
                text: qsTr("Adjusts palette contrast. -1 is minimum contrast, 0 is standard, and 1 is maximum contrast.")
            }
        }

        // --------------------------------------------------------------------
        // SECTION 3: WALLPAPER SOURCE (Dynamic OR Static)
        // --------------------------------------------------------------------

        // A. DYNAMIC MODE UI
        SectionCard {
            title: qsTr("Dynamic Collection Config")
            Layout.fillWidth: true
            visible: root.localEnableDynamic

            // Folder Path
            Controls.Label {
                text: qsTr("Source Folder")
                font.bold: true
            }
            RowLayout {
                Layout.fillWidth: true
                EditableField {
                    text: root.localDynamicPath
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    selectedTheme: root.theme
                    onEditingFinished: {
                        if (root.isLoading)
                            return;
                        root.localDynamicPath = text;
                        root.applySingleProperty("_dynamicWallpapersPath", text);
                    }
                }
                MButton {
                    text: ""
                    font.family: root.typ("iconFont", "Arial")
                    onClicked: dirDialog.open()
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 30
                }
            }
            DescriptionLabel {
                text: qsTr("The folder containing your wallpaper collection. The system will pick random images from here.")
                Layout.leftMargin: 0
            }

            // Interval
            SliderWithLabel {
                label: qsTr("Change Interval (Minutes)")
                from: 1
                to: 59
                stepSize: 0.01
                decimals: 2
                value: root.localInterval / 60
                onEditingFinished: val => {
                    root.localInterval = (val * 60);
                }
            }
            DescriptionLabel {
                text: qsTr("How often the wallpaper updates. Short intervals are good for testing, longer ones (e.g., 300s) for daily use.")
                Layout.leftMargin: 0
            }

            // Navigation
            Controls.Label {
                text: qsTr("Manual Control")
                font.bold: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Controls.Label {
                    text: "Current Index: " + root.localWallpaperIndex
                    Layout.fillWidth: true
                    color: root.theme.colors.onSurfaceVariant
                }
                MButton {
                    text: "Back"
                    iconText: "󰒮"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    iconFirst: true
                    textPreferredWidth: 4
                    iconPreferredWidth: 3
                    topRightRadius: 0
                    bottomRightRadius: 0
                    onClicked: {
                        ThemeManager.switchToPreviousWallpaper();
                        root.localWallpaperIndex = theme._selectedWallpaperIndex;
                    }
                }
                MButton {
                    text: "Next"
                    iconText: "󰒭"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    textPreferredWidth: 4
                    iconPreferredWidth: 3
                    topLeftRadius: 0
                    bottomLeftRadius: 0
                    onClicked: {
                        ThemeManager.switchToNextWallpaper();
                        root.localWallpaperIndex = theme._selectedWallpaperIndex;
                    }
                }
            }
            DescriptionLabel {
                text: qsTr("Manually force a wallpaper update if you don't like the current one.")
                Layout.leftMargin: 0
            }
        }

        // B. STATIC MODE UI
        SectionCard {
            title: qsTr("Static Image Config")
            Layout.fillWidth: true
            visible: !root.localEnableDynamic

            Controls.Label {
                text: qsTr("Image Path")
                font.bold: true
            }
            RowLayout {
                Layout.fillWidth: true
                EditableField {
                    text: root.localStaticWallpaper
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    selectedTheme: root.theme
                    onEditingFinished: {
                        if (root.isLoading)
                            return;
                        root.localStaticWallpaper = text;
                        root.applySingleProperty("_wallpaper", text);
                    }
                }
                MButton {
                    text: ""
                    font.family: root.typ("iconFont", "Arial")
                    onClicked: fileDialog.open()
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 30
                }
            }
            DescriptionLabel {
                text: qsTr("The absolute path to the single image file you want to set as your permanent background.")
                Layout.leftMargin: 0
            }
        }
    }
}
