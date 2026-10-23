pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: rosePineLight

    themeName: "RosePineLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("rosepine-light.png")

    _primary: Qt.rgba(0.843137264251709, 0.5098039507865906, 0.4941176474094391, 1)             // Rose (Dawn)
    _onPrimary: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)           // Base Dawn
    _secondary: Qt.rgba(0.5647059082984924, 0.47843137383461, 0.6627451181411743, 1)           // Iris
    _onSecondary: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)
    _tertiary: Qt.rgba(0.33725491166114807, 0.5803921818733215, 0.6235294342041016, 1)            // Foam
    _onTertiary: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)
    _error: Qt.rgba(0.7058823704719543, 0.38823530077934265, 0.47843137383461, 1)               // Love
    _onError: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)

    _surface: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)                        // Base Dawn
    _onSurface: Qt.rgba(0.34117648005485535, 0.32156863808631897, 0.4745098054409027, 1)                      // Text Dawn
    _surfaceDim: Qt.rgba(0.9490196108818054, 0.9137254953384399, 0.8823529481887817, 1)                     // Overlay
    _surfaceBright: Qt.rgba(1, 0.9803921580314636, 0.9529411792755127, 1)                  // Surface
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(1, 0.9803921580314636, 0.9529411792755127, 1)            // Surface
    _surfaceContainer: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)               // Base
    _surfaceContainerHigh: Qt.rgba(0.9490196108818054, 0.9137254953384399, 0.8823529481887817, 1)           // Overlay
    _surfaceContainerHighest: Qt.rgba(0.9098039269447327, 0.8666666746139526, 0.8274509906768799, 1)
    _surfaceVariant: Qt.rgba(0.9490196108818054, 0.9137254953384399, 0.8823529481887817, 1)
    _onSurfaceVariant: Qt.rgba(0.4745098054409027, 0.4588235318660736, 0.5764706134796143, 1)               // Subtle

    _primaryContainer: Qt.rgba(0.9411764740943909, 0.8509804010391235, 0.843137264251709, 1)               // Light Rose container
    _onPrimaryContainer: Qt.rgba(0.5411764979362488, 0.22745098173618317, 0.19607843458652496, 1)
    _secondaryContainer: Qt.rgba(0.9019607901573181, 0.8627451062202454, 0.929411768913269, 1)             // Light Iris container
    _onSecondaryContainer: Qt.rgba(0.3529411852359772, 0.22745098173618317, 0.4156862795352936, 1)
    _tertiaryContainer: Qt.rgba(0.8470588326454163, 0.9098039269447327, 0.9176470637321472, 1)              // Light Foam container
    _onTertiaryContainer: Qt.rgba(0.16470588743686676, 0.3529411852359772, 0.3843137323856354, 1)
    _errorContainer: Qt.rgba(0.929411768913269, 0.8470588326454163, 0.8627451062202454, 1)                 // Light Love container
    _onErrorContainer: Qt.rgba(0.7058823704719543, 0.38823530077934265, 0.47843137383461, 1)

    _outline: Qt.rgba(0.5960784554481506, 0.5764706134796143, 0.6470588445663452, 1)                        // Muted
    _outlineVariant: Qt.rgba(0.9490196108818054, 0.9137254953384399, 0.8823529481887817, 1)                 // Overlay
    _inverseSurface: Qt.rgba(0.34117648005485535, 0.32156863808631897, 0.4745098054409027, 1)
    _onInverseSurface: Qt.rgba(0.9803921580314636, 0.95686274766922, 0.929411768913269, 1)
    _inversePrimary: Qt.rgba(0.843137264251709, 0.5098039507865906, 0.4941176474094391, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasRosePineLight"
    _konsoleProfile: "RosePineLight.profile"

    _themeIcons: "Tela-light"
    _gtkTheme: "Breeze"
    _kvantumTheme: "KvArc"
}
