pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: draculaLight

    themeName: "DraculaLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("DraculaLight.jpeg")

    _primary: Qt.rgba(0.0313725508749485, 0.5685969591140747, 0.6980392336845398, 1)           // Purple (تصحيح درجة البنفسجي لتلائم دراكولا الرسمي)
    _onPrimary: Qt.rgba(1, 1, 1, 1)
    _secondary: Qt.rgba(0.9607843160629272, 0.6195773482322693, 0.04313725605607033, 1)         // Pink
    _onSecondary: Qt.rgba(0.06666667014360428, 0.0941176488995552, 0.15294118225574493, 1)
    _tertiary: Qt.rgba(0.8823529481887817, 0.11372549086809158, 0.2823071777820587, 1)          // Cyan
    _onTertiary: Qt.rgba(1, 1, 1, 1)
    _error: Qt.rgba(0.8627451062202454, 0.14901961386203766, 0.14901961386203766, 1)
    _onError: Qt.rgba(1, 1, 1, 1)

    _surface: Qt.rgba(0.9725490212440491, 0.9803921580314636, 0.9882352948188782, 1)
    _onSurface: Qt.rgba(0.05882352963089943, 0.09021133929491043, 0.16472114622592926, 1)
    _surfaceDim: Qt.rgba(0.886274516582489, 0.9098039269447327, 0.9411764740943909, 1)
    _surfaceBright: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9490196108818054, 0.9490196108818054, 0.9254902005195618, 1)
    _surfaceContainer: Qt.rgba(0.9450980424880981, 0.9607843160629272, 0.9764705896377563, 1)
    _surfaceContainerHigh: Qt.rgba(0.886274516582489, 0.9098039269447327, 0.9411764740943909, 1)
    _surfaceContainerHighest: Qt.rgba(0.7960784435272217, 0.8352941274642944, 0.8823529481887817, 1)
    _surfaceVariant: Qt.rgba(0.7960784435272217, 0.8352941274642944, 0.8823529481887817, 1)
    _onSurfaceVariant: Qt.rgba(0.20000000298023224, 0.2549172341823578, 0.3333333432674408, 1)

    // تحسين حاويات النسخة المضيئة لإعطاء عمق أنيق
    _primaryContainer: Qt.rgba(0.8117799758911133, 0.9803768992424011, 0.9960784316062927, 1)             // Light Purple Container
    _onPrimaryContainer: Qt.rgba(0.0313725508749485, 0.20000000298023224, 0.2666666805744171, 1)
    _secondaryContainer: Qt.rgba(0.9960784316062927, 0.9529411792755127, 0.7804074287414551, 1)           // Light Pink Container
    _onSecondaryContainer: Qt.rgba(0.47060349583625793, 0.2078126221895218, 0.05882352963089943, 1)
    _tertiaryContainer: Qt.rgba(1, 0.8941329121589661, 0.9019607901573181, 1)            // Light Cyan Container
    _onTertiaryContainer: Qt.rgba(0.5333486199378967, 0.07450980693101883, 0.21568627655506134, 1)
    _errorContainer: Qt.rgba(0.9960784316062927, 0.8039368391036987, 0.8274815082550049, 1)               // Light Red Container
    _onErrorContainer: Qt.rgba(0.5333486199378967, 0.07450980693101883, 0.21568627655506134, 1)

    _outline: Qt.rgba(0.5803921818733215, 0.6392157077789307, 0.7215686440467834, 1)
    _outlineVariant: Qt.rgba(0.7960784435272217, 0.8352941274642944, 0.8823529481887817, 1)
    _inverseSurface: Qt.rgba(0.2666666805744171, 0.27843138575553894, 0.3529411852359772, 1)
    _onInverseSurface: Qt.rgba(0.9725490212440491, 0.9725490212440491, 0.9490196108818054, 1)
    _inversePrimary: Qt.rgba(0.7412070035934448, 0.5764706134796143, 0.9764705896377563, 1)
    _shadow: Qt.rgba(0.2078431397676468, 0.2078431397676468, 0.2078431397676468, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)

    _baseRadius: 12
    _elementRadius: 11

    _shapeNone: 0
    _shapeExtraSmall: 1
    _shapeSmall: 1
    _shapeMedium: 1
    _shapeLarge: 1
    _shapeExtraLarge: 1
    _shapeFull: 1

    _iconButtonRadius: 9
    _statCardRadius: 9
    _hyprShadowColor: Qt.rgba(0, 0, 0.2666666805744171, 0)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasShellAiGenerated-20260702_042526"
    _konsoleProfile: "DraculaLight.profile"

    _themeIcons: "Fluent-light"
    _kvantumTheme: "Tellgo"
    _gtkTheme: "Tokyonight-Dark-BL"
    _desktopClockFont: "Yukarimobile"
    _desktopClockColor: Qt.rgba(0.27844664454460144, 0.03529411926865578, 0.329427033662796, 0.5333333611488342)
    _desktopClockPosition: Qt.point(126.8515625, 151.68359375)
    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "isnet-general-use"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("DraculaLight_depth.png")
    _desktopClockSize: Qt.size(1041.98828125, 282.53125)
    _desktopClockGlowColor: Qt.rgba(0, 0, 0.250980406999588, 0)
    _desktopClockUseThemeColor: false
}
