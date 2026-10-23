// themes/BaseTheme.qml

import QtQuick
import Quickshell
import org.kde.kirigami as Kirigami
import "root:/config"

PersistentProperties {
    id: root

    property string themeName: "BaseTheme"

    // --- SOURCE PROPERTIES (for overriding in custom themes) ---
    // These are the actual values. Custom themes will override these.
    // The underscore is a convention to indicate these are the 'backing' properties.
    property real _alpha: 1

    // --------------------
    // ------ Colors ------
    // --------------------
    property color _primary: Kirigami.Theme.highlightColor
    property color _onPrimary: Kirigami.Theme.highlightedTextColor

    property color _secondary: Kirigami.Theme.textColor
    property color _onSecondary: Kirigami.Theme.textColor

    property color _tertiary: "#bd93f9"
    property color _onTertiary: "#ffffff"

    function _colorToHyprRgba(color) {
        return 'rgba(' + Qt.rgba(color.r, color.g, color.b, 1).toString().slice(1) + 'ff)';
    }

    property color _error: Kirigami.Theme.negativeTextColor
    property color _onError: "#ffffff"

    // --- M3 Surface ---
    property color _surface: Kirigami.Theme.backgroundColor
    property color _onSurface: Kirigami.Theme.textColor
    property color _surfaceDim: Qt.darker(root._surface, 1.1)
    property color _surfaceBright: Qt.lighter(root._surface, 1.1)

    // --- M3 Surface Containers ---
    property color _surfaceContainerLowest: Qt.darker(root._surface, 1.15)
    property color _surfaceContainerLow: Qt.darker(root._surface, 1.05)
    property color _surfaceContainer: Kirigami.Theme.alternateBackgroundColor
    property color _surfaceContainerHigh: Qt.lighter(Kirigami.Theme.alternateBackgroundColor, 1.1)
    property color _surfaceContainerHighest: Qt.lighter(Kirigami.Theme.alternateBackgroundColor, 1.2)

    // --- M3 Surface Variant ---
    property color _surfaceVariant: Kirigami.Theme.alternateBackgroundColor
    property color _onSurfaceVariant: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.7)

    // --- M3 Container Colors ---
    property color _primaryContainer: root._primary
    property color _onPrimaryContainer: root._onPrimary
    property color _secondaryContainer: root._secondary
    property color _onSecondaryContainer: root._onSecondary
    property color _tertiaryContainer: root._tertiary
    property color _onTertiaryContainer: root._onTertiary
    property color _errorContainer: root._error
    property color _onErrorContainer: root._onError

    // --- M3 Outline ---
    property color _outline: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)
    property color _outlineVariant: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

    // --- M3 Inverse ---
    property color _inverseSurface: root._onSurface
    property color _onInverseSurface: root._surface
    property color _inversePrimary: root._primary

    // --- M3 Shadow & Scrim ---
    property color _shadow: "#000000"
    property color _scrim: "#000000"

    // --------------------
    // ---- Dimensions ----
    // --------------------
    property int _baseRadius: 12
    property int _barHeight: 30
    property int _leftBarWidth: 40
    property int _barBottomMargin: 10
    property int _barWidgetsHeight: 22
    property int _menuHeight: 900
    property int _menuWidth: 380
    property int _menuWidgetsMargin: 15
    property int _elementRadius: root._baseRadius // Reference the source property

    property int _spacingSmall: 4
    property int _spacingMedium: 8
    property int _spacingLarge: 12

    // --- M3 Shape Scale (Corner Radii) ---
    property int _shapeNone: 0
    property int _shapeExtraSmall: 4
    property int _shapeSmall: 8
    property int _shapeMedium: root._baseRadius // 12
    property int _shapeLarge: 16
    property int _shapeExtraLarge: 24
    property int _shapeFull: 28

    // --- Component Dimensions ---
    property int _dialogIconSize: 72
    property int _iconButtonSize: 36
    property int _iconButtonRadius: 18
    property int _chipHeight: 28
    property int _scrollbarWidth: 6
    property int _statCardRadius: 20
    property int _statCardHeight: 104

    // --- Animation Durations ---
    property int _dialogOpenScaleDuration: 400
    property int _dialogOpenOpacityDuration: 300
    property real _dialogInitialScale: 0.90

    // --------------------
    // ---- Typography ----
    // --------------------
    property string _iconFont: "FantasqueSansM Nerd Font Propo"
    property string _bodyFont: "JF Flat"
    property int _baseFontSize: 12
    property int _heading1Size: 22
    property int _heading2Size: 20
    property int _heading3Size: 18
    property int _heading4Size: 16
    property int _mediumFontSize: 14
    property int _smallFontSize: 12

    // ------------------------
    // -- System Integration --
    // ------------------------
    property bool _enableAccentColoring: false
    property string _qtThemeStyle: "Breeze"
    property string _plasmaColorScheme: "MaterialYouDark"
    property string _kvantumTheme: "KvGnome"
    property string _konsoleProfile: "MaterialYouAlt.profile"

    property string _gtkTheme: "Breeze"
    property string _themeMode: "dark"

    property string _themeIcons: "breeze-dark"

    property string _cursorTheme: "breeze_cursors"
    property int _cursorSize: 24

    // -------------------------
    // -- Wallpapers Settings --
    // -------------------------
    property string _wallpaper: "linux.png"
    property bool _enableDynamicColoring: false
    property bool _enableWallpaperBlur: false
    property real _wallpaperBlurStrength: 0.9

    property int _dynamicColoringSchemeVariant: 2
    property real _dynamicColoringChromaMult: 2.5
    property real _dynamicColoringToneMult: 1

    property bool _enableDynamicWallpapers: false
    property int _dynamicWallpapersInterval: 15 * 1000 * 60
    property string _dynamicWallpapersPath: ""
    property int _selectedWallpaperIndex: 0

    // ===================================
    // Hyprland Properties
    // ===================================
    // Decoration
    property int _hyprBorderWidth: 2
    property string _hyprActiveBorder: `${_colorToHyprRgba(_primary)} ${_colorToHyprRgba(_secondary)} ${_colorToHyprRgba(_tertiary)} 45deg`
    property string _hyprInactiveBorder: 'rgba(50505088)'
    property int _hyprRounding: 16
    property string _hyprDropShadow: 'no'

    // Gaps & Layout
    property int _hyprGapsIn: 5
    property string _hyprGapsOut: "12, 15, 15, 52"
    property string _hyprLayout: "dwindle"

    // Animations
    property bool _hyprAnimationsEnabled: true
    property string _hyprBezier: AnimationConfig.hyprBezier
    property string _hyprAnimWindows: AnimationConfig.hyprAnimWindows
    property string _hyprAnimWindowsIn: AnimationConfig.hyprAnimWindowsIn
    property string _hyprAnimWindowsMove: AnimationConfig.hyprAnimWindowsMove
    property string _hyprAnimWindowsOut: AnimationConfig.hyprAnimWindowsOut
    property string _hyprAnimBorder: AnimationConfig.hyprAnimBorder
    property string _hyprAnimBorderAngle: AnimationConfig.hyprAnimBorderAngle
    property string _hyprAnimFadeIn: AnimationConfig.hyprAnimFadeIn
    property string _hyprAnimFadeOut: AnimationConfig.hyprAnimFadeOut

    // مساحات العمل
    property string _hyprAnimWorkspaces: AnimationConfig.hyprAnimWorkspaces

    // Visual Effects (Blur & Dim)
    property bool _hyprBlurEnabled: true
    property int _hyprBlurSize: 4
    property int _hyprBlurPasses: 2
    property bool _hyprDimInactive: true
    property double _hyprDimStrength: 0.0

    // Shadow Enhancements
    property int _hyprShadowRange: 30
    property point _hyprShadowOffset: Qt.point(0, 0)
    property color _hyprShadowColor: "#00000044"

    // ----------------------------
    // --- Desktop Clock Widget ---
    // ----------------------------
    property bool _desktopClockEnabled: true
    property bool _desktopClockGlowEnabled: false
    property color _desktopClockGlowColor: "#FFFFFF"
    property real _desktopClockGlowIntensity: 0.65
    property color _desktopClockColor: _primary
    // توافقية: الأسماء القديمة (ظل) تشير لنفس قيم التوهج — للحفاظ على كاشات قديمة
    property alias _desktopClockShadowEnabled: root._desktopClockGlowEnabled
    property alias _desktopClockShadowColor: root._desktopClockGlowColor
    property bool _desktopClockUseThemeColor: true
    property bool _desktopClockUseAnimation: false
    property string _desktopClockLocal: "en_US"
    property string _desktopClockFormat: "hh:mm AP"
    property string _desktopClockFont: _bodyFont
    property point _desktopClockPosition: Qt.point(100, 100)

    // Depth Effect Settings
    property bool _desktopClockDepthEffectEnabled: false
    property string _desktopClockDepthModel: "u2net"
    property string _desktopClockDepthOverlayPath
    property size _desktopClockSize: Qt.size(701, 501)

    // ======================================================================
    // --- PUBLIC GROUPED API (for using the theme) ---
    // These structured objects are for clean access (e.g., theme.colors.xyz).
    // They are readonly to prevent accidental replacement.
    // ======================================================================

    // --- Color Palette ---

    readonly property var colors: QtObject {
        // General
        property color primary: Qt.rgba(root._primary.r, root._primary.g, root._primary.b, root._alpha)
        property color secondary: Qt.rgba(root._secondary.r, root._secondary.g, root._secondary.b, root._alpha)
        property alias onPrimary: root._onPrimary
        property alias onSecondary: root._onSecondary

        property color tertiary: Qt.rgba(root._tertiary.r, root._tertiary.g, root._tertiary.b, root._alpha)
        property alias onTertiary: root._onTertiary

        property color error: Qt.rgba(root._error.r, root._error.g, root._error.b, root._alpha)
        property alias onError: root._onError

        // --- M3 Surface ---
        property color surface: Qt.rgba(root._surface.r, root._surface.g, root._surface.b, root._alpha)
        property alias onSurface: root._onSurface
        property color surfaceDim: Qt.rgba(root._surfaceDim.r, root._surfaceDim.g, root._surfaceDim.b, root._alpha)
        property color surfaceBright: Qt.rgba(root._surfaceBright.r, root._surfaceBright.g, root._surfaceBright.b, root._alpha)

        // --- M3 Surface Containers ---
        property color surfaceContainerLowest: Qt.rgba(root._surfaceContainerLowest.r, root._surfaceContainerLowest.g, root._surfaceContainerLowest.b, root._alpha)
        property color surfaceContainerLow: Qt.rgba(root._surfaceContainerLow.r, root._surfaceContainerLow.g, root._surfaceContainerLow.b, root._alpha)
        property color surfaceContainer: Qt.rgba(root._surfaceContainer.r, root._surfaceContainer.g, root._surfaceContainer.b, root._alpha)
        property color surfaceContainerHigh: Qt.rgba(root._surfaceContainerHigh.r, root._surfaceContainerHigh.g, root._surfaceContainerHigh.b, root._alpha)
        property color surfaceContainerHighest: Qt.rgba(root._surfaceContainerHighest.r, root._surfaceContainerHighest.g, root._surfaceContainerHighest.b, root._alpha)

        // --- M3 Surface Variant ---
        property color surfaceVariant: Qt.rgba(root._surfaceVariant.r, root._surfaceVariant.g, root._surfaceVariant.b, root._alpha)
        property alias onSurfaceVariant: root._onSurfaceVariant

        // --- M3 Container Colors ---
        property color primaryContainer: Qt.rgba(root._primaryContainer.r, root._primaryContainer.g, root._primaryContainer.b, root._alpha)
        property alias onPrimaryContainer: root._onPrimaryContainer
        property color secondaryContainer: Qt.rgba(root._secondaryContainer.r, root._secondaryContainer.g, root._secondaryContainer.b, root._alpha)
        property alias onSecondaryContainer: root._onSecondaryContainer
        property color tertiaryContainer: Qt.rgba(root._tertiaryContainer.r, root._tertiaryContainer.g, root._tertiaryContainer.b, root._alpha)
        property alias onTertiaryContainer: root._onTertiaryContainer
        property color errorContainer: Qt.rgba(root._errorContainer.r, root._errorContainer.g, root._errorContainer.b, root._alpha)
        property alias onErrorContainer: root._onErrorContainer

        // --- M3 Outline ---
        property color outline: Qt.rgba(root._outline.r, root._outline.g, root._outline.b, root._alpha)
        property color outlineVariant: Qt.rgba(root._outlineVariant.r, root._outlineVariant.g, root._outlineVariant.b, root._alpha)

        // --- M3 Inverse ---
        property color inverseSurface: Qt.rgba(root._inverseSurface.r, root._inverseSurface.g, root._inverseSurface.b, root._alpha)
        property alias onInverseSurface: root._onInverseSurface
        property color inversePrimary: Qt.rgba(root._inversePrimary.r, root._inversePrimary.g, root._inversePrimary.b, root._alpha)

        // --- M3 Shadow & Scrim ---
        property alias shadow: root._shadow
        property alias scrim: root._scrim
    }

    // --- Dimensions and Spacing ---
    readonly property var dimensions: QtObject {
        property alias baseRadius: root._baseRadius
        property alias barHeight: root._barHeight
        property alias leftBarWidth: root._leftBarWidth
        property alias barBottomMargin: root._barBottomMargin
        property alias barWidgetsHeight: root._barWidgetsHeight
        property alias menuHeight: root._menuHeight
        property alias menuWidth: root._menuWidth
        property alias menuWidgetsMargin: root._menuWidgetsMargin
        property alias elementRadius: root._elementRadius

        property alias spacingSmall: root._spacingSmall
        property alias spacingMedium: root._spacingMedium
        property alias spacingLarge: root._spacingLarge

        // --- M3 Shape Scale ---
        property alias shapeNone: root._shapeNone
        property alias shapeExtraSmall: root._shapeExtraSmall
        property alias shapeSmall: root._shapeSmall
        property alias shapeMedium: root._shapeMedium
        property alias shapeLarge: root._shapeLarge
        property alias shapeExtraLarge: root._shapeExtraLarge
        property alias shapeFull: root._shapeFull

        // --- Component Dimensions ---
        property alias dialogIconSize: root._dialogIconSize
        property alias iconButtonSize: root._iconButtonSize
        property alias iconButtonRadius: root._iconButtonRadius
        property alias chipHeight: root._chipHeight
        property alias scrollbarWidth: root._scrollbarWidth
        property alias statCardRadius: root._statCardRadius
        property alias statCardHeight: root._statCardHeight

        // --- Animation ---
        property alias dialogOpenScaleDuration: root._dialogOpenScaleDuration
        property alias dialogOpenOpacityDuration: root._dialogOpenOpacityDuration
        property alias dialogInitialScale: root._dialogInitialScale
    }

    // --- Typography ---
    readonly property var typography: QtObject {
        property alias iconFont: root._iconFont
        property alias bodyFont: root._bodyFont
        property alias heading1Size: root._heading1Size
        property alias heading2Size: root._heading2Size
        property alias heading3Size: root._heading3Size
        property alias heading4Size: root._heading4Size
        property alias baseFontSize: root._baseFontSize
        property alias medium: root._mediumFontSize
        property alias small: root._smallFontSize

        property alias spacingSmall: root._spacingSmall
        property alias spacingMedium: root._spacingMedium
        property alias spacingLarge: root._spacingLarge
    }

    // --- System Integration Settings ---
    readonly property var systemSettings: QtObject {
        property alias wallpaper: root._wallpaper
        property alias qtThemeStyle: root._qtThemeStyle
        property alias kvantumTheme: root._kvantumTheme
        property alias gtkTheme: root._gtkTheme
        property alias themeIcons: root._themeIcons
        property alias themeMode: root._themeMode
        property alias cursorTheme: root._cursorTheme
        property alias cursorSize: root._cursorSize
        property alias plasmaColorScheme: root._plasmaColorScheme
        property alias konsoleProfile: root._konsoleProfile
        property alias fontName: root._bodyFont

        property alias enableAccentColoring: root._enableAccentColoring
        property alias enableDynamicColoring: root._enableDynamicColoring
        property alias enableWallpaperBlur: root._enableWallpaperBlur
        property alias wallpaperBlurStrength: root._wallpaperBlurStrength
        property alias enableDynamicWallpapers: root._enableDynamicWallpapers
        property alias dynamicWallpapersInterval: root._dynamicWallpapersInterval
        property alias dynamicWallpapersPath: root._dynamicWallpapersPath
        property alias selectedWallpaperIndex: root._selectedWallpaperIndex

        property alias dynamicColoringSchemeVariant: root._dynamicColoringSchemeVariant
        property alias dynamicColoringChromaMult: root._dynamicColoringChromaMult
        property alias dynamicColoringToneMult: root._dynamicColoringToneMult
    }

    // --- Hyprland Configuration ---
    readonly property var hyprlandConfiguration: QtObject {
        // --- Decoration ---
        property alias borderWidth: root._hyprBorderWidth
        property alias activeBorder: root._hyprActiveBorder
        property alias inactiveBorder: root._hyprInactiveBorder
        property alias rounding: root._hyprRounding
        property alias dropShadow: root._hyprDropShadow

        // --- Gaps & Layout ---
        property alias gapsIn: root._hyprGapsIn
        property alias gapsOut: root._hyprGapsOut
        property alias layout: root._hyprLayout

        // --- Animations ---
        property alias animationsEnabled: root._hyprAnimationsEnabled
        property alias bezier: root._hyprBezier
        property alias animWindows: root._hyprAnimWindows
        property alias animWindowsIn: root._hyprAnimWindowsIn
        property alias animWindowsMove: root._hyprAnimWindowsMove
        property alias animWindowsOut: root._hyprAnimWindowsOut
        property alias animBorder: root._hyprAnimBorder
        property alias animBorderAngle: root._hyprAnimBorderAngle
        property alias animFadeIn: root._hyprAnimFadeIn
        property alias animFadeOut: root._hyprAnimFadeOut
        property alias animWorkspaces: root._hyprAnimWorkspaces

        // --- Visual Effects ---
        property alias blurEnabled: root._hyprBlurEnabled
        property alias blurSize: root._hyprBlurSize
        property alias blurPasses: root._hyprBlurPasses
        property alias dimInactive: root._hyprDimInactive
        property alias dimStrength: root._hyprDimStrength

        // --- Shadow Enhancements ---
        property alias shadowRange: root._hyprShadowRange
        property alias shadowOffset: root._hyprShadowOffset
        property alias shadowColor: root._hyprShadowColor

        // --- Cursor Settings ---
        property alias cursorTheme: root._cursorTheme
        property alias cursorSize: root._cursorSize
    }

    // --- Desktop Clock Widget Configuration ---
    readonly property var desktopClock: QtObject {
        property alias enabled: root._desktopClockEnabled
        property alias glowEnabled: root._desktopClockGlowEnabled
        property alias glowColor: root._desktopClockGlowColor
        property alias glowIntensity: root._desktopClockGlowIntensity
        // أسماء قديمة للتوافق
        property alias shadowEnabled: root._desktopClockGlowEnabled
        property alias shadowColor: root._desktopClockGlowColor
        property alias color: root._desktopClockColor
        property alias useThemeColor: root._desktopClockUseThemeColor
        property alias enableAnimation: root._desktopClockUseAnimation
        property alias local: root._desktopClockLocal
        property alias format: root._desktopClockFormat
        property alias font: root._desktopClockFont
        property alias position: root._desktopClockPosition
        property alias size: root._desktopClockSize

        // Depth Effect
        property alias depthEffectEnabled: root._desktopClockDepthEffectEnabled
        property alias depthModel: root._desktopClockDepthModel
        property alias depthOverlayPath: root._desktopClockDepthOverlayPath
    }
}
