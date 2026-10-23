pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: catppuccinLightTheme

    themeName: "CatppuccinLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("catppuccin_light.jpeg")

    _desktopClockEnabled: true
    _desktopClockFont: "Overhead BRK"
    _desktopClockColor: Qt.rgba(0.1568627506494522, 0.12156862765550613, 0.20393683016300201, 1)
    _desktopClockFormat: "hh:mm AP - MM/dd"
    _desktopClockSize: Qt.size(638.23, 225.73)
    _desktopClockPosition: Qt.point(638.09, 552.60)
    _desktopClockShadowEnabled: false
    _desktopClockShadowColor: Qt.rgba(0, 0, 0.2666666805744171, 0)
    _desktopClockUseThemeColor: false
    _desktopClockUseAnimation: true

    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "u2net"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("catppuccin_light_depth.png")

    _baseRadius: 12
    _elementRadius: 15
    _iconFont: "FantasqueSansM Nerd Font Propo"
    _bodyFont: "JF Flat"

    _themeIcons: "Colloid-Purple-Dracula-Dark"

    _hyprBorderWidth: 2
    _hyprRounding: 12
    _hyprDropShadow: "yes"
    _hyprGapsIn: 5
    _hyprGapsOut: "12, 15, 15, 52"
    _hyprLayout: "dwindle"
    _hyprAnimationsEnabled: true
    _hyprBezier: "win_in, 0.16, 1, 0.3, 1\nwin_out, 0.3, 0, 0.6, 1\nmove, 0.2, 0.85, 0.15, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.12, 0.95, 0.22, 1"
    _hyprAnimWindows: "1, 8, launch, popin 90%"
    _hyprAnimWorkspaces: "1, 7, move, slide"
    _hyprBlurEnabled: true
    _hyprBlurSize: 4
    _hyprBlurPasses: 2
    _hyprDimInactive: false
    _hyprDimStrength: 0
    _hyprShadowRange: 11
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.3333333432674408)

    _primary: Qt.rgba(0.125490203499794, 0.6235294342041016, 0.7098191976547241, 1)           // Teal
    _onPrimary: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)         // Base
    _secondary: Qt.rgba(0.9176470637321472, 0.4627451002597809, 0.7961089611053467, 1)         // Pink
    _onSecondary: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)
    _tertiary: Qt.rgba(0.2509956657886505, 0.6274662613868713, 0.16862745583057404, 1)          // Green (تم تغييرها لـ Latte Green الحقيقية لزيادة التناسق)
    _onTertiary: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)
    _error: Qt.rgba(0.8235446810722351, 0.05882352963089943, 0.2234988957643509, 1)             // Red
    _onError: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)

    _surface: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)                      // Base
    _onSurface: Qt.rgba(0.2980392277240753, 0.30981919169425964, 0.4117799699306488, 1)                    // Text
    _surfaceDim: Qt.rgba(0.8627451062202454, 0.8784313797950745, 0.9098039269447327, 1)                   // Crust
    _surfaceBright: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)                // Base
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9490348696708679, 0.9529564380645752, 0.9686274528503418, 1)          // Mantle
    _surfaceContainer: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)             // Base
    _surfaceContainerHigh: Qt.rgba(0.9019760489463806, 0.9137407541275024, 0.9372549057006836, 1)         // Mantle
    _surfaceContainerHighest: Qt.rgba(0.800000011920929, 0.8156862854957581, 0.8549019694328308, 1)      // Surface0
    _surfaceVariant: Qt.rgba(0.9019760489463806, 0.9137407541275024, 0.9372549057006836, 1)
    _onSurfaceVariant: Qt.rgba(0.42352941632270813, 0.43921568989753723, 0.5254902243614197, 1)             // Subtext0

    _primaryContainer: Qt.rgba(0.8235446810722351, 0.9450980424880981, 0.9607843160629272, 1)             // Light Teal Container
    _onPrimaryContainer: Qt.rgba(0.11764705926179886, 0.42352941632270813, 0.47843137383461, 1)
    _secondaryContainer: Qt.rgba(0.9921568632125854, 0.8745098114013672, 0.9137254953384399, 1)           // Light Pink Container
    _onSecondaryContainer: Qt.rgba(0.6196231245994568, 0.239215686917305, 0.5098039507865906, 1)
    _tertiaryContainer: Qt.rgba(0.886274516582489, 0.9372549057006836, 0.8745098114013672, 1)            // Light Green Container
    _onTertiaryContainer: Qt.rgba(0.1765011101961136, 0.43921568989753723, 0.11764705926179886, 1)
    _errorContainer: Qt.rgba(0.9725490212440491, 0.8431525230407715, 0.8549019694328308, 1)               // Light Red Container
    _onErrorContainer: Qt.rgba(0.8235446810722351, 0.05882352963089943, 0.2234988957643509, 1)

    _outline: Qt.rgba(0.6117647290229797, 0.6274510025978088, 0.6901960968971252, 1)                      // Surface2
    _outlineVariant: Qt.rgba(0.800000011920929, 0.8156862854957581, 0.8549019694328308, 1)               // Surface0
    _inverseSurface: Qt.rgba(0.2980392277240753, 0.30981919169425964, 0.4117799699306488, 1)
    _onInverseSurface: Qt.rgba(0.9372549057006836, 0.9450980424880981, 0.9607843160629272, 1)
    _inversePrimary: Qt.rgba(0.125490203499794, 0.6235294342041016, 0.7098191976547241, 1)
    _shadow: Qt.rgba(0.13333334028720856, 0.13333334028720856, 0.13333334028720856, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasCatppuccinLight"
    _konsoleProfile: "CatppuccinLight.profile"

    _gtkTheme: "Catppuccin-Latte-Standard-Blue-Light"
    _desktopClockGlowColor: Qt.rgba(0, 0, 0.2666666805744171, 0)
}
