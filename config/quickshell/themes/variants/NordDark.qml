pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: nordDark
    themeName: "NordDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("nord-dark.gif")
    _desktopClockFont: "Daydream"
    _desktopClockFormat: "hh:mm AP"
    _desktopClockPosition: Qt.point(346, 121)
    _desktopClockDepthEffectEnabled: false
    _desktopClockSize: Qt.size(818, 266)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.22000457346439362, 0.17999541759490967, 0.46999314427375793, 0.6000000238418579)

    _primary: Qt.rgba(0.5058823823928833, 0.6313725709915161, 0.7568627595901489, 1)           // Nord9 (أزرق نورد القياسي)
    _onPrimary: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)         // Nord0
    _secondary: Qt.rgba(0.6392157077789307, 0.7450980544090271, 0.5490196347236633, 1)         // Nord14 (الأخضر النوردي)
    _onSecondary: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _tertiary: Qt.rgba(0.7058823704719543, 0.5568627715110779, 0.6784313917160034, 1)          // Nord15 (الأرجواني النوردي)
    _onTertiary: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _error: Qt.rgba(0.7490196228027344, 0.3803921639919281, 0.4156862795352936, 1)             // Nord11 (الأحمر النوردي)
    _onError: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)           // Nord6

    _surface: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)                      // Nord0
    _onSurface: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)                    // Nord6
    _surfaceDim: Qt.rgba(0.1411764770746231, 0.16078431904315948, 0.20000000298023224, 1)                   // درجة مخصصة أغمق قليلاً من Nord0
    _surfaceBright: Qt.rgba(0.23137255012989044, 0.25882354378700256, 0.32156863808631897, 1)                // Nord1
    _surfaceContainerLowest: Qt.rgba(0.125490203499794, 0.1411764770746231, 0.1725490242242813, 1)
    _surfaceContainerLow: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _surfaceContainer: Qt.rgba(0.20392157137393951, 0.22745098173618317, 0.27843138575553894, 1)             // Nord0_medium
    _surfaceContainerHigh: Qt.rgba(0.23137255012989044, 0.25882354378700256, 0.32156863808631897, 1)         // Nord1
    _surfaceContainerHighest: Qt.rgba(0.26274511218070984, 0.2980392277240753, 0.3686274588108063, 1)      // Nord2
    _surfaceVariant: Qt.rgba(0.23137255012989044, 0.25882354378700256, 0.32156863808631897, 1)
    _onSurfaceVariant: Qt.rgba(0.8470588326454163, 0.8705882430076599, 0.9137254953384399, 1)             // Nord4

    // استبدال اللون الموحد 434C5E لزيادة التباين البصري الداكن والعمق
    _primaryContainer: Qt.rgba(0.23137255012989044, 0.2862745225429535, 0.3686274588108063, 1)             // Dark Frost Blue
    _onPrimaryContainer: Qt.rgba(0.5333333611488342, 0.7529411911964417, 0.8156862854957581, 1)
    _secondaryContainer: Qt.rgba(0.239215686917305, 0.2980392277240753, 0.24705882370471954, 1)           // Dark Aurora Green
    _onSecondaryContainer: Qt.rgba(0.6392157077789307, 0.7450980544090271, 0.5490196347236633, 1)
    _tertiaryContainer: Qt.rgba(0.27450981736183167, 0.239215686917305, 0.2980392277240753, 1)            // Dark Aurora Purple
    _onTertiaryContainer: Qt.rgba(0.7058823704719543, 0.5568627715110779, 0.6784313917160034, 1)
    _errorContainer: Qt.rgba(0.2980392277240753, 0.23137255012989044, 0.239215686917305, 1)               // Dark Aurora Red
    _onErrorContainer: Qt.rgba(0.7490196228027344, 0.3803921639919281, 0.4156862795352936, 1)

    _outline: Qt.rgba(0.2980392277240753, 0.33725491166114807, 0.4156862795352936, 1)                      // Nord3 (الحدود الافتراضية للسمة)
    _outlineVariant: Qt.rgba(0.26274511218070984, 0.2980392277240753, 0.3686274588108063, 1)               // Nord2
    _inverseSurface: Qt.rgba(0.9254902005195618, 0.9372549057006836, 0.95686274766922, 1)
    _onInverseSurface: Qt.rgba(0.18039216101169586, 0.20392157137393951, 0.250980406999588, 1)
    _inversePrimary: Qt.rgba(0.5333333611488342, 0.7529411911964417, 0.8156862854957581, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0, 0, 0, 0.3333333432674408)

    _plasmaColorScheme: "NibrasNordDark"
    _konsoleProfile: "NordDark.profile"

    _themeIcons: "Zafiro-Nord-Black-Blue"
    _gtkTheme: "Nordic-darker-standard-buttons"
}
