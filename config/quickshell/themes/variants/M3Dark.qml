pragma Singleton

import org.kde.kirigami as Kirigami
import QtQuick

import "root:/themes"
import "root:/config"

BaseTheme {
    id: root
    themeName: "M3Dark"

    _enableDynamicColoring: true
    _enableDynamicWallpapers: false
    _wallpaper: App.assets.getWallpaperPath("m3_dark.png")
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("m3_dark_depth.png")
    _desktopClockFont: "Unrealised"
    _desktopClockFormat: "hh:mm AP - MM/dd"
    _desktopClockPosition: Qt.point(3.0234375, 8.60546875)
    _desktopClockDepthEffectEnabled: true
    _desktopClockSize: Qt.size(1859.52734375, 498.1171875)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.7900053262710571, 0.9700007438659668, 0.7700007557868958, 0.800000011920929)

    _themeMode: "dark"
    _baseRadius: 14
    _hyprBorderWidth: 3

    // ربط الألوان الرئيسية بنظام ألوان KDE
    _primary: Qt.rgba(0.34117648005485535, 0.2549019753932953, 0.4627451002597809, 1)
    _onPrimary: Qt.rgba(1, 1, 1, 1)

    _secondary: Qt.rgba(0.16078431904315948, 0.501960813999176, 0.7254902124404907, 1)
    _onSecondary: Qt.rgba(1, 1, 1, 1)

    _tertiary: Qt.rgba(0.7411764860153198, 0.5764706134796143, 0.9764705896377563, 1) // اللون التكميلي الافتراضي (يمكنك تعديله أو ربطه بالنظام)
    _onTertiary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)

    _error: Qt.rgba(0.8549019694328308, 0.2666666805744171, 0.32549020648002625, 1)
    _onError: Qt.rgba(1, 1, 1, 1)

    // تدرج الأسطح الديناميكي للوضع الداكن باستخدام مرجع الخلفية الأساسي للنظام
    _surface: Qt.rgba(0.09019608050584793, 0.13725490868091583, 0.04313725605607033, 1)
    _onSurface: Qt.rgba(0.7019608020782471, 0.8117647171020508, 0.6039215922355652, 1)
    _surfaceDim: Qt.rgba(0.07215991616249084, 0.10980392247438431, 0.03451590612530708, 1)
    _surfaceBright: Qt.rgba(0.16235598921775818, 0.24705882370471954, 0.07765316218137741, 1)

    _surfaceContainerLowest: Qt.rgba(0.050110626965761185, 0.07624933123588562, 0.02397192269563675, 1)
    _surfaceContainerLow: Qt.rgba(0.053055617958307266, 0.08073548227548599, 0.02537575364112854, 1)
    _surfaceContainer: Qt.rgba(0.05368123948574066, 0.08168154209852219, 0.02566567435860634, 1)
    _surfaceContainerHigh: Qt.rgba(0.0644083321094513, 0.09800869971513748, 0.030792705714702606, 1)
    _surfaceContainerHighest: Qt.rgba(0.08052185922861099, 0.12251468747854233, 0.03849851340055466, 1)

    _surfaceVariant: Qt.rgba(0.08589303493499756, 0.13070878386497498, 0.04107728600502014, 1)
    _onSurfaceVariant: Qt.rgba(0.7019608020782471, 0.8117647171020508, 0.6039215922355652, 0.7000076174736023)

    // دمج ذكي للألوان: نأخذ لون الخلفية ونخلطه بنسبة 16% مع اللون الأساسي للحصول على حاوية متناسقة
    _primaryContainer: Qt.rgba(0.13035781681537628, 0.15608453750610352, 0.1102769523859024, 1)
    _onPrimaryContainer: Qt.rgba(0.4094300866127014, 0.30588236451148987, 0.5552910566329956, 1)

    _secondaryContainer: Qt.rgba(0.10148775577545166, 0.19560539722442627, 0.15231555700302124, 1)
    _onSecondaryContainer: Qt.rgba(0.19293507933616638, 0.6023498773574829, 0.8705882430076599, 1)

    _tertiaryContainer: Qt.rgba(0.19435416162014008, 0.2075379639863968, 0.1924773007631302, 1)
    _onTertiaryContainer: Qt.rgba(0.8600747585296631, 0.7621118426322937, 1, 1)

    _errorContainer: Qt.rgba(0.21255818009376526, 0.1579613983631134, 0.08831921964883804, 1)
    _onErrorContainer: Qt.rgba(0.8549019694328308, 0.2666666805744171, 0.32549020648002625, 1)

    _outline: Qt.rgba(0.7019608020782471, 0.8117647171020508, 0.6039215922355652, 0.3000076413154602)
    _outlineVariant: Qt.rgba(0.7019608020782471, 0.8117647171020508, 0.6039215922355652, 0.14999619126319885)
    _inverseSurface: Qt.rgba(0.7019608020782471, 0.8117647171020508, 0.6039215922355652, 1)
    _onInverseSurface: Qt.rgba(0.09019608050584793, 0.13725490868091583, 0.04313725605607033, 1)
    _inversePrimary: Qt.rgba(0.34117648005485535, 0.2549019753932953, 0.4627451002597809, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0, 0, 0.2666666805744171, 0.3333333432674408)
}
