pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import "root:/components"
import "root:/components/settings"
import "root:/themes"
import "root:/windows/settings/components"

BaseThemeSettings {
    id: root

    title: qsTr("Layout & Fonts")
    icon: ""
    showApplyButton: true

    property string localIconFont: ""
    property string localBodyFont: ""

    property int localBaseFontSize: 12
    property int localMediumFontSize: 14
    property int localSmallFontSize: 12
    property int localHeading1Size: 22
    property int localHeading2Size: 20
    property int localHeading3Size: 18
    property int localHeading4Size: 16

    property int localSpacingSmall: 4
    property int localSpacingMedium: 8
    property int localSpacingLarge: 12

    property int localBaseRadius: 12
    property int localElementRadius: 12
    property int localBarHeight: 30
    property int localBarBottomMargin: 10
    property int localBarWidgetsHeight: 22
    property int localMenuHeight: 900
    property int localMenuWidth: 380
    property int localMenuWidgetsMargin: 15

    property int localShapeNone: 0
    property int localShapeExtraSmall: 4
    property int localShapeSmall: 8
    property int localShapeMedium: 12
    property int localShapeLarge: 16
    property int localShapeExtraLarge: 24
    property int localShapeFull: 28

    property int localDialogIconSize: 72
    property int localIconButtonSize: 36
    property int localIconButtonRadius: 18
    property int localChipHeight: 28
    property int localScrollbarWidth: 6
    property int localStatCardRadius: 20
    property int localStatCardHeight: 104

    readonly property int radiusSafeMax: 40
    readonly property int shapeNoneSafeMax: 8
    readonly property bool radiusMasterIsUniform: localBaseRadius === localElementRadius && localBaseRadius === localShapeMedium

    function sanitizeRadius(value, fallback, maxValue) {
        const safeFallback = (typeof fallback === "number" && Number.isFinite(fallback))
                ? fallback : 12;

        if (value === undefined || value === null || value === "")
            return safeFallback;
        if (typeof value === "boolean" || typeof value === "object")
            return safeFallback;

        const numeric = typeof value === "number" ? value : Number(value);
        if (!Number.isFinite(numeric))
            return safeFallback;

        const upper = (typeof maxValue === "number" && Number.isFinite(maxValue))
                ? maxValue : root.radiusSafeMax;
        return Math.max(0, Math.min(upper, Math.round(numeric)));
    }

    function previewRadiusMaster(value) {
        const radius = root.sanitizeRadius(value, root.localBaseRadius, root.radiusSafeMax);
        root.localBaseRadius = radius;
        root.localElementRadius = radius;
        root.localShapeMedium = radius;
    }

    function applyRadiusMaster(value) {
        if (!root.theme || root.isLoading || !root.isReady)
            return false;

        const radius = root.sanitizeRadius(value, root.localBaseRadius, root.radiusSafeMax);
        root.localBaseRadius = radius;
        root.localElementRadius = radius;
        root.localShapeMedium = radius;

        return root.applyProperties({
            "_baseRadius": radius,
            "_elementRadius": radius,
            "_shapeMedium": radius
        }, false);
    }

    function previewShapeMedium(value) {
        root.localShapeMedium = root.sanitizeRadius(
                value, root.localShapeMedium, root.radiusSafeMax);
    }

    function applyShapeMedium(value) {
        if (!root.theme || root.isLoading || !root.isReady)
            return false;

        const radius = root.sanitizeRadius(value, root.localShapeMedium, root.radiusSafeMax);
        root.localShapeMedium = radius;

        return root.applyProperties({ "_shapeMedium": radius }, false);
    }

    function previewShapeNone(value) {
        root.localShapeNone = root.sanitizeRadius(
                value, root.localShapeNone, root.shapeNoneSafeMax);
    }

    function applyShapeNone(value) {
        if (!root.theme || root.isLoading || !root.isReady)
            return false;

        const radius = root.sanitizeRadius(value, root.localShapeNone, root.shapeNoneSafeMax);
        root.localShapeNone = radius;

        return root.applyProperties({ "_shapeNone": radius }, false);
    }

    function syncFromTheme() {
        localIconFont = theme._iconFont;
        localBodyFont = theme._bodyFont;

        localBaseFontSize = theme._baseFontSize;
        localMediumFontSize = theme._mediumFontSize;
        localSmallFontSize = theme._smallFontSize;
        localHeading1Size = theme._heading1Size;
        localHeading2Size = theme._heading2Size;
        localHeading3Size = theme._heading3Size;
        localHeading4Size = theme._heading4Size;

        localSpacingSmall = theme._spacingSmall;
        localSpacingMedium = theme._spacingMedium;
        localSpacingLarge = theme._spacingLarge;

        localBaseRadius = sanitizeRadius(theme._baseRadius, 12, radiusSafeMax);
        localElementRadius = sanitizeRadius(theme._elementRadius, localBaseRadius, radiusSafeMax);
        localShapeMedium = sanitizeRadius(theme._shapeMedium, localBaseRadius, radiusSafeMax);
        localShapeNone = sanitizeRadius(theme._shapeNone, 0, shapeNoneSafeMax);

        localBarHeight = theme._barHeight;
        localBarBottomMargin = theme._barBottomMargin;
        localBarWidgetsHeight = theme._barWidgetsHeight;
        localMenuHeight = theme._menuHeight;
        localMenuWidth = theme._menuWidth;
        localMenuWidgetsMargin = theme._menuWidgetsMargin;

        localShapeExtraSmall = theme._shapeExtraSmall;
        localShapeSmall = theme._shapeSmall;
        localShapeLarge = theme._shapeLarge;
        localShapeExtraLarge = theme._shapeExtraLarge;
        localShapeFull = theme._shapeFull;

        localDialogIconSize = theme._dialogIconSize;
        localIconButtonSize = theme._iconButtonSize;
        localIconButtonRadius = theme._iconButtonRadius;
        localChipHeight = theme._chipHeight;
        localScrollbarWidth = theme._scrollbarWidth;
        localStatCardRadius = theme._statCardRadius;
        localStatCardHeight = theme._statCardHeight;
    }

    function serializeData() {
        return {
            "_baseRadius": localBaseRadius,
            "_elementRadius": localElementRadius,
            "_shapeMedium": localShapeMedium,
            "_shapeNone": localShapeNone,
            "_iconFont": localIconFont,
            "_bodyFont": localBodyFont,
            "_baseFontSize": localBaseFontSize,
            "_mediumFontSize": localMediumFontSize,
            "_smallFontSize": localSmallFontSize,
            "_heading1Size": localHeading1Size,
            "_heading2Size": localHeading2Size,
            "_heading3Size": localHeading3Size,
            "_heading4Size": localHeading4Size,
            "_spacingSmall": localSpacingSmall,
            "_spacingMedium": localSpacingMedium,
            "_spacingLarge": localSpacingLarge,
            "_barHeight": localBarHeight,
            "_barBottomMargin": localBarBottomMargin,
            "_barWidgetsHeight": localBarWidgetsHeight,
            "_menuHeight": localMenuHeight,
            "_menuWidth": localMenuWidth,
            "_menuWidgetsMargin": localMenuWidgetsMargin,
            "_shapeExtraSmall": localShapeExtraSmall,
            "_shapeSmall": localShapeSmall,
            "_shapeLarge": localShapeLarge,
            "_shapeExtraLarge": localShapeExtraLarge,
            "_shapeFull": localShapeFull,
            "_dialogIconSize": localDialogIconSize,
            "_iconButtonSize": localIconButtonSize,
            "_iconButtonRadius": localIconButtonRadius,
            "_chipHeight": localChipHeight,
            "_scrollbarWidth": localScrollbarWidth,
            "_statCardRadius": localStatCardRadius,
            "_statCardHeight": localStatCardHeight
        };
    }

    FontPickerDialog {
        id: fontDialog
        property var activeCallback: null
        onFontSelected: family => {
            if (activeCallback)
                activeCallback(family);
            activeCallback = null;
        }
        onCanceled: activeCallback = null
    }

    component PreviewBox: Rectangle {
        property alias text: previewLabel.text
        property alias previewFont: previewLabel.font
        property int effectiveRadius: root.localElementRadius

        Layout.fillWidth: true
        color: root.theme.colors.surfaceContainerHigh.alpha(0.65)
        radius: Math.max(0, Math.round(effectiveRadius / 1.5))
        border.color: root.theme.colors.primary.alpha(0.14)
        border.width: 1
        implicitHeight: previewLabel.implicitHeight + 22

        Behavior on radius {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Controls.Label {
            id: previewLabel
            anchors.fill: parent
            anchors.margins: 11
            color: root.theme.colors.onSurface
            wrapMode: Text.WordWrap
        }
    }

    component FontPickerRow: ColumnLayout {
        property string label: ""
        property string value: ""
        property string previewText: ""
        property bool isIconFont: false
        signal userChanged(string newValue)

        Layout.fillWidth: true
        spacing: 6

        Controls.Label {
            text: label
            font.bold: true
            color: root.theme.colors.onSurface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            EditableField {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                selectedTheme: root.theme
                horizontalAlignment: Text.AlignLeft
                text: value
                onEditingFinished: userChanged(text)
            }

            MButton {
                text: qsTr("Choose")
                Layout.preferredWidth: 88
                onClicked: {
                    fontDialog.previewText = previewText;
                    fontDialog.currentFont = value;
                    fontDialog.activeCallback = fontFamily => userChanged(fontFamily);
                    fontDialog.open();
                }
            }
        }

        PreviewBox {
            text: previewText
            previewFont.family: value
            previewFont.pixelSize: isIconFont ? 18 : root.localBaseFontSize
        }
    }

    ColumnLayout {
        spacing: root.dim("spacingMedium", 8)
        Layout.preferredWidth: 620

        SettingsHelperText {
            Layout.fillWidth: true
            Layout.preferredWidth: 580
            text: qsTr("This page controls typography and shell proportions. The controls below focus on the values that affect readability and spacing the most.")
        }

        SectionCard {
            title: qsTr("Fonts")
            subtitle: qsTr("Choose the body font for normal text and the icon font used in workspace indicators, buttons, and glyph-based widgets.")

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                FontPickerRow {
                    Layout.fillWidth: true
                    label: qsTr("Body Font")
                    value: root.localBodyFont
                    previewText: qsTr("The quick brown fox jumps over the lazy dog. 1234567890")
                    onUserChanged: newValue => {
                        root.localBodyFont = newValue;
                        root.applySingleProperty("_bodyFont", newValue);
                    }
                }

                FontPickerRow {
                    Layout.fillWidth: true
                    label: qsTr("Icon Font")
                    value: root.localIconFont
                    isIconFont: true
                    previewText: "󰋜 󰿣 󰂔 󰉋 󱙋 󰭹"
                    onUserChanged: newValue => {
                        root.localIconFont = newValue;
                        root.applySingleProperty("_iconFont", newValue);
                    }
                }
            }
        }

        SectionCard {
            title: qsTr("Typography Scale")
            subtitle: qsTr("These values control how large text appears across widgets, menus, and section headers.")

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Base Text")
                from: 10
                to: 20
                value: root.localBaseFontSize
                onEditingFinished: v => {
                    root.localBaseFontSize = v;
                    root.applySingleProperty("_baseFontSize", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Medium Text")
                from: 10
                to: 24
                value: root.localMediumFontSize
                onEditingFinished: v => {
                    root.localMediumFontSize = v;
                    root.applySingleProperty("_mediumFontSize", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Small Text")
                from: 8
                to: 18
                value: root.localSmallFontSize
                onEditingFinished: v => {
                    root.localSmallFontSize = v;
                    root.applySingleProperty("_smallFontSize", v);
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Heading 1")
                    from: 16
                    to: 34
                    value: root.localHeading1Size
                    onEditingFinished: v => {
                        root.localHeading1Size = v;
                        root.applySingleProperty("_heading1Size", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Heading 2")
                    from: 14
                    to: 30
                    value: root.localHeading2Size
                    onEditingFinished: v => {
                        root.localHeading2Size = v;
                        root.applySingleProperty("_heading2Size", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Heading 3")
                    from: 12
                    to: 26
                    value: root.localHeading3Size
                    onEditingFinished: v => {
                        root.localHeading3Size = v;
                        root.applySingleProperty("_heading3Size", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Heading 4")
                    from: 11
                    to: 24
                    value: root.localHeading4Size
                    onEditingFinished: v => {
                        root.localHeading4Size = v;
                        root.applySingleProperty("_heading4Size", v);
                    }
                }
            }

            PreviewBox {
                text: qsTr("Preview: headings and labels will follow the body font and size scale you choose here.")
                previewFont.family: root.localBodyFont
                previewFont.pixelSize: root.localMediumFontSize
            }
        }

        SectionCard {
            title: qsTr("Spacing & Radius")
            subtitle: qsTr("Use these controls to make the interface denser or more relaxed without touching every component manually.")

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Corner Radius (Master)")
                from: 0
                to: 40
                stepSize: 1
                decimals: 0
                value: root.localBaseRadius
                onCurrentValueChanged: v => root.previewRadiusMaster(v)
                onEditingFinished: v => root.applyRadiusMaster(v)
            }

            Controls.Label {
                Layout.fillWidth: true
                text: qsTr("Base %1 | Element %2 | Medium %3")
                        .arg(root.localBaseRadius)
                        .arg(root.localElementRadius)
                        .arg(root.localShapeMedium)
                color: root.theme.colors.onSurfaceVariant
                font.pixelSize: root.localSmallFontSize
                wrapMode: Text.WordWrap
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: !root.radiusMasterIsUniform
                text: qsTr("This theme defines different base, element, or medium radii. Using the master slider will unify them.")
                color: root.theme.colors.tertiary
                font.pixelSize: root.localSmallFontSize
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Small Spacing")
                    from: 0
                    to: 24
                    value: root.localSpacingSmall
                    onEditingFinished: v => {
                        root.localSpacingSmall = v;
                        root.applySingleProperty("_spacingSmall", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Medium Spacing")
                    from: 0
                    to: 32
                    value: root.localSpacingMedium
                    onEditingFinished: v => {
                        root.localSpacingMedium = v;
                        root.applySingleProperty("_spacingMedium", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Large Spacing")
                    from: 0
                    to: 40
                    value: root.localSpacingLarge
                    onEditingFinished: v => {
                        root.localSpacingLarge = v;
                        root.applySingleProperty("_spacingLarge", v);
                    }
                }
            }
        }

        SectionCard {
            title: qsTr("M3 Shape Scale")
            subtitle: qsTr("Corner radius scale following Material Design 3 shape tokens.")

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("None (M3 expects 0)")
                from: 0
                to: 8
                stepSize: 1
                decimals: 0
                value: root.localShapeNone
                onCurrentValueChanged: v => root.previewShapeNone(v)
                onEditingFinished: v => root.applyShapeNone(v)
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Extra Small")
                from: 0
                to: 12
                stepSize: 1
                decimals: 0
                value: root.localShapeExtraSmall
                onEditingFinished: v => {
                    root.localShapeExtraSmall = v;
                    root.applySingleProperty("_shapeExtraSmall", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Small")
                from: 0
                to: 16
                stepSize: 1
                decimals: 0
                value: root.localShapeSmall
                onEditingFinished: v => {
                    root.localShapeSmall = v;
                    root.applySingleProperty("_shapeSmall", v);
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Medium")
                    from: 0
                    to: 40
                    stepSize: 1
                    decimals: 0
                    value: root.localShapeMedium
                    onCurrentValueChanged: v => root.previewShapeMedium(v)
                    onEditingFinished: v => root.applyShapeMedium(v)
                }

                MButton {
                    text: qsTr("Use master")
                    Layout.preferredWidth: 110
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.localShapeMedium !== root.localBaseRadius
                    onClicked: root.applyShapeMedium(root.localBaseRadius)
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Large")
                from: 8
                to: 32
                stepSize: 1
                decimals: 0
                value: root.localShapeLarge
                onEditingFinished: v => {
                    root.localShapeLarge = v;
                    root.applySingleProperty("_shapeLarge", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Extra Large")
                from: 12
                to: 40
                stepSize: 1
                decimals: 0
                value: root.localShapeExtraLarge
                onEditingFinished: v => {
                    root.localShapeExtraLarge = v;
                    root.applySingleProperty("_shapeExtraLarge", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Full")
                from: 12
                to: 40
                stepSize: 1
                decimals: 0
                value: root.localShapeFull
                onEditingFinished: v => {
                    root.localShapeFull = v;
                    root.applySingleProperty("_shapeFull", v);
                }
            }
        }

        SectionCard {
            title: qsTr("Component Dimensions")
            subtitle: qsTr("Sizes for icons, buttons, chips, and cards.")

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Dialog Icon Size")
                from: 48
                to: 120
                value: root.localDialogIconSize
                onEditingFinished: v => {
                    root.localDialogIconSize = v;
                    root.applySingleProperty("_dialogIconSize", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Icon Button Size")
                from: 24
                to: 56
                value: root.localIconButtonSize
                onEditingFinished: v => {
                    root.localIconButtonSize = v;
                    root.applySingleProperty("_iconButtonSize", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Icon Button Radius")
                from: 0
                to: 28
                value: root.localIconButtonRadius
                onEditingFinished: v => {
                    root.localIconButtonRadius = v;
                    root.applySingleProperty("_iconButtonRadius", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Chip Height")
                from: 20
                to: 40
                value: root.localChipHeight
                onEditingFinished: v => {
                    root.localChipHeight = v;
                    root.applySingleProperty("_chipHeight", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Scrollbar Width")
                from: 2
                to: 12
                value: root.localScrollbarWidth
                onEditingFinished: v => {
                    root.localScrollbarWidth = v;
                    root.applySingleProperty("_scrollbarWidth", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Stat Card Radius")
                from: 1
                to: 32
                value: root.localStatCardRadius
                onEditingFinished: v => {
                    root.localStatCardRadius = v;
                    root.applySingleProperty("_statCardRadius", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Stat Card Height")
                from: 64
                to: 160
                value: root.localStatCardHeight
                onEditingFinished: v => {
                    root.localStatCardHeight = v;
                    root.applySingleProperty("_statCardHeight", v);
                }
            }
        }

        SectionCard {
            title: qsTr("Shell Layout")
            subtitle: qsTr("These values control the physical size of bars and menus across the shell.")

            Controls.Label {
                text: qsTr("Bar")
                font.bold: true
                color: root.theme.colors.primary
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Bar Height")
                    from: 22
                    to: 64
                    value: root.localBarHeight
                    onEditingFinished: v => {
                        root.localBarHeight = v;
                        root.applySingleProperty("_barHeight", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Bottom Margin")
                    from: 0
                    to: 40
                    value: root.localBarBottomMargin
                    onEditingFinished: v => {
                        root.localBarBottomMargin = v;
                        root.applySingleProperty("_barBottomMargin", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Widgets Height")
                    from: 16
                    to: 44
                    value: root.localBarWidgetsHeight
                    onEditingFinished: v => {
                        root.localBarWidgetsHeight = v;
                        root.applySingleProperty("_barWidgetsHeight", v);
                    }
                }
            }

            Controls.Label {
                text: qsTr("Menu")
                font.bold: true
                color: root.theme.colors.primary
                Layout.topMargin: 8
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Menu Height")
                    from: 420
                    to: 1400
                    stepSize: 10
                    value: root.localMenuHeight
                    onEditingFinished: v => {
                        root.localMenuHeight = v;
                        root.applySingleProperty("_menuHeight", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Menu Width")
                    from: 240
                    to: 720
                    stepSize: 10
                    value: root.localMenuWidth
                    onEditingFinished: v => {
                        root.localMenuWidth = v;
                        root.applySingleProperty("_menuWidth", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Widgets Margin")
                    from: 0
                    to: 48
                    value: root.localMenuWidgetsMargin
                    onEditingFinished: v => {
                        root.localMenuWidgetsMargin = v;
                        root.applySingleProperty("_menuWidgetsMargin", v);
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            width: 1
        }
    }
}
