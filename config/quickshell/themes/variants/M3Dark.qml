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
    _primary: Kirigami.Theme.highlightColor
    _onPrimary: Kirigami.Theme.highlightedTextColor

    _secondary: Kirigami.Theme.linkColor
    _onSecondary: Kirigami.Theme.highlightedTextColor

    _tertiary: "#bd93f9" // اللون التكميلي الافتراضي (يمكنك تعديله أو ربطه بالنظام)
    _onTertiary: "#16161e"

    _error: Kirigami.Theme.negativeTextColor
    _onError: Kirigami.Theme.highlightedTextColor

    // تدرج الأسطح الديناميكي للوضع الداكن باستخدام مرجع الخلفية الأساسي للنظام
    _surface: Kirigami.Theme.backgroundColor
    _onSurface: Kirigami.Theme.textColor
    _surfaceDim: Qt.darker(_surface, 1.25)
    _surfaceBright: Qt.lighter(_surface, 1.8)

    _surfaceContainerLowest: Qt.darker(_surface, 1.8)
    _surfaceContainerLow: Qt.darker(_surface, 1.7)
    _surfaceContainer: Qt.darker(Kirigami.Theme.alternateBackgroundColor, 1.6)
    _surfaceContainerHigh: Qt.lighter(_surfaceContainer, 1.2)
    _surfaceContainerHighest: Qt.lighter(_surfaceContainer, 1.5)

    _surfaceVariant: Kirigami.Theme.alternateBackgroundColor
    _onSurfaceVariant: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.7)

    // دمج ذكي للألوان: نأخذ لون الخلفية ونخلطه بنسبة 16% مع اللون الأساسي للحصول على حاوية متناسقة
    _primaryContainer: Qt.tint(_surface, Qt.rgba(_primary.r, _primary.g, _primary.b, 0.16))
    _onPrimaryContainer: Qt.lighter(_primary, 1.2)

    _secondaryContainer: Qt.tint(_surface, Qt.rgba(_secondary.r, _secondary.g, _secondary.b, 0.16))
    _onSecondaryContainer: Qt.lighter(_secondary, 1.2)

    _tertiaryContainer: Qt.tint(_surface, Qt.rgba(_tertiary.r, _tertiary.g, _tertiary.b, 0.16))
    _onTertiaryContainer: Qt.lighter(_tertiary, 1.2)

    _errorContainer: Qt.tint(_surface, Qt.rgba(_error.r, _error.g, _error.b, 0.16))
    _onErrorContainer: _error

    _outline: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.3)
    _outlineVariant: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.15)
    _inverseSurface: _onSurface
    _onInverseSurface: _surface
    _inversePrimary: _primary
    _shadow: "#121212"
    _scrim: "#000000"
}
