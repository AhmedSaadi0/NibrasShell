pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: draculaDark

    themeName: "DraculaDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("dracula_dark.png")

    _desktopClockEnabled: true
    _desktopClockFont: "abeatbyKai"
    _desktopClockColor: Qt.rgba(1, 1, 0.7843289971351624, 1)
    _desktopClockFormat: "hh:mm AP"
    _desktopClockSize: Qt.size(547.51, 120.33)
    _desktopClockPosition: Qt.point(1328.48, 40.24)
    _desktopClockShadowEnabled: true
    _desktopClockShadowColor: Qt.rgba(0.8196078538894653, 0.8196078538894653, 0.8196078538894653, 1)
    _desktopClockUseThemeColor: false
    _desktopClockUseAnimation: true

    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "u2net"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("dracula_dark_depth.png")

    _baseRadius: 1
    _elementRadius: 1
    _iconFont: "FantasqueSansM Nerd Font Propo"
    _bodyFont: "JF Flat"

    _shapeNone: 0
    _shapeExtraSmall: 1
    _shapeSmall: 1
    _shapeMedium: 1
    _shapeLarge: 1
    _shapeExtraLarge: 1
    _shapeFull: 1

    _iconButtonRadius: 1
    _statCardRadius: 1

    _themeIcons: "Papirus"

    _hyprBorderWidth: 2
    _hyprRounding: 0
    _hyprDropShadow: "yes"
    _hyprGapsIn: 5
    _hyprGapsOut: "12, 15, 15, 52"
    _hyprLayout: "dwindle"
    _hyprAnimationsEnabled: true
    _hyprBezier: "win_in, 0.16, 1, 0.3, 1\nwin_out, 0.3, 0, 0.6, 1\nmove, 0.2, 0.85, 0.15, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.12, 0.95, 0.22, 1"
    _hyprAnimWindows: "1, 8, launch, popin 90%"
    _hyprAnimWorkspaces: "1, 7, move, slide"
    _hyprBlurEnabled: true
    _hyprBlurSize: 2
    _hyprBlurPasses: 2
    _hyprDimInactive: true
    _hyprDimStrength: 0
    _hyprShadowRange: 30
    _hyprShadowColor: Qt.rgba(0, 0, 0, 0.2666666805744171)

    _primary: Qt.rgba(0.7412070035934448, 0.5764706134796143, 0.9764705896377563, 1)           // Purple
    _secondary: Qt.rgba(0.545098066329956, 0.9136949777603149, 0.9921568632125854, 1)         // Cyan
    _onPrimary: Qt.rgba(0.09803921729326248, 0.10196078568696976, 0.12941177189350128, 1)         // Standard Dracula dark bg
    _onSecondary: Qt.rgba(0.09803921729326248, 0.10196078568696976, 0.12941177189350128, 1)
    _tertiary: Qt.rgba(0.3137255012989044, 0.9803921580314636, 0.48239871859550476, 1)          // Green
    _onTertiary: Qt.rgba(0.09803921729326248, 0.10196078568696976, 0.12941177189350128, 1)
    _error: Qt.rgba(1, 0.3333333432674408, 0.3333333432674408, 1)             // Red
    _onError: Qt.rgba(0.09803921729326248, 0.10196078568696976, 0.12941177189350128, 1)

    _surface: Qt.rgba(0.1568627506494522, 0.16470588743686676, 0.21176470816135406, 1)                      // Background
    _onSurface: Qt.rgba(0.9725490212440491, 0.9725490212440491, 0.9490196108818054, 1)                    // Foreground
    _surfaceDim: Qt.rgba(0.12941177189350128, 0.13333334028720856, 0.1725642830133438, 1)                   // Darker bg
    _surfaceBright: Qt.rgba(0.20392157137393951, 0.21568627655506134, 0.27450981736183167, 1)                // Selection / Current Line
    _surfaceContainerLowest: Qt.rgba(0.09803921729326248, 0.10196078568696976, 0.12941177189350128, 1)
    _surfaceContainerLow: Qt.rgba(0.12941177189350128, 0.13333334028720856, 0.1725642830133438, 1)
    _surfaceContainer: Qt.rgba(0.1568627506494522, 0.16470588743686676, 0.21176470816135406, 1)
    _surfaceContainerHigh: Qt.rgba(0.20392157137393951, 0.21568627655506134, 0.27450981736183167, 1)
    _surfaceContainerHighest: Qt.rgba(0.2666666805744171, 0.27843138575553894, 0.3529411852359772, 1)
    _surfaceVariant: Qt.rgba(0.20392157137393951, 0.21568627655506134, 0.27450981736183167, 1)
    _onSurfaceVariant: Qt.rgba(0.7490196228027344, 0.7490196228027344, 0.7490196228027344, 1)

    // مواءمة الألوان وفق تدرجات دراكولا الحقيقية (بأبعاد متباينة بدلاً من اللون الموحد 44475A)
    _primaryContainer: Qt.rgba(0.2078583985567093, 0.16078431904315948, 0.29021134972572327, 1)             // Dark Purple selection-like
    _onPrimaryContainer: Qt.rgba(0.7412070035934448, 0.5764706134796143, 0.9764705896377563, 1)
    _secondaryContainer: Qt.rgba(0.11764705926179886, 0.2078583985567093, 0.23138780891895294, 1)           // Dark Cyan selection-like
    _onSecondaryContainer: Qt.rgba(0.545098066329956, 0.9136949777603149, 0.9921568632125854, 1)
    _tertiaryContainer: Qt.rgba(0.10980392247438431, 0.23138780891895294, 0.1411764770746231, 1)            // Dark Green selection-like
    _onTertiaryContainer: Qt.rgba(0.3137255012989044, 0.9803921580314636, 0.48239871859550476, 1)
    _errorContainer: Qt.rgba(0.2392309457063675, 0.10980392247438431, 0.10980392247438431, 1)               // Dark Red selection-like
    _onErrorContainer: Qt.rgba(1, 0.3333333432674408, 0.3333333432674408, 1)

    _outline: Qt.rgba(0.3843137323856354, 0.4470740854740143, 0.6431372761726379, 1)                      // Dracula Comment Color (ممتازة للحدود الافتراضية)
    _outlineVariant: Qt.rgba(0.2666666805744171, 0.27843138575553894, 0.3529411852359772, 1)               // Dracula Selection Color
    _inverseSurface: Qt.rgba(0.9725490212440491, 0.9725490212440491, 0.9490196108818054, 1)
    _onInverseSurface: Qt.rgba(0.1568627506494522, 0.16470588743686676, 0.21176470816135406, 1)
    _inversePrimary: Qt.rgba(0.7412070035934448, 0.5764706134796143, 0.9764705896377563, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)

    _plasmaColorScheme: "Dracula"
    _konsoleProfile: "DraculaDark.profile"

    _kvantumTheme: "Tellgo"
    _gtkTheme: "Dracula"
    _desktopClockGlowColor: Qt.rgba(0.8196078538894653, 0.8196078538894653, 0.8196078538894653, 1)
    _desktopClockGlowEnabled: true
}
