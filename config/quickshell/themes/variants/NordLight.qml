pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: lightTheme
    themeName: "NordLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("nord-light.gif")

    _desktopClockFont: "Daydream"
    _desktopClockFormat: "hh:mm AP"
    _desktopClockPosition: Qt.point(675, 435)
    _desktopClockDepthEffectEnabled: false
    _desktopClockSize: Qt.size(470, 188)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.36002135276794434, 0.3700007498264313, 0.5000076293945312, 0.6000000238418579)

    _primary: Qt.rgba(0.3686274588108063, 0.5058671236038208, 0.6745098233222961, 1)           // Nord10 (أزرق نورد الغامق والواضح)
    _onPrimary: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)         // Nord6
    _secondary: Qt.rgba(0.5333333611488342, 0.7529564499855042, 0.8156862854957581, 1)         // Nord8 (Frost Ice Blue)
    _onSecondary: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)       // Nord0
    _tertiary: Qt.rgba(0.6392157077789307, 0.7450980544090271, 0.5490196347236633, 1)          // Nord14
    _onTertiary: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _error: Qt.rgba(0.7490196228027344, 0.3803921639919281, 0.4156557619571686, 1)             // Nord11
    _onError: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)

    _surface: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)                      // Nord6
    _onSurface: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)                    // Nord0
    _surfaceDim: Qt.rgba(0.8470740914344788, 0.8706035017967224, 0.9137254953384399, 1)                   // Nord4
    _surfaceBright: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9098039269447327, 0.9254902005195618, 0.9490196108818054, 1)
    _surfaceContainer: Qt.rgba(0.8823529481887817, 0.8980392217636108, 0.9215686321258545, 1)
    _surfaceContainerHigh: Qt.rgba(0.8470740914344788, 0.8706035017967224, 0.9137254953384399, 1)
    _surfaceContainerHighest: Qt.rgba(0.7843137383460999, 0.8078431487083435, 0.8470588326454163, 1)
    _surfaceVariant: Qt.rgba(0.8470740914344788, 0.8706035017967224, 0.9137254953384399, 1)
    _onSurfaceVariant: Qt.rgba(0.2980392277240753, 0.33725491166114807, 0.4156862795352936, 1)             // Nord3

    // تحسين الحاويات لتنسجم مع بياض خلفيات نورد الناصعة بظلال خفيفة
    _primaryContainer: Qt.rgba(0.8980392217636108, 0.929411768913269, 0.9607843160629272, 1)             // Light Frost Blue
    _onPrimaryContainer: Qt.rgba(0.3686274588108063, 0.5058671236038208, 0.6745098233222961, 1)
    _secondaryContainer: Qt.rgba(0.9176623225212097, 0.95686274766922, 0.9686274528503418, 1)           // Light Ice Blue
    _onSecondaryContainer: Qt.rgba(0.5333333611488342, 0.7529564499855042, 0.8156862854957581, 1)
    _tertiaryContainer: Qt.rgba(0.9333333373069763, 0.9607843160629272, 0.9137254953384399, 1)            // Light Green Tint
    _onTertiaryContainer: Qt.rgba(0.6392157077789307, 0.7450980544090271, 0.5490196347236633, 1)
    _errorContainer: Qt.rgba(0.9607843160629272, 0.9137254953384399, 0.9176470637321472, 1)               // Light Red Tint
    _onErrorContainer: Qt.rgba(0.7490196228027344, 0.3803921639919281, 0.4156557619571686, 1)

    _outline: Qt.rgba(0.48235294222831726, 0.5333486199378967, 0.6313725709915161, 1)
    _outlineVariant: Qt.rgba(0.8470740914344788, 0.8706035017967224, 0.9137254953384399, 1)
    _inverseSurface: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _onInverseSurface: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)
    _inversePrimary: Qt.rgba(0.3686274588108063, 0.5058671236038208, 0.6745098233222961, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasNordLight"
    _konsoleProfile: "NordLight.profile"

    _themeIcons: "Zafiro-Nord-Light-Blue"
    _gtkTheme: "Nordic-lighter"
}
