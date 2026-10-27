pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: catppuccinLightTheme

    themeName: "CatppuccinLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("catppuccin_light.jpeg")

    _desktopClockEnabled: true
    _desktopClockFont: "Overhead BRK"
    _desktopClockColor: Qt.rgba(0.157, 0.122, 0.204, 1)
    _desktopClockFormat: "hh:mm AP - MM/dd"
    _desktopClockSize: Qt.size(638.23, 225.73)
    _desktopClockPosition: Qt.point(638.09, 552.60)
    _desktopClockShadowEnabled: false
    _desktopClockShadowColor: Qt.rgba(0, 0, 0.267, 0)
    _desktopClockUseThemeColor: false
    _desktopClockUseAnimation: true

    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "u2net"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("catppuccin_light_depth.png")

    _baseRadius: 12
    _elementRadius: 15
    _iconFont: "FantasqueSansM Nerd Font Propo"
    _bodyFont: "JF Flat"

    _themeIcons: "Colloid-Purple-Dracula-Dark"

    _hyprBorderWidth: 2
    _hyprRounding: 12
    _hyprDropShadow: "yes"
    _hyprGapsIn: 5
    _hyprGapsOut: "12, 15, 15, 52"
    _hyprLayout: "dwindle"
    _hyprAnimationsEnabled: true
    _hyprBezier: "win_in, 0.16, 1, 0.3, 1\nwin_out, 0.3, 0, 0.6, 1\nmove, 0.2, 0.85, 0.15, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.12, 0.95, 0.22, 1"
    _hyprAnimWindows: "1, 8, launch, popin 90%"
    _hyprAnimWorkspaces: "1, 7, move, slide"
    _hyprBlurEnabled: true
    _hyprBlurSize: 4
    _hyprBlurPasses: 2
    _hyprDimInactive: false
    _hyprDimStrength: 0
    _hyprShadowRange: 11
    _hyprShadowColor: Qt.rgba(0.051, 0.051, 0.051, 0.333)

    // الألوان الرئيسية لـ Catppuccin Latte
    _primary: Qt.rgba(0.106, 0.525, 0.796, 1)                     // Latte Blue (#1e66f5)
    _onPrimary: Qt.rgba(1, 1, 1, 1)

    _secondary: Qt.rgba(0.918, 0.463, 0.796, 1)                   // Latte Pink (#ea76cb)
    _onSecondary: Qt.rgba(0.298, 0.310, 0.412, 1)                 // تصحيح: نص داكن للقراءة فوق الوردي (#4c4f69)

    _tertiary: Qt.rgba(0.251, 0.627, 0.169, 1)                    // Latte Green (#40a02b)
    _onTertiary: Qt.rgba(1, 1, 1, 1)

    _error: Qt.rgba(0.824, 0.059, 0.224, 1)                       // Latte Red (#d20f39)
    _onError: Qt.rgba(1, 1, 1, 1)

    // الخلفيات والأسطح
    _surface: Qt.rgba(0.937, 0.945, 0.961, 1)                     // Base (#eff1f5)
    _onSurface: Qt.rgba(0.298, 0.310, 0.412, 1)                   // Text (#4c4f69)
    _surfaceDim: Qt.rgba(0.863, 0.878, 0.910, 1)                  // Crust (#dce0e8)
    _surfaceBright: Qt.rgba(1, 1, 1, 1)

    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.902, 0.914, 0.937, 1)         // Mantle (#e6e9ef)
    _surfaceContainer: Qt.rgba(0.937, 0.945, 0.961, 1)            // Base (#eff1f5)
    _surfaceContainerHigh: Qt.rgba(0.863, 0.878, 0.910, 1)
    _surfaceContainerHighest: Qt.rgba(0.800, 0.816, 0.855, 1)     // Surface0 (#ccd0da)
    _surfaceVariant: Qt.rgba(0.863, 0.878, 0.910, 1)
    _onSurfaceVariant: Qt.rgba(0.424, 0.439, 0.525, 1)            // Subtext0 (#6c6f85)

    _primaryContainer: Qt.rgba(0.824, 0.902, 0.988, 1)
    _onPrimaryContainer: Qt.rgba(0.106, 0.325, 0.596, 1)
    _secondaryContainer: Qt.rgba(0.992, 0.875, 0.914, 1)
    _onSecondaryContainer: Qt.rgba(0.518, 0.153, 0.424, 1)
    _tertiaryContainer: Qt.rgba(0.886, 0.937, 0.875, 1)
    _onTertiaryContainer: Qt.rgba(0.176, 0.439, 0.118, 1)
    _errorContainer: Qt.rgba(0.973, 0.843, 0.855, 1)
    _onErrorContainer: Qt.rgba(0.524, 0.039, 0.141, 1)

    _outline: Qt.rgba(0.612, 0.627, 0.690, 1)                     // Surface2 (#9ca0b0)
    _outlineVariant: Qt.rgba(0.800, 0.816, 0.855, 1)              // Surface0 (#ccd0da)
    _inverseSurface: Qt.rgba(0.298, 0.310, 0.412, 1)
    _onInverseSurface: Qt.rgba(0.937, 0.945, 0.961, 1)
    _inversePrimary: Qt.rgba(0.537, 0.706, 0.980, 1)
    _shadow: Qt.rgba(0.133, 0.133, 0.133, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasCatppuccinLight"
    _konsoleProfile: "CatppuccinLight.profile"

    _gtkTheme: "Catppuccin-Latte-Standard-Blue-Light"
    _desktopClockGlowColor: Qt.rgba(0, 0, 0.267, 0)
}
