pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: solarizedLight

    themeName: "SolarizedLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("solarized-light.png")

    _primary: Qt.rgba(0.14901961386203766, 0.545098066329956, 0.8235294222831726, 1)             // Blue
    _onPrimary: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)           // base3
    _secondary: Qt.rgba(0.5215686559677124, 0.6000000238418579, 0, 1)           // Green
    _onSecondary: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)
    _tertiary: Qt.rgba(0.8274509906768799, 0.21176470816135406, 0.5098039507865906, 1)            // Magenta
    _onTertiary: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)
    _error: Qt.rgba(0.8627451062202454, 0.19607843458652496, 0.18431372940540314, 1)               // Red
    _onError: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)

    _surface: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)                        // base3
    _onSurface: Qt.rgba(0.3960784375667572, 0.48235294222831726, 0.5137255191802979, 1)                      // base00
    _surfaceDim: Qt.rgba(0.9333333373069763, 0.9098039269447327, 0.8352941274642944, 1)                     // base2
    _surfaceBright: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9960784316062927, 0.9764705896377563, 0.9254902005195618, 1)
    _surfaceContainer: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)               // base3
    _surfaceContainerHigh: Qt.rgba(0.9333333373069763, 0.9098039269447327, 0.8352941274642944, 1)           // base2
    _surfaceContainerHighest: Qt.rgba(0.8274509906768799, 0.7960784435272217, 0.7176470756530762, 1)
    _surfaceVariant: Qt.rgba(0.9333333373069763, 0.9098039269447327, 0.8352941274642944, 1)
    _onSurfaceVariant: Qt.rgba(0.3450980484485626, 0.4313725531101227, 0.4588235318660736, 1)               // base01

    _primaryContainer: Qt.rgba(0.8196078538894653, 0.9019607901573181, 0.9607843160629272, 1)               // Light Blue container
    _onPrimaryContainer: Qt.rgba(0.10196078568696976, 0.3764705955982208, 0.5647059082984924, 1)
    _secondaryContainer: Qt.rgba(0.8784313797950745, 0.9137254953384399, 0.7843137383460999, 1)             // Light Green container
    _onSecondaryContainer: Qt.rgba(0.3529411852359772, 0.41960784792900085, 0, 1)
    _tertiaryContainer: Qt.rgba(0.9411764740943909, 0.8392156958580017, 0.8901960849761963, 1)              // Light Magenta container
    _onTertiaryContainer: Qt.rgba(0.5411764979362488, 0.16470588743686676, 0.3529411852359772, 1)
    _errorContainer: Qt.rgba(0.9607843160629272, 0.8392156958580017, 0.8392156958580017, 1)                 // Light Red container
    _onErrorContainer: Qt.rgba(0.6392157077789307, 0.11764705926179886, 0.11764705926179886, 1)

    _outline: Qt.rgba(0.5764706134796143, 0.6313725709915161, 0.6313725709915161, 1)                        // base1
    _outlineVariant: Qt.rgba(0.9333333373069763, 0.9098039269447327, 0.8352941274642944, 1)                 // base2
    _inverseSurface: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)                 // base03
    _onInverseSurface: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)
    _inversePrimary: Qt.rgba(0.14901961386203766, 0.545098066329956, 0.8235294222831726, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasSolarizedLight"
    _konsoleProfile: "SolarizedLight.profile"

    _themeIcons: "Papirus-Light"
    _gtkTheme: "Breeze"
    _kvantumTheme: "KvArc"
    _desktopClockPosition: Qt.point(1182.58984375, 329.7421875)
    _desktopClockSize: Qt.size(612.28125, 338.60546875)
}
