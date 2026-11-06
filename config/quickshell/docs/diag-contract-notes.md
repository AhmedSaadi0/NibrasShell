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

---

## 10. المرحلة 5 — مُهايئات العرض QML (Legacy / New Diagnosis)

**النطاق:** عرض QML إضافي فقط. لم تُفعَّل مسارات الخادم الجديدة افتراضياً، ولم يُعدَّل `main.py` أو محرّك السياسة في هذه المرحلة. المُهايئ الجديد يعرض الحقول عندما يصل رد يحمل `schema_version: "nibras.diagnosis/v1"`، ويحافظ مسار الإقلاع القديم على سلوكه مع عزل صريح.

### 10.1 عقد الردود التي يفهمها المُهايئ

- **Legacy Adapter:** ظرف بلا `schema_version`، ويحتوي `response.solutions[]` بالشكل القديم (`steps[].command`). يُوسم كل اقتراح بـ`QUARANTINED_LEGACY` بغض النظر عن أي حقول أخرى. لا شيء في هذا المسار يضع `validated = true`.
- **New Diagnosis Adapter:** `response.schema_version == "nibras.diagnosis/v1"` مع `response.solutions[]`. يدعم أيضاً شكل المُنسِّق المتداخل `{schema_version, response: {incident_summary, findings, proposed_remediation, ...}}` دون اختراع حالة سياسة.
- **آلية الحالات المقبولة:** `GUIDANCE_VALIDATED`، `POLICY_REJECTED`، `ANALYSIS_UNVERIFIED`، و`QUARANTINED_LEGACY` للمسار القديم. إذا غاب سجل التحقق في رد جديد، تعرض الواجهة `STATUS_ABSENT` وتبقى غير قابلة للنسخ — لا يُستنتج `VERIFIED`.
- **الفصل بين القرارات:** قرارات الأدوات تُقرأ من `response.validation.tool_decisions[]` (أو الغلاف المتداخل) وتُعرض في قسم مستقل؛ لا تُدمج مع قرارات الإرشاد.
- **النسخ:** زر النسخ يظهر فقط عندما تكون البطاقة `nibras.diagnosis/v1` وحالة الإرشاد `GUIDANCE_VALIDATED` ونص الإرشاد قادماً من `guidance_lines[]` أو `template.lines[]` الخلفية. نصوص النموذج (`description`، `why_this_works`، `findings`) و`ANALYSIS_UNVERIFIED` و`POLICY_REJECTED` و`QUARANTINED_LEGACY` غير قابلة للنسخ. أوامر `steps[].command` القديمة تبقى مرئية للسياق فقط، مع تعطيل النسخ والتحديد اليدوي (تُعرض كـ`Text` غير قابل للتحديد، لا كـ`TextEdit`). سجلات الإقلاع المعروضة (`OBSERVED LOGS`) تُعرض أيضاً كنص غير قابل للتحديد، وليس كمسار نسخ.
- **الحقول المعروضة عند وجودها:** `runtime_domain`، `event_transport`، `verification.status/reasons/time_scope`، `identity_limits`، `uncertainties`/`uncertainty`، `missing_evidence`، `evidence[]`، `confidence_note`، `validation.reasons`/`reason_codes`، و`findings`.
- **قيم enum الغائبة:** لا افتراضات `easy` أو `optional`؛ البطاقة تعرض `UNLABELED` صراحةً.
- **تحليل spike:** يظل تحليل النموذج موسوماً `ANALYSIS_UNVERIFIED`، وأفعاله نصوص اعتبارية غير قابلة للنسخ. لا يوجد مسار تنفيذ في QML.

### 10.2 مُثبّتات الاختبار

