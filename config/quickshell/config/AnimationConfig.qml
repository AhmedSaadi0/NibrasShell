pragma Singleton
import QtQuick

QtObject {
    id: root

    // ============================================================
    // منحنى التسارع المستمر (Continuous Acceleration - Ease In)
    // ============================================================
    // يبدأ ببطء ويتسارع حتى اللحظة الأخيرة (يصطدم بـ 100% بأقصى سرعة)
    readonly property list<double> bezierAccelerate: [0.5, 0.0, 1.0, 1.0]

    // ============================================================
    // التوقيتات (Durations)
    // ============================================================
    readonly property int animDuration: 200
    readonly property int fadeDuration: 200
    readonly property int barExpandDuration: 200

    // ============================================================
    // إعدادات Hyprland (المصدر الوحيد — متطابقة مع CatppuccinDark.json / بروفايل "Calm")
    // ============================================================
    // مجموعة منحنيات الحركة (win_in / win_out / move / ui / launch)
    readonly property string hyprBezier: "win_in, 0.16, 1, 0.3, 1\nwin_out, 0.3, 0, 0.6, 1\nmove, 0.2, 0.85, 0.15, 1\nui, 0.25, 0.1, 0.25, 1\nlaunch, 0.12, 0.95, 0.22, 1"

    readonly property string hyprAnimWindows: "1, 8, launch, popin 90%"
    readonly property string hyprAnimWindowsIn: "1, 8, launch, popin 90%"
    readonly property string hyprAnimWindowsMove: "1, 7, move, slide"
    readonly property string hyprAnimWindowsOut: "1, 7, win_out, popin 88%"
    readonly property string hyprAnimBorder: "1, 10, ui"
    readonly property string hyprAnimBorderAngle: "1, 12, ui"
    readonly property string hyprAnimFadeIn: "1, 8, launch"
    readonly property string hyprAnimFadeOut: "1, 6, win_out"
    readonly property string hyprAnimWorkspaces: "1, 7, move, slide"
}
