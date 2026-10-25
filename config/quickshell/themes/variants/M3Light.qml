pragma Singleton

import org.kde.kirigami as Kirigami
import QtQuick

import "root:/themes"
import "root:/config"

BaseTheme {
    id: root
    themeName: "M3Light"

    _enableDynamicColoring: true
    _enableDynamicWallpapers: false

    _themeMode: "light"

    _baseRadius: 14
    _hyprBorderWidth: 3

    _wallpaper: App.assets.getWallpaperPath("m3_light.png")
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("m3_light_depth.png")
    _desktopClockFont: "Xenophobia"
    _desktopClockFormat: "hh:mm A - MM/dd"
    _desktopClockPosition: Qt.point(166.453125, 276)
    _desktopClockDepthEffectEnabled: true
    _desktopClockSize: Qt.size(1504.37890625, 453.2109375)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.1900053471326828, 0.14000152051448822, 0.4000000059604645, 0.800000011920929)

    // ربط الألوان الرئيسية بنظام ألوان KDE
    _primary: Kirigami.Theme.highlightColor
    _onPrimary: Kirigami.Theme.highlightedTextColor

    _secondary: Kirigami.Theme.linkColor
    _onSecondary: Kirigami.Theme.highlightedTextColor

    _tertiary: "#bd93f9"
    _onTertiary: "#16161e"

    _error: Kirigami.Theme.negativeTextColor
    _onError: Kirigami.Theme.highlightedTextColor

    // تدرج الأسطح الديناميكي للوضع المضيء لضمان طبقات ناصعة ومريحة
    _surface: Kirigami.Theme.backgroundColor
    _onSurface: Kirigami.Theme.textColor
    _surfaceDim: Qt.darker(_surface, 1.08)
    _surfaceBright: "#FFFFFF"

    _surfaceContainerLowest: "#FFFFFF"
    _surfaceContainerLow: Qt.darker(_surface, 1.02)
    _surfaceContainer: Kirigami.Theme.alternateBackgroundColor
    _surfaceContainerHigh: Qt.darker(_surfaceContainer, 1.04)
    _surfaceContainerHighest: Qt.darker(_surfaceContainer, 1.08)

    _surfaceVariant: Kirigami.Theme.alternateBackgroundColor
    _onSurfaceVariant: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.7)

    // في الوضع المضيء نخلط الخلفية بنسبة 12% مع الألوان الأساسية لإنشاء حاويات فاتحة (Pastel)
    // ونقوم بتغميق نصوصها لضمان سهولة القراءة والمقروئية العالية (Accessibility)
    _primaryContainer: Qt.tint(_surface, Qt.rgba(_primary.r, _primary.g, _primary.b, 0.12))
    _onPrimaryContainer: Qt.darker(_primary, 1.8)

    _secondaryContainer: Qt.tint(_surface, Qt.rgba(_secondary.r, _secondary.g, _secondary.b, 0.12))
    _onSecondaryContainer: Qt.darker(_secondary, 1.8)

    _tertiaryContainer: Qt.tint(_surface, Qt.rgba(_tertiary.r, _tertiary.g, _tertiary.b, 0.12))
    _onTertiaryContainer: Qt.darker(_tertiary, 1.8)

    _errorContainer: Qt.tint(_surface, Qt.rgba(_error.r, _error.g, _error.b, 0.12))
    _onErrorContainer: Qt.darker(_error, 1.8)

    _outline: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.3)
    _outlineVariant: Qt.rgba(_onSurface.r, _onSurface.g, _onSurface.b, 0.15)
    _inverseSurface: _onSurface
    _onInverseSurface: _surface
    _inversePrimary: _primary
    _shadow: "#121212"
    _scrim: "#000000"

    _plasmaColorScheme: "MaterialYouLight"
    _konsoleProfile: "MaterialYouAlt.profile"

    _themeIcons: "Tela-light"
    _kvantumTheme: "Tellgo"
    _gtkTheme: "Breeze-Light"
}
