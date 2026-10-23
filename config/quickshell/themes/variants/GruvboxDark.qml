pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: gruvboxDark
    themeName: "GruvboxDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("gruvbox-dark.png")

    _primary: Qt.rgba(0.5490196347236633, 0.7647058963775635, 0.48235294222831726, 1)           // Gruvbox Green
    _onPrimary: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)
    _secondary: Qt.rgba(0.9803921580314636, 0.7411764860153198, 0.18431372940540314, 1)         // Gruvbox Yellow
    _onSecondary: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)
    _tertiary: Qt.rgba(0.5137255191802979, 0.6470588445663452, 0.5960784554481506, 1)          // Gruvbox Blue
    _onTertiary: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)
    _error: Qt.rgba(0.9843137264251709, 0.2862745225429535, 0.20392157137393951, 1)             // Gruvbox Red
    _onError: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)

    _surface: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)                      // bg0
    _onSurface: Qt.rgba(0.9215686321258545, 0.8588235378265381, 0.6980392336845398, 1)                    // fg0
    _surfaceDim: Qt.rgba(0.11372549086809158, 0.125490203499794, 0.12941177189350128, 1)                   // bg0_h
    _surfaceBright: Qt.rgba(0.23529411852359772, 0.21960784494876862, 0.21176470816135406, 1)                // bg1
    _surfaceContainerLowest: Qt.rgba(0.11372549086809158, 0.125490203499794, 0.12941177189350128, 1)
    _surfaceContainerLow: Qt.rgba(0.13333334028720856, 0.1411764770746231, 0.14901961386203766, 1)
    _surfaceContainer: Qt.rgba(0.1725490242242813, 0.18431372940540314, 0.1921568661928177, 1)
    _surfaceContainerHigh: Qt.rgba(0.23529411852359772, 0.21960784494876862, 0.21176470816135406, 1)
    _surfaceContainerHighest: Qt.rgba(0.3137255012989044, 0.2862745225429535, 0.2705882489681244, 1)      // bg2
    _surfaceVariant: Qt.rgba(0.23529411852359772, 0.21960784494876862, 0.21176470816135406, 1)
    _onSurfaceVariant: Qt.rgba(0.8352941274642944, 0.7686274647712708, 0.6313725709915161, 1)             // fg2

    // تصحيح الألوان الموحدة 504945 في الحاويات وجعلها متطابقة مع تدرجات Gruvbox
    _primaryContainer: Qt.rgba(0.22745098173618317, 0.24313725531101227, 0.14509804546833038, 1)             // Dark Green Highlight
    _onPrimaryContainer: Qt.rgba(0.5490196347236633, 0.7647058963775635, 0.48235294222831726, 1)
    _secondaryContainer: Qt.rgba(0.2705882489681244, 0.2078431397676468, 0.07058823853731155, 1)           // Dark Yellow Highlight
    _onSecondaryContainer: Qt.rgba(0.9803921580314636, 0.7411764860153198, 0.18431372940540314, 1)
    _tertiaryContainer: Qt.rgba(0.10980392247438431, 0.1764705926179886, 0.1882352977991104, 1)            // Dark Blue Highlight
    _onTertiaryContainer: Qt.rgba(0.5137255191802979, 0.6470588445663452, 0.5960784554481506, 1)
    _errorContainer: Qt.rgba(0.250980406999588, 0.08627451211214066, 0.0784313753247261, 1)               // Dark Red Highlight
    _onErrorContainer: Qt.rgba(0.9843137264251709, 0.2862745225429535, 0.20392157137393951, 1)

    _outline: Qt.rgba(0.4000000059604645, 0.3607843220233917, 0.3294117748737335, 1)                      // bg3
    _outlineVariant: Qt.rgba(0.3137255012989044, 0.2862745225429535, 0.2705882489681244, 1)               // bg2
    _inverseSurface: Qt.rgba(0.9215686321258545, 0.8588235378265381, 0.6980392336845398, 1)
    _onInverseSurface: Qt.rgba(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1)
    _inversePrimary: Qt.rgba(0.5490196347236633, 0.7647058963775635, 0.48235294222831726, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0, 0, 0, 0.20000000298023224)

    _plasmaColorScheme: "NibrasGruvboxDark"
    _konsoleProfile: "GruvboxDark.profile"

    _themeIcons: "Gruvbox"
    _gtkTheme: "Gruvbox-Dark-Soft"
}
