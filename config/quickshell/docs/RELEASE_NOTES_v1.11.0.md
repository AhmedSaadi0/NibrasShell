v1.11.0 — matugen Migration, Contrast Control & Theme Sync Fixes

# 🚀 Release Notes / ملاحظات الإصدار (v1.11.0)

---

## 🇺🇸 English Version

### ✨ Key Improvements

- 🎨 **matugen-Powered Dynamic Coloring**
  - Replaced `kde-material-you-colors` with **matugen 3.1.0** as the Material You color engine.
  - Added a new stdlib-only Python wrapper that calls `matugen image ... -j hex --dry-run`, parses the generated palette, and writes KDE `.colors`, Konsole `.colorscheme`, and `kdeglobals ColorSchemeHash` directly.
  - Removed all Python package dependencies from the m3 layer; the shell no longer needs `kde_material_you_colors`, `materialyoucolor`, Pillow, NumPy, or pywal for dynamic colors.
  - Preserved existing Plasma/KDE integration: generated `MaterialYouDark` / `MaterialYouLight` schemes keep `Kirigami.Theme`, Qt apps, and KDE apps in sync.

- 🎚️ **Official Contrast Control**
  - Replaced the old **Chroma** and **Tone** multipliers with matugen’s official **Contrast** slider (`-1.0` to `1.0`, default `0.0`).
  - Kept the existing `0..8` scheme IDs and cache layout, mapping them 1:1 to matugen scheme types such as `scheme-fidelity`, `scheme-tonal-spot`, and `scheme-vibrant`.
  - Old cache files with legacy chroma/tone keys are ignored safely and rewritten cleanly on the next save.

- 🔄 **Proper Async M3 Execution & Sync**
  - Replaced fire-and-forget process launching for dynamic coloring with a real QML `Process` including stdout/stderr logging, failure reporting, and a pending-command guard to avoid overlapping palette writes.
  - Added `m3Applied` / `m3Failed` callbacks so Hyprland border colors are re-applied immediately after the new palette is live.
  - Consolidated live Konsole switching through the existing Plasma 6 profile script, refreshing running sessions after colors are generated.

- 🧹 **Cleanup & Safety**
  - Dropped dormant AGS CSS, Kitty, pywal, and KSyntax generators that were no longer active.
  - Prevented `AiThemeAssistant` from silently overriding matugen-managed schemes while Material You coloring is enabled; AI scheme switching remains available for static themes.
  - Updated UI dependency text and translations to reference `matugen`.

- 🧪 **Testing**
  - Added stdlib unit tests for scheme mapping, CLI flag construction, KDE/Konsole output generation, hash updating, fallback color handling, and invalid contrast validation.

---

## 🇾🇪 النسخة العربية

### ✨ أبرز التحسينات

- 🎨 **توليد الألوان الديناميكية عبر matugen**
  - استبدال `kde-material-you-colors` بـ **matugen 3.1.0** كمحرك Material You الجديد.
  - إضافة غلاف Python يعتمد على المكتبة القياسية فقط، يستدعي `matugen image ... -j hex --dry-run`، ويحلل اللوحة الناتجة، ثم يكتب ملفات KDE `.colors` وKonsole `.colorscheme` و`kdeglobals ColorSchemeHash` مباشرة.
  - إزالة اعتماديات Python الخارجية من طبقة الألوان؛ لم يعد توليد الألوان يحتاج `kde_material_you_colors` أو `materialyoucolor` أو Pillow أو NumPy أو pywal.
  - الحفاظ على تكامل Plasma/KDE: ما زالت مخططات `MaterialYouDark` و`MaterialYouLight` تُحدّث `Kirigami.Theme` وتطبيقات Qt وKDE بشكل متسق.

- 🎚️ **تحكم رسمي في التباين**
  - استبدال معاملَي **Chroma** و**Tone** بشريط **Contrast** الرسمي من matugen من `-1.0` إلى `1.0` بقيمة افتراضية `0.0`.
  - الإبقاء على معرّفات المخططات الحالية `0..8` وربطها مباشرة بأنواع matugen مثل `scheme-fidelity` و`scheme-tonal-spot` و`scheme-vibrant`.
  - ملفات الكاش القديمة التي تحتوي مفاتيح Chroma/Tone يتم تجاهلها بأمان وإعادة كتابتها عند الحفظ التالي.

- 🔄 **تنفيذ M3 غير متزامن ومزامنة أفضل**
  - استبدال تشغيل العملية بدون مراقبة بـ `Process` حقيقي في QML مع تسجيل stdout/stderr، والإبلاغ عن الأخطاء، ومنع تشغيل أكثر من مهمة توليد ألوان في الوقت نفسه.
  - إضافة ردّي `m3Applied` / `m3Failed` لإعادة تطبيق ألوان حدود Hyprland فور تفعيل اللوحة الجديدة.
  - توحيد تبديل بروفايل Konsole المباشر عبر سكربت Plasma 6 الحالي، مع تحديث الجلسات المفتوحة بعد توليد الألوان.

- 🧹 **تنظيف وحماية**
  - إزالة مولّدات AGS CSS وKitty وpywal وKSyntax غير المستخدمة.
  - منع `AiThemeAssistant` من الكتابة فوق مخططات matugen أثناء تفعيل Material You، مع الإبقاء على ميزة ألوان الذكاء الاصطناعي للثيمات الثابتة.
  - تحديث نص الاعتمادية والترجمات للإشارة إلى `matugen`.

- 🧪 **اختبارات**
  - إضافة اختبارات وحدة قياسية تغطي ربط المخططات، بناء أوامر CLI، مخرجات KDE/Konsole، تحديث الهاش، لون الاحتياط، والتحقق من نطاق Contrast.

---

> Skipped: installer changes, `ar.qm` recompile, and live Quickshell run. Risk: legacy cache keys remain until the next save rewrites the cache.
