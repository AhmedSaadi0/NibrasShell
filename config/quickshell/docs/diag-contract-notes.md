# diag-contract-notes.md — ملاحظات عقد التشخيص (المرحلة 0)

- **التاريخ:** 2026-11-02
- **النطاق:** مخرجات المرحلة 0 من `docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md` فقط (تدقيق + احتواء + تثبيت عقود). لا يُنفَّذ أي منطق تشغيل جديد هنا.
- **المرجع الحاكم:** `docs/NibrasShell_AI_Diagnostics_Plan_vFinal.md` — sha256 `d8fe2fb93341f2c13b8d4d9613b136a69fb04af9426c7356c84cc89ab423c254`.
- **مشتق بصري (طلب مستخدم منفصل):** `docs/NibrasShell_AI_Diagnostics_Plan_Guide_AR.html` — ملف مرجعي مشتق لا حاكم؛ `docs/NibrasShell_AI_Diagnostics_Plan_Guide_AR.html` (طلب المستخدم؛ مشتق لا حاكم).

---

## 1. قرار إطار الاختبار (unittest) — مُسجَّل

- **الإطار:** `unittest` من المكتبة القياسية فقط — **لا تبعيات جديدة**، ولا venv جديد.
- **المفسر:** مفسّر النظام `python3` (نفس مستوى التشغيل المتاح في المرحلة 0).
- **أمر التشغيل:** `python3 scripts/python/tests/test_phase0_fixtures.py -v`
- **السبب:** أهداف هذه المرحلة تثبيت أشكال مُثبّتة (golden fixtures) بحتة — بدون أي كود تجميع/اكتشاف؛ وتحميل ملفات JSON بالمسارات النسبية من `__file__` لا يحتاج أي تغليف.
- **انتباه للأنواع:** `journalctl --output=json` يُخرج الحقول الموثوقة كنصوص (`PRIORITY: "4"`, `_PID: "1839"`, `__MONOTONIC_TIMESTAMP: "..."`). الاختبارات تفرض **نوع النص** حتى تفشل بصوتْ عالٍ أي parser مستقبلي يفترض أعداداً — بدل فشل صامت.

## 2. تدقيق واجهات وحالات خطأ الحالية (قراءة فقط، مُتحقَّق على القرص 2026-11-02)

| المكوّن | الموقع | ما ثبت |
|---|---|---|
| الظرف الموحَّد | `scripts/python/ai/main.py` (L89-216) | مفاتيح الظرف الأربعة `{success, response, updated_history, error}` — عقد ثابت تستهلكه `AiService.qml` |
| استخراج JSON | `main.py::extract_and_clean_json` (L19-77) | ماسح الأقواس + `json_repair` اختياري (import-guard) |
| الرد الافتراضي | `main.py` L80-86 تقريباً | `{"reply", "apply": False, "changes": [], "warnings": []}` |
| الكشط الحالي | `scripts/python/ai/config.py` `get_raw_boot_logs` (L75-112) | `journalctl -b 0 -p 3 -n 30 --output=short-iso --no-pager` — أي `err` وما أكثر إلحاحاً؛ يُفوّت التحذير (4) ولا يحمل أي حقول موثوقة (نص فقط) |
| قالب الحلول | `scripts/python/ai/prompts/boot_solution.py` (L1-109) | `solutions[]` بمفاتيح `id/related_log/title/difficulty(easy|medium|hard)/priority(critical|important|optional)/description/why_this_works/steps[{label,command,warning}]` + كلاسيكية جدول الحزم (L17-20) |
| مهمة العملية | `services/AiTask.qml` (L1-56) | **بلا مهلة ولا قتل** — فشل JSON → `failed("Invalid JSON envelope")` |
| الواجهة | `config/App.qml` L318-320 | `callBootAnalysisAi` / `callBootSolutionAi` / `callSpikeAnalysisAi` بنفس نمط argv |
| عرض السجلات | `windows/leftwindow/monitoring/components/BootDetails.qml` | افتراضيات فشل-مفتوح L399-400 (`difficulty/priority`)؛ MouseArea "Copy Log" L222-238 — **خارج نطاق الاحتواء** (نسخ سجل، ليس أوامر نموذج) |
| سلسلة النسخ المارّة | `windows/leftwindow/monitoring/components/SolutionCard.qml` L250-256 | المستهلك الوحيد لـ`CommandBox`؛ يمرّر `command: modelData.command \|\| ""` |
| قراءة أحداث النسخ | `windows/leftwindow/monitoring/components/SolutionCard.qml` L75 | `App.dispatchCommand("Copy solution command", ["wl-copy", root.command])` — وجهة الحاجز |
| **لا تنفيذ** | — | لا يوجد مسار تنفيذ للأوامر في الشيفرة الحالية (الخطر إفصاح ونسخ فقط) — نسخ/تحديد يُغلقان عبر الحاجز §6 (لا مسار تنفيذ أصلاً) |

