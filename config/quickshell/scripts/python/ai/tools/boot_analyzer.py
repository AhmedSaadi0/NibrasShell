import argparse
import json
import os
import subprocess
import sys

# -----------------------------------------------------------------------------
# 1. إعداد مسار الاستيراد للوصول إلى مجلد AI
# -----------------------------------------------------------------------------
# نفترض أن هذا الملف داخل scripts/python/tools/
# ونحتاج للوصول إلى scripts/python/ai/
current_dir = os.path.dirname(os.path.abspath(__file__))
ai_dir = os.path.join(current_dir, "..", "ai")
sys.path.append(ai_dir)

from credential_transport import (
    CredentialTransportError,
    read_credential,
    redact_secret,
)

# الآن يمكننا استيراد كلاسات الذكاء الاصطناعي الموجودة لديك
try:
    from ..config import get_provider
    from ..prompt import SYSTEM_ANALYST_PROMPT
except ImportError as e:
    print(f'{{"error": "Failed to import AI modules: {e}"}}')
    sys.exit(1)


# -----------------------------------------------------------------------------
# 2. دوال جلب بيانات النظام
# -----------------------------------------------------------------------------
def get_system_data():
    data_buffer = []

    # أ) وقت الإقلاع
    try:
        boot_time = subprocess.check_output(
            ["systemd-analyze", "time"], text=True
        ).strip()
        data_buffer.append(f"--- BOOT TIME ---\n{boot_time}")
    except Exception as e:
        data_buffer.append(f"--- BOOT TIME ERROR ---\n{e}")

    # ب) سجلات الأخطاء (Priority 3)
    try:
        logs = subprocess.check_output(
            [
                "journalctl",
                "-b",
                "0",
                "-p",
                "3",
                "-n",
                "15",
                "--output",
                "short-iso",
                "--no-pager",
            ],
            text=True,
        ).strip()
        data_buffer.append(f"--- CRITICAL LOGS ---\n{logs}")
    except Exception as e:
        data_buffer.append(f"--- LOGS ERROR ---\n{e}")

    return "\n\n".join(data_buffer)


# -----------------------------------------------------------------------------
# 3. التشغيل الرئيسي
# -----------------------------------------------------------------------------
def main():
    # إعداد المستقبلات (Arguments) مثل السكربت الرئيسي تماماً
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--provider", default="openai"
    )  # أو حسب الافتراضي لديك
    parser.add_argument("--model", default="gpt-4o")
    parser.add_argument(
        "--credential-stdin",
        action="store_true",
        help="Read the API credential from one bounded JSON line on stdin",
    )
    # Legacy argv option: rejected without echoing or using its value.
    parser.add_argument(
        "--api_key", dest="_argv_api_key", default=None, help=argparse.SUPPRESS
    )
    parser.add_argument("--base_url", default="")
    parser.add_argument("--preferred_language", default="English")
    parser.add_argument("--user_persona", default="You are Nibras")
    # ... أي وسائط أخرى يحتاجها config.py

    # ملاحظة: نحن لا نحتاج "preferred_language" هنا لأن التحليل تقني،
    # لكن يمكن إضافته إذا أردت الملخص بالعربية

    args = parser.parse_args()

    if args._argv_api_key is not None:
        print(
            json.dumps(
                {
                    "summary": "Internal Script Error",
                    "boot_duration": "Error",
                    "logs": [
                        {
                            "time": "00:00",
                            "msg": "CREDENTIAL_TRANSPORT_ERROR:ARGV_FORBIDDEN",
                        }
                    ],
                }
            )
        )
        return

    try:
        args.api_key = read_credential() if args.credential_stdin else ""
    except CredentialTransportError as exc:
        print(
            json.dumps(
                {
                    "summary": "Internal Script Error",
                    "boot_duration": "Error",
                    "logs": [{"time": "00:00", "msg": str(exc)}],
                }
            )
        )
        return

    # 1. جلب البيانات الحقيقية
    raw_data = get_system_data()

    # 2. تجهيز البرومبت
    # نقوم بحقن البيانات داخل القالب
    final_prompt = SYSTEM_ANALYST_PROMPT.replace("{SYSTEM_LOGS}", raw_data)

    # 3. تجهيز المزود (Provider)
    # نستخدم دالة get_provider الموجودة في config.py الخاص بك
    # لكننا نمرر البرومبت المجهز يدوياً

    # نحتاج لكائن Args وهمي أو نمرر الـ args الحقيقية مع تعديلات
    # هنا سنعتمد على أن config.get_provider يقبل الـ args ويستخدم system_instruction

    try:
        ai_provider = get_provider(
            args=args,
            final_system_instruction=final_prompt,  # البرومبت النظامي هو التحليل
            final_temperature=0.1,  # حرارة منخفضة جداً للدقة
            final_json_mode=True,  # نريد JSON حصراً
        )

        # 4. إرسال طلب فارغ (لأن التعليمات كلها في الـ System Instruction)
        # أو إرسال كلمة "Analyze"
        response = ai_provider.generate(
            "Analyze current boot status based on provided logs."
        )

        # 5. طباعة النتيجة (QML سيقرأ هذا)
        print(response)

    except Exception as e:
        # طباعة خطأ بتنسيق JSON ليفهمه QML
        error_json = json.dumps(
            {
                "summary": "Internal Script Error",
                "boot_duration": "Error",
                "logs": [
                    {
                        "time": "00:00",
                        "msg": redact_secret(str(e), getattr(args, "api_key", "")),
                    }
                ],
            }
        )
        print(error_json)


if __name__ == "__main__":
    main()
