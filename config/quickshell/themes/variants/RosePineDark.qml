pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: rosePineDark

    themeName: "RosePineDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("rosepine-dark.png")

    _primary: Qt.rgba(0.9215686321258545, 0.7372549176216125, 0.729411780834198, 1)             // Rose
    _onPrimary: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)           // Base
    _secondary: Qt.rgba(0.7686274647712708, 0.6549019813537598, 0.9058823585510254, 1)            // Iris
    _onSecondary: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)
    _tertiary: Qt.rgba(0.6117647290229797, 0.8117647171020508, 0.8470588326454163, 1)             // Foam
    _onTertiary: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)
    _error: Qt.rgba(0.9215686321258545, 0.43529412150382996, 0.572549045085907, 1)               // Love
    _onError: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)

    _surface: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)                        // Base
    _onSurface: Qt.rgba(0.8784313797950745, 0.8705882430076599, 0.95686274766922, 1)                      // Text
    _surfaceDim: Qt.rgba(0.073048, 0.067204, 0.105189, 1)
    _surfaceBright: Qt.rgba(0.230307, 0.223614, 0.267118, 1)
    _surfaceContainerLowest: Qt.rgba(0.061195, 0.056299, 0.088120, 1)
    _surfaceContainerLow: Qt.rgba(0.121599, 0.113960, 0.163609, 1)
    _surfaceContainer: Qt.rgba(0.145770, 0.138342, 0.186625, 1)
    _surfaceContainerHigh: Qt.rgba(0.170517, 0.163304, 0.210188, 1)
    _surfaceContainerHighest: Qt.rgba(0.195803, 0.188810, 0.234265, 1)
    _surfaceVariant: Qt.rgba(0.14901961386203766, 0.13725490868091583, 0.22745098173618317, 1)
    _onSurfaceVariant: Qt.rgba(0.5647059082984924, 0.5490196347236633, 0.6666666865348816, 1)               // Subtle

    _primaryContainer: Qt.rgba(0.20000000298023224, 0.15294118225574493, 0.20000000298023224, 1)               // Dark Rose container
    _onPrimaryContainer: Qt.rgba(0.9215686321258545, 0.7372549176216125, 0.729411780834198, 1)
    _secondaryContainer: Qt.rgba(0.16862745583057404, 0.14509804546833038, 0.25882354378700256, 1)             // Dark Iris container
    _onSecondaryContainer: Qt.rgba(0.7686274647712708, 0.6549019813537598, 0.9058823585510254, 1)
    _tertiaryContainer: Qt.rgba(0.11764705926179886, 0.18431372940540314, 0.22745098173618317, 1)              // Dark Foam container
    _onTertiaryContainer: Qt.rgba(0.6117647290229797, 0.8117647171020508, 0.8470588326454163, 1)
    _errorContainer: Qt.rgba(0.239215686917305, 0.11764705926179886, 0.18039216101169586, 1)                 // Dark Love container
    _onErrorContainer: Qt.rgba(0.9215686321258545, 0.43529412150382996, 0.572549045085907, 1)

    _outline: Qt.rgba(0.4313725531101227, 0.4156862795352936, 0.5254902243614197, 1)                        // Muted
    _outlineVariant: Qt.rgba(0.14901961386203766, 0.13725490868091583, 0.22745098173618317, 1)                 // Overlay
    _inverseSurface: Qt.rgba(0.8784313797950745, 0.8705882430076599, 0.95686274766922, 1)
    _onInverseSurface: Qt.rgba(0.09803921729326248, 0.09019608050584793, 0.1411764770746231, 1)
    _inversePrimary: Qt.rgba(0.9215686321258545, 0.7372549176216125, 0.729411780834198, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.2666666805744171)

    _plasmaColorScheme: "NibrasRosePineDark"
    _konsoleProfile: "RosePineDark.profile"

    _themeIcons: "Tela-dark"
    _gtkTheme: "Breeze-Dark"
    _kvantumTheme: "KvArcDark"
    _desktopClockFont: "Korner Deli NF"
    _desktopClockPosition: Qt.point(225.23828125, 38.47265625)
    _desktopClockSize: Qt.size(356.82421875, 172.625)
}
