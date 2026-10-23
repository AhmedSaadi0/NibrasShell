pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: solarizedDark

    themeName: "SolarizedDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("solarized-dark.png")

    _primary: Qt.rgba(0.14901961386203766, 0.545098066329956, 0.8235294222831726, 1)             // Blue
    _onPrimary: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)           // base03
    _secondary: Qt.rgba(0.16470588743686676, 0.6313725709915161, 0.5960784554481506, 1)           // Cyan
    _onSecondary: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)
    _tertiary: Qt.rgba(0.42352941632270813, 0.4431372582912445, 0.7686274647712708, 1)            // Violet
    _onTertiary: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)
    _error: Qt.rgba(0.8627451062202454, 0.19607843458652496, 0.18431372940540314, 1)               // Red
    _onError: Qt.rgba(0.9921568632125854, 0.9647058844566345, 0.8901960849761963, 1)             // base3

    _surface: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)                        // base03
    _onSurface: Qt.rgba(0.5137255191802979, 0.5803921818733215, 0.5882353186607361, 1)                      // base0
    _surfaceDim: Qt.rgba(0, 0.11764705926179886, 0.14901961386203766, 1)                     // darker than base03
    _surfaceBright: Qt.rgba(0.027450980618596077, 0.21176470816135406, 0.25882354378700256, 1)                  // base02
    _surfaceContainerLowest: Qt.rgba(0, 0.0784313753247261, 0.10980392247438431, 1)
    _surfaceContainerLow: Qt.rgba(0, 0.11764705926179886, 0.14901961386203766, 1)
    _surfaceContainer: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)               // base03
    _surfaceContainerHigh: Qt.rgba(0.027450980618596077, 0.21176470816135406, 0.25882354378700256, 1)           // base02
    _surfaceContainerHighest: Qt.rgba(0.03921568766236305, 0.29019609093666077, 0.3529411852359772, 1)        // lighter highlight
    _surfaceVariant: Qt.rgba(0.027450980618596077, 0.21176470816135406, 0.25882354378700256, 1)
    _onSurfaceVariant: Qt.rgba(0.5764706134796143, 0.6313725709915161, 0.6313725709915161, 1)               // base1

    _primaryContainer: Qt.rgba(0.054901961237192154, 0.18431372940540314, 0.2705882489681244, 1)               // Dark Blue container
    _onPrimaryContainer: Qt.rgba(0.14901961386203766, 0.545098066329956, 0.8235294222831726, 1)
    _secondaryContainer: Qt.rgba(0.05098039284348488, 0.20000000298023224, 0.18431372940540314, 1)             // Dark Cyan container
    _onSecondaryContainer: Qt.rgba(0.16470588743686676, 0.6313725709915161, 0.5960784554481506, 1)
    _tertiaryContainer: Qt.rgba(0.11764705926179886, 0.13725490868091583, 0.25882354378700256, 1)              // Dark Violet container
    _onTertiaryContainer: Qt.rgba(0.42352941632270813, 0.4431372582912445, 0.7686274647712708, 1)
    _errorContainer: Qt.rgba(0.239215686917305, 0.10196078568696976, 0.10196078568696976, 1)                 // Dark Red container
    _onErrorContainer: Qt.rgba(0.8627451062202454, 0.19607843458652496, 0.18431372940540314, 1)

    _outline: Qt.rgba(0.3450980484485626, 0.4313725531101227, 0.4588235318660736, 1)                        // base01
    _outlineVariant: Qt.rgba(0.027450980618596077, 0.21176470816135406, 0.25882354378700256, 1)                 // base02
    _inverseSurface: Qt.rgba(0.9333333373069763, 0.9098039269447327, 0.8352941274642944, 1)                 // base2
    _onInverseSurface: Qt.rgba(0, 0.16862745583057404, 0.21176470816135406, 1)
    _inversePrimary: Qt.rgba(0.14901961386203766, 0.545098066329956, 0.8235294222831726, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasSolarizedDark"
    _konsoleProfile: "SolarizedDark.profile"

    _themeIcons: "Papirus-Dark"
    _gtkTheme: "Breeze-Dark"
    _kvantumTheme: "KvArcDark"
    _desktopClockPosition: Qt.point(515.24609375, 52.9140625)
    _desktopClockSize: Qt.size(535.30859375, 219.63671875)
}
