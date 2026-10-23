pragma Singleton
import QtQuick

import "root:/config"
import "root:/themes"

BaseTheme {
    id: tokyoNightDark
    themeName: "TokyoNightDark"
    _themeMode: "dark"

    _wallpaper: App.assets.getWallpaperPath("TokyoNightDark.jpeg")

    // الألوان الرئيسية والثانوية الرسمية لـ Tokyo Night
    _primary: Qt.rgba(0.47843137383461, 0.6352941393852234, 0.9686274528503418, 1)            // Blue (الأزرق الرئيسي)
    _onPrimary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)          // bg_dark (الخلفية الداكنة)
    _secondary: Qt.rgba(0.7333333492279053, 0.6039215922355652, 0.9686274528503418, 1)          // Magenta (الأرجواني)
    _onSecondary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)
    _tertiary: Qt.rgba(0.4901960790157318, 0.8117647171020508, 1, 1)           // Cyan (السماوي)
    _onTertiary: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)
    _error: Qt.rgba(0.9686274528503418, 0.4627451002597809, 0.5568627715110779, 1)              // Red (الأحمر)
    _onError: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)

    // تدرجات الأسطح والخلفيات (Surfaces & Containers) لبناء تسلسل طبقات مريح للعين
    _surface: Qt.rgba(0.10196078568696976, 0.10588235408067703, 0.14901961386203766, 1)                      // bg (الخلفية الأساسية للسمة)
    _onSurface: Qt.rgba(0.7529411911964417, 0.7921568751335144, 0.9607843160629272, 1)                    // fg (النص الأساسي البارز)
    _surfaceDim: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)                   // bg_dark (الخلفية الأكثر دكنة للتحكم الجانبي والـ Sidebars)
    _surfaceBright: Qt.rgba(0.16078431904315948, 0.18039216101169586, 0.25882354378700256, 1)                // bg_highlight (الخلفية المضيئة للتحديد والأسطر النشطة)
    _surfaceContainerLowest: Qt.rgba(0.07450980693101883, 0.0784313753247261, 0.10980392247438431, 1)       // درجة داكنة جداً للطبقات العميقة السفلى
    _surfaceContainerLow: Qt.rgba(0.08627451211214066, 0.08627451211214066, 0.11764705926179886, 1)          // bg_dark (الطبقة السفلى)
    _surfaceContainer: Qt.rgba(0.10196078568696976, 0.10588235408067703, 0.14901961386203766, 1)             // bg (الطبقة المتوسطة)
    _surfaceContainerHigh: Qt.rgba(0.12156862765550613, 0.13725490868091583, 0.2078431397676468, 1)         // درجة انتقالية بين الخلفية والتحديد
    _surfaceContainerHighest: Qt.rgba(0.16078431904315948, 0.18039216101169586, 0.25882354378700256, 1)      // bg_highlight (الطبقة الأعلى)
    _surfaceVariant: Qt.rgba(0.16078431904315948, 0.18039216101169586, 0.25882354378700256, 1)
    _onSurfaceVariant: Qt.rgba(0.6627451181411743, 0.6941176652908325, 0.8392156958580017, 1)             // fg_dark (النصوص الثانوية الأقل بروزاً)

    // ألوان الحاويات وخلفيات التحديد النشطة
    _primaryContainer: Qt.rgba(0.1568627506494522, 0.20392157137393951, 0.34117648005485535, 1)             // bg_visual (خلفية التحديد البصري الأزرق)
    _onPrimaryContainer: Qt.rgba(0.47843137383461, 0.6352941393852234, 0.9686274528503418, 1)           // الأزرق الرئيسي للتحديدات
    _secondaryContainer: Qt.rgba(0.2666666805744171, 0.22745098173618317, 0.3686274588108063, 1)           // درجة تحديد أرجوانية داكنة متناسقة
    _onSecondaryContainer: Qt.rgba(0.7333333492279053, 0.6039215922355652, 0.9686274528503418, 1)         // الأرجواني الرئيسي
    _tertiaryContainer: Qt.rgba(0.12156862765550613, 0.2078431397676468, 0.27843138575553894, 1)            // درجة تحديد سماوية داكنة
    _onTertiaryContainer: Qt.rgba(0.4901960790157318, 0.8117647171020508, 1, 1)          // السماوي الرئيسي
    _errorContainer: Qt.rgba(0.2980392277240753, 0.1411764770746231, 0.1725490242242813, 1)               // درجة أحمر داكنة لخلفية الأخطاء
    _onErrorContainer: Qt.rgba(0.9686274528503418, 0.4627451002597809, 0.5568627715110779, 1)             // الأحمر الرئيسي للأخطاء

    // الحدود والفواصل (Outlines) لتقليل التشتت البصري
    _outline: Qt.rgba(0.23137255012989044, 0.25882354378700256, 0.3803921639919281, 1)                      // fg_gutter (اللون المستخدم للحدود والفواصل الافتراضية)
    _outlineVariant: Qt.rgba(0.2549019753932953, 0.2823529541492462, 0.40784314274787903, 1)               // terminal_black (درجة حدود بديلة أكثر وضوحاً عند الحاجة)

    _inverseSurface: Qt.rgba(0.7529411911964417, 0.7921568751335144, 0.9607843160629272, 1)
    _onInverseSurface: Qt.rgba(0.10196078568696976, 0.10588235408067703, 0.14901961386203766, 1)
    _inversePrimary: Qt.rgba(0.47843137383461, 0.6352941393852234, 0.9686274528503418, 1)
    _shadow: Qt.rgba(0, 0, 0, 1)
    _scrim: Qt.rgba(0, 0, 0, 1)
    _hyprShadowColor: Qt.rgba(0, 0.2666666805744171, 0, 0)
    _enableWallpaperBlur: true

    _plasmaColorScheme: "NibrasTokyoNightDark"
    _konsoleProfile: "NibrasTokyoNightDark.profile"

    _themeIcons: "Tela-dark"
    _gtkTheme: "Tokyonight-Dark"
    _desktopClockFont: "Kitchen police"
    _desktopClockColor: Qt.rgba(0.6823682188987732, 0.5137255191802979, 0.9215686321258545, 1)
    _desktopClockPosition: Qt.point(352.2890625, 520.2578125)
    _desktopClockDepthEffectEnabled: true
    _desktopClockDepthModel: "isnet-general-use"
    _desktopClockDepthOverlayPath: App.assets.getWallpaperPath("TokyoNightDark_depth.png")
    _desktopClockSize: Qt.size(940.77734375, 397.546875)
    _desktopClockGlowColor: Qt.rgba(0.8823224306106567, 0.5255054831504822, 1, 1)
    _desktopClockGlowEnabled: true
    _desktopClockGlowIntensity: 0.5
    _desktopClockUseThemeColor: false
}
