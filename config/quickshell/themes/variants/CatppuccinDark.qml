pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: catppuccindarkTheme

    themeName: "CatppuccinDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("CatppuccinDark.jpeg")

    _primary: Qt.rgba(0.5372549295425415, 0.7058823704719543, 0.9803921580314636, 1)           // Blue
    _onPrimary: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.10588235408067703, 1)         // Crust
    _secondary: Qt.rgba(0.9529411792755127, 0.545098066329956, 0.658823549747467, 1)         // Pink
    _onSecondary: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.10588235408067703, 1)
    _tertiary: Qt.rgba(0.7960784435272217, 0.6509804129600525, 0.9686274528503418, 1)          // Mauve
    _onTertiary: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.10588235408067703, 1)
    _error: Qt.rgba(0.9529411792755127, 0.545098066329956, 0.658823549747467, 1)             // Red
    _onError: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.10588235408067703, 1)

    _surface: Qt.rgba(0.11764705926179886, 0.11764705926179886, 0.18039216101169586, 1)                      // Base
    _onSurface: Qt.rgba(0.8039215803146362, 0.8392156958580017, 0.95686274766922, 1)                    // Text
    _surfaceDim: Qt.rgba(0.0941176488995552, 0.0941176488995552, 0.14509804546833038, 1)                   // Mantle
    _surfaceBright: Qt.rgba(0.1921568661928177, 0.19607843458652496, 0.2666666805744171, 1)                // Surface0
    _surfaceContainerLowest: Qt.rgba(0.06666667014360428, 0.06666667014360428, 0.10588235408067703, 1)       // Crust
    _surfaceContainerLow: Qt.rgba(0.08235294371843338, 0.08235294371843338, 0.13333334028720856, 1)          // Mantle-Base Intermediate
    _surfaceContainer: Qt.rgba(0.11764705926179886, 0.11764705926179886, 0.18039216101169586, 1)             // Base
    _surfaceContainerHigh: Qt.rgba(0.14509804546833038, 0.14509804546833038, 0.21960784494876862, 1)         // Base-Surface0 Intermediate
    _surfaceContainerHighest: Qt.rgba(0.1921568661928177, 0.19607843458652496, 0.2666666805744171, 1)      // Surface0
    _surfaceVariant: Qt.rgba(0.1921568661928177, 0.19607843458652496, 0.2666666805744171, 1)
    _onSurfaceVariant: Qt.rgba(0.729411780834198, 0.7607843279838562, 0.8705882430076599, 1)             // Subtext1

    // ضبط حاويات التحديد وخلفيات الأزرار بتدرج ناعم ومتناسق
    _primaryContainer: Qt.rgba(0.14509804546833038, 0.1882352977991104, 0.29411765933036804, 1)             // Dark Sapphire/Blue container
    _onPrimaryContainer: Qt.rgba(0.5372549295425415, 0.7058823704719543, 0.9803921580314636, 1)
    _secondaryContainer: Qt.rgba(0.2705882489681244, 0.1411764770746231, 0.2078431397676468, 1)           // Dark Pink container
    _onSecondaryContainer: Qt.rgba(0.9529411792755127, 0.545098066329956, 0.658823549747467, 1)
    _tertiaryContainer: Qt.rgba(0.22745098173618317, 0.14509804546833038, 0.30588236451148987, 1)            // Dark Mauve container
    _onTertiaryContainer: Qt.rgba(0.7960784435272217, 0.6509804129600525, 0.9686274528503418, 1)
    _errorContainer: Qt.rgba(0.2705882489681244, 0.1411764770746231, 0.1725490242242813, 1)               // Dark Red container
    _onErrorContainer: Qt.rgba(0.9529411792755127, 0.545098066329956, 0.658823549747467, 1)

    _outline: Qt.rgba(0.3450980484485626, 0.35686275362968445, 0.43921568989753723, 1)                      // Surface2 (الحدود الافتراضية للسمة)
    _outlineVariant: Qt.rgba(0.2705882489681244, 0.27843138575553894, 0.3529411852359772, 1)               // Surface1 (حدود فرعية أقل وضوحاً)
    _inverseSurface: Qt.rgba(0.8039215803146362, 0.8392156958580017, 0.95686274766922, 1)
    _onInverseSurface: Qt.rgba(0.11764705926179886, 0.11764705926179886, 0.18039216101169586, 1)
    _inversePrimary: Qt.rgba(0.5372549295425415, 0.7058823704719543, 0.9803921580314636, 1)
    _shadow: Qt.rgba(0.05882352963089943, 0.05882352963089943, 0.05882352963089943, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprActiveBorder: "rgba(7aa2f7ff) rgba(f7768eff) rgba(9ece6aff) 45deg"
    _hyprShadowColor: Qt.rgba(0, 0.2666666805744171, 0, 0)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasShellAiGenerated-20260702_035126"
    _konsoleProfile: "CatppuccinDark.profile"

    _themeIcons: "Tela-blue"
    _gtkTheme: "Catppuccin-Mocha-Standard-Blue-Dark"
    _cursorTheme: "Ketsa-icons"
    _desktopClockFont: "Blacklisted"
    _desktopClockColor: Qt.rgba(0.5529564619064331, 0.8157168030738831, 0.9411764740943909, 1)
    _desktopClockPosition: Qt.point(973.82421875, 491.3125)
    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "isnet-general-use"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("CatppuccinDark_depth.png")
    _desktopClockSize: Qt.size(785.49609375, 283.03515625)
    _desktopClockGlowColor: Qt.rgba(0.5529564619064331, 0.8157168030738831, 0.9411764740943909, 1)
    _desktopClockGlowEnabled: true
    _desktopClockGlowIntensity: 0.5
    _desktopClockUseThemeColor: false
}
