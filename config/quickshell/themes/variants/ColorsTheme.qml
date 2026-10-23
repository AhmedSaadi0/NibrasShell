pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: colorsTheme

    themeName: "ColorsTheme"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("colors.png")
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("colors_depth.png")
    _desktopClockFont: "Xenophobia"
    _desktopClockFormat: "hh mm AP - MM/dd"
    _desktopClockPosition: Qt.point(7, 11)
    _desktopClockDepthEffectEnabled: true
    _desktopClockSize: Qt.size(1860, 600)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.13333334028720856, 0.7568627595901489, 0.9215686321258545, 1)

    _primary: Qt.rgba(0.13333334028720856, 0.7568627595901489, 0.9215686321258545, 1)
    _onPrimary: Qt.rgba(0.11764705926179886, 0.07058823853731155, 0.250980406999588, 1)

    _secondary: Qt.rgba(0.9921568632125854, 0.007843137718737125, 1, 1)
    _onSecondary: Qt.rgba(0.9372549057006836, 0.9411764740943909, 0.9450980424880981, 1)

    _tertiary: Qt.rgba(0.9803921580314636, 0.8156862854957581, 0, 1)
    _onTertiary: Qt.rgba(0.09803921729326248, 0, 0.18039216101169586, 1)

    _error: Qt.rgba(1, 0.20000000298023224, 0.20000000298023224, 1)
    _onError: Qt.rgba(1, 1, 1, 1)

    _surface: Qt.rgba(0.22745098173618317, 0.16078431904315948, 0.3803921639919281, 1)
    _onSurface: Qt.rgba(0.9372549057006836, 0.9411764740943909, 0.9450980424880981, 1)
    _surfaceDim: Qt.rgba(0.1764705926179886, 0.12156862765550613, 0.3019607961177826, 1)
    _surfaceBright: Qt.rgba(0.30980393290519714, 0.21568627655506134, 0.5176470875740051, 1)
    _surfaceContainerLowest: Qt.rgba(0.11764705926179886, 0.07058823853731155, 0.250980406999588, 1)
    _surfaceContainerLow: Qt.rgba(0.1764705926179886, 0.12156862765550613, 0.3019607961177826, 1)
    _surfaceContainer: Qt.rgba(0.24313725531101227, 0.1764705926179886, 0.40784314274787903, 1)
    _surfaceContainerHigh: Qt.rgba(0.30980393290519714, 0.21568627655506134, 0.5176470875740051, 1)
    _surfaceContainerHighest: Qt.rgba(0.4431372582912445, 0.3137255012989044, 0.6313725709915161, 1)
    _surfaceVariant: Qt.rgba(0.30980393290519714, 0.21568627655506134, 0.5176470875740051, 1)
    _onSurfaceVariant: Qt.rgba(0.8156862854957581, 0.772549033164978, 0.9098039269447327, 1)

    // حاويات الألوان تم جعلها بظلال نيون غامقة تندمج بشكل مثالي مع خلفية Shades of Purple الداكنة
    _primaryContainer: Qt.rgba(0.0784313753247261, 0.239215686917305, 0.30980393290519714, 1)             // Dark Neon Blue
    _onPrimaryContainer: Qt.rgba(0.13333334028720856, 0.7568627595901489, 0.9215686321258545, 1)
    _secondaryContainer: Qt.rgba(0.3019607961177826, 0.08235294371843338, 0.3019607961177826, 1)           // Dark Neon Magenta
    _onSecondaryContainer: Qt.rgba(0.9921568632125854, 0.007843137718737125, 1, 1)
    _tertiaryContainer: Qt.rgba(0.239215686917305, 0.20000000298023224, 0, 1)            // Dark Neon Gold
    _onTertiaryContainer: Qt.rgba(0.9803921580314636, 0.8156862854957581, 0, 1)
    _errorContainer: Qt.rgba(0.27843138575553894, 0.0784313753247261, 0.0784313753247261, 1)
    _onErrorContainer: Qt.rgba(1, 0.20000000298023224, 0.20000000298023224, 1)

    _outline: Qt.rgba(0.5411764979362488, 0.43529412150382996, 0.7490196228027344, 1)
    _outlineVariant: Qt.rgba(0.30980393290519714, 0.21568627655506134, 0.5176470875740051, 1)
    _inverseSurface: Qt.rgba(0.9372549057006836, 0.9411764740943909, 0.9450980424880981, 1)
    _onInverseSurface: Qt.rgba(0.22745098173618317, 0.16078431904315948, 0.3803921639919281, 1)
    _inversePrimary: Qt.rgba(0.13333334028720856, 0.7568627595901489, 0.9215686321258545, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)

    _plasmaColorScheme: "AColors"
    _themeIcons: "Vivid-Dark-Icons"
    _kvantumTheme: "Shades-of-purple"
    _gtkTheme: "Shades-of-purple"
    _konsoleProfile: "pinky.profile"

    _baseRadius: 12

    _hyprBorderWidth: 3
    _hyprRounding: 12
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)
}
