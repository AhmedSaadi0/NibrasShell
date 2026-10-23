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
    _primary: Qt.rgba(0.6196078658103943, 0.5215686559677124, 0.7607843279838562, 1)
    _onPrimary: Qt.rgba(0, 0, 0, 1)

    _secondary: Qt.rgba(0.16078431904315948, 0.501960813999176, 0.7254902124404907, 1)
    _onSecondary: Qt.rgba(0, 0, 0, 1)

    _tertiary: Qt.rgba(0.7411764860153198, 0.5764706134796143, 0.9764705896377563, 1)
    _onTertiary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)

    _error: Qt.rgba(0.8549019694328308, 0.2666666805744171, 0.32549020648002625, 1)
    _onError: Qt.rgba(0, 0, 0, 1)

    // تدرج الأسطح الديناميكي للوضع المضيء لضمان طبقات ناصعة ومريحة
    _surface: Qt.rgba(0.8980392217636108, 0.9176470637321472, 1, 1)
    _onSurface: Qt.rgba(0.20000000298023224, 0.27843138575553894, 0.4313725531101227, 1)
    _surfaceDim: Qt.rgba(0.8315098881721497, 0.8496681451797485, 0.9259174466133118, 1)
    _surfaceBright: Qt.rgba(1, 1, 1, 1)

    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.880430281162262, 0.8996566534042358, 0.9803921580314636, 1)
    _surfaceContainer: Qt.rgba(0.8552681803703308, 0.8739452362060547, 0.9523766040802002, 1)
    _surfaceContainerHigh: Qt.rgba(0.8223697543144226, 0.8403295874595642, 0.9157396554946899, 1)
    _surfaceContainerHighest: Qt.rgba(0.7919127345085144, 0.809201180934906, 0.8818188905715942, 1)

    _surfaceVariant: Qt.rgba(0.8552681803703308, 0.8739452362060547, 0.9523766040802002, 1)
    _onSurfaceVariant: Qt.rgba(0.20000000298023224, 0.27843138575553894, 0.4313725531101227, 0.7000076174736023)

    // في الوضع المضيء نخلط الخلفية بنسبة 12% مع الألوان الأساسية لإنشاء حاويات فاتحة (Pastel)
    // ونقوم بتغميق نصوصها لضمان سهولة القراءة والمقروئية العالية (Accessibility)
    _primaryContainer: Qt.rgba(0.8646219372749329, 0.8701152205467224, 0.9712978005409241, 1)
    _onPrimaryContainer: Qt.rgba(0.34421300888061523, 0.2897535562515259, 0.42264437675476074, 1)

    _secondaryContainer: Qt.rgba(0.809567391872406, 0.8677653074264526, 0.9670557975769043, 1)
    _onSecondaryContainer: Qt.rgba(0.08932631462812424, 0.27885863184928894, 0.40303653478622437, 1)

    _tertiaryContainer: Qt.rgba(0.879209578037262, 0.8767070770263672, 0.9971770644187927, 1)
    _onTertiaryContainer: Qt.rgba(0.4117647111415863, 0.3202563524246216, 0.5424734950065613, 1)

    _errorContainer: Qt.rgba(0.8928664326667786, 0.8395361304283142, 0.9190661311149597, 1)
    _onErrorContainer: Qt.rgba(0.4749370515346527, 0.14814984798431396, 0.18081940710544586, 1)

    _outline: Qt.rgba(0.20000000298023224, 0.27843138575553894, 0.4313725531101227, 0.3000076413154602)
    _outlineVariant: Qt.rgba(0.20000000298023224, 0.27843138575553894, 0.4313725531101227, 0.14999619126319885)
    _inverseSurface: Qt.rgba(0.20000000298023224, 0.27843138575553894, 0.4313725531101227, 1)
    _onInverseSurface: Qt.rgba(0.8980392217636108, 0.9176470637321472, 1, 1)
    _inversePrimary: Qt.rgba(0.6196078658103943, 0.5215686559677124, 0.7607843279838562, 1)
    _shadow: Qt.rgba(0.07058823853731155, 0.07058823853731155, 0.07058823853731155, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0, 0, 0.2666666805744171, 0.3333333432674408)

    _plasmaColorScheme: "MaterialYouLight"
    _konsoleProfile: "MaterialYouAlt.profile"

    _themeIcons: "Tela-light"
    _kvantumTheme: "Tellgo"
    _gtkTheme: "Breeze-Light"
}
