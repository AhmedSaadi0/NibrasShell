const themeSelect = document.getElementById("themeSelect");
const langSelect = document.getElementById("langSelect");
const navToggle = document.getElementById("navToggle");
const navRoot = document.getElementById("navRoot");
const heroImage = document.getElementById("heroImage");

const translations = {
  ar: {
    // --- العلامة التجارية والقائمة (Global) ---
    page_title: "نِبراس شِل - واجهة مدمجة بالذكاء الاصطناعي",
    brand_name: "نِبراس شِل",
    brand_tagline: "واجهة مدمجة بالذكاء الاصطناعي",
    nav_home: "الرئيسية",
    nav_docs: "الوثائق",
    nav_roadmap: "خارطة الطريق",
    nav_menu: "فتح القائمة",

    // --- الصفحة الرئيسية: الهيرو (Hero) ---
    hero_badge: "واجهة مدمجة بالذكاء الاصطناعي",
    hero_title: "تجربة سطح مكتب حديثة، ذكية، ومتكاملة",
    hero_desc:
      "واجهة تركّز على أفضل ما في التجربة: شريط علوي ذكي، كبسولة تفاعلية، وثيمات مصممة بعناية.",
    cta_docs: "اقرأ الوثائق",
    cta_github: "المستودع",
    stat_themes: "ثيمات جاهزة",
    stat_modules: "وحدات رئيسية",
    stat_live: "مراقبة حيّة",
    signal_1: "واجهة متجددة باستمرار",
    signal_2: "ذكاء مدمج في تفاصيل التجربة",
    signal_3: "تخصيص عميق بضغطة واحدة",
    ai_providers_note:
      "يدعم عدة مزودين للذكاء الاصطناعي، بما فيها مزود محلي عبر:",

    // --- الصفحة الرئيسية: لماذا والأدوات ---
    why_title: "لماذا نبراس شِل؟",
    tools_title: "هي هواية، ليس إلا",
    tools_sub:
      "كل سطر كود في هذه الأدوات كُتب من أجل المتعة الشخصية وحب الاستكشاف، دون أي أهداف أخرى.",

    tool_settings_title: "تطبيق إعدادات مدمج وشامل",
    tool_settings_desc:
      "لا حاجة لتعديل ملفات التكوين يدوياً. تطبيق الإعدادات المدمج يمنحك السيطرة الكاملة على الألوان، الثيمات، الخلفيات، وحتى اختيار نماذج الذكاء الاصطناعي المفضلة لديك.",
    tool_settings_li1: "تعديل الثيمات والألوان لحظياً.",
    tool_settings_li2: "إدارة نماذج AI وتخصيصها.",

    tool_launcher_title: "مشغل تطبيقات ذكي ومتصل",
    tool_launcher_desc:
      "أكثر من مجرد قائمة تطبيقات. يوفر لك وضع الأوامر المتطور وخاصية جلب الخلفيات مباشرة.",
    tool_launcher_li1: "استخدم الرمز > للوصول لأوامر النظام السريعة.",
    tool_launcher_li2: "تكامل مع Wallhaven لجلب وتغيير الخلفيات مباشرة.",
    tool_network_title: "إدارة الشبكة الكاملة ومراقبة الاستهلاك",
    tool_network_desc:
      "تحكم كامل بالشبكة من مكان واحد، مع مراقبة مباشرة لاستهلاك البيانات لكل تطبيق وتوثيق الحركة داخل سجل تاريخي واضح.",
    tool_network_li1: "عرض الاستهلاك الفوري على مستوى كل تطبيق.",
    tool_network_li2: "تسجيل الحركة في تبويب History للرجوع إليها لاحقًا.",

    // --- الصفحة الرئيسية: المميزات (Bento) ---
    why_1_title: "واجهة ذكية",
    why_1_desc:
      "كبسولة ذكية تتفاعل مع المستخدم عبر الهوفر، وتعرض رسائل الذكاء الاصطناعي مع ملخصات الطقس والموسيقى.",
    smart_preview_label: "معاينة الكبسولة الذكية",
    why_2_title: "تخصيص عميق",
    why_2_desc: "تحكم شامل بالألوان والخطوط والخلفيات وأسلوب القوائم.",
    why_3_title: "خدمات متكاملة",
    why_3_desc: "مراقبة النظام، إشعارات ذكية، شبكة، حافظة، ومركز إعدادات كامل.",

    // --- الصفحة الرئيسية: المعرض والقيم ---
    shots_title: "لقطات من الواجهة",
    shots_desc: "صور قليلة تبيّن الجو العام للواجهة والثيمات.",

    // --- Lightbox ---
    lightbox_close: "إغلاق",
    lightbox_prev: "السابق",
    lightbox_next: "التالي",

    quick_value_title: "ما الذي يميز الواجهة بسرعة؟",
    quick_value_desc: "نظرة مختصرة على أهم نقاط القوة العملية للمستخدم اليومي.",
    quick_value_1_title: "أداء متوازن",
    quick_value_1_desc:
      "واجهة خفيفة نسبيًا مع تنظيم واضح للعناصر المهمة بدون فوضى.",
    quick_value_2_title: "وصول أسرع",
    quick_value_2_desc:
      "الإعدادات، التطبيقات، والإشعارات في أماكن ثابتة وسهلة الوصول.",
    quick_value_3_title: "ذكاء مفيد",
    quick_value_3_desc:
      "تحليلات وتلميحات ذكية تركز على المعلومات التي تهمك فعلاً.",

    // --- صفحة خارطة الطريق (Roadmap) - العناوين ---
    roadmap_title: "خارطة الطريق",
    roadmap_sub:
      "نبراس شِل هو نتاج هوايتي المستمرة. إليك ما أعمل عليه الآن وما أطمح لتحقيقه في المستقبل.",
    roadmap_ai_title: "الذكاء الاصطناعي والكبسولة الذكية",
    roadmap_desktop_title: "تخطيط سطح المكتب والشل",
    roadmap_ui_title: "الواجهة والثيمات",
    roadmap_sys_title: "الإنتاجية والنظام",
    roadmap_archive_title: "ما تم إنجازه (أرشيف الإصدارات السابقة)",

    // --- خارطة الطريق - القوائم التفصيلية ---
    rd_ai_phases: "الجزء 1: خارطة العقل (الذكاء المدمج)",
    rd_ai_li1: "المرحلة 1: المراقبة والتسجيل (تحليل السجلات)",
    rd_ai_li2: "المرحلة 2: التشخيص (المودل يحدد الأخطاء بدقة)",
    rd_ai_li3: "المرحلة 3: المحادثة السياقية حول المشكلة",
    rd_ai_li4: "المرحلة 4: اقتراح الحلول البرمجية",
    rd_ai_li5: "المرحلة 5: التنفيذ الذاتي (المعالجة الذاتية - تجريبي)",

    rd_capsule_features: "الجزء 2: ميزات الجسد (الكبسولة)",
    rd_cap_li1: "ردود فعل النظام: فكاهة عند ضغط المعالج/الذاكرة",
    rd_cap_li2: "ألوان الكبسولة: إعدادات ألوان مستقلة",
    rd_cap_li3: "ساعة تقريبية (Fuzzy Clock) متصلة بالذكاء",
    rd_cap_li4: "ملخص الحافظة الذكي (Clipboard AI)",

    rd_ai_ui_control: "الجزء 3: التحكم بالواجهة",
    rd_ai_ui_li1: "التحكم بالالوان وتغييرها",
    rd_ai_ui_li2: "اضافة ثيمات جديدة مخصصة",
    rd_ai_ui_li3: "التحكم بثيمات بلازما",
    rd_ai_ui_li4: "التحكم بثيمات GTK",

    rd_desktop_bars: "الأشرطة والدك (Bars & Dock)",
    rd_desk_li1: "تغيير مواقع الأشرطة (علوي، سفلي، جانبي)",
    rd_desk_li2: "الإخفاء التلقائي للأشرطة",
    rd_desk_li3: "إضافة شريط تطبيقات سفلي مستقل (Dock)",
    rd_desk_li4: "التكيف الذكي للـ Dock عند تغيير موقع الشريط",
    rd_desk_li5: "تحسين تكامل أدوات التحكم في Hyprland",
    rd_desk_li6: "عرض مساحة التخزين في القائمة الجانبية اليسرى (Left Menu)",

    rd_desktop_workspaces: "مساحات العمل (Workspaces)",
    rd_ws_li1: "أيقونات ديناميكية بدلاً من الأرقام",
    rd_ws_li2: "سحب وإفلات الأيقونات لنقل التطبيقات",
    rd_ws_li3: "واجهة مرئية (Overview) لاستعراض مساحات العمل",
    rd_ws_li4: "النقر على الأيقونة للتركيز والانتقال للمساحة",

    rd_ui_li1: "تحسين هيكلية ThemeManager",
    rd_ui_li2: "دعم خلفيات GIF و Video",
    rd_ui_li3: "ضبط متغيرات Material 3 الديناميكية",
    rd_ui_li4: "وضع الألعاب (Game Mode) للأداء العالي",
    rd_ui_li5: "تأثير العمق التلقائي وربطه بـ Cava",
    rd_ui_li6: "ثيمات جديدة: Solarized, Rosé Pine, Oxocarbon",
    rd_ui_li7: "تحسين حركات سطح المكتب والمزامنة مع Quickshell",
    rd_ui_li8: "دعم سمات المؤشر (Plasma, GTK, Hyprland)",
    rd_ui_li9: "الكشف الديناميكي لأنماط Qt عبر PyQt6",
    rd_ui_li10: "مكونات واجهة قابلة لإعادة الاستخدام (SectionCard/FieldLabel)",

    rd_sys_li1: "مؤشر اللغة، البطارية، وأوضع الطاقة",
    rd_sys_li2: "مدير الحافظة وقائمة المهام",
    rd_sys_li3: "ودجت الملاحظات السريعة",
    rd_sys_li4: "قائمة التطبيقات المفضلة",
    rd_sys_li5: "مواقيت الصلاة والتاريخ الهجري",
    rd_sys_li6: "مدير البلوتوث وإعدادات الشاشة الكاملة",
    rd_sys_li7: "تحسين الكود: الانتقال إلى نظام EventBus",
    rd_sys_li8:
      "مراقبة تفصيلية للشبكة، تتضمن رصد حركة التطبيقات لحظياً وتوثيق استهلاكها للبيانات",
    rd_sys_li9: "التحكم بالشاشات (Monitors) في تطبيق الإعدادات",
    rd_sys_li10: "مراقبة استخدام GPU و VRAM",

    // --- صفحة الوثائق (Docs) ---
    docs_sidebar_title: "دليل الوثائق",
    docs_sidebar_overview: "نظرة عامة",
    docs_sidebar_install: "التثبيت الكامل",
    docs_sidebar_dev: "توثيق التطوير",
    docs_sidebar_keys: "اختصارات لوحة المفاتيح",
    docs_overview_title: "الوثائق",
    docs_overview_desc:
      "اختر القسم المناسب من الشريط الجانبي للوصول إلى شرح التثبيت أو توثيق التطوير.",
    docs_overview_install_title: "التثبيت الكامل",
    docs_overview_install_desc:
      "خطوات تلقائية ويدوية مفصلة مع أمثلة للتوزيعات.",
    docs_overview_install_btn: "افتح التثبيت",
    docs_overview_dev_title: "توثيق التطوير",
    docs_overview_dev_desc: "المعمارية، الخدمات، محركات النظام، والذكاء الاصطناعي.",
    docs_overview_dev_btn: "افتح التوثيق ←",
    docs_overview_keys_title: "اختصارات لوحة المفاتيح",
    docs_overview_keys_desc:
      "كل اختصارات Hyprland و Quickshell مصنّفة في جداول واضحة.",
    docs_overview_keys_btn: "افتح الاختصارات ←",

    docs_structure_title: "ماذا تجد في هذه الوثائق؟",
    docs_structure_install_title: "📦 التثبيت",
    docs_structure_install_li1: "طريقة تلقائية (موصى بها)",
    docs_structure_install_li2: "تثبيت يدوي مع البرامج الضرورية",
    docs_structure_install_li3: "أوامر Arch و Fedora",
    docs_structure_install_li4: "إعداد Python venv لتأثير العمق",
    docs_structure_dev_title: "🔧 التطوير",
    docs_structure_dev_li1: "المعمارية العامة وأنماط التصميم",
    docs_structure_dev_li2: "محرك الثيمات والتكامل مع النظام",
    docs_structure_dev_li3: "نظام الذكاء الاصطناعي والتحليل",
    docs_structure_dev_li4: "الخدمات، الأحداث، والسكربتات",
    docs_structure_keys_title: "⌨️ الاختصارات",
    docs_structure_keys_li1: "تحكم بالنوافذ، الصوت، الوسائط، السطوع",
    docs_structure_keys_li2: "تشغيل التطبيقات وقوائم Quickshell",
    docs_structure_keys_li3: "مساحات العمل، الشاشات، الفأرة",
    docs_structure_keys_li4: "جميع الاختصارات من binding.conf",

    // --- صفحة الاختصارات (Keys) ---
    keys_title: "اختصارات لوحة المفاتيح",
    keys_subtitle: "جميع اختصارات Hyprland و Quickshell المعرَّفة في <code>~/.config/hypr/binding.conf</code>. المفتاح الرئيسي (Modifier) هو <code>SUPER</code> (يُعرف أيضاً بـ Windows key).",
    keys_mod_note: "<strong>ملاحظة:</strong> الاختصارات التالية تستعمل <code>SUPER</code> كمفتاح رئيسي ما لم يُذكر غير ذلك. الاختصارات المعلَّقة في ملف الإعدادات (<code>#</code>) غير ظاهرة هنا.",
    keys_col_combo: "الاختصار",
    keys_col_action: "الإجراء",
    keys_window_control: "1. التحكم بالنوافذ",
    keys_audio: "2. الصوت",
    keys_media: "3. الوسائط",
    keys_media_desc: "مفاتيح التحكم بالوسائط تستدعي إجراءات Quickshell لإدارة المشغل (MPRIS).",
    keys_brightness: "4. السطوع",
    keys_apps: "5. التطبيقات",
    keys_apps_note: "<strong>(*) تعارض:</strong> الاختصار <code>SUPER+SHIFT+B</code> مُعرَّف مرتين في <code>binding.conf</code> (Microsoft Edge و Brave) — الأخير هو الفعلي عند التحميل. يُنصح بحذف أحدهما.",
    keys_screenshot: "6. لقطات الشاشة",
    keys_menus: "7. قوائم Quickshell (الشريط الجانبي)",
    keys_menus_desc: "تتحكم بقوائم الواجهة الجانبية (LeftBar) عبر استدعاءات IPC من Hyprland إلى Quickshell.",
    keys_focus: "8. التركيز بين النوافذ",
    keys_monitors: "9. الشاشات",
    keys_window_move: "10. تحريك النوافذ",
    keys_split_ratio: "11. نسبة التقسيم",
    keys_workspaces: "12. مساحات العمل",
    keys_ws_move_title: "نقل النافذة إلى مساحة عمل",
    keys_minimize: "13. التصغير",
    keys_mouse: "14. الفأرة، الطبقات، وتعليق النظام",
    keys_kvm_note: "<strong>مفتاح KVM:</strong> <code>bindl=,switch:on:[switch name],exec,hyprctl keyword monitor \"HDMI-1-0,1920x1080@144,1600x0,1\"</code> — ينفّذ عند تفعيل المفتاح الفعلي المُسمَّى <code>switch name</code> على لوحة المفاتيح.",
    // Keybinding actions
    key_act_kill: "إغلاق التطبيق المُركَّز",
    key_act_fullscreen: "تبديل وضع ملء الشاشة",
    key_act_floating: "تبديل النافذة العائمة",
    key_act_split: "تبديل التقسيم (dwindle)",
    key_act_pin: "تثبيت النافذة (دائماً فوق)",
    key_act_mute: "كتم / إلغاء كتم الصوت",
    key_act_micmute: "كتم / إلغاء كتم الميكروفون",
    key_act_volup: "رفع الصوت (+5%)",
    key_act_voldown: "خفض الصوت (-5%)",
    key_act_playpause: "تشغيل / إيقاف مؤقت",
    key_act_next: "المسار التالي",
    key_act_prev: "المسار السابق",
    key_act_stop: "إيقاف التشغيل",
    key_act_brightup: "رفع السطوع",
    key_act_brightdown: "خفض السطوع",
    key_app_konsole: "فتح Konsole (الطرفية)",
    key_app_konsole_t: "فتح Konsole (اختصار بديل)",
    key_app_android: "فتح Android Studio",
    key_app_browser_conflict: "فتح Microsoft Edge <small style=\"color:var(--accent-3);\">(*)</small>",
    key_app_vscode: "فتح VS Code",
    key_app_hopofy: "تشغيل سكربت Hopofy",
    key_app_discord: "فتح Discord",
    key_app_dolphin: "فتح Dolphin (مدير الملفات)",
    key_app_firefox: "فتح Firefox",
    key_app_sysmon: "فتح System Monitor (مراقب النظام)",
    key_app_mission: "فتح Mission Center",
    key_app_settings: "فتح إعدادات النظام",
    key_app_telegram: "فتح Telegram",
    key_app_pcsx2: "فتح PCSX2 (محاكي PlayStation 2)",
    key_app_strawberry: "فتح Strawberry (مشغل الموسيقى)",
    key_app_easyeffects: "فتح EasyEffects (معادل الصوت)",
    key_app_hyprpicker: "فتح Hyprpicker (ملتقط الألوان)",
    key_act_shot_region: "التقاط منطقة محددة من الشاشة",
    key_menu_dashboard: "تبديل قائمة لوحة المعلومات (Dashboard)",
    key_menu_notif: "تبديل قائمة الإشعارات",
    key_menu_weather: "تبديل قائمة الطقس",
    key_menu_monitors: "تبديل قائمة مراقبة النظام",
    key_menu_network: "تبديل قائمة الشبكة",
    key_menu_clipboard: "تبديل قائمة الحافظة",
    key_menu_todo: "تبديل قائمة المهام (Todo)",
    key_menu_ai: "تبديل قائمة روبوتات الذكاء الاصطناعي",
    key_menu_power: "خيارات الطاقة (إيقاف، إعادة تشغيل، تعليق...)",
    key_menu_launcher: "إظهار مشغّل التطبيقات",
    key_menu_nsettings: "فتح إعدادات NibrasShell",
    key_menu_cheatsheet: "فتح ورقة الاختصارات (Cheatsheet)",
    key_menu_media: "إظهار كبسولة مشغل الوسائط",
    key_menu_weather_island: "إظهار كبسولة الطقس",
    key_menu_clipboard2: "تبديل قائمة الحافظة (اختصار بديل)",
    key_focus_l: "نقل التركيز يساراً",
    key_focus_r: "نقل التركيز يميناً",
    key_focus_u: "نقل التركيز للأعلى",
    key_focus_d: "نقل التركيز للأسفل",
    key_mon_focus1: "التركيز على الشاشة 1",
    key_mon_focus2: "التركيز على الشاشة 2",
    key_mon_move1: "نقل مساحة العمل الحالية إلى الشاشة 1",
    key_mon_move2: "نقل مساحة العمل الحالية إلى الشاشة 2",
    key_mon_reload: "إعادة تحميل المُحرِّك الرسومي (forcerendererreload)",
    key_wmove_l: "نقل النافذة يساراً",
    key_wmove_r: "نقل النافذة يميناً",
    key_wmove_u: "نقل النافذة للأعلى",
    key_wmove_d: "نقل النافذة للأسفل",
    key_split_dec: "تقليل نسبة التقسيم (-0.1)",
    key_split_inc: "زيادة نسبة التقسيم (+0.1)",
    key_ws_prev: "الذهاب إلى مساحة العمل السابقة",
    key_ws_special: "تبديل مساحة العمل الخاصة (Special)",
    key_ws_go1: "الانتقال لمساحة العمل 1",
    key_ws_go2: "الانتقال لمساحة العمل 2",
    key_ws_go3: "الانتقال لمساحة العمل 3",
    key_ws_go4: "الانتقال لمساحة العمل 4",
    key_ws_go5: "الانتقال لمساحة العمل 5",
    key_ws_go6: "الانتقال لمساحة العمل 6",
    key_ws_go7: "الانتقال لمساحة العمل 7",
    key_ws_go8: "الانتقال لمساحة العمل 8",
    key_ws_go9: "الانتقال لمساحة العمل 9",
    key_ws_go10: "الانتقال لمساحة العمل 10",
    key_wsmove_1: "نقل النافذة إلى مساحة العمل 1",
    key_wsmove_2: "نقل النافذة إلى مساحة العمل 2",
    key_wsmove_3: "نقل النافذة إلى مساحة العمل 3",
    key_wsmove_4: "نقل النافذة إلى مساحة العمل 4",
    key_wsmove_5: "نقل النافذة إلى مساحة العمل 5",
    key_wsmove_6: "نقل النافذة إلى مساحة العمل 6",
    key_wsmove_7: "نقل النافذة إلى مساحة العمل 7",
    key_wsmove_8: "نقل النافذة إلى مساحة العمل 8",
    key_wsmove_9: "نقل النافذة إلى مساحة العمل 9",
    key_wsmove_10: "نقل النافذة إلى مساحة العمل 10",
    key_act_minimize: "تصغير النافذة الحالية",
    key_act_min_restored: "استرجاع النوافذ المُصغَّرة",
    key_scroll_next: "مساحة العمل التالية",
    key_scroll_prev: "مساحة العمل السابقة",
    key_mouse_move: "نقل النافذة بالسحب",
    key_mouse_resize: "تغيير حجم النافذة بالسحب",
    key_layer_bottom: "إرسال النافذة المُركَّزة إلى الطبقة السفلية",
    key_act_suspend: "تعليق النظام (systemctl suspend)",
    key_act_kvm: "تفعيل تهيئة شاشة HDMI-1-0 (مفتاح KVM مادي)",

    // --- صفحة التثبيت (Install) ---
    install_title: "التثبيت",
    install_subtitle: "طريقتان لتثبيت NibrasShell على نظامك",
    install_auto_title: "الطريقة التلقائية",
    install_auto_desc:
      "قم باستنساخ المستودع، ثم قم بتشغيل السكربت التالي الذي سيهتم بكل شيء، بما في ذلك إنشاء ملف الإعدادات",

    install_manual_title: "التثبيت اليدوي",
    install_manual_toggle: "التثبيت اليدوي (اضغط للفتح)",
    install_manual_deps: "برامج ضرورية",
    install_manual_optional: "برامج اختيارية",
    install_arch_title: "تثبيت البرامج لمستخدمي Arch:",
    install_fedora_title: "مستخدمي Fedora",
    install_void_title: "مستخدمي Void",
    install_other_distros:
      "<strong>ملاحظة:</strong> إذا كنت تستخدم نظام تشغيل آخر غير أرش او فيدورا او فويد فسوف تحتاج إلى تثبيت جميع البرامج الضرورية. قد تختلف الخطوات بناءً على نوع توزيعتك.",
    tag_recommended: "موصى به",
    tag_required: "إلزامي",
    tag_optional: "اختياري",

    install_depth_effect: "متطلبات تأثير العمق للساعة في سطح المكتب",
    install_depth_desc:
      "نحتاج مكتبه rembg و pillow لانشاء الصور ذات تاثير العمق",
    install_script_step: "الآن يمكنك استخدام سكربت التثبيت واختيار رقم 2",
    install_script_step_2: `
$ cd nibras_installer
$ python main.py
Choose your language / اختر لغتك / Vyberte jazyk:
1. English
2. العربية
3. Česky
> 2

=============================================
سكربت تثبيت NibrasShell
=============================================
1. تثبيت المتطلبات
2. تثبيت الواجهة
3. تحديث QuickShell
4. حذف الواجهة
5. إنشاء/تعديل ملف الإعدادات
6. خروج
اختر أحد الخيارات: 2
...`,
    install_manual_files:
      "في حال لم يعمل السكربت الآن اكمل مع التثبيت اليدوي لتهيئة الملفات:",
    install_manual_files_note: "في حال لم يعمل السكربت، اكمل مع التثبيت اليدوي أدناه",
    step_clone_repo: "استنساخ المستودع",
    step_backup_configs: "Backup الملفات الحالية",
    step_copy_configs: "نسخ ملفات الإعدادات",
    step_permissions: "صلاحيات التنفيذ",
    step_easyeffects: "إعداد EasyEffects",
    step_copy_themes: "نسخ الثيمات",
    step_copy_fonts: "نسخ الخطوط",
    step_extract_icons: "استخراج الأيقونات",
    install_final_note:
      "بإمكانك تغيير خط الجهاز إلى 'JF Flat' وتخصيص الواجهة من خلال الإعدادات المتقدمة (win+s).",

    // --- صفحة المطورين (Dev Docs) ---
    dev_title: "وثائق المطورين",
    dev_sub:
      "دليل شامل لفهم بنية المشروع، المعمارية، وكيفية المساهمة في التطوير.",
    dev_arch: "1. المعمارية العامة",
    dev_arch_desc:
      "نبراس شِل مبني على طبقات متدرجة، كل طبقة تخدم هدفاً محدداً:",
    dev_arch_patterns: "أنماط التصميم الأساسية",
    dev_pattern_1:
      "<strong>Singleton-heavy:</strong> الخدمات الأساسية تستخدم <code>pragma Singleton</code> للوصول العام.",
    dev_pattern_2:
      "<strong>EventBus pub/sub:</strong> التواصل بين المكونات عبر أحداث مسماة في <code>EventNames.js</code>.",
    dev_pattern_3:
      "<strong>Theme-reactive:</strong> كل مكونات UI مرتبطة بخصائص <code>ThemeManager.selectedTheme</code> فتتحدث تلقائياً.",
    dev_pattern_4:
      "<strong>Per-screen vs Global:</strong> الأشرطة تُنشأ لكل شاشة (<code>Variants</code>)، النوافذ المنبثقة نسخة واحدة.",
    dev_pattern_5:
      "<strong>Lazy loading:</strong> القوائم تُحمّل عند الطلب عبر <code>StackView</code> لتوفير الموارد.",
    dev_arch_1: "واجهة QML عبر Quickshell.",
    dev_arch_2: "Hyprland للتعامل مع النوافذ والشاشات والأحداث.",
    dev_arch_3: "خدمات خلفية في `config/quickshell/services`.",
    dev_arch_4:
      "سكربتات Python/Bash في `config/quickshell/scripts` و `scripts`.",
    dev_entry: "2. نقطة البداية",
    dev_entry_hint: "المكوّن الرئيسي في:",
    dev_entry_desc: "هذا الملف يجمع الطبقات الأساسية ويدير تسلسل الإقلاع:",
    dev_boot_1: "<strong>SplashScreen:</strong> شاشة بدء متحركة.",
    dev_boot_2:
      "<strong>ThemeManager.initialThemeReady:</strong> إشارة لبدء تحميل الواجهة.",
    dev_boot_3:
      "<strong>Loader (async):</strong> تحميل غير متزامن مع تأثير opacity.",
    dev_boot_4:
      "<strong>Variants:</strong> إنشاء نسخة لكل شاشة من Desktop, Topbar, LeftBar, SmartCapsule, Dock.",
    dev_ipc_title: "التحكم الخارجي (IPC)",
    dev_ipc_desc: "يمكن التحكم بالقائمة من سكربتات خارجية عبر:",
    dev_settings: "3. إدارة الإعدادات",
    dev_settings_1:
      "<strong>ConfigStore.qml:</strong> يقرأ/يكتب <code>~/.nibrasshell.json</code> عبر <code>FileView</code> مع مراقبة الملف.",
    dev_settings_2:
      "<strong>App.qml:</strong> يوحّد المسارات (assets, scripts, cache)، أوامر Python/Bash، وإعدادات AI.",
    dev_settings_3:
      "<strong>الكاش:</strong> <code>~/.cache/nibrasshell/</code> يحتوي theme.json و venv.",
    dev_settings_4:
      "<strong>EventBus.qml:</strong> نظام pub/sub مع <code>emit()</code>, <code>on()</code>, <code>off()</code>, <code>clearOwner()</code>.",
    dev_settings_5:
      "<strong>ConstValues.js:</strong> ثوابت القوائم (0-9)، حالات الكبسولة، أولوياتها.",
    dev_theme_engine: "4. محرك الثيمات",
    dev_theme_engine_desc: "نظام ثيمات متعدد الطبقات مع تكامل عميق مع النظام.",
    dev_theme_phases: "ThemeManager - 6 مراحل تحميل",
    dev_theme_phases_code: `1. Request        → طلب الثيم (من المستخدم أو افتراضي)
2. Cache check    → فحص ~/.cache/nibrasshell/theme.json
3. Loader instruct → توجيه ThemeLoader لتحميل QML
4. Object creation → إنشاء كائن الثيم
5. Cache hydration → ملء الخصائص من الكاش
6. System apply   → تطبيق الثيم على النظام (SystemBridge)`,
    dev_theme_basetheme: "BaseTheme - 100+ خاصية",
    dev_base_colors:
      "<strong>colors:</strong> M3 palette (primary, secondary, tertiary, surface, error, outline...)",
    dev_base_dimensions:
      "<strong>dimensions:</strong> radii, bar sizes, component sizes, M3 shape scale.",
    dev_base_typography: "<strong>typography:</strong> fonts, sizes.",
    dev_base_system:
      "<strong>systemSettings:</strong> Qt style, Kvantum, GTK, Plasma, Konsole, icons, cursor.",
    dev_base_hyprland:
      "<strong>hyprlandConfiguration:</strong> borders, gaps, layout, animations, blur, shadows.",
    dev_base_clock:
      "<strong>desktopClock:</strong> position, format, depth effect.",
    dev_theme_bridge: "SystemBridge - التكامل مع النظام",
    dev_bridge_desc: "يطبق الثيم على أدوات التوزيعات المختلفة:",
    dev_bridge_plasma:
      "<strong>Plasma:</strong> colorscheme, icons, font, cursor.",
    dev_bridge_gtk: "<strong>GTK3/4:</strong> theme, icons, font, cursor.",
    dev_bridge_kvantum: "<strong>Kvantum:</strong> Qt application styling.",
    dev_bridge_konsole: "<strong>Konsole:</strong> terminal profiles.",
    dev_bridge_hyprland:
      "<strong>Hyprland:</strong> borders, gaps, animations via config rewrite.",
    dev_theme_variants:
      "<strong>14 ثيم:</strong> Catppuccin, Colors, Deer, Dracula, Gruvbox, M3, Nord, TokyoNight (كل منها Dark + Light).",
    dev_themes: "إدارة الثيمات والخلفيات",
    dev_themes_1: "`ThemeManager.qml` مسؤول عن تحميل الثيمات وتطبيقها.",
    dev_themes_2:
      "`WallpaperController.qml` لإدارة الخلفيات الثابتة والديناميكية.",
    dev_themes_3: "`DepthEffectController.qml` لتوليد طبقات العمق.",
    dev_services: "5. الخدمات الأساسية",
    dev_services_desc: "الخدمات مقسمة إلى طبقات حسب الوظيفة:",
    dev_services_hardware: "Hardware Layer",
    dev_services_data: "Data Layer",
    dev_services_ai: "AI Layer",
    dev_services_analysis: "Analysis Layer",
    dev_services_ui: "UI Support",
    dev_services_facade: "System Facade",
    dev_actionresponses: "ActionResponses - رسائل تفاعلية",
    dev_services_th1: "الخدمة",
    dev_services_th2: "الدور",
    dev_svc_audio: "PipeWire volume/mute control",
    dev_svc_brightness: "DDC/CI (external) + brightnessctl (laptop)",
    dev_svc_hwstate: "Aggregator: volume, brightness, battery, keyboard layout",
    dev_svc_weather:
      "wttr.in API + AI analysis + smart polling + 8 alert signals",
    dev_svc_music:
      "MPRIS + AI commentary + history (20 tracks) + debounced analysis",
    dev_svc_network:
      "WiFi scan/connect + data usage (monthly/daily/live/history)",
    dev_svc_clipboard:
      "wl-paste watch + Python clipboard manager + smart model sync",
    dev_svc_todo:
      "Persistent JSON + AI prioritization + due tracking + notifications",
    dev_svc_aiservice:
      "Priority queue (0-2) + rate limiting (3s cooldown, 15s throttle) + JSON cleaning",
    dev_svc_aitask: "Individual process execution unit (spawned per request)",
    dev_svc_aianalysis:
      "Orchestrator: SystemService signals → SpikeDetector → EventStore",
    dev_svc_spike: "CPU/RAM/Temp spike detection + AI triggers (priority 2)",
    dev_svc_cooldown:
      "3-level cooldown (global 30s, per-process 30s, temp 5min)",
    dev_svc_eventstore: "In-memory event log (max 50) with AI results",
    dev_svc_diagnostics: "Normalized data collection for processes/temps",
    dev_svc_notif: "Notification server + DND + sound dispatch + auto-cleanup",
    dev_svc_overlay: "Fullscreen overlay (image preview mode)",
    dev_svc_icon:
      "Batch icon resolution + theme-aware caching + flicker prevention",
    dev_svc_actions:
      "Pre-generated AI messages (round-robin rotation per category)",
    dev_svc_system:
      "Aggregator: BootAnalyzer + HardwareState + ResourceMonitor + ActionResponses",
    dev_svc_resource:
      "CPU/RAM/Temp monitoring + episode-based alerting + hysteresis",
    dev_svc_resdiag:
      "On-demand process/temp diagnostics with request deduplication",
    dev_svc_boot: "AI-powered boot log analysis + solution suggestions",
    dev_services_row1: "مراقبة الموارد وتحليل الإقلاع وارتفاعات الأداء",
    dev_services_row2: "جلب الطقس والتحليل الذكي والتنبيهات",
    dev_services_row3: "تكامل MPRIS والتعليق الذكي",
    dev_services_row4: "إدارة الإشعارات ووضع عدم الإزعاج",
    dev_services_row5: "مراقبة الحافظة وإدارتها",
    dev_ai_system: "6. نظام الذكاء الاصطناعي",
    dev_ai_system_desc: "نظام AI متكامل مع طابور أولويات وحماية من الإغراق.",
    dev_ai_queue: "AiService - البوابة المركزية",
    dev_ai_pipeline: "Spike Detection Pipeline",
    dev_actions_1:
      "<strong>Categories:</strong> charging, discharging, cpu_alerts, ram_alerts, temp_alerts.",
    dev_actions_2:
      "<strong>Round-robin:</strong> كل تنبيه يعرض رسالة مختلفة من المصفوفة.",
    dev_actions_3:
      "<strong>Auto-fetch:</strong> يجلب الرسائل بعد 5 ثوانٍ من بدء التشغيل.",
    dev_capsule: "7. الكبسولة الذكية",
    dev_capsule_desc: "Widget مستوحى من Dynamic Island مع تعبيرات عين متحركة.",
    dev_bars_windows: "8. الأشرطة والنوافذ",
    dev_bars_title: "Bars (Layer Shell)",
    dev_bar_topbar:
      "<strong>Topbar:</strong> SystemTray | NetworkSpeed | ActiveWindow | Clock | Monitors",
    dev_bar_leftbar:
      "<strong>LeftBar:</strong> 10 icon buttons (Dashboard, Notifications, Weather, Monitoring, Network, Clipboard, Todo, AI, Apps, Power)",
    dev_windows_title: "Windows (Popup)",
    dev_win_left:
      "<strong>LeftWindowFull:</strong> StackView-based menu system (3 styles: FLOATING, DOCKED_FIXED_BAR, DOCKED_MOVING_BAR)",
    dev_win_launcher:
      "<strong>BottomLauncher:</strong> app launcher with command mode (<code>&gt;</code> prefix)",
    dev_win_dock: "<strong>Dock:</strong> pinned apps with auto-hide",
    dev_win_settings:
      "<strong>Settings:</strong> ApplicationWindow with General/Appearance/Monitors/Audio sections",
    dev_win_power:
      "<strong>PowerMenuWindow:</strong> shutdown/reboot/logout/suspend/lock",
    dev_win_cheatsheet:
      "<strong>Cheatsheet:</strong> keyboard shortcuts reference",
    dev_win_overlay: "<strong>OverlayWindow:</strong> fullscreen overlay layer",
    dev_event_system: "9. نظام الأحداث",
    dev_eventbus: "EventBus (pub/sub)",
    dev_eventbus_code: `EventBus:
  ├── emit(eventName, data)     → بث حدث
  ├── on(eventName, callback)   → اشتراك
  ├── off(eventName, callback)  → إلغاء اشتراك
  └── clearOwner(owner)         → تنظيف تلقائي عند تدمير الكائن`,
    dev_eventnames: "EventNames.js - أمثلة",
    dev_python_integration: "10. التكامل مع Python",
    dev_python_venv:
      "Python يعمل في بيئة معزولة: <code>~/.cache/nibrasshell/venv/bin/python</code>",
    dev_py_ai: "🤖 AI Scripts",
    dev_py_monitoring: "📊 Monitoring",
    dev_py_network: "🌐 Network",
    dev_py_theme: "🎨 Theme Integration",
    dev_py_wallpaper: "🖼️ Wallpaper/Depth",
    dev_py_utils: "🔧 Utilities",
    dev_scripts: "11. السكربتات المهمة",
    dev_python: "Python",
    dev_bash: "Bash",
    dev_py_mon:
      "monitoring: <code>system_monitor.py</code>, <code>system_diagnostics.py</code>",
    dev_py_wall:
      "wallpapers: <code>scan_wallpapers.py</code>, <code>dynamic-m3.py</code>",
    dev_py_depth: "depth: <code>create_depth_image_rembg.py</code>",
    dev_py_net:
      "network: <code>list_wifi.py</code>, <code>connect_wifi.py</code>, <code>data_usage.py</code>",
    dev_py_ai_script: "ai: <code>main.py</code>, <code>list-gemini.py</code>",
    dev_bash_internet: "<code>internet.sh</code> - فحص الاتصال",
    dev_bash_temp: "<code>temp.sh</code> - قراءة الحرارة",
    dev_bash_wall: "<code>get_wallpapers.sh</code> - جلب الخلفيات",
    dev_run: "12. التشغيل والتصحيح",
    dev_run_title: "تشغيل Quickshell",
    dev_run_desc: "السكربت يضبط log rules لتقليل الضوضاء:",
    dev_debug_title: "نصائح التصحيح",
    dev_debug_1:
      "<strong>اختبار AI:</strong> <code>AiAnalysisService.testHighCpu</code> / <code>testHighRam</code>",
    dev_debug_2:
      "<strong>فحص الأحداث:</strong> <code>EventStore.eventsModel</code> (آخر 50 حدث)",
    dev_debug_3:
      "<strong>كاش الثيم:</strong> <code>~/.cache/nibrasshell/theme.json</code>",
    dev_debug_4: "<strong>الإعدادات:</strong> <code>~/.nibrasshell.json</code>",
    dev_debug_5:
      "<strong>ملفات التشغيل:</strong> <code>~/.cache/nibrasshell/venv/</code>",
    dev_notes: "ملاحظات تطوير",
    dev_note_1:
      "الكبسولة الذكية في <code>config/quickshell/windows/smart_capsule</code>.",
    dev_note_2:
      "القائمة الجانبية في <code>config/quickshell/windows/leftwindow</code>.",
    dev_note_3: "الإعدادات في <code>config/quickshell/windows/settings</code>.",
    dev_note_4:
      "المكونات القابلة لإعادة الاستخدام في <code>components/</code>.",
    dev_note_5:
      "الأدوات المساعدة في <code>utils/Helper.qml</code> و <code>utils/helpers.js</code>.",
    donate_title: "دعم المشروع؟",
    donate_desc:
      "إذا كنت ترغب في دعمي مالياً، فشكراً لك! لكن الحمد لله وضعي المادي جيد. بدلاً من ذلك، أدعوك للتبرع لأهلنا في غزة، فهم في أمسّ الحاجة للدعم الآن.",
    donate_btn: "تبرع لغزة الآن 🇵🇸",
    org_medical: "إغاثة طبية للأطفال",
    org_general: "إغاثة عامة وطوارئ",
    org_food: "توفير الغذاء والوجبات",
    org_msf: "دعم الفرق الطبية",
    // --- Footer ---
    footer_pages: "NibrasShell Project © " + new Date().getFullYear(),
    tool_daemon_title: "رقيب نظام ذكي ومستقل (System Daemon)",
    tool_daemon_desc:
      'نبراس شِل لا يعرض لك الأرقام فقط، بل يمتلك "جهازاً عصبياً" يعمل في الخلفية. يقوم بمراقبة استهلاك المعالج، الذاكرة، والحرارة بصمت. وعند حدوث أي ضغط مفاجئ (Spike)، يقوم تلقائياً بالتقاط البرامج المسببة للمشكلة وتحليلها عبر الذكاء الاصطناعي لتشخيص العطل وإعطائك الحلول.',
    tool_daemon_li1:
      "تحليل جذري (Root-Cause Analysis) لاستهلاك الموارد والحرارة.",
    tool_daemon_li2: "نظام تنبيهات ذكي (Smart Cooldowns) يمنع الإزعاج المتكرر.",
    tool_daemon_li3: "طابور مهام (Queue System) يمنع تجميد النظام أثناء الفحص.",
  },

  en: {
    // --- Global ---
    page_title: "NibrasShell - AI Integrated Shell",
    brand_name: "NibrasShell",
    brand_tagline: "AI Integrated Shell",
    nav_home: "Home",
    nav_docs: "Docs",
    nav_roadmap: "Roadmap",
    nav_menu: "Open Menu",

    // --- Hero ---
    hero_badge: "AI Integrated Shell",
    hero_title: "A modern, smart, and complete desktop experience",
    hero_desc:
      "A focused UI that highlights the best: a smart top bar, an interactive capsule, and carefully crafted themes.",
    cta_docs: "Read Docs",
    cta_github: "Repository",
    stat_themes: "Ready themes",
    stat_modules: "Core modules",
    stat_live: "Live monitoring",
    signal_1: "Continuously evolving interface",
    signal_2: "Intelligence built into the experience",
    signal_3: "Deep customization in one click",
    ai_providers_note:
      "Supports multiple AI providers, including a local provider via:",

    // --- Why & Tools ---
    why_title: "Why NibrasShell?",
    tools_title: "It's just a hobby, nothing more",
    tools_sub:
      "Every line of code in these tools was written for personal enjoyment and the love of exploration, with no other goals.",

    tool_settings_title: "Comprehensive Built-in Settings",
    tool_settings_desc:
      "No need to edit config files manually. The built-in settings app gives you full control over colors, themes, wallpapers, and AI models.",
    tool_settings_li1: "Modify themes and colors instantly.",
    tool_settings_li2: "Manage and customize AI models.",

    tool_launcher_title: "Smart Connected Launcher",
    tool_launcher_desc:
      "More than just an app list. It offers an advanced command mode and direct wallpaper fetching.",
    tool_launcher_li1: "Use the > symbol for quick system commands.",
    tool_launcher_li2: "Wallhaven integration to fetch wallpapers directly.",
    tool_network_title: "Full Network Management and Usage Monitoring",
    tool_network_desc:
      "Manage networking from one place with live per-application data usage visibility and a clear historical activity log.",
    tool_network_li1: "Live data usage view for each running application.",
    tool_network_li2: "Traffic logging in the History tab for later review.",

    // --- Features (Bento) ---
    why_1_title: "Smart Interactions",
    why_1_desc:
      "A smart capsule that reacts to user hover and shows AI messages with weather and music summaries.",
    smart_preview_label: "Smart Capsule Preview",
    why_2_title: "Deep Customization",
    why_2_desc:
      "Full control over colors, fonts, wallpapers, and menu behavior.",
    why_3_title: "Integrated Services",
    why_3_desc:
      "System monitoring, smart notifications, network, clipboard, and a full settings hub.",

    // --- Shots & Value ---
    shots_title: "UI Highlights",
    shots_desc: "A few shots that capture the look and feel of the themes.",

    // --- Lightbox ---
    lightbox_close: "Close",
    lightbox_prev: "Previous",
    lightbox_next: "Next",

    quick_value_title: "Why this interface works",
    quick_value_desc:
      "A compact view of the most practical strengths for daily use.",
    quick_value_1_title: "Balanced performance",
    quick_value_1_desc:
      "Relatively lightweight UI with clear structure and less visual noise.",
    quick_value_2_title: "Faster access",
    quick_value_2_desc:
      "Settings, apps, and notifications stay in predictable, easy-to-reach places.",
    quick_value_3_title: "Useful intelligence",
    quick_value_3_desc:
      "Smart summaries and hints focused on the information that actually matters.",

    // --- Roadmap ---
    roadmap_title: "Roadmap",
    roadmap_sub:
      "NibrasShell is a product of my ongoing hobby. Here is what I am working on now and what I aim to achieve.",
    roadmap_ai_title: "AI & Smart Capsule",
    roadmap_desktop_title: "Desktop & Shell",
    roadmap_ui_title: "UI & Theming",
    roadmap_sys_title: "System & Productivity",
    roadmap_archive_title: "Completed (Archive)",

    // --- Roadmap List Items ---
    rd_ai_phases: "Part 1: The Brain Roadmap (AI Phases)",
    rd_ai_li1: "Phase 1: Observation & Logging (Log analysis)",
    rd_ai_li2: "Phase 2: Diagnosis (Model identifies errors)",
    rd_ai_li3: "Phase 3: Contextual Chat (Issue-based chat)",
    rd_ai_li4: "Phase 4: Solution Proposal (Suggesting fixes)",
    rd_ai_li5: "Phase 5: Autonomous Execution (Experimental)",

    rd_capsule_features: "Part 2: The Body Features (Capsule)",
    rd_cap_li1: "System Reactions: Humor/Reactions to CPU/RAM spikes",
    rd_cap_li2: "Capsule Colors: Independent color settings",
    rd_cap_li3: "Fuzzy Clock: AI-connected rough time logic",
    rd_cap_li4: "Clipboard AI: Summarizer for copied text",

    rd_ai_ui_control: "Part 3: UI Control",
    rd_ai_ui_li1: "Color Control & Change",
    rd_ai_ui_li2: "Add Custom Themes",
    rd_ai_ui_li3: "Plasma Theme Control",
    rd_ai_ui_li4: "GTK Theme Control",

    rd_desktop_bars: "Bars & Dock",
    rd_desk_li1: "Positioning: Move default bars (Top, Bottom, Side)",
    rd_desk_li2: "Auto-hide: Implement auto-hide for bars",
    rd_desk_li3: "Standalone Dock: Add a bottom application dock",
    rd_desk_li4: "Smart Adaptation: Dock auto-adjusts layout",
    rd_desk_li5: "Enhanced Hyprland controls integration",
    rd_desk_li6: "Show storage usage in the left menu",

    rd_desktop_workspaces: "Workspaces",
    rd_ws_li1: "Dynamic Icons: Show app icons instead of numbers",
    rd_ws_li2: "Drag-and-Drop: Move apps between workspaces",
    rd_ws_li3: "Visual Overview: New UI view for workspace previews",
    rd_ws_li4: "Click-to-Focus: Click app icon to focus window",

    rd_ui_li1: "Improve Themes: Restructure ThemeManager",
    rd_ui_li2: "GIF & Video Wallpapers support",
    rd_ui_li3: "Dynamic Coloring: Configure Material 3 variants",
    rd_ui_li4: "Game Mode: Toggle for high performance",
    rd_ui_li5: "Depth Effect: Auto-generation linked with Cava",
    rd_ui_li6: "New Themes: Solarized, Rosé Pine, Oxocarbon",
    rd_ui_li7: "Enhanced desktop animations & Quickshell sync",
    rd_ui_li8: "Cursor theme support (Plasma, GTK, Hyprland)",
    rd_ui_li9: "Dynamic Qt widget styles via PyQt6",
    rd_ui_li10: "Reusable UI components (SectionCard/FieldLabel)",

    rd_sys_li1: "Indicators: Language, Battery, Power Profiles",
    rd_sys_li2: "Clipboard Manager & Todo List",
    rd_sys_li3: "Widgets: Quick Notes",
    rd_sys_li4: "Favorite Apps List",
    rd_sys_li5: "Prayer Times & Hijri Date",
    rd_sys_li6: "Bluetooth Manager & Display Settings",
    rd_sys_li7: "Code Refactoring: Migration to EventBus",
    rd_sys_li8:
      "Detailed network monitoring, including real-time application traffic tracking and data usage logging",
    rd_sys_li9: "Monitor control (Displays) inside the Settings app",
    rd_sys_li10: "GPU usage & VRAM monitoring",

    // --- Docs ---
    docs_sidebar_title: "Docs Guide",
    docs_sidebar_overview: "Overview",
    docs_sidebar_install: "Full Install",
    docs_sidebar_dev: "Developer Docs",
    docs_sidebar_keys: "Keyboard Shortcuts",
    docs_overview_title: "Documentation",
    docs_overview_desc:
      "Pick a section from the sidebar to reach install steps or developer docs.",
    docs_overview_install_title: "Full Install",
    docs_overview_install_desc:
      "Automatic and manual steps with distro examples.",
    docs_overview_install_btn: "Open Install",
    docs_overview_dev_title: "Developer Docs",
    docs_overview_dev_desc: "Architecture, services, system engines, and AI.",
    docs_overview_dev_btn: "Open Docs ←",
    docs_overview_keys_title: "Keyboard Shortcuts",
    docs_overview_keys_desc:
      "All Hyprland and Quickshell keybindings organized in clean tables.",
    docs_overview_keys_btn: "Open Shortcuts ←",

    docs_structure_title: "What's in these docs?",
    docs_structure_install_title: "📦 Installation",
    docs_structure_install_li1: "Automatic method (recommended)",
    docs_structure_install_li2: "Manual install with dependencies",
    docs_structure_install_li3: "Arch & Fedora commands",
    docs_structure_install_li4: "Python venv setup for depth effect",
    docs_structure_dev_title: "🔧 Development",
    docs_structure_dev_li1: "Architecture & design patterns",
    docs_structure_dev_li2: "Theme engine & system integration",
    docs_structure_dev_li3: "AI system & analysis pipeline",
    docs_structure_dev_li4: "Services, events, and scripts",
    docs_structure_keys_title: "⌨️ Shortcuts",
    docs_structure_keys_li1: "Window, audio, media, brightness control",
    docs_structure_keys_li2: "Apps launcher and Quickshell menus",
    docs_structure_keys_li3: "Workspaces, monitors, mouse",
    docs_structure_keys_li4: "All bindings from binding.conf",

    // --- Keys page ---
    keys_title: "Keyboard Shortcuts",
    keys_subtitle: "All Hyprland and Quickshell keybindings defined in <code>~/.config/hypr/binding.conf</code>. The main modifier is <code>SUPER</code> (also known as the Windows key).",
    keys_mod_note: "<strong>Note:</strong> Shortcuts below use <code>SUPER</code> as the main modifier unless stated otherwise. Commented-out bindings (<code>#</code>) are not shown here.",
    keys_col_combo: "Shortcut",
    keys_col_action: "Action",
    keys_window_control: "1. Window Control",
    keys_audio: "2. Audio",
    keys_media: "3. Media",
    keys_media_desc: "Media keys call Quickshell actions to control the player (MPRIS).",
    keys_brightness: "4. Brightness",
    keys_apps: "5. Applications",
    keys_apps_note: "<strong>(*) Conflict:</strong> <code>SUPER+SHIFT+B</code> is defined twice in <code>binding.conf</code> (Microsoft Edge and Brave) — the latter wins at load. Consider removing one.",
    keys_screenshot: "6. Screenshots",
    keys_menus: "7. Quickshell Menus (LeftBar)",
    keys_menus_desc: "Toggle the side panel menus via Hyprland → Quickshell IPC calls.",
    keys_focus: "8. Focus",
    keys_monitors: "9. Monitors",
    keys_window_move: "10. Move Windows",
    keys_split_ratio: "11. Split Ratio",
    keys_workspaces: "12. Workspaces",
    keys_ws_move_title: "Move Window to Workspace",
    keys_minimize: "13. Minimize",
    keys_mouse: "14. Mouse, Layers & Suspend",
    keys_kvm_note: "<strong>KVM switch:</strong> <code>bindl=,switch:on:[switch name],exec,hyprctl keyword monitor \"HDMI-1-0,1920x1080@144,1600x0,1\"</code> — executes when the physical key named <code>switch name</code> is toggled on.",
    // Keybinding actions
    key_act_kill: "Kill the focused application",
    key_act_fullscreen: "Toggle fullscreen",
    key_act_floating: "Toggle floating",
    key_act_split: "Toggle split (dwindle)",
    key_act_pin: "Pin window (always on top)",
    key_act_mute: "Toggle mute",
    key_act_micmute: "Toggle microphone mute",
    key_act_volup: "Increase volume (+5%)",
    key_act_voldown: "Decrease volume (-5%)",
    key_act_playpause: "Play / Pause",
    key_act_next: "Next track",
    key_act_prev: "Previous track",
    key_act_stop: "Stop playback",
    key_act_brightup: "Increase brightness",
    key_act_brightdown: "Decrease brightness",
    key_app_konsole: "Open Konsole (terminal)",
    key_app_konsole_t: "Open Konsole (alt binding)",
    key_app_android: "Open Android Studio",
    key_app_browser_conflict: "Open Microsoft Edge <small style=\"color:var(--accent-3);\">(*)</small>",
    key_app_vscode: "Open VS Code",
    key_app_hopofy: "Run Hopofy script",
    key_app_discord: "Open Discord",
    key_app_dolphin: "Open Dolphin (file manager)",
    key_app_firefox: "Open Firefox",
    key_app_sysmon: "Open System Monitor",
    key_app_mission: "Open Mission Center",
    key_app_settings: "Open System Settings",
    key_app_telegram: "Open Telegram",
    key_app_pcsx2: "Open PCSX2 (PS2 emulator)",
    key_app_strawberry: "Open Strawberry (music player)",
    key_app_easyeffects: "Open EasyEffects (audio EQ)",
    key_app_hyprpicker: "Open Hyprpicker (color picker)",
    key_act_shot_region: "Take region screenshot",
    key_menu_dashboard: "Toggle Dashboard menu",
    key_menu_notif: "Toggle Notifications menu",
    key_menu_weather: "Toggle Weather menu",
    key_menu_monitors: "Toggle Monitoring menu",
    key_menu_network: "Toggle Network menu",
    key_menu_clipboard: "Toggle Clipboard menu",
    key_menu_todo: "Toggle Todo menu",
    key_menu_ai: "Toggle AI Bots menu",
    key_menu_power: "Power options (shutdown, reboot, suspend...)",
    key_menu_launcher: "Show app launcher",
    key_menu_nsettings: "Open NibrasShell settings",
    key_menu_cheatsheet: "Open Cheatsheet",
    key_menu_media: "Show media player capsule",
    key_menu_weather_island: "Show weather capsule",
    key_menu_clipboard2: "Toggle Clipboard menu (alt binding)",
    key_focus_l: "Move focus left",
    key_focus_r: "Move focus right",
    key_focus_u: "Move focus up",
    key_focus_d: "Move focus down",
    key_mon_focus1: "Focus monitor 1",
    key_mon_focus2: "Focus monitor 2",
    key_mon_move1: "Move current workspace to monitor 1",
    key_mon_move2: "Move current workspace to monitor 2",
    key_mon_reload: "Force renderer reload (forcerendererreload)",
    key_wmove_l: "Move window left",
    key_wmove_r: "Move window right",
    key_wmove_u: "Move window up",
    key_wmove_d: "Move window down",
    key_split_dec: "Decrease split ratio (-0.1)",
    key_split_inc: "Increase split ratio (+0.1)",
    key_ws_prev: "Go to previous workspace",
    key_ws_special: "Toggle special workspace",
    key_ws_go1: "Go to workspace 1",
    key_ws_go2: "Go to workspace 2",
    key_ws_go3: "Go to workspace 3",
    key_ws_go4: "Go to workspace 4",
    key_ws_go5: "Go to workspace 5",
    key_ws_go6: "Go to workspace 6",
    key_ws_go7: "Go to workspace 7",
    key_ws_go8: "Go to workspace 8",
    key_ws_go9: "Go to workspace 9",
    key_ws_go10: "Go to workspace 10",
    key_wsmove_1: "Move window to workspace 1",
    key_wsmove_2: "Move window to workspace 2",
    key_wsmove_3: "Move window to workspace 3",
    key_wsmove_4: "Move window to workspace 4",
    key_wsmove_5: "Move window to workspace 5",
    key_wsmove_6: "Move window to workspace 6",
    key_wsmove_7: "Move window to workspace 7",
    key_wsmove_8: "Move window to workspace 8",
    key_wsmove_9: "Move window to workspace 9",
    key_wsmove_10: "Move window to workspace 10",
    key_act_minimize: "Minimize current window",
    key_act_min_restored: "Restore minimized windows",
    key_scroll_next: "Next workspace",
    key_scroll_prev: "Previous workspace",
    key_mouse_move: "Move window (drag)",
    key_mouse_resize: "Resize window (drag)",
    key_layer_bottom: "Send focused window to bottom layer",
    key_act_suspend: "Suspend system (systemctl suspend)",
    key_act_kvm: "Apply HDMI-1-0 profile (physical KVM switch)",

    // --- Install ---
    install_title: "Installation",
    install_subtitle: "Two ways to install NibrasShell on your system",
    install_auto_title: "Automatic Method",
    install_auto_desc:
      'Clone the repo and run <span dir="ltr">python nibras_installer/main.py</span>.',
    install_manual_title: "Manual Installation",
    install_manual_toggle: "Manual Installation (Click to expand)",
    install_manual_deps: "Essential Software",
    install_manual_optional: "Optional Software",
    install_arch_title: "Arch Users:",
    install_fedora_title: "Fedora Users:",
    install_void_title: "Void Users:",
    install_other_distros:
      "<strong>Note:</strong> For other distros (not Arch, Fedora, or Void), install dependencies manually.",
    tag_recommended: "Recommended",
    tag_required: "Required",
    tag_optional: "Optional",
    install_depth_effect: "Depth Effect Requirements",
    install_depth_desc: "We need 'rembg' and 'pillow' libraries.",
    install_script_step: "Now run the install script and choose option 2",
    install_script_step_2: `

$ cd nibras_installer
$ python main.py
Choose your language / اختر لغتك / Vyberte jazyk:
1. English
2. العربية
3. Česky
> 1

=============================================
NibrasShell Installation Script
=============================================
1. Install Dependencies
2. Install NibrasShell
3. Update QuickShell
4. Uninstall NibrasShell
5. Create/Edit User Config
6. Exit
Choose an option: 2
`,
    install_manual_files: "If script fails, proceed with manual file setup:",
    install_manual_files_note: "If the script doesn't work, continue with manual installation below.",
    step_clone_repo: "Clone Repository",
    step_backup_configs: "Backup Existing Configs",
    step_copy_configs: "Copy Config Files",
    step_permissions: "Set Execute Permissions",
    step_easyeffects: "Configure EasyEffects",
    step_copy_themes: "Copy Themes",
    step_copy_fonts: "Copy Fonts",
    step_extract_icons: "Extract Icons",
    install_final_note:
      "You can change system font to 'JF Flat' and customize via (win+s).",

    // --- Dev Docs ---
    dev_title: "Developer Docs",
    dev_sub:
      "A comprehensive guide to understand project structure, architecture, and how to contribute.",
    dev_arch: "1. Architecture",
    dev_arch_desc:
      "NibrasShell is built on layered architecture, each layer serves a specific purpose:",
    dev_arch_patterns: "Core Design Patterns",
    dev_pattern_1:
      "<strong>Singleton-heavy:</strong> Core services use <code>pragma Singleton</code> for global access.",
    dev_pattern_2:
      "<strong>EventBus pub/sub:</strong> Components communicate via named events in <code>EventNames.js</code>.",
    dev_pattern_3:
      "<strong>Theme-reactive:</strong> All UI components bind to <code>ThemeManager.selectedTheme</code> properties for auto-updates.",
    dev_pattern_4:
      "<strong>Per-screen vs Global:</strong> Bars are created per screen (<code>Variants</code>), popup windows are single-instance.",
    dev_pattern_5:
      "<strong>Lazy loading:</strong> Menus load on demand via <code>StackView</code> to save resources.",
    dev_arch_1: "QML UI via Quickshell.",
    dev_arch_2: "Hyprland for window/event handling.",
    dev_arch_3: "Background services in `config/quickshell/services`.",
    dev_arch_4: "Python/Bash scripts in `scripts` folders.",
    dev_entry: "2. Entry Point",
    dev_entry_hint: "Main file:",
    dev_entry_desc:
      "This file assembles the base layers and manages the boot sequence:",
    dev_boot_1: "<strong>SplashScreen:</strong> Animated boot splash.",
    dev_boot_2:
      "<strong>ThemeManager.initialThemeReady:</strong> Signal to start UI loading.",
    dev_boot_3:
      "<strong>Loader (async):</strong> Async loading with opacity fade effect.",
    dev_boot_4:
      "<strong>Variants:</strong> Creates per-screen instances of Desktop, Topbar, LeftBar, SmartCapsule, Dock.",
    dev_ipc_title: "External Control (IPC)",
    dev_ipc_desc: "Control menus from external scripts via:",
    dev_settings: "3. Settings Management",
    dev_settings_1:
      "<strong>ConfigStore.qml:</strong> Reads/writes <code>~/.nibrasshell.json</code> via <code>FileView</code> with file watching.",
    dev_settings_2:
      "<strong>App.qml:</strong> Unifies paths (assets, scripts, cache), Python/Bash commands, and AI settings.",
    dev_settings_3:
      "<strong>Cache:</strong> <code>~/.cache/nibrasshell/</code> contains theme.json and venv.",
    dev_settings_4:
      "<strong>EventBus.qml:</strong> pub/sub system with <code>emit()</code>, <code>on()</code>, <code>off()</code>, <code>clearOwner()</code>.",
    dev_settings_5:
      "<strong>ConstValues.js:</strong> Menu constants (0-9), capsule states and priorities.",
    dev_theme_engine: "4. Theme Engine",
    dev_theme_engine_desc:
      "Multi-layered theming system with deep system integration.",
    dev_theme_phases: "ThemeManager - 6 Loading Phases",
    dev_theme_phases_code: `1. Request        → Request theme (user or default)
2. Cache check    → Check ~/.cache/nibrasshell/theme.json
3. Loader instruct → Instruct ThemeLoader to load QML
4. Object creation → Create theme object
5. Cache hydration → Fill properties from cache
6. System apply   → Apply theme to system (SystemBridge)`,
    dev_theme_basetheme: "BaseTheme - 100+ Properties",
    dev_base_colors:
      "<strong>colors:</strong> M3 palette (primary, secondary, tertiary, surface, error, outline...)",
    dev_base_dimensions:
      "<strong>dimensions:</strong> radii, bar sizes, component sizes, M3 shape scale.",
    dev_base_typography: "<strong>typography:</strong> fonts, sizes.",
    dev_base_system:
      "<strong>systemSettings:</strong> Qt style, Kvantum, GTK, Plasma, Konsole, icons, cursor.",
    dev_base_hyprland:
      "<strong>hyprlandConfiguration:</strong> borders, gaps, layout, animations, blur, shadows.",
    dev_base_clock:
      "<strong>desktopClock:</strong> position, format, depth effect.",
    dev_theme_bridge: "SystemBridge - System Integration",
    dev_bridge_desc: "Applies theme to various distro tools:",
    dev_bridge_plasma:
      "<strong>Plasma:</strong> colorscheme, icons, font, cursor.",
    dev_bridge_gtk: "<strong>GTK3/4:</strong> theme, icons, font, cursor.",
    dev_bridge_kvantum: "<strong>Kvantum:</strong> Qt application styling.",
    dev_bridge_konsole: "<strong>Konsole:</strong> terminal profiles.",
    dev_bridge_hyprland:
      "<strong>Hyprland:</strong> borders, gaps, animations via config rewrite.",
    dev_theme_variants:
      "<strong>14 Themes:</strong> Catppuccin, Colors, Deer, Dracula, Gruvbox, M3, Nord, TokyoNight (each Dark + Light).",
    dev_themes: "Themes & Wallpapers",
    dev_themes_1: "`ThemeManager.qml` handles themes.",
    dev_themes_2: "`WallpaperController.qml` manages wallpapers.",
    dev_themes_3: "`DepthEffectController.qml` handles depth.",
    dev_services: "5. Core Services",
    dev_services_desc: "Services are organized into layers by function:",
    dev_services_hardware: "Hardware Layer",
    dev_services_data: "Data Layer",
    dev_services_ai: "AI Layer",
    dev_services_analysis: "Analysis Layer",
    dev_services_ui: "UI Support",
    dev_services_facade: "System Facade",
    dev_actionresponses: "ActionResponses - Interactive Messages",
    dev_services_th1: "Service",
    dev_services_th2: "Role",
    dev_svc_audio: "PipeWire volume/mute control",
    dev_svc_brightness: "DDC/CI (external) + brightnessctl (laptop)",
    dev_svc_hwstate: "Aggregator: volume, brightness, battery, keyboard layout",
    dev_svc_weather:
      "wttr.in API + AI analysis + smart polling + 8 alert signals",
    dev_svc_music:
      "MPRIS + AI commentary + history (20 tracks) + debounced analysis",
    dev_svc_network:
      "WiFi scan/connect + data usage (monthly/daily/live/history)",
    dev_svc_clipboard:
      "wl-paste watch + Python clipboard manager + smart model sync",
    dev_svc_todo:
      "Persistent JSON + AI prioritization + due tracking + notifications",
    dev_svc_aiservice:
      "Priority queue (0-2) + rate limiting (3s cooldown, 15s throttle) + JSON cleaning",
    dev_svc_aitask: "Individual process execution unit (spawned per request)",
    dev_svc_aianalysis:
      "Orchestrator: SystemService signals → SpikeDetector → EventStore",
    dev_svc_spike: "CPU/RAM/Temp spike detection + AI triggers (priority 2)",
    dev_svc_cooldown:
      "3-level cooldown (global 30s, per-process 30s, temp 5min)",
    dev_svc_eventstore: "In-memory event log (max 50) with AI results",
    dev_svc_diagnostics: "Normalized data collection for processes/temps",
    dev_svc_notif: "Notification server + DND + sound dispatch + auto-cleanup",
    dev_svc_overlay: "Fullscreen overlay (image preview mode)",
    dev_svc_icon:
      "Batch icon resolution + theme-aware caching + flicker prevention",
    dev_svc_actions:
      "Pre-generated AI messages (round-robin rotation per category)",
    dev_svc_system:
      "Aggregator: BootAnalyzer + HardwareState + ResourceMonitor + ActionResponses",
    dev_svc_resource:
      "CPU/RAM/Temp monitoring + episode-based alerting + hysteresis",
    dev_svc_resdiag:
      "On-demand process/temp diagnostics with request deduplication",
    dev_svc_boot: "AI-powered boot log analysis + solution suggestions",
    dev_services_row1: "Resource monitoring & Boot analysis",
    dev_services_row2: "Weather & AI analysis",
    dev_services_row3: "MPRIS & AI commentary",
    dev_services_row4: "Notifications & DND",
    dev_services_row5: "Clipboard monitoring",
    dev_ai_system: "6. AI System",
    dev_ai_system_desc:
      "Integrated AI system with priority queue and rate limiting.",
    dev_ai_queue: "AiService - Central Gateway",
    dev_ai_pipeline: "Spike Detection Pipeline",
    dev_actions_1:
      "<strong>Categories:</strong> charging, discharging, cpu_alerts, ram_alerts, temp_alerts.",
    dev_actions_2:
      "<strong>Round-robin:</strong> Each alert shows a different message from the array.",
    dev_actions_3:
      "<strong>Auto-fetch:</strong> Fetches messages 5 seconds after startup.",
    dev_capsule: "7. Smart Capsule",
    dev_capsule_desc:
      "Dynamic Island-inspired widget with animated eye expressions.",
    dev_bars_windows: "8. Bars & Windows",
    dev_bars_title: "Bars (Layer Shell)",
    dev_bar_topbar:
      "<strong>Topbar:</strong> SystemTray | NetworkSpeed | ActiveWindow | Clock | Monitors",
    dev_bar_leftbar:
      "<strong>LeftBar:</strong> 10 icon buttons (Dashboard, Notifications, Weather, Monitoring, Network, Clipboard, Todo, AI, Apps, Power)",
    dev_windows_title: "Windows (Popup)",
    dev_win_left:
      "<strong>LeftWindowFull:</strong> StackView-based menu system (3 styles: FLOATING, DOCKED_FIXED_BAR, DOCKED_MOVING_BAR)",
    dev_win_launcher:
      "<strong>BottomLauncher:</strong> app launcher with command mode (<code>&gt;</code> prefix)",
    dev_win_dock: "<strong>Dock:</strong> pinned apps with auto-hide",
    dev_win_settings:
      "<strong>Settings:</strong> ApplicationWindow with General/Appearance/Monitors/Audio sections",
    dev_win_power:
      "<strong>PowerMenuWindow:</strong> shutdown/reboot/logout/suspend/lock",
    dev_win_cheatsheet:
      "<strong>Cheatsheet:</strong> keyboard shortcuts reference",
    dev_win_overlay: "<strong>OverlayWindow:</strong> fullscreen overlay layer",
    dev_event_system: "9. Event System",
    dev_eventbus: "EventBus (pub/sub)",
    dev_eventbus_code: `EventBus:
  ├── emit(eventName, data)     → Broadcast event
  ├── on(eventName, callback)   → Subscribe
  ├── off(eventName, callback)  → Unsubscribe
  └── clearOwner(owner)         → Auto cleanup on object destroy`,
    dev_eventnames: "EventNames.js - Examples",
    dev_python_integration: "10. Python Integration",
    dev_python_venv:
      "Python runs in an isolated environment: <code>~/.cache/nibrasshell/venv/bin/python</code>",
    dev_py_ai: "🤖 AI Scripts",
    dev_py_monitoring: "📊 Monitoring",
    dev_py_network: "🌐 Network",
    dev_py_theme: "🎨 Theme Integration",
    dev_py_wallpaper: "🖼️ Wallpaper/Depth",
    dev_py_utils: "🔧 Utilities",
    dev_scripts: "11. Key Scripts",
    dev_python: "Python",
    dev_bash: "Bash",
    dev_py_mon:
      "monitoring: <code>system_monitor.py</code>, <code>system_diagnostics.py</code>",
    dev_py_wall:
      "wallpapers: <code>scan_wallpapers.py</code>, <code>dynamic-m3.py</code>",
    dev_py_depth: "depth: <code>create_depth_image_rembg.py</code>",
    dev_py_net:
      "network: <code>list_wifi.py</code>, <code>connect_wifi.py</code>, <code>data_usage.py</code>",
    dev_py_ai_script: "ai: <code>main.py</code>, <code>list-gemini.py</code>",
    dev_bash_internet: "<code>internet.sh</code> - connectivity check",
    dev_bash_temp: "<code>temp.sh</code> - temperature reading",
    dev_bash_wall: "<code>get_wallpapers.sh</code> - wallpaper discovery",
    dev_run: "12. Running & Debugging",
    dev_run_title: "Running Quickshell",
    dev_run_desc: "The script sets log rules to reduce noise:",
    dev_debug_title: "Debugging Tips",
    dev_debug_1:
      "<strong>Test AI:</strong> <code>AiAnalysisService.testHighCpu</code> / <code>testHighRam</code>",
    dev_debug_2:
      "<strong>Check events:</strong> <code>EventStore.eventsModel</code> (last 50 events)",
    dev_debug_3:
      "<strong>Theme cache:</strong> <code>~/.cache/nibrasshell/theme.json</code>",
    dev_debug_4: "<strong>Settings:</strong> <code>~/.nibrasshell.json</code>",
    dev_debug_5:
      "<strong>Runtime files:</strong> <code>~/.cache/nibrasshell/venv/</code>",
    dev_notes: "Dev Notes",
    dev_note_1:
      "Smart capsule: <code>config/quickshell/windows/smart_capsule</code>.",
    dev_note_2: "Side menu: <code>config/quickshell/windows/leftwindow</code>.",
    dev_note_3: "Settings: <code>config/quickshell/windows/settings</code>.",
    dev_note_4: "Reusable components in <code>components/</code>.",
    dev_note_5:
      "Helper utilities in <code>utils/Helper.qml</code> and <code>utils/helpers.js</code>.",
    donate_title: "Support the project?",
    donate_desc:
      "If you're considering a financial donation, thank you! However, my financial situation is stable. Instead, I invite you to donate to the people of Gaza, as they are in much greater need of support right now.",
    donate_btn: "Donate to Gaza Now 🇵🇸",
    org_medical: "Medical relief for children",
    org_general: "General & emergency relief",
    org_food: "Food & meal programs",
    org_msf: "Support medical teams",
    // --- Footer ---
    footer_pages: "NibrasShell Project © " + new Date().getFullYear(),
    tool_daemon_title: "Autonomous & Smart System Daemon",
    tool_daemon_desc:
      "NibrasShell doesn't just show you numbers; it has a 'nervous system' running in the background. It silently monitors CPU, Memory, and Thermals. Upon any sudden spike, it automatically captures the culprit processes and analyzes them via AI to diagnose the issue and provide solutions.",
    tool_daemon_li1: "Root-Cause Analysis for resource and thermal spikes.",
    tool_daemon_li2:
      "Smart alert system (Cooldowns) to prevent notification spam.",
    tool_daemon_li3:
      "Task Queue system to prevent UI freezing during diagnostics.",
  },
};