- `scripts/python/tests/fixtures/legacy_envelope/boot_solution_legacy_unlabeled.json` — حل قديم بلا `difficulty`/`priority`.
- `scripts/python/tests/fixtures/diagnosis_envelope/boot_solution_diagnosis_v1.json` — ثلاث حالات: `POLICY_REJECTED` مع عدم يقين وهوية محدودة، `GUIDANCE_VALIDATED` مع إرشاد خلفي بلا أوامر، و`ANALYSIS_UNVERIFIED`، إضافةً إلى `tool_decisions[]` منفصلة.
- `scripts/python/tests/test_phase5_qml_adapters.py` — يثبّت أشكال JSON ويختبر عقود المصدر (غياب defaults الفشل-المفتوح، بوابة النسخ، وسوم الحالات، وعزل legacy). لا يوجد `qmltestrunner` في البيئة، لذلك هذه الاختبارات لا تدّعي تشغيل QML.

### 10.3 Manual checklist (Phase 5)

نفّذها يدوياً عند توفر جلسة Quickshell حقيقية:

1. **Legacy quarantine:** افتح بطاقة الإقلاع القديمة. تحقق من ظهور `QUARANTINED_LEGACY` على بطاقة كل حل، ومن بقاء `difficulty`/`priority` كما وردا (أو `UNLABELED` عند غيابهما).
2. **Legacy copy lock:** وسّع بطاقة قديمة. يجب أن يظهر كل `steps[].command` مع شارة `unvalidated (legacy)`، وألا يظهر زر النسخ، وألا يعمل تحديد النص بالفأرة. لا تنفّذ أي أمر.
3. **Unlabeled legacy:** حمّل/حاكِ `boot_solution_legacy_unlabeled.json`. يجب أن تظهر شارتا `UNLABELED` بدل `easy`/`optional`.
4. **New diagnosis statuses:** حمّل/حاكِ `boot_solution_diagnosis_v1.json` (أو رداً جديداً فعلياً). تحقق من ظهور `GUIDANCE_VALIDATED` و`POLICY_REJECTED` و`ANALYSIS_UNVERIFIED` حرفياً، ومن بقاء البطاقة المرفوضة مرئية مع أسباب السياسة.
5. **Validated copy only:** في بطاقة `GUIDANCE_VALIDATED` فقط، تحقق من ظهور زر نسخ لنص `guidance_lines[]` الخلفي. يجب ألا يظهر زر نسخ للوصف أو التعليل أو النتائج أو أي بطاقة أخرى.
6. **Uncertainty / identity limits:** تحقق من ظهور `identity_limits` و`uncertainties` و`missing_evidence` و`verification.reasons` وأسباب الرفض، ومن ظهور `runtime_domain` و`event_transport` كما وردا.
7. **Tool decisions separation:** تحقق من ظهور قسم "Read-only inspection decisions" منفصلاً، وأن `TOOL_REQUEST_ALLOWED` لا يظهر كحالة إرشاد أو كإصلاح معتمد.
8. **Log domains:** تحقق من ظهور وسم `domain` على سجلات الإقلاع عندما يوفره الخادم، ومن بقاء النص الظاهر `MODEL INTERPRETATION — NOT VERIFIED` منفصلاً عن `OBSERVED LOGS`، ومن أن نص السجل المعروض غير قابل للتحديد أو النسخ.
9. **Spike analysis:** أنشئ/حاكِ حدث spike. تحقق من ظهور `ANALYSIS_UNVERIFIED` في الرأس حتى وهو مطوي، ومن عنوان "Model-suggested considerations — unverified"، ومن عدم وجود نسخ أو تنفيذ.
10. **Failure/absence:** رد جديد بلا `validation` يجب أن يظهر `STATUS_ABSENT` وغير قابل للنسخ؛ لا تعرض الواجهة `VERIFIED` تلقائياً.

---

## 11. المرحلة 6 — Regression hardening & release gate

**النطاق:** تحصين وإثبات بوابة الإصدار فقط. لم يُفعَّل مسار v2 افتراضياً، ولم تُضَف أي عملية كتابة/إصلاح تلقائي، وبقي مسار v1 كما هو خلف علمه. الملفات الجديدة: `scripts/python/ai/audit.py`، `scripts/python/ai/provider_limits.py`، `scripts/python/ai/agent/model_worker.py`، `docs/supported-runtime-matrix.md`، و`scripts/python/tests/test_phase6_release_hardening.py`.

