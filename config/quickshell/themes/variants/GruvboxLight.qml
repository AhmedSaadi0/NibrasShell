pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: gruvboxLight
    themeName: "GruvboxLight"
    _themeMode: "light"

    _wallpaper: App.assets.getWallpaperPath("gruvbox-light.png")
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("gruvbox-light-depth.png")
    _desktopClockFont: "Xenophobia"
    _desktopClockFormat: "hh mm AP - MM/dd"
    _desktopClockPosition: Qt.point(31.29, 45.73)
    _desktopClockDepthEffectEnabled: true
    _desktopClockSize: Qt.size(1829.6484375, 453.57421875)
    _desktopClockShadowEnabled: false
    _desktopClockUseThemeColor: false
    _desktopClockColor: Qt.rgba(0.800000011920929, 0.7499961853027344, 0.6899977326393127, 0.800000011920929)

    _primary: Qt.rgba(0.41960784792900085, 0.6196078658103943, 0.41960784792900085, 1)
    _onPrimary: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)
    _secondary: Qt.rgba(0.843137264251709, 0.6000000238418579, 0.12941177189350128, 1)
    _onSecondary: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)
    _tertiary: Qt.rgba(0.2705882489681244, 0.5215686559677124, 0.5333333611488342, 1)
    _onTertiary: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)
    _error: Qt.rgba(0.800000011920929, 0.1411764770746231, 0.11372549086809158, 1)
    _onError: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)

    _surface: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)                      // bg0_light
    _onSurface: Qt.rgba(0.23529411852359772, 0.21960784494876862, 0.21176470816135406, 1)                    // fg0_light
    _surfaceDim: Qt.rgba(0.9215686321258545, 0.8588235378265381, 0.6980392336845398, 1)                   // bg1_light
    _surfaceBright: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)
    _surfaceContainerLowest: Qt.rgba(1, 1, 1, 1)
    _surfaceContainerLow: Qt.rgba(0.9490196108818054, 0.9215686321258545, 0.8039215803146362, 1)
    _surfaceContainer: Qt.rgba(0.9215686321258545, 0.8588235378265381, 0.6980392336845398, 1)
    _surfaceContainerHigh: Qt.rgba(0.8352941274642944, 0.7686274647712708, 0.6313725709915161, 1)
    _surfaceContainerHighest: Qt.rgba(0.7411764860153198, 0.6823529601097107, 0.5764706134796143, 1)
    _surfaceVariant: Qt.rgba(0.9215686321258545, 0.8588235378265381, 0.6980392336845398, 1)
    _onSurfaceVariant: Qt.rgba(0.48627451062202454, 0.43529412150382996, 0.3921568691730499, 1)

    // تحسين ألوان الحاويات والبطاقات للنسخة المضيئة لمنع مظهر السطح المسطح العادي
    _primaryContainer: Qt.rgba(0.8980392217636108, 0.929411768913269, 0.8352941274642944, 1)             // Light Green Tint
    _onPrimaryContainer: Qt.rgba(0.25882354378700256, 0.48235294222831726, 0.3450980484485626, 1)
    _secondaryContainer: Qt.rgba(0.9607843160629272, 0.9019607901573181, 0.7686274647712708, 1)           // Light Yellow/Gold Tint
    _onSecondaryContainer: Qt.rgba(0.7098039388656616, 0.4627451002597809, 0.0784313753247261, 1)
    _tertiaryContainer: Qt.rgba(0.8627451062202454, 0.9411764740943909, 0.9450980424880981, 1)            // Light Blue/Cyan Tint
    _onTertiaryContainer: Qt.rgba(0.027450980618596077, 0.4000000059604645, 0.47058823704719543, 1)
    _errorContainer: Qt.rgba(0.9764705896377563, 0.8705882430076599, 0.8627451062202454, 1)               // Light Red Tint
    _onErrorContainer: Qt.rgba(0.800000011920929, 0.1411764770746231, 0.11372549086809158, 1)

    _outline: Qt.rgba(0.572549045085907, 0.5137255191802979, 0.45490196347236633, 1)
    _outlineVariant: Qt.rgba(0.8352941274642944, 0.7686274647712708, 0.6313725709915161, 1)
    _inverseSurface: Qt.rgba(0.23529411852359772, 0.21960784494876862, 0.21176470816135406, 1)
    _onInverseSurface: Qt.rgba(0.9843137264251709, 0.9450980424880981, 0.7803921699523926, 1)
    _inversePrimary: Qt.rgba(0.41960784792900085, 0.6196078658103943, 0.41960784792900085, 1)
    _shadow: Qt.rgba(0.2078431397676468, 0.2078431397676468, 0.2078431397676468, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprDropShadow: "yes"
    _hyprShadowColor: Qt.rgba(0.05098039284348488, 0.05098039284348488, 0.05098039284348488, 0.20000000298023224)

    _plasmaColorScheme: "NibrasGruvboxLight"
    _konsoleProfile: "GruvboxLight.profile"

    _themeIcons: "Gruvbox"
    _gtkTheme: "Gruvbox-Light-Soft"
}