// --- وظيفة تطبيق اللغة ---
function applyLanguage(lang) {
  const dict = translations[lang] || translations.en;
  document.documentElement.lang = lang === "en" ? "en" : "ar";
  document.documentElement.dir = lang === "en" ? "ltr" : "rtl";
  if (dict.page_title) document.title = dict.page_title;

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    if (dict[key]) el.textContent = dict[key];
  });

  document.querySelectorAll("[data-i18n-html]").forEach((el) => {
    const key = el.getAttribute("data-i18n-html");
    if (dict[key]) el.innerHTML = dict[key];
  });

  document.querySelectorAll("[data-i18n-aria]").forEach((el) => {
    const key = el.getAttribute("data-i18n-aria");
    if (dict[key]) el.setAttribute("aria-label", dict[key]);
  });

  // إعادة ضبط الأكواد بعد الترجمة (لضمان ظهور النصوص وزر النسخ)
  setupCodeBlocks();
}

// --- وظيفة تنظيف الكود وإضافة زر النسخ ---
function setupCodeBlocks() {
  const codeBlocks = document.querySelectorAll(".code");
  const currentLang = localStorage.getItem("nibras-lang") || "ar";

  codeBlocks.forEach((block) => {
    // إزالة الزر القديم لتجنب التكرار
    const oldBtn = block.querySelector(".copy-btn");
    if (oldBtn) oldBtn.remove();

    // تنظيف النص (Trim) من المسافات الزائدة
    // ملاحظة: نستخدم textContent للحصول على النص الخام فقط
    // إذا كان هناك نص سابق تم تنظيفه، نستخدمه
    if (!block.dataset.original) {
      block.dataset.original = block.textContent;
    }
    let codeContent = block.dataset.original.trim();
    block.textContent = codeContent;

    // إنشاء زر النسخ
    const copyBtn = document.createElement("button");
    copyBtn.className = "copy-btn";
    copyBtn.type = "button";
    copyBtn.innerText = currentLang === "ar" ? "نسخ" : "Copy";

    copyBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      navigator.clipboard.writeText(codeContent).then(() => {
        const originalText = copyBtn.innerText;
        copyBtn.innerText = currentLang === "ar" ? "تم!" : "Done!";
        copyBtn.classList.add("copied");

        setTimeout(() => {
          copyBtn.innerText = originalText;
          copyBtn.classList.remove("copied");
        }, 2000);
      });
    });

    block.appendChild(copyBtn);
  });
}