### 11.1 ما أُضيف

- **Audit logging:** `AuditLogger` يكتب JSONL إلى `$XDG_STATE_HOME/nibrasshell/ai-diagnostics/audit.jsonl` (أو `NIBRAS_SHELL_AI_AUDIT_LOG`)، بحقول `ts/correlation_id/stage/outcome/reason_codes/redaction_counts/budget_usage/latency_ms` فقط. داخل `latency_ms.model_calls[]` يُسجَّل `payload_sha256` (بصمة SHA-256 للـ prompt/history المُنقّى) لإثبات تدقيق حِزمة المزوّد دون تخزين النص. لا نصوص حوادث أو أوامر أو أسرار؛ فشل الكتابة لا يفشل التشخيص. مراحل التسجيل: `collect`، `discover`، `orchestrate`، `validate`، `render`.
- **Measured latency:** كل نداء نموذج يُقاس حول supervisor 120s، وكل أداة تُقاس حول غلاف 5s. القيم تُضاف كحقول إضافية في `orchestrator.latency_ms` وفي سجل audit. لم تُخفَّض أي حدود بلا قياس حقيقي؛ تبقى PROPOSED حتى قياس مزوّد محلي فعلي.
- **Provider cancellation:** `LocalProvider` يستخدم الآن `(connect 5s, read 60s)` بدلاً من `1200s` المفردة، ويعيد `provider_error: TIMEOUT` في meta عند انتهاء المهلة (المسار v1 يتجاهل meta ويحتفظ بشكل النص القديم). OpenAI/OpenRouter يمرران `timeout=120s` حيث تسمح حزمة SDK المثبتة؛ Gemini/Ollama بلا ربط timeout أصلي مُتحقَّق. نداء المزوّد نفسه يُنفَّذ في **worker child** قابل للإلغاء (`agent/model_worker.py`)؛ عند 120s يرسل الـ supervisor SIGTERM ثم SIGKILL ويستعيد العملية، ولا يُترك thread daemonized. إذا تعذّر إنشاء `fork` يفشل التشخيص مغلقاً بـ `PROVIDER_ERROR` بدلاً من الرجوع إلى نداء غير قابل للإلغاء.
- **QML lifecycle:** `AiTask.qml` و`ResourceDiagnostics.qml` يملكان watchdog 310s، SIGTERM ثم SIGKILL بعد ثانية، وتسوية فشل مرة واحدة لتحرير الطابور/التبريد. دلالات Quickshell 0.3.1 الدقيقة غير موثقة داخلياً؛ لذلك التنفيذ best-effort مع فشل مغلق، والتحقق اليدوي أدناه.
- **Privacy:** `redact_environment()` يرفض أي allowlist غير فارغ في R1 ويعيد `{}` لأي env؛ لا يوجد قراءة `/proc/<pid>/environ` في كود الإنتاج؛ سجل audit لا يقبل نصوصاً حرة. سجل AiTask لم يعد يطبع الظرف الخام، بل عدد البايتات فقط.
- **Supported runtime:** المصفوفة الكاملة في `docs/supported-runtime-matrix.md`، وتشمل checklist الصلاحيات/السياق، مراجعة إلغاء المزوّد، ومراجعة دورة حياة QML.

### 11.2 Manual checklist (Phase 6)