## 3. فحوصات المضيف الحية (قراءة فقط — بدون حفظ رسائل سجل حقيقية)

| الفحص | النتيجة |
|---|---|
| `journalctl -b 0 -p 3 -n 30 --output=short-iso` | 30 سجلاً — نص فقط |
| `journalctl -b 0 -p warning -n 200 --output=json` | 200 سجل · أولويات {2: 2, 3: 30, 4: 168} · نقلات kernel 14 / journal 183 / syslog 3 → تأكيد أن `-p warning` تضم الأخطر (0..3) مع (4) |
| غلة الحقول | `_PID/_COMM/_UID/_GID/_SYSTEMD_UNIT/_SYSTEMD_CGROUP` 186/200 · `_AUDIT_LOGINUID`+`_AUDIT_SESSION` 147/200 · `__CURSOR/__MONOTONIC_TIMESTAMP/_BOOT_ID` 200/200 |
| `journalctl -b 0 -t open-webui -n 3 --output=json` (حقول تعريفية فقط) | المُرسِل الموثوق `_COMM: conmon` و`_EXE: /usr/bin/conmon` بينما `SYSLOG_IDENTIFIER: open-webui` — نطاق `user@1000.service / libpod-conmon-<64hex>.scope`، و`_AUDIT_LOGINUID/_AUDIT_SESSION` حاضران، `PRIORITY: "6"` |

- **الحالة المحورية مثبتة حياً:** المُرسِل (بالحقول الموثوقة) `conmon` ≠ صاحب الاسم `open-webui` — أساس مُثبّتة `motivating_conmon_stdout.json` الاصطناعية.
- **ملاحظة توصيف مؤجَّلة (لا سبب معزى):** ظهر سطر مستوى `INFO` ضمن نافذة `-p 3` (`open-webui[1839]`)؛ ربط مسارات الخطأ للحاويات بدرجات أعلى يحتاج توصيفاً في المرحلتين 1-2.

## 4. مُثبّتات الظرف القديم (legacy) المجمَّدة — العقد

- الملفات: `scripts/python/tests/fixtures/legacy_envelope/boot_analyze_legacy.json` و`boot_solution_legacy.json`.
- **العقد:** مفاتيح الظرف **أربعة بالضبط**؛ سجلات `updated_history` بمفاتيح `{role, content}`؛ رد `boot_analyze` بـ`title/summary/status_color/boot_duration/logs[{time,process,message,raw_details}]`؛ ردّ `boot_solution` بـ`solutions[]` وفق مخطط القالب، وخطوة أمر واحدة غير فارغة على الأقل.
- **تمثيل آمن:** القيم اصطناعية بالكامل؛ أوامر `systemctl --user` على خدمة اصطناعية (`app-synthetic-000.service`) — آمنة حتى لو نُفّذت.
- مصدر الشكل: مواقع الاستهلاك المذكورة أعلاه (§2) — والقيم الافتراضية فشل-مفتوح في `BootDetails` L399-400 لم **تُعدَّل** — استكمالها محصور في المرحلة 5.

## 5. مُثبّتات journald الاصطناعية — المخزون ومنشأ القيم

المجلد: `scripts/python/tests/fixtures/journal/` (كل سجل كائن JSON واحد، قيم نصية مطابقة لمخرجات `journalctl --output=json`):

| الملف | الغرض |
|---|---|
| `motivating_conmon_stdout.json` | إعادة إنتاج الحالة المحورية اصطناعياً: `_COMM "conmon"` + scope `libpod-conmon-…` مع `SYSLOG_IDENTIFIER ≠ conmon` + `_AUDIT_LOGINUID/_AUDIT_SESSION` + `PRIORITY "4"` |
| `host_systemd_v2.json` | وحدة نظام مستضيفة بثنائية `_SYSTEMD_UNIT/_SYSTEMD_CGROUP` متوافقة (`synthetic-daemon.service`)، أولوية 3 |
| `host_user_session_v2.json` | إعلان جلسة المستخدم (`user@1000.service` / `app-synthetic-000.service`) + هوية تدقيق موثوقة، أولوية 4 |
| `audit_trusted_identity.json` | ناقل `audit` لحمل هوية تدقيق موثوقة؛ **انتباه:** الحقول الموثوقة للسجل جاءت من journald نفسها (`_COMM systemd-journald`)، وهوية العملية تعيش في جسم التدقيق — هذه نقطة توصيف مؤجَّلة للمرحلة 1 (لا يُتَّخذ منها إثبات) |
| `unknown_sender_minimal.json` | نقل `kernel` بلا `_PID/_UID/_COMM/_SYSTEMD_*` — مُرسِل مُغمَض |
| `boot_mismatch_cursor.json` | `_BOOT_ID` مختلف + واحد مُتعمَّد — قيمة حدّيّة لاختبارات الفرز بالمؤشر وبصمة الإقلاع |

