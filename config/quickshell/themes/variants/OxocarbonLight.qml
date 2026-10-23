pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: oxocarbonLight

    themeName: "OxocarbonLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("oxocarbon-light.png")

    _primary: Qt.rgba(0.05882352963089943, 0.3843137323856354, 0.9960784316062927, 1)             // IBM Blue 60
    _onPrimary: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)           // Light bg
    _secondary: Qt.rgba(0.5411764979362488, 0.24705882370471954, 0.9882352948188782, 1)           // IBM Purple 60
    _onSecondary: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)
    _tertiary: Qt.rgba(0, 0.4901960790157318, 0.4745098054409027, 1)            // Teal 60
    _onTertiary: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)
    _error: Qt.rgba(0.8549019694328308, 0.11764705926179886, 0.1568627506494522, 1)               // Red 60
    _onError: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)

    _surface: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)                        // Light bg
    _onSurface: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)                      // Dark fg
    _surfaceDim: Qt.rgba(0.8666666746139526, 0.8823529481887817, 0.9019607901573181, 1)                     // Gray 10
    _surfaceBright: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9725490212440491, 0.9803921580314636, 0.9843137264251709, 1)
    _surfaceContainer: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)
    _surfaceContainerHigh: Qt.rgba(0.8666666746139526, 0.8823529481887817, 0.9019607901573181, 1)
    _surfaceContainerHighest: Qt.rgba(0.7568627595901489, 0.7803921699523926, 0.8039215803146362, 1)        // Gray 20
    _surfaceVariant: Qt.rgba(0.8666666746139526, 0.8823529481887817, 0.9019607901573181, 1)
    _onSurfaceVariant: Qt.rgba(0.32156863808631897, 0.32156863808631897, 0.32156863808631897, 1)               // Gray 70

    _primaryContainer: Qt.rgba(0.8156862854957581, 0.886274516582489, 1, 1)               // Light Blue container
    _onPrimaryContainer: Qt.rgba(0, 0.16470588743686676, 0.3019607961177826, 1)
    _secondaryContainer: Qt.rgba(0.9098039269447327, 0.8549019694328308, 1, 1)             // Light Purple container
    _onSecondaryContainer: Qt.rgba(0.16470588743686676, 0.03921568766236305, 0.3686274588108063, 1)
    _tertiaryContainer: Qt.rgba(0.7568627595901489, 0.9411764740943909, 0.9411764740943909, 1)              // Light Teal container
    _onTertiaryContainer: Qt.rgba(0, 0.24313725531101227, 0.24313725531101227, 1)
    _errorContainer: Qt.rgba(1, 0.8392156958580017, 0.8509804010391235, 1)                 // Light Red container
    _onErrorContainer: Qt.rgba(0.3529411852359772, 0.03921568766236305, 0.054901961237192154, 1)

    _outline: Qt.rgba(0.5529412031173706, 0.5529412031173706, 0.5529412031173706, 1)                        // Gray 50
    _outlineVariant: Qt.rgba(0.8666666746139526, 0.8823529481887817, 0.9019607901573181, 1)
    _inverseSurface: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.08627451211214066, 1)
    _onInverseSurface: Qt.rgba(0.9490196108818054, 0.95686274766922, 0.9725490212440491, 1)
    _inversePrimary: Qt.rgba(0.05882352963089943, 0.3843137323856354, 0.9960784316062927, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasOxocarbonLight"
    _konsoleProfile: "OxocarbonLight.profile"

    _themeIcons: "Tela-light"
    _gtkTheme: "Breeze"
    _kvantumTheme: "KvArc"
}