1. **Audit path:** شغّل مسار v2 مع `NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE=1` ومزوّد محلي. تحقق من إنشاء `~/.local/state/nibrasshell/ai-diagnostics/audit.jsonl` (أو مسار XDG)، ومن أن كل سطر JSON صالح، وأنه لا يحتوي نص حادثة أو أمراً أو مفتاح API. جرّب `NIBRAS_SHELL_AI_AUDIT_DISABLED=1` للتأكد من تعطيل الكتابة.
2. **No state changes:** راقب العملية أثناء حادثة container/unit. يجب ألا يظهر أي `sudo`، `dnf/apt/pacman`، `systemctl start/stop/restart/enable`، `podman create/run/rm/update`، أو shell تنفيذي. الأدوات المسموحة قراءة فقط: `journalctl`، `systemctl show`، `podman inspect/info`.
3. **Provider timeout:** وجّه المزوّد إلى endpoint بطيء/متوقف. يجب أن ينتهي الطلب بحالة فشل آمنة (`MODEL_TIMEOUT`/`PROVIDER_ERROR`) عند حد 120s، مع `no_action_taken: true`، ودون retry إضافي. تحقق من ملاحظة `worker child terminated` ومن عدم بقاء عملية الـ provider؛ اختبار `test_worker_child_is_hard_cancelled` يغطي ذلك آلياً.
4. **QML child watchdog:** باستخدام harness محلي أو أمر يحاكي طفلاً لا ينتهي، تحقق من أن `AiTask` يطلق `failed` بعد 310s، وأن العملية تُستهدف بـ SIGTERM ثم SIGKILL، وأن طلب AI التالي يعمل بعد انتهاء `requestCooldownMs`. لا تشغّل هذا الاختبار ضد مزوّد حقيقي أو حادثة إنتاج.
5. **ResourceDiagnostics watchdog:** كرر الفحص على `ResourceDiagnostics`؛ يجب أن يعود الطلب الافتراضي المحدود وتُستأنف قائمة الانتظار بدل التعليق.
6. **Privacy spot-check:** افحص `journalctl --output=json` وحادثة تحتوي `password=...`/token. تحقق من غياب القيمة الأصلية من prompt/model/tool result/audit/QML copy، ومن ظهور عدّاد redaction فقط.
7. **Latency calibration:** نفّذ خمس حوادث تمثيلية على المزوّد المحلي، ثم اقرأ `latency_ms` و`budget_usage` من audit. لا تغيّر 120/300/310s اعتماداً على قياس اصطناعي؛ وثّق p50/p95 قبل أي معايرة.
   - **Status (2026-11-06): BLOCKED.** لا يوجد endpoint محلي قابل للوصول في بيئة التحقق (`127.0.0.1:8080` و`:11434` و`:8000` و`:1234` مغلقة)، لذا تبقى الثوابت **PROPOSED** ولا تُدَّعى معايرة تجريبية.

### 11.3 بوابة القبول

- `python3 -m unittest discover -s scripts/python/tests -p 'test_phase*.py' -v` — يجب أن تنجح كل اختبارات المراحل 0–6.
- `scripts/python/tests/test_phase6_release_hardening.py` يثبت: audit metadata/path/fail-open، latency/budget instrumentation، privacy source contracts، `docs/supported-runtime-matrix.md`، QML watchdog source contracts، provider worker source contract، typed local timeout meta، وعدم وجود tool/action يغيّر الحالة.
- `scripts/python/tests/test_phase3_orchestrator.py::TestOrchestratorSupervision` يثبت: hard cancel للـ worker child عند المهلة (`test_worker_child_is_hard_cancelled`)، وإعادة استرجاعه بعد النجاح (`test_worker_child_reaped_after_success`)، وتحويل meta/exception إلى `MODEL_TIMEOUT`/`PROVIDER_ERROR`، وفشل مغلق عند تعذّر `fork`.
- AC #1–#17 mapped to tests/manual checks in `docs/supported-runtime-matrix.md` §8.
- **Calibration gate:** يبقى `BLOCKED` حتى يتوفر local provider endpoint حقيقي؛ لا تُغيَّر الثوابت PROPOSED بناءً على الاختبارات الاصطناعية.
- **صفر سلوك تلقائي يغيّر الحالة في R1:** لا أداة كتابة، ولا action_kind تنفيذي، ولا أمر يُشتق من نص النموذج؛ كل النتائج التشغيلية إما قراءة أو إرشاد خلفي declarative.


