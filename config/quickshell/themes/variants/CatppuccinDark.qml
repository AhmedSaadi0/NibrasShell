pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: catppuccindarkTheme

    themeName: "CatppuccinDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("CatppuccinDark.jpeg")

    _primary: Qt.rgba(0.537, 0.706, 0.980, 1)                     // Blue (#89b4fa)
    _onPrimary: Qt.rgba(0.067, 0.067, 0.106, 1)                   // Crust (#11111b)
    _secondary: Qt.rgba(0.961, 0.761, 0.906, 1)                   // تصحيح: Pink الحقيقي لكاتبوتشين (#f5c2e7)
    _onSecondary: Qt.rgba(0.067, 0.067, 0.106, 1)
    _tertiary: Qt.rgba(0.796, 0.651, 0.969, 1)                    // Mauve (#cba6f7)
    _onTertiary: Qt.rgba(0.067, 0.067, 0.106, 1)
    _error: Qt.rgba(0.953, 0.545, 0.659, 1)                       // Red (#f38ba8)
    _onError: Qt.rgba(0.067, 0.067, 0.106, 1)

    _surface: Qt.rgba(0.118, 0.118, 0.180, 1)                     // Base (#1e1e2e)
    _onSurface: Qt.rgba(0.804, 0.839, 0.957, 1)                   // Text (#cdd6f4)
    _surfaceDim: Qt.rgba(0.094, 0.094, 0.145, 1)                  // Mantle (#181825)
    _surfaceBright: Qt.rgba(0.192, 0.196, 0.267, 1)               // Surface0 (#313244)
    _surfaceContainerLowest: Qt.rgba(0.067, 0.067, 0.106, 1)      // Crust (#11111b)
    _surfaceContainerLow: Qt.rgba(0.082, 0.082, 0.133, 1)
    _surfaceContainer: Qt.rgba(0.118, 0.118, 0.180, 1)            // Base (#1e1e2e)
    _surfaceContainerHigh: Qt.rgba(0.145, 0.145, 0.220, 1)
    _surfaceContainerHighest: Qt.rgba(0.192, 0.196, 0.267, 1)     // Surface0 (#313244)
    _surfaceVariant: Qt.rgba(0.192, 0.196, 0.267, 1)
    _onSurfaceVariant: Qt.rgba(0.729, 0.761, 0.871, 1)            // Subtext1 (#bac2de)

    _primaryContainer: Qt.rgba(0.145, 0.188, 0.294, 1)
    _onPrimaryContainer: Qt.rgba(0.537, 0.706, 0.980, 1)
    _secondaryContainer: Qt.rgba(0.271, 0.141, 0.208, 1)
    _onSecondaryContainer: Qt.rgba(0.961, 0.761, 0.906, 1)
    _tertiaryContainer: Qt.rgba(0.227, 0.145, 0.306, 1)
    _onTertiaryContainer: Qt.rgba(0.796, 0.651, 0.969, 1)
    _errorContainer: Qt.rgba(0.271, 0.141, 0.173, 1)
    _onErrorContainer: Qt.rgba(0.953, 0.545, 0.659, 1)

    _outline: Qt.rgba(0.345, 0.357, 0.439, 1)                     // Surface2 (#585b70)
    _outlineVariant: Qt.rgba(0.271, 0.278, 0.353, 1)              // Surface1 (#45475a)
    _inverseSurface: Qt.rgba(0.804, 0.839, 0.957, 1)
    _onInverseSurface: Qt.rgba(0.118, 0.118, 0.180, 1)
    _inversePrimary: Qt.rgba(0.537, 0.706, 0.980, 1)
    _shadow: Qt.rgba(0.059, 0.059, 0.059, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)

    // تصحيح ألوان الإطار لتكون ألوان كاتبوتشين موكا الأصلية (Blue, Mauve, Pink)
    _hyprActiveBorder: "rgba(89b4faff) rgba(cba6f7ff) rgba(f5c2e7ff) 45deg"
    _hyprShadowColor: Qt.rgba(0, 0.267, 0, 0)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasShellAiGenerated-20260702_035126"
    _konsoleProfile: "CatppuccinDark.profile"

    _themeIcons: "Tela-blue"
    _gtkTheme: "Catppuccin-Mocha-Standard-Blue-Dark"
    _cursorTheme: "Ketsa-icons"
    _desktopClockFont: "Blacklisted"
    _desktopClockColor: Qt.rgba(0.553, 0.816, 0.941, 1)
    _desktopClockPosition: Qt.point(973.82421875, 491.3125)
    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "isnet-general-use"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("CatppuccinDark_depth.png")
    _desktopClockSize: Qt.size(785.49609375, 283.03515625)
    _desktopClockGlowColor: Qt.rgba(0.553, 0.816, 0.941, 1)
    _desktopClockGlowEnabled: true
    _desktopClockGlowIntensity: 0.5
    _desktopClockUseThemeColor: false
}