// --- إدارة الثيمات والصور ---
function resolveHeroImage(theme) {
  const map = {
    tokyonight: "assets/tokyonight-dark.webp",
    "tokyonight-light": "assets/tokyonight-light.webp",
    dracula: "assets/dracula-dark.webp",
    "dracula-light": "assets/dracula-light.webp",
    catppuccin: "assets/catppuccin-dark.webp",
    "catppuccin-light": "assets/catppuccin-light.webp",
    gruvbox: "assets/gruvbox-dark.webp",
    "gruvbox-light": "assets/gruvbox-light.webp",
    nord: "assets/nord-dark.webp",
    "nord-light": "assets/nord-light.webp",
    material: "assets/material-dark.webp",
    "material-light": "assets/material-light.webp",
  };
  return map[theme] || "assets/material-dark.webp";
}

function applyTheme(theme) {
  if (!theme) return;
  document.documentElement.setAttribute("data-theme", theme);
  if (themeSelect) themeSelect.value = theme;
  if (heroImage) heroImage.src = resolveHeroImage(theme);
}

// --- تهيئة الصفحة عند التحميل ---
document.addEventListener("DOMContentLoaded", () => {
  // تحميل الثيم المحفوظ
  const savedTheme = localStorage.getItem("nibras-theme") || "material";
  applyTheme(savedTheme);

  // تحميل اللغة المحفوظة
  const savedLang =
    localStorage.getItem("nibras-lang") ||
    (navigator.language.startsWith("ar") ? "ar" : "en");

  if (langSelect) langSelect.value = savedLang;
  applyLanguage(savedLang);

  // مستمعي الأحداث (Event Listeners)
  if (themeSelect) {
    themeSelect.addEventListener("change", (e) => {
      const theme = e.target.value;
      applyTheme(theme);
      localStorage.setItem("nibras-theme", theme);
    });
  }

  if (langSelect) {
    langSelect.addEventListener("change", (e) => {
      const lang = e.target.value;
      localStorage.setItem("nibras-lang", lang);
      applyLanguage(lang);
    });
  }

  if (navToggle && navRoot) {
    navToggle.addEventListener("click", () => {
      navRoot.classList.toggle("open");
    });
  }

  // --- Lightbox: open UI shots on click ---
  initLightbox();
});

