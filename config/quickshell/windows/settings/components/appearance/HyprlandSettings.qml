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

    title: qsTr("Hyprland Settings")
    icon: ""
    showApplyButton: true

    property int localRounding: 0
    property int localBorderWidth: 0
    property int localGapsIn: 0
    property string localGapsOut: "0, 0, 0, 0"
    property int localGapTop: 0
    property int localGapRight: 0
    property int localGapBottom: 0
    property int localGapLeft: 0
    property string localLayout: "dwindle"
    property string localActiveBorder: ""
    property string localInactiveBorder: ""

    property bool localBlurEnabled: true
    property int localBlurSize: 1
    property int localBlurPasses: 1

    property bool localDropShadow: false
    property int localShadowRange: 0
    property int localShadowOffsetX: 0
    property int localShadowOffsetY: 0
    property string localShadowColor: ""

    property bool localDimInactive: false
    property double localDimStrength: 0.0

    property bool localAnimationsEnabled: true
    property string localBezier: ""
    property string localAnimWindows: ""
    property string localAnimWindowsIn: ""
    property string localAnimWindowsMove: ""
    property string localAnimWindowsOut: ""
    property string localAnimBorder: ""
    property string localAnimBorderAngle: ""
    property string localAnimFadeIn: ""
    property string localAnimFadeOut: ""
    property string localAnimWorkspaces: ""
    property string localAnimationPresetKey: "custom"
    property bool localShowAdvancedAnimations: false

    readonly property var _animationPresets: ({
            "calm": {
                bezier: "win_in, 0.16, 1, 0.3, 1\nwin_out, 0.3, 0, 0.6, 1\nmove, 0.2, 0.85, 0.15, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.12, 0.95, 0.22, 1",
                windows: "1, 8, launch, popin 90%",
                windowsIn: "1, 8, launch, popin 90%",
                windowsMove: "1, 7, move, slide",
                windowsOut: "1, 7, win_out, popin 88%",
                border: "1, 10, ui",
                borderAngle: "1, 12, ui",
                fadeIn: "1, 8, launch",
                fadeOut: "1, 6, win_out",
                workspaces: "1, 7, move, slide"
            },
            "balanced": {
                bezier: "win_in, 0.2, 1, 0.32, 1\nwin_out, 0.35, 0, 0.65, 1\nmove, 0.22, 0.75, 0.18, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.16, 0.9, 0.24, 1",
                windows: "1, 7, launch, popin 92%",
                windowsIn: "1, 7, launch, popin 92%",
                windowsMove: "1, 6, move, slide",
                windowsOut: "1, 6, win_out, popin 90%",
                border: "1, 9, ui",
                borderAngle: "1, 10, ui",
                fadeIn: "1, 7, launch",
                fadeOut: "1, 5, win_out",
                workspaces: "1, 6, move, slide"
            },
            "snappy": {
                bezier: "win_in, 0.22, 1, 0.36, 1\nwin_out, 0.4, 0, 0.7, 1\nmove, 0.25, 0.7, 0.2, 1\nui, 0.3, 0.1, 0.25, 1\nlaunch, 0.2, 0.85, 0.25, 1",
                windows: "1, 6, launch, popin 94%",
                windowsIn: "1, 6, launch, popin 94%",
                windowsMove: "1, 5, move, slide",
                windowsOut: "1, 5, win_out, popin 92%",
                border: "1, 8, ui",
                borderAngle: "1, 8, ui",
                fadeIn: "1, 6, launch",
                fadeOut: "1, 4, win_out",
                workspaces: "1, 5, move, slide"
            }
        })

    function _parseIntSafe(value, fallback = 0) {
        const parsed = parseInt(String(value).trim(), 10);
        return isNaN(parsed) ? fallback : parsed;
    }

    function _parseBoxValues(value, fallback = 0) {
        const parts = String(value || "").split(",").map(part => _parseIntSafe(part, fallback));

        if (parts.length <= 1)
            return [parts[0] || fallback, parts[0] || fallback, parts[0] || fallback, parts[0] || fallback];
        if (parts.length === 2)
            return [parts[0], parts[1], parts[0], parts[1]];
        if (parts.length === 3)
            return [parts[0], parts[1], parts[2], parts[1]];
        return [parts[0], parts[1], parts[2], parts[3]];
    }

    function _syncGapFields() {
        const values = _parseBoxValues(localGapsOut, 0);
        localGapTop = values[0];
        localGapRight = values[1];
        localGapBottom = values[2];
        localGapLeft = values[3];
    }

    function _applyGapFields() {
        localGapsOut = `${localGapTop}, ${localGapRight}, ${localGapBottom}, ${localGapLeft}`;
        root.applySingleProperty("_hyprGapsOut", localGapsOut);
    }

    function _trimmed(value) {
        return String(value || "").trim();
    }

    function _animationPresetLabel(key) {
        switch (key) {
        case "calm":
            return qsTr("Calm 120Hz");
        case "balanced":
            return qsTr("Balanced");
        case "snappy":
            return qsTr("Snappy");
        default:
            return qsTr("Custom");
        }
    }

    function _detectAnimationPreset() {
        for (const key of ["calm", "balanced", "snappy"]) {
            const preset = _animationPresets[key];
            if (_trimmed(localBezier) === _trimmed(preset.bezier) && _trimmed(localAnimWindows) === _trimmed(preset.windows) && _trimmed(localAnimWindowsIn) === _trimmed(preset.windowsIn) && _trimmed(localAnimWindowsMove) === _trimmed(preset.windowsMove) && _trimmed(localAnimWindowsOut) === _trimmed(preset.windowsOut) && _trimmed(localAnimBorder) === _trimmed(preset.border) && _trimmed(localAnimBorderAngle) === _trimmed(preset.borderAngle) && _trimmed(localAnimFadeIn) === _trimmed(preset.fadeIn) && _trimmed(localAnimFadeOut) === _trimmed(preset.fadeOut) && _trimmed(localAnimWorkspaces) === _trimmed(preset.workspaces))
                return key;
        }

        return "custom";
    }

    function _applyAnimationPreset(key) {
        const preset = _animationPresets[key];
        if (!preset)
            return;

        localAnimationsEnabled = true;
        localBezier = preset.bezier;
        localAnimWindows = preset.windows;
        localAnimWindowsIn = preset.windowsIn;
        localAnimWindowsMove = preset.windowsMove;
        localAnimWindowsOut = preset.windowsOut;
        localAnimBorder = preset.border;
        localAnimBorderAngle = preset.borderAngle;
        localAnimFadeIn = preset.fadeIn;
        localAnimFadeOut = preset.fadeOut;
        localAnimWorkspaces = preset.workspaces;
        localAnimationPresetKey = key;

        ThemeManager.updateAndApplyTheme({
            "_hyprAnimationsEnabled": true,
            "_hyprBezier": localBezier,
            "_hyprAnimWindows": localAnimWindows,
            "_hyprAnimWindowsIn": localAnimWindowsIn,
            "_hyprAnimWindowsMove": localAnimWindowsMove,
            "_hyprAnimWindowsOut": localAnimWindowsOut,
            "_hyprAnimBorder": localAnimBorder,
            "_hyprAnimBorderAngle": localAnimBorderAngle,
            "_hyprAnimFadeIn": localAnimFadeIn,
            "_hyprAnimFadeOut": localAnimFadeOut,
            "_hyprAnimWorkspaces": localAnimWorkspaces
        }, false);
    }

    function syncFromTheme() {
        localRounding = theme._hyprRounding;
        localBorderWidth = theme._hyprBorderWidth;
        localGapsIn = theme._hyprGapsIn;
        localGapsOut = theme._hyprGapsOut;
        _syncGapFields();
        localLayout = theme._hyprLayout;
        localActiveBorder = theme._hyprActiveBorder;
        localInactiveBorder = theme._hyprInactiveBorder;

        localBlurEnabled = theme._hyprBlurEnabled;
        localBlurSize = theme._hyprBlurSize;
        localBlurPasses = theme._hyprBlurPasses;

        localDropShadow = theme._hyprDropShadow === "yes" || theme._hyprDropShadow === true;
        localShadowRange = theme._hyprShadowRange;
        localShadowOffsetX = theme._hyprShadowOffset.x;
        localShadowOffsetY = theme._hyprShadowOffset.y;
        localShadowColor = theme._hyprShadowColor;

        localDimInactive = theme._hyprDimInactive;
        localDimStrength = theme._hyprDimStrength;

        localAnimationsEnabled = theme._hyprAnimationsEnabled;
        localBezier = theme._hyprBezier;
        localAnimWindows = theme._hyprAnimWindows;
        localAnimWindowsIn = theme._hyprAnimWindowsIn !== undefined ? theme._hyprAnimWindowsIn : localAnimWindows;
        localAnimWindowsMove = theme._hyprAnimWindowsMove;
        localAnimWindowsOut = theme._hyprAnimWindowsOut;
        localAnimBorder = theme._hyprAnimBorder;
        localAnimBorderAngle = theme._hyprAnimBorderAngle;
        localAnimFadeIn = theme._hyprAnimFadeIn;
        localAnimFadeOut = theme._hyprAnimFadeOut;
        localAnimWorkspaces = theme._hyprAnimWorkspaces;
        localAnimationPresetKey = _detectAnimationPreset();
    }

    function serializeData() {
        return {
            "_hyprRounding": localRounding,
            "_hyprBorderWidth": localBorderWidth,
            "_hyprGapsIn": localGapsIn,
            "_hyprGapsOut": localGapsOut,
            "_hyprLayout": localLayout,
            "_hyprActiveBorder": localActiveBorder,
            "_hyprInactiveBorder": localInactiveBorder,
            "_hyprBlurEnabled": localBlurEnabled,
            "_hyprBlurSize": localBlurSize,
            "_hyprBlurPasses": localBlurPasses,
            "_hyprDropShadow": localDropShadow ? "yes" : "no",
            "_hyprShadowRange": localShadowRange,
            "_hyprShadowOffset": Qt.point(localShadowOffsetX, localShadowOffsetY),
            "_hyprShadowColor": localShadowColor,
            "_hyprDimInactive": localDimInactive,
            "_hyprDimStrength": localDimStrength,
            "_hyprAnimationsEnabled": localAnimationsEnabled,
            "_hyprBezier": localBezier,
            "_hyprAnimWindows": localAnimWindows,
            "_hyprAnimWindowsIn": localAnimWindowsIn,
            "_hyprAnimWindowsMove": localAnimWindowsMove,
            "_hyprAnimWindowsOut": localAnimWindowsOut,
            "_hyprAnimBorder": localAnimBorder,
            "_hyprAnimBorderAngle": localAnimBorderAngle,
            "_hyprAnimFadeIn": localAnimFadeIn,
            "_hyprAnimFadeOut": localAnimFadeOut,
            "_hyprAnimWorkspaces": localAnimWorkspaces
        };
    }

    component FieldLabel: Controls.Label {
        font.bold: true
        color: root.theme.colors.onSurface
    }

    component CompactField: EditableField {
        selectedTheme: root.theme
        horizontalAlignment: Text.AlignLeft
        Layout.preferredHeight: 30
    }

    component IntField: CompactField {
        validator: IntValidator {}
    }

    component StyledTextArea: Controls.ScrollView {
        id: scrollRoot
        property alias text: textArea.text
        property bool _dirty: false
        signal editingFinished(string value)
        implicitHeight: 130
        clip: true

        Controls.TextArea {
            id: textArea
            wrapMode: TextEdit.NoWrap
            selectByMouse: true
            font.family: root.theme.typography.bodyFont
            font.pixelSize: root.theme.typography.small
            color: root.theme.colors.onSurface
            selectedTextColor: root.theme.colors.onPrimary
            selectionColor: root.theme.colors.primary

            onTextChanged: {
                if (activeFocus)
                    scrollRoot._dirty = true;
            }

            onActiveFocusChanged: {
                if (!activeFocus && scrollRoot._dirty) {
                    scrollRoot._dirty = false;
                    scrollRoot.editingFinished(text);
                }
            }

            background: Rectangle {
                color: root.theme.colors.surfaceContainer
                radius: root.theme.dimensions.baseRadius / 2
                border.color: textArea.activeFocus ? root.theme.colors.primary : root.theme.colors.onSurfaceVariant
                border.width: textArea.activeFocus ? 2 : 1
                opacity: 0.9
            }
        }
    }

    ColumnLayout {
        spacing: root.dim("spacingMedium", 8)
        Layout.preferredWidth: 620

        SettingsHelperText {
            Layout.fillWidth: true
            Layout.preferredWidth: 580
            text: qsTr("This page focuses on the settings most users actually change. Layout, gaps, blur, shadows, and animation profiles are simplified here. Raw Hyprland syntax stays available only in Advanced mode.")
        }

        SectionCard {
            title: qsTr("Layout & Borders")
            subtitle: qsTr("Safe, common options for shape and spacing. Outer gaps are saved as top, right, bottom, left.")

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    FieldLabel {
                        text: qsTr("Window Layout")
                    }

                    SettingsComboBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        model: [qsTr("Dwindle (Spiral)"), qsTr("Master (Stack)")]
                        currentIndex: root.localLayout === "master" ? 1 : 0
                        onActivated: index => {
                            root.localLayout = index === 1 ? "master" : "dwindle";
                            root.applySingleProperty("_hyprLayout", root.localLayout);
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    FieldLabel {
                        text: qsTr("Inner Gaps")
                    }

                    SliderWithLabel {
                        Layout.fillWidth: true
                        label: qsTr("Px")
                        from: 0
                        to: 40
                        value: root.localGapsIn
                        onEditingFinished: v => {
                            root.localGapsIn = v;
                            root.applySingleProperty("_hyprGapsIn", v);
                        }
                    }
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Corner Rounding")
                from: 0
                to: 50
                value: root.localRounding
                onEditingFinished: v => {
                    root.localRounding = v;
                    root.applySingleProperty("_hyprRounding", v);
                }
            }

            SliderWithLabel {
                Layout.fillWidth: true
                label: qsTr("Border Width")
                from: 0
                to: 10
                value: root.localBorderWidth
                onEditingFinished: v => {
                    root.localBorderWidth = v;
                    root.applySingleProperty("_hyprBorderWidth", v);
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 8

                FieldLabel {
                    text: qsTr("Top")
                }
                FieldLabel {
                    text: qsTr("Right")
                }
                FieldLabel {
                    text: qsTr("Bottom")
                }
                FieldLabel {
                    text: qsTr("Left")
                }

                IntField {
                    Layout.fillWidth: true
                    text: root.localGapTop.toString()
                    onEditingFinished: {
                        root.localGapTop = root._parseIntSafe(text, 0);
                        root._applyGapFields();
                    }
                }
                IntField {
                    Layout.fillWidth: true
                    text: root.localGapRight.toString()
                    onEditingFinished: {
                        root.localGapRight = root._parseIntSafe(text, 0);
                        root._applyGapFields();
                    }
                }
                IntField {
                    Layout.fillWidth: true
                    text: root.localGapBottom.toString()
                    onEditingFinished: {
                        root.localGapBottom = root._parseIntSafe(text, 0);
                        root._applyGapFields();
                    }
                }
                IntField {
                    Layout.fillWidth: true
                    text: root.localGapLeft.toString()
                    onEditingFinished: {
                        root.localGapLeft = root._parseIntSafe(text, 0);
                        root._applyGapFields();
                    }
                }
            }

            SettingsHelperText {
                text: qsTr("Hyprland accepts CSS-style gap syntax, but this page always writes the full four-value form so the result is predictable.")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                FieldLabel {
                    text: qsTr("Active Border Color")
                }

                SettingsHelperText {
                    text: qsTr("Gradient format example: 'rgba(FDEAB0ff) rgba(fd77e0ff) 45deg'.")
                }

                CompactField {
                    Layout.fillWidth: true
                    text: root.localActiveBorder
                    onEditingFinished: {
                        root.localActiveBorder = text;
                        root.applySingleProperty("_hyprActiveBorder", text);
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                FieldLabel {
                    text: qsTr("Inactive Border Color")
                }

                CompactField {
                    Layout.fillWidth: true
                    text: root.localInactiveBorder
                    onEditingFinished: {
                        root.localInactiveBorder = text;
                        root.applySingleProperty("_hyprInactiveBorder", text);
                    }
                }
            }
        }

        SectionCard {
            title: qsTr("Visual Effects")
            subtitle: qsTr("Blur, shadow, and dim controls based on the official Hyprland decoration variables.")

            SettingSwitch {
                label: qsTr("Enable Background Blur")
                isChecked: root.localBlurEnabled
                onIsCheckedChanged: {
                    if (root.isLoading)
                        return;
                    root.localBlurEnabled = isChecked;
                    root.applySingleProperty("_hyprBlurEnabled", isChecked);
                }
            }

            ColumnLayout {
                enabled: root.localBlurEnabled
                Layout.fillWidth: true
                Layout.leftMargin: 16
                spacing: 12

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Blur Size")
                    from: 1
                    to: 30
                    value: root.localBlurSize
                    onEditingFinished: v => {
                        root.localBlurSize = v;
                        root.applySingleProperty("_hyprBlurSize", v);
                    }
                }

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Blur Passes")
                    from: 1
                    to: 5
                    value: root.localBlurPasses
                    onEditingFinished: v => {
                        root.localBlurPasses = v;
                        root.applySingleProperty("_hyprBlurPasses", v);
                    }
                }

                SettingsHelperText {
                    text: qsTr("Larger blur size makes the blur softer. More passes improve quality but cost performance. For most systems, size 6-10 and 2-3 passes is enough.")
                }
            }

            SettingSwitch {
                label: qsTr("Enable Drop Shadow")
                isChecked: root.localDropShadow
                onIsCheckedChanged: {
                    if (root.isLoading)
                        return;
                    root.localDropShadow = isChecked;
                    root.applySingleProperty("_hyprDropShadow", isChecked ? "yes" : "no");
                }
            }

            ColumnLayout {
                enabled: root.localDropShadow
                Layout.fillWidth: true
                Layout.leftMargin: 16
                spacing: 12

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Shadow Range")
                    from: 0
                    to: 60
                    value: root.localShadowRange
                    onEditingFinished: v => {
                        root.localShadowRange = v;
                        root.applySingleProperty("_hyprShadowRange", v);
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        FieldLabel {
                            text: qsTr("Offset X")
                        }

                        IntField {
                            Layout.fillWidth: true
                            text: root.localShadowOffsetX.toString()
                            onEditingFinished: {
                                root.localShadowOffsetX = root._parseIntSafe(text, 0);
                                root.applySingleProperty("_hyprShadowOffset", Qt.point(root.localShadowOffsetX, root.localShadowOffsetY));
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        FieldLabel {
                            text: qsTr("Offset Y")
                        }

                        IntField {
                            Layout.fillWidth: true
                            text: root.localShadowOffsetY.toString()
                            onEditingFinished: {
                                root.localShadowOffsetY = root._parseIntSafe(text, 0);
                                root.applySingleProperty("_hyprShadowOffset", Qt.point(root.localShadowOffsetX, root.localShadowOffsetY));
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    FieldLabel {
                        text: qsTr("Shadow Color")
                    }

                    CompactField {
                        Layout.fillWidth: true
                        text: root.localShadowColor
                        onEditingFinished: {
                            root.localShadowColor = text;
                            root.applySingleProperty("_hyprShadowColor", text);
                        }
                    }
                }

                SettingsHelperText {
                    text: qsTr("Shadow range controls spread. Offset moves the shadow in pixels. A subtle setup is usually range 15-30 with offsets near 0-3.")
                }
            }

            SettingSwitch {
                label: qsTr("Dim Inactive Windows")
                isChecked: root.localDimInactive
                onIsCheckedChanged: {
                    if (root.isLoading)
                        return;
                    root.localDimInactive = isChecked;
                    root.applySingleProperty("_hyprDimInactive", isChecked);
                }
            }

            ColumnLayout {
                enabled: root.localDimInactive
                Layout.fillWidth: true
                Layout.leftMargin: 16

                SliderWithLabel {
                    Layout.fillWidth: true
                    label: qsTr("Dim Strength")
                    from: 0.0
                    to: 1.0
                    stepSize: 0.01
                    decimals: 2
                    value: root.localDimStrength
                    onEditingFinished: v => {
                        root.localDimStrength = v;
                        root.applySingleProperty("_hyprDimStrength", v);
                    }
                }
            }
        }

        SectionCard {
            title: qsTr("Animations")
            subtitle: qsTr("Presets are the easiest way to tune motion. Advanced rules remain available if you need exact Hyprland syntax.")

            SettingSwitch {
                label: qsTr("Enable Animations")
                isChecked: root.localAnimationsEnabled
                onIsCheckedChanged: {
                    if (root.isLoading)
                        return;
                    root.localAnimationsEnabled = isChecked;
                    root.applySingleProperty("_hyprAnimationsEnabled", isChecked);
                }
            }

            ColumnLayout {
                enabled: root.localAnimationsEnabled
                Layout.fillWidth: true
                Layout.leftMargin: 16
                spacing: 12

                Controls.Label {
                    text: qsTr("Current profile: ") + root._animationPresetLabel(root.localAnimationPresetKey)
                    font.bold: true
                    color: root.theme.colors.primary
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    MButton {
                        text: qsTr("Calm 120Hz")
                        isActive: root.localAnimationPresetKey === "calm"
                        onClicked: root._applyAnimationPreset("calm")
                        implicitWidth: 150
                    }

                    MButton {
                        text: qsTr("Balanced")
                        isActive: root.localAnimationPresetKey === "balanced"
                        onClicked: root._applyAnimationPreset("balanced")
                        implicitWidth: 150
                    }

                    MButton {
                        text: qsTr("Snappy")
                        isActive: root.localAnimationPresetKey === "snappy"
                        onClicked: root._applyAnimationPreset("snappy")
                        implicitWidth: 150
                    }
                }

                SettingsHelperText {
                    text: qsTr("Presets update all Hyprland animation rules together: bezier curves, window open/close, movement, fades, and workspace transitions.")
                }

                SettingSwitch {
                    label: qsTr("Show Advanced Animation Rules")
                    isChecked: root.localShowAdvancedAnimations
                    onIsCheckedChanged: root.localShowAdvancedAnimations = isChecked
                }

                ColumnLayout {
                    visible: root.localShowAdvancedAnimations
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        FieldLabel {
                            text: qsTr("Bezier Presets")
                        }

                        SettingsHelperText {
                            text: qsTr("One rule per line. Example: 'launch, 0.12, 0.95, 0.22, 1'.")
                        }

                        StyledTextArea {
                            Layout.fillWidth: true
                            text: root.localBezier
                            onEditingFinished: {
                                root.localBezier = value;
                                root.localAnimationPresetKey = root._detectAnimationPreset();
                                root.applySingleProperty("_hyprBezier", value);
                            }
                        }
                    }

                    Repeater {
                        model: [
                            {
                                label: qsTr("Window Open"),
                                prop: "_hyprAnimWindows",
                                valueProp: "localAnimWindows"
                            },
                            {
                                label: qsTr("Window Open (In)"),
                                prop: "_hyprAnimWindowsIn",
                                valueProp: "localAnimWindowsIn"
                            },
                            {
                                label: qsTr("Window Move"),
                                prop: "_hyprAnimWindowsMove",
                                valueProp: "localAnimWindowsMove"
                            },
                            {
                                label: qsTr("Window Close"),
                                prop: "_hyprAnimWindowsOut",
                                valueProp: "localAnimWindowsOut"
                            },
                            {
                                label: qsTr("Border"),
                                prop: "_hyprAnimBorder",
                                valueProp: "localAnimBorder"
                            },
                            {
                                label: qsTr("Border Angle"),
                                prop: "_hyprAnimBorderAngle",
                                valueProp: "localAnimBorderAngle"
                            },
                            {
                                label: qsTr("Fade In"),
                                prop: "_hyprAnimFadeIn",
                                valueProp: "localAnimFadeIn"
                            },
                            {
                                label: qsTr("Fade Out"),
                                prop: "_hyprAnimFadeOut",
                                valueProp: "localAnimFadeOut"
                            },
                            {
                                label: qsTr("Workspaces"),
                                prop: "_hyprAnimWorkspaces",
                                valueProp: "localAnimWorkspaces"
                            }
                        ]

                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            FieldLabel {
                                text: modelData.label
                            }

                            CompactField {
                                Layout.fillWidth: true
                                text: root[modelData.valueProp]
                                onEditingFinished: {
                                    root[modelData.valueProp] = text;
                                    root.localAnimationPresetKey = root._detectAnimationPreset();
                                    root.applySingleProperty(modelData.prop, text);
                                }
                            }
                        }
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
