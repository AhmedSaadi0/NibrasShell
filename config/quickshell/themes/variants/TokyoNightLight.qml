pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: lightTheme
    themeName: "TokyoNightLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("TokyoNightLight.png")

    _primary: Qt.rgba(0.18039216101169586, 0.4901960790157318, 0.9137254953384399, 1)           // Light Blue
    _onPrimary: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)         // Light Base
    _secondary: Qt.rgba(0.47058823704719543, 0.27843138575553894, 0.7411764860153198, 1)         // Light Purple
    _onSecondary: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)
    _tertiary: Qt.rgba(0, 0.4431372582912445, 0.5921568870544434, 1)           // Light Cyan
    _onTertiary: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)
    _error: Qt.rgba(0.9607843160629272, 0.16470588743686676, 0.3960784375667572, 1)             // Light Red
    _onError: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)

    _surface: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)                      // bg
    _onSurface: Qt.rgba(0.21568627655506134, 0.3764705955982208, 0.7490196228027344, 1)                    // fg
    _surfaceDim: Qt.rgba(0.8352941274642944, 0.8392156958580017, 0.8588235378265381, 1)                   // bg_dark
    _surfaceBright: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9019607901573181, 0.9019607901573181, 0.9137254953384399, 1)
    _surfaceContainer: Qt.rgba(0.8705882430076599, 0.8705882430076599, 0.8823529481887817, 1)
    _surfaceContainerHigh: Qt.rgba(0.8352941274642944, 0.8392156958580017, 0.8588235378265381, 1)
    _surfaceContainerHighest: Qt.rgba(0.7372549176216125, 0.7529411911964417, 0.800000011920929, 1)
    _surfaceVariant: Qt.rgba(0.8352941274642944, 0.8392156958580017, 0.8588235378265381, 1)
    _onSurfaceVariant: Qt.rgba(0.3803921639919281, 0.4470588266849518, 0.6901960968971252, 1)             // fg_gutter

    // استبدال اللون الموحد D5D6DB بتدرجات تحديد لطيفة وباهتة تلائم طوكيو نايت المضيء
    _primaryContainer: Qt.rgba(0.8117647171020508, 0.8784313797950745, 0.9764705896377563, 1)             // Light Blue Selection
    _onPrimaryContainer: Qt.rgba(0.18039216101169586, 0.4901960790157318, 0.9137254953384399, 1)
    _secondaryContainer: Qt.rgba(0.8980392217636108, 0.8588235378265381, 0.9607843160629272, 1)           // Light Purple Selection
    _onSecondaryContainer: Qt.rgba(0.47058823704719543, 0.27843138575553894, 0.7411764860153198, 1)
    _tertiaryContainer: Qt.rgba(0.8392156958580017, 0.9333333373069763, 0.9607843160629272, 1)            // Light Cyan Selection
    _onTertiaryContainer: Qt.rgba(0, 0.4431372582912445, 0.5921568870544434, 1)
    _errorContainer: Qt.rgba(0.9921568632125854, 0.8666666746139526, 0.9019607901573181, 1)               // Light Red Selection
    _onErrorContainer: Qt.rgba(0.9607843160629272, 0.16470588743686676, 0.3960784375667572, 1)

    _outline: Qt.rgba(0.5372549295425415, 0.5647059082984924, 0.7019608020782471, 1)
    _outlineVariant: Qt.rgba(0.8352941274642944, 0.8392156958580017, 0.8588235378265381, 1)
    _inverseSurface: Qt.rgba(0.21568627655506134, 0.3764705955982208, 0.7490196228027344, 1)
    _onInverseSurface: Qt.rgba(0.9137254953384399, 0.9137254953384399, 0.9254902005195618, 1)
    _inversePrimary: Qt.rgba(0.18039216101169586, 0.4901960790157318, 0.9137254953384399, 1)
    _shadow: Qt.rgba(0.33725491166114807, 0.32156863808631897, 0.47058823704719543, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprActiveBorder: "rgba(006ec7ff) rgba(7847bdff) rgba(007197ff) 45deg"
    _hyprShadowColor: Qt.rgba(0, 0.2666666805744171, 0, 0)

    _plasmaColorScheme: "NibrasShellAiGenerated-20261012_124130"
    _konsoleProfile: "NibrasTokyoNightLight.profile"

    _themeIcons: "Tela-light"
    _gtkTheme: "Tokyonight-Light"
    _desktopClockFont: "Aldo the Apache"
    _desktopClockColor: Qt.rgba(0.03921568766236305, 0.21568627655506134, 0.2980392277240753, 1)
    _desktopClockPosition: Qt.point(117.25390625, 64.53515625)
    _desktopClockSize: Qt.size(514.9296875, 228.17578125)
    _desktopClockGlowColor: Qt.rgba(0, 0, 0.250980406999588, 0)
    _desktopClockUseThemeColor: false
}
