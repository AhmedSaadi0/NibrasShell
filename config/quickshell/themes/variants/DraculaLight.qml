pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: draculaLight

    themeName: "DraculaLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("DraculaLight.jpeg")

    // --- ألوان دراكولا الأساسية (Darkened for Light Mode Accessibility) ---
    _primary: Qt.rgba(0.392, 0.290, 0.788, 1)                     // Dracula Purple (#644ac9)
    _onPrimary: Qt.rgba(1, 1, 1, 1)

    _secondary: Qt.rgba(0.639, 0.078, 0.302, 1)                   // Dracula Pink (#a3144d)
    _onSecondary: Qt.rgba(1, 1, 1, 1)

    _tertiary: Qt.rgba(0.012, 0.416, 0.588, 1)                    // Dracula Cyan (#036a96)
    _onTertiary: Qt.rgba(1, 1, 1, 1)

    _error: Qt.rgba(0.796, 0.227, 0.165, 1)                       // Dracula Red (#cb3a2a)
    _onError: Qt.rgba(1, 1, 1, 1)

    // --- أسطح وخلفيات دراكولا الفاتحة الرسمية ---
    _surface: Qt.rgba(0.973, 0.973, 0.949, 1)                     // Dracula Inverted Background (#f8f8f2)
    _onSurface: Qt.rgba(0.157, 0.165, 0.212, 1)                   // Dracula Dark Background as Text (#282a36)
    _surfaceDim: Qt.rgba(0.918, 0.914, 0.882, 1)                  // #eae9e1
    _surfaceBright: Qt.rgba(1, 1, 1, 1)

    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.953, 0.953, 0.922, 1)         // #f3f3eb
    _surfaceContainer: Qt.rgba(0.933, 0.929, 0.898, 1)            // #eeede5
    _surfaceContainerHigh: Qt.rgba(0.910, 0.906, 0.871, 1)        // #e8e7de
    _surfaceContainerHighest: Qt.rgba(0.886, 0.882, 0.843, 1)     // #e2e1d7

    _surfaceVariant: Qt.rgba(0.886, 0.882, 0.843, 1)             // Dracula Selection/Variant
    _onSurfaceVariant: Qt.rgba(0.384, 0.447, 0.643, 1)           // Dracula Comment Color (#6272a4)

    // --- الحاويات (Tonal Containers) ---
    _primaryContainer: Qt.rgba(0.929, 0.910, 0.984, 1)           // Soft Purple Container
    _onPrimaryContainer: Qt.rgba(0.141, 0.086, 0.353, 1)

    _secondaryContainer: Qt.rgba(0.988, 0.894, 0.925, 1)         // Soft Pink Container
    _onSecondaryContainer: Qt.rgba(0.259, 0.000, 0.118, 1)

    _tertiaryContainer: Qt.rgba(0.847, 0.945, 0.984, 1)          // Soft Cyan Container
    _onTertiaryContainer: Qt.rgba(0.004, 0.153, 0.220, 1)

    _errorContainer: Qt.rgba(0.992, 0.910, 0.902, 1)             // Soft Red Container
    _onErrorContainer: Qt.rgba(0.290, 0.043, 0.016, 1)

    // --- الإطارات والظلال والوضع العكسي ---
    _outline: Qt.rgba(0.384, 0.447, 0.643, 1)                    // Dracula Comment Color (#6272a4)
    _outlineVariant: Qt.rgba(0.812, 0.812, 0.871, 1)             // Soft Border (#cfcfde)

    _inverseSurface: Qt.rgba(0.157, 0.165, 0.212, 1)             // Dracula Original Dark (#282a36)
    _onInverseSurface: Qt.rgba(0.973, 0.973, 0.949, 1)           // #f8f8f2
    _inversePrimary: Qt.rgba(0.741, 0.576, 0.976, 1)             // Dracula Original Purple (#bd93f9)

    _shadow: Qt.rgba(0.157, 0.165, 0.212, 0.12)                  // ظلال ناعمة بدلاً من الرمادي الباهت
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
    _hyprShadowColor: Qt.rgba(0.157, 0.165, 0.212, 0.15)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasShellAiGenerated-20260702_042526"
    _konsoleProfile: "DraculaLight.profile"

    _themeIcons: "Fluent-light"
    _kvantumTheme: "Tellgo"
    _gtkTheme: "Tokyonight-Dark-BL"
    _desktopClockFont: "Yukarimobile"
    _desktopClockColor: Qt.rgba(0.392, 0.290, 0.788, 0.85)       // متطابق مع بنفسجي دراكولا
    _desktopClockPosition: Qt.point(126.8515625, 151.68359375)
    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "isnet-general-use"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("DraculaLight_depth.png")
    _desktopClockSize: Qt.size(1041.98828125, 282.53125)
    _desktopClockGlowColor: Qt.rgba(0, 0, 0, 0)
    _desktopClockUseThemeColor: false
}
