pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: oxocarbonDark

    themeName: "OxocarbonDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("oxocarbon-dark.png")

    _primary: Qt.rgba(0.20000000298023224, 0.6941176652908325, 1, 1)             // Blue
    _onPrimary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)           // Background
    _secondary: Qt.rgba(0.7450980544090271, 0.5843137502670288, 1, 1)           // Purple
    _onSecondary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)
    _tertiary: Qt.rgba(0.239215686917305, 0.8588235378265381, 0.8509804010391235, 1)            // Cyan
    _onTertiary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)
    _error: Qt.rgba(0.9333333373069763, 0.32549020648002625, 0.5882353186607361, 1)               // Red/Pink
    _onError: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)

    _surface: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)                        // Background
    _onSurface: Qt.rgba(0.8666666746139526, 0.8823529481887817, 0.9019607901573181, 1)                      // Foreground
    _surfaceDim: Qt.rgba(0.05882352963089943, 0.05882352963089943, 0.05882352963089943, 1)                     // Darker bg
    _surfaceBright: Qt.rgba(0.14901961386203766, 0.14901961386203766, 0.14901961386203766, 1)                  // bg2
    _surfaceContainerLowest: Qt.rgba(0.03921568766236305, 0.03921568766236305, 0.03921568766236305, 1)
    _surfaceContainerLow: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.06666667014360428, 1)
    _surfaceContainer: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)               // Background
    _surfaceContainerHigh: Qt.rgba(0.14901961386203766, 0.14901961386203766, 0.14901961386203766, 1)           // bg2
    _surfaceContainerHighest: Qt.rgba(0.2235294133424759, 0.2235294133424759, 0.2235294133424759, 1)        // bg3
    _surfaceVariant: Qt.rgba(0.14901961386203766, 0.14901961386203766, 0.14901961386203766, 1)
    _onSurfaceVariant: Qt.rgba(0.658823549747467, 0.658823549747467, 0.658823549747467, 1)

    _primaryContainer: Qt.rgba(0.10196078568696976, 0.16470588743686676, 0.22745098173618317, 1)               // Dark Blue container
    _onPrimaryContainer: Qt.rgba(0.20000000298023224, 0.6941176652908325, 1, 1)
    _secondaryContainer: Qt.rgba(0.16470588743686676, 0.12156862765550613, 0.22745098173618317, 1)             // Dark Purple container
    _onSecondaryContainer: Qt.rgba(0.7450980544090271, 0.5843137502670288, 1, 1)
    _tertiaryContainer: Qt.rgba(0.05882352963089943, 0.18039216101169586, 0.18039216101169586, 1)              // Dark Cyan container
    _onTertiaryContainer: Qt.rgba(0.239215686917305, 0.8588235378265381, 0.8509804010391235, 1)
    _errorContainer: Qt.rgba(0.22745098173618317, 0.10196078568696976, 0.16470588743686676, 1)                 // Dark Red container
    _onErrorContainer: Qt.rgba(0.9333333373069763, 0.32549020648002625, 0.5882353186607361, 1)

    _outline: Qt.rgba(0.32156863808631897, 0.32156863808631897, 0.32156863808631897, 1)                        // bg4
    _outlineVariant: Qt.rgba(0.2235294133424759, 0.2235294133424759, 0.2235294133424759, 1)                 // bg3
    _inverseSurface: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)
    _onInverseSurface: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)
    _inversePrimary: Qt.rgba(0.20000000298023224, 0.6941176652908325, 1, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.2666666805744171)

    _plasmaColorScheme: "NibrasOxocarbonDark"
    _konsoleProfile: "OxocarbonDark.profile"

    _themeIcons: "Tela-dark"
    _gtkTheme: "Breeze-Dark"
    _kvantumTheme: "KvArcDark"
}