- **القيم اصطناعية مُتعمدة:** boot ids `b0e0…/1111…`، معرفات الجهاز `0f0f…`، scope hex `ffff…0000…`، أسماء `synthetic-*` — لا تطابق مضيفاً حقيقياً، ولا رسائل سجل حقيقية محفوظة في أي ملف.
- بيانات المنشأ موثقة **هنا** (وفي توثيق الاختبار) — **وليس** بحقول مخفيّة داخل ملفات المُثبّتات، حتى تبقى مطابقةً لمخرج journald الحقيقي.

## 6. الحاجز الأدنى في QML (CommandBox.qml) — التصميم والمبررة

- **الموقع الوحيد:** `CommandBox.qml` هو كل قناة نسخ/عرض لأوامر الخطوات القديمة؛ مستهلكه الوحيد `SolutionCard.qml` L250-256. لا تعديل على `BootDetails.qml` (زر "Copy Log" معزول عن الأوامر).
- **الإضافة:** `validated: false` + `quarantined: !validated`؛
  - `selectByMouse: root.validated` — يقفل أيضاً التحديد اليدوي (Ctrl+C) للنص CommandBox؛
  - زر النسخ: `visible: root.validated` و`MouseArea.enabled: root.validated`؛
  - شارة ظاهرة `unvalidated (legacy)` بلون التحذير حين `quarantined` (نص الواجهة إنجليزي عمداً)؛
- **المرحلة 0:** لا شيء يضع `validated = true` – كل أمر وارد عبر السلوك القديم معزول، القرار مربوط لاحقاً بمُهايئ العقد الجديد في المرحلة 5.
- التعليق داخل الشيفرة يشير إلى الخطة §13 و§16.4 لغرض تتبع السبب.

## 7. مسارات مُغيَّرة/منشأة في المرحلة 0 (فهرس يُتابَع يدوياً)

**منشأة:**
1. `docs/NibrasShell_AI_Diagnostics_Plan_Guide_AR.html` — طلب مستخدم منفصل (مرجع بصري عربي RTL)
2. `docs/diag-contract-notes.md`
3. `scripts/python/tests/test_phase0_fixtures.py`
4. `scripts/python/tests/fixtures/legacy_envelope/boot_analyze_legacy.json`
5. `scripts/python/tests/fixtures/legacy_envelope/boot_solution_legacy.json`
6. `scripts/python/tests/fixtures/journal/motivating_conmon_stdout.json`
7. `scripts/python/tests/fixtures/journal/host_systemd_v2.json`
8. `scripts/python/tests/fixtures/journal/host_user_session_v2.json`
9. `scripts/python/tests/fixtures/journal/audit_trusted_identity.json`
10. `scripts/python/tests/fixtures/journal/unknown_sender_minimal.json`
11. `scripts/python/tests/fixtures/journal/boot_mismatch_cursor.json`

**مُعدَّلة:**
12. `windows/leftwindow/monitoring/components/CommandBox.qml` (حاجز العزل)

**لم تُمس** بقية مسارات العمل ولا أي شيء في `.git`.

**ملاحظة أثر بيئي (للشفافية):** ظهر في فحص mtime أثر ذاكرة أداة فحص آلي `./.ruff_cache/0.15.22/11202383206027209231` (تاريخها أثناء جلسة العمل) — لم يصدره أي أمر من مخرجات هذه المرحلة، وليس مساراً مقصوداً؛ تُرك كما هو ولم يُحذف.

## 8. بوابات المرحلة 0 حالة مقابل معايير الخطة

| المعيار | الحالة |
|---|---|
| تدقيق مساحة العمل (الواجهات/حالات الخطأ موثقة) | ✅ §2 + هذا الملف |
| فحص قراءة-فقط للكشط الحالي والنافذة المقترحة | ✅ §3 |
| العقد القديم مجمَّد في مُثبّتة | ✅ §4 + اختبار |
| قرار unittest مسجَّل | ✅ §1 |
| مُثبّتات journald اصطناعية تشمل الحالة المحورية | ✅ §5 + اختبار |
| أدوات النسخ/التنفيذ للأوامر غير المُتحقَّقة مُعطَّلة | ✅ §6 (غير قابل للتنفيذ أصلاً؛ النسخ/التحديد مقفولان) |
| صفر عمليات git | ✅ لم تُنفَّذ |

## 9. مواد مؤجَّلة صراحة (المرحلتان 1-2)

1. توصيف `stderr`→أولوية للحاويات (سطر `INFO` في نافذة `-p 3`).
2. دلالات نافذة أولوية نقلات `audit` (بند `PRIORITY "6"` في مُثبّتة audit خارج فحص شريط 0..4 عمداً).
3. حقول المُرسِل الفعلية لسجلات تدقيق journald (المُثبّتة تحاكي شكلاً ضرورياً فقط).
4. اكتشاف `role` للحاويات (podman) وربط قواعد cgroup v1/v2 — القلب الأساسي للمرحلة 1.