// =====================================================
// Lightbox controller — opens gallery images fullscreen
// =====================================================
function initLightbox() {
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightboxImg");
  const lightboxCaption = document.getElementById("lightboxCaption");
  const lightboxCounter = document.getElementById("lightboxCounter");
  const lightboxClose = document.getElementById("lightboxClose");
  const lightboxPrev = document.getElementById("lightboxPrev");
  const lightboxNext = document.getElementById("lightboxNext");

  if (!lightbox || !lightboxImg) return;

  // collect all gallery items in document order
  const triggers = Array.from(
    document.querySelectorAll("[data-lightbox-trigger] img")
  ).filter((img) => img && img.src);

  if (triggers.length === 0) return;

  const items = triggers.map((img) => ({
    src: img.getAttribute("src"),
    alt: img.getAttribute("alt") || "",
  }));

  let currentIndex = 0;
  let lastFocus = null;

  function render() {
    const item = items[currentIndex];
    lightboxImg.src = item.src;
    lightboxImg.alt = item.alt;
    lightboxCaption.textContent = item.alt;
    if (items.length > 1) {
      lightboxCounter.textContent = `${currentIndex + 1} / ${items.length}`;
    } else {
      lightboxCounter.textContent = "";
    }
  }

  function open(index) {
    currentIndex = index;
    lastFocus = document.activeElement;
    render();
    lightbox.hidden = false;
    lightbox.setAttribute("aria-hidden", "false");
    lightbox.setAttribute("data-single", items.length === 1 ? "true" : "false");
    document.body.classList.add("lightbox-open");
    // focus the close button for keyboard users
    setTimeout(() => lightboxClose && lightboxClose.focus(), 30);
  }

  function close() {
    lightbox.hidden = true;
    lightbox.setAttribute("aria-hidden", "true");
    document.body.classList.remove("lightbox-open");
    if (lastFocus && typeof lastFocus.focus === "function") {
      lastFocus.focus();
    }
  }

  function next() {
    if (items.length < 2) return;
    currentIndex = (currentIndex + 1) % items.length;
    render();
  }

  function prev() {
    if (items.length < 2) return;
    currentIndex = (currentIndex - 1 + items.length) % items.length;
    render();
  }

  // attach click to each card
  triggers.forEach((img, idx) => {
    const card = img.closest("[data-lightbox-trigger]");
    if (!card) return;
    card.setAttribute("role", "button");
    card.setAttribute("tabindex", "0");
    card.setAttribute(
      "aria-label",
      img.getAttribute("alt") || "Open image"
    );
    card.addEventListener("click", (e) => {
      e.preventDefault();
      open(idx);
    });
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        open(idx);
      }
    });
  });

  // close handlers
  if (lightboxClose) lightboxClose.addEventListener("click", close);
  lightbox.querySelectorAll("[data-lightbox-close]").forEach((el) => {
    el.addEventListener("click", close);
  });

  // nav handlers
  if (lightboxPrev) lightboxPrev.addEventListener("click", (e) => {
    e.stopPropagation();
    prev();
  });
  if (lightboxNext) lightboxNext.addEventListener("click", (e) => {
    e.stopPropagation();
    next();
  });

  // keyboard nav while open
  document.addEventListener("keydown", (e) => {
    if (lightbox.hidden) return;
    if (e.key === "Escape") {
      e.preventDefault();
      close();
    } else if (e.key === "ArrowRight") {
      e.preventDefault();
      // in RTL, arrow keys should feel natural — right arrow goes "next" in content order
      next();
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      prev();
    }
  });
}
