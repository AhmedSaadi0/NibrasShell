pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: deerTheme

    themeName: "DeerTheme"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("deer.jpg")
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("deer_depth.png")
    _desktopClockFont: "Xenophobia"
    _desktopClockFormat: "hh:mm AP MM/dd"
    _desktopClockPosition: Qt.point(8.015625, 8.015625)
    _desktopClockDepthEffectEnabled: true
    _desktopClockSize: Qt.size(1848.86328125, 612.8984375)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.050003815442323685, 0.0800030529499054, 0.13000686466693878, 0.800000011920929)

    _primary: Qt.rgba(0.7019608020782471, 0.545098066329956, 1, 1)
    _onPrimary: Qt.rgba(0.07058823853731155, 0.03921568766236305, 0.16470588743686676, 1)
    _secondary: Qt.rgba(0.9019607901573181, 0.5411764979362488, 0.3607843220233917, 1)
    _onSecondary: Qt.rgba(0.10196078568696976, 0.05882352963089943, 0.03921568766236305, 1)
    _tertiary: Qt.rgba(0.5529412031173706, 0.9098039269447327, 1, 1)
    _onTertiary: Qt.rgba(0.03921568766236305, 0.11372549086809158, 0.15294118225574493, 1)
    _error: Qt.rgba(1, 0.5607843399047852, 0.6196078658103943, 1)
    _onError: Qt.rgba(0.03921568766236305, 0.11372549086809158, 0.15294118225574493, 1)

    _surface: Qt.rgba(0.03921568766236305, 0.11372549086809158, 0.15294118225574493, 1)
    _onSurface: Qt.rgba(1, 1, 1, 1)
    _surfaceDim: Qt.rgba(0.0235294122248888, 0.08235294371843338, 0.125490203499794, 1)
    _surfaceBright: Qt.rgba(0.0784313753247261, 0.16470588743686676, 0.23529411852359772, 1)
    _surfaceContainerLowest: Qt.rgba(0.019607843831181526, 0.05882352963089943, 0.09019608050584793, 1)
    _surfaceContainerLow: Qt.rgba(0.0470588244497776, 0.125490203499794, 0.1882352977991104, 1)
    _surfaceContainer: Qt.rgba(0.054901961237192154, 0.1411764770746231, 0.2078431397676468, 1)
    _surfaceContainerHigh: Qt.rgba(0.0784313753247261, 0.16470588743686676, 0.23529411852359772, 1)
    _surfaceContainerHighest: Qt.rgba(0.11764705926179886, 0.22745098173618317, 0.3529411852359772, 1)
    _surfaceVariant: Qt.rgba(0.0784313753247261, 0.16470588743686676, 0.23529411852359772, 1)
    _onSurfaceVariant: Qt.rgba(0.6901960968971252, 0.7686274647712708, 0.8705882430076599, 1)

    // تدرجات الألوان للحاويات من أجل إبراز المظهر الداكن الغني باللون الكحلي/البنفسجي
    _primaryContainer: Qt.rgba(0.18039216101169586, 0.10588235408067703, 0.3019607961177826, 1)             // Subtle Dark Purple container
    _onPrimaryContainer: Qt.rgba(0.7019608020782471, 0.545098066329956, 1, 1)
    _secondaryContainer: Qt.rgba(0.239215686917305, 0.10196078568696976, 0.03921568766236305, 1)           // Subtle Dark Orange container
    _onSecondaryContainer: Qt.rgba(0.9019607901573181, 0.5411764979362488, 0.3607843220233917, 1)
    _tertiaryContainer: Qt.rgba(0.054901961237192154, 0.16470588743686676, 0.21176470816135406, 1)            // Subtle Dark Cyan container
    _onTertiaryContainer: Qt.rgba(0.5529412031173706, 0.9098039269447327, 1, 1)
    _errorContainer: Qt.rgba(0.22745098173618317, 0.08235294371843338, 0.10588235408067703, 1)
    _onErrorContainer: Qt.rgba(1, 0.5607843399047852, 0.6196078658103943, 1)

    _outline: Qt.rgba(0.22745098173618317, 0.3529411852359772, 0.47843137383461, 1)
    _outlineVariant: Qt.rgba(0.11764705926179886, 0.22745098173618317, 0.3529411852359772, 1)
    _inverseSurface: Qt.rgba(1, 1, 1, 1)
    _onInverseSurface: Qt.rgba(0.03921568766236305, 0.11372549086809158, 0.15294118225574493, 1)
    _inversePrimary: Qt.rgba(0.7019608020782471, 0.545098066329956, 1, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "BlueDeer"
    _konsoleProfile: "game.profile"

    _themeIcons: "Vivid-Dark-Icons"
    _kvantumTheme: "Tellgo"
    _gtkTheme: "Kimi-dark"
}
