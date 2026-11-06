import argparse
import json

import google.generativeai as genai

from credential_transport import (
    CredentialTransportError,
    read_credential,
    redact_secret,
)


def main():
    parser = argparse.ArgumentParser(
        description="List available Gemini models"
    )
    parser.add_argument(
        "--credential-stdin",
        action="store_true",
        help="Read the API credential from one bounded JSON line on stdin",
    )
    # Legacy argv option: rejected without echoing or using its value.
    parser.add_argument(
        "--api_key", dest="_argv_api_key", default=None, help=argparse.SUPPRESS
    )

    args = parser.parse_args()

    result = {"success": False, "models": [], "error": ""}

    if args._argv_api_key is not None:
        result["error"] = "CREDENTIAL_TRANSPORT_ERROR:ARGV_FORBIDDEN"
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    try:
        credential = read_credential() if args.credential_stdin else ""
    except CredentialTransportError as exc:
        result["error"] = str(exc)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    if not credential:
        result["error"] = "MISSING_API_CREDENTIAL"
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    try:
        genai.configure(api_key=credential)

        # جلب كل المودلات المتاحة
        all_models = genai.list_models()

        for m in all_models:
            # نحن مهتمون بالمودلات التي تدعم توليد المحتوى (Chat)
            if "generateContent" in m.supported_generation_methods:
                model_info = {
                    "name": m.name.replace(
                        "models/", ""
                    ),  # إزالة البادئة لتسهيل الاستخدام
                    "display_name": m.display_name,
                    "description": m.description,
                    "input_token_limit": m.input_token_limit,
                    "output_token_limit": m.output_token_limit,
                    "temperature_support": True,  # افتراضياً أغلبها يدعم
                }
                result["models"].append(model_info)

        result["success"] = True

    except Exception as e:
        result["error"] = redact_secret(str(e), credential)

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
