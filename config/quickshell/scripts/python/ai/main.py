import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Optional, Union

import prompt

from config import PRESETS, get_provider, structured_evidence_enabled

try:
    from json_repair import repair_json

    HAS_JSON_REPAIR = True
except ImportError:
    HAS_JSON_REPAIR = False


def extract_and_clean_json(
    raw_text: str,
) -> Optional[Union[Dict[str, Any], List[Any]]]:
    if not raw_text:
        return None

    # 1. تنظيف أولي للنص من علامات المارك داون
    clean_text = re.sub(r"```json\s*", "", raw_text, flags=re.IGNORECASE)
    clean_text = re.sub(r"```\s*", "", clean_text).strip()

    # 2. البحث عن أول قوس مفتوح سواء كان كائن { أو مصفوفة [
    match = re.search(r"[\{\[]", clean_text)
    if not match:
        # إذا لم نجد أي أقواس، نجرب استدعاء json_repair على النص بأكمله كمحاولة أخيرة
        if HAS_JSON_REPAIR:
            try:
                return json.loads(repair_json(raw_text))
            except Exception:
                pass
        return None

    start_idx = match.start()
    start_char = match.group()
    # تحديد قوس الإغلاق المقابل بناءً على نوع البداية
    end_char = "}" if start_char == "{" else "]"

    balance = 0
    end_idx = -1

    # نبدأ البحث من أول قوس مفتوح ونعد التوازن للعثور على القوس المغلق الصحيح
    for i, char in enumerate(clean_text[start_idx:], start=start_idx):
        if char == start_char:
            balance += 1
        elif char == end_char:
            balance -= 1
            if balance == 0:
                end_idx = i
                break

    if end_idx != -1:
        potential_json = clean_text[start_idx : end_idx + 1]

        # محاولة التحليل (Parsing)
        try:
            if HAS_JSON_REPAIR:
                return json.loads(repair_json(potential_json))
            else:
                return json.loads(potential_json)
        except Exception:
            pass

    # إذا فشل الاستخراج الدقيق بالأقواس، نجرب الاستخراج الخام كمحاولة أخيرة
    try:
        if HAS_JSON_REPAIR:
            return json.loads(repair_json(raw_text))
    except Exception:
        pass

    return None


def get_fallback_response(language: str = "en") -> Dict[str, Any]:
    """رد احتياطي في حال فشل كل شيء لضمان عدم انهيار التطبيق"""
    msg = "I am seemingly speechless."
    if language and "Arabic" in language.lower():
        msg = "يبدو أنني عاجز عن الكلام حالياً."

    return {"reply": msg, "apply": False, "changes": [], "warnings": []}


def _phase6_audit_logger():
    """Opt-in production audit logger (Phase 6, §14).

    Library/test calls of the orchestrator remain side-effect-free.  The
    production v2 path enables the logger when structured evidence is on or
    when an explicit ``NIBRAS_SHELL_AI_AUDIT_LOG`` override is supplied.
    """
    try:
        from audit import AuditLogger

        if not structured_evidence_enabled() and not os.environ.get(
            "NIBRAS_SHELL_AI_AUDIT_LOG"
        ):
            return None
        return AuditLogger.from_env()
    except Exception:  # noqa: BLE001 — audit setup must never break diagnostics
        return None


def _audit_emit(logger, stage, outcome, **kwargs) -> None:
    if logger is None:
        return
    try:
        logger.emit(stage=stage, outcome=outcome, **kwargs)
    except Exception:  # noqa: BLE001
        pass


def _audit_response_reasons(envelope) -> list[str]:
    """Extract typed reason codes from an orchestrator envelope."""
    response = envelope.get("response") if isinstance(envelope, dict) else None
    if not isinstance(response, dict):
        return []
    payload = response.get("response")
    if not isinstance(payload, dict):
        payload = response
    codes: list[str] = []
    failure = payload.get("analysis_failure") or response.get("analysis_failure")
    if isinstance(failure, str) and failure:
        codes.append(failure)
    validation = payload.get("validation")
    if isinstance(validation, dict):
        for decision in validation.get("tool_decisions") or []:
            if isinstance(decision, dict):
                codes.extend(str(c) for c in decision.get("reason_codes") or [])
        guidance = validation.get("guidance_decision")
        if isinstance(guidance, dict):
            codes.extend(str(c) for c in guidance.get("reason_codes") or [])
    return list(dict.fromkeys(c for c in codes if c))[:32]


def _run_orchestrator_v2(args) -> None:
    """المرحلة 3 (نتائج س18): مسار التنسيق المُقيَّد فوق nibras.incident/v1.

    يعمل فقط عند تمرير ``--orchestrator v2`` (مغلق افتراضيًا حتى تُقَيَّد).
    المسار القديم لا يُلمس إطلاقًا: نفس المظروف (success/response/
    updated_history/error) + قالب إضافي ``orchestrator`` للتدقيق.
    يتطلب تجميع الشواهد المهيكلة: ``NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE=1``.
    """
    output: Dict[str, Any] = {
        "success": False,
        "response": None,
        "updated_history": [],
        "error": "",
        "orchestrator": None,
    }
    audit = _phase6_audit_logger()
    try:
        from agent import prompt_agent as agent_prompts
        from agent import tools as agent_tools
        from agent.orchestrator import run_orchestrator

        from config import get_boot_incident

        # نظام التعليمات = برومبت الوكيل المخصص (§10.2-B) — لا يحتوي
        # {SYSTEM_LOGS} إطلاقاً؛ بيانات الحادثة تدخل عبر <incident> DATA فقط.
        llm = get_provider(
            args,
            agent_prompts.AGENT_SYSTEM_PROMPT_EN,
            0.1,
            True,
        )

        def model_call(message: str, history: Any):
            return llm.generate(message, history or [])

        bundle = get_boot_incident()
        collection = bundle.get("collection", {}) if isinstance(bundle, dict) else {}
        if not isinstance(collection, dict):
            collection = {}
        incidents = bundle.get("incidents") or [] if isinstance(bundle, dict) else []
        if not isinstance(incidents, list):
            incidents = []
        counters = collection.get("counters", {})
        if not isinstance(counters, dict):
            counters = {}
        valid = [
            inc
            for inc in incidents
            if isinstance(inc, dict) and inc.get("schema_version")
        ]
        _audit_emit(
            audit,
            "collect",
            "FAILURE"
            if (not isinstance(bundle, dict) or collection.get("collection_failed"))
            else "SUCCESS",
            reason_codes=(
                collection.get("failure_reasons", [])
                if isinstance(collection, dict)
                else ["STRUCTURED_EVIDENCE_DISABLED"]
            ),
            budget_usage={
                "records": counters.get("records_collected", 0),
                "max_records": 200,
                "incidents": len(incidents),
            },
        )
        _audit_emit(
            audit,
            "discover",
            "SUCCESS" if valid else "NO_INCIDENTS_COLLECTED",
            reason_codes=(
                collection.get("failure_reasons", [])
                if isinstance(collection, dict)
                else []
            ),
            budget_usage={"incidents": len(valid)},
        )
        if not valid:
            output["success"] = True
            output["response"] = {
                "analysis_failure": "NO_INCIDENTS_COLLECTED",
                "no_action_taken": True,
            }
            output["orchestrator"] = {
                "version": "v2",
                "notes": [
                    "collect with NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE=1 "
                    "(flag-gated, default-deny)",
                ],
            }
            _audit_emit(
                audit,
                "render",
                "NO_INCIDENTS_COLLECTED",
                reason_codes=["NO_INCIDENTS_COLLECTED"],
            )
            print(json.dumps(output, ensure_ascii=False))
            return

        incident = valid[0]
        envelope = run_orchestrator(
            incident,
            model_call,
            agent_tools.OsToolCommandRunner(),
            audit_logger=audit,
        )
        for key in ("success", "response", "updated_history", "error"):
            output[key] = envelope.get(key, output[key])
        output["orchestrator"] = envelope.get("orchestrator")
        response = envelope.get("response")
        payload = response.get("response") if isinstance(response, dict) else None
        if not isinstance(payload, dict):
            payload = response if isinstance(response, dict) else {}
        failure = payload.get("analysis_failure")
        if failure is None and isinstance(response, dict):
            failure = response.get("analysis_failure")
        validation = payload.get("validation")
        if validation is None and isinstance(response, dict):
            validation = response.get("validation")
        render_outcome = (
            str(failure)
            if isinstance(failure, str) and failure
            else (
                str(
                    (validation.get("guidance_decision") or {}).get("status", "SUCCESS")
                )
                if isinstance(validation, dict)
                else "SUCCESS"
            )
        )
        _audit_emit(
            audit,
            "render",
            render_outcome,
            correlation_id=incident.get("correlation_id")
            if isinstance(incident, dict)
            else None,
            reason_codes=_audit_response_reasons(envelope),
            budget_usage={
                "incidents": len(valid),
                "model_calls_used": (envelope.get("orchestrator") or {}).get(
                    "model_calls_used", 0
                ),
            },
        )
    except Exception as exc:  # noqa: BLE001 — the envelope never crashes out
        output["error"] = f"{type(exc).__name__}: {str(exc)[:300]}"
        output["response"] = {
            "analysis_failure": "ORCHESTRATOR_UNAVAILABLE",
            "no_action_taken": True,
        }
        _audit_emit(
            audit,
            "render",
            "ORCHESTRATOR_UNAVAILABLE",
            reason_codes=["ORCHESTRATOR_UNAVAILABLE"],
        )
    print(json.dumps(output, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--message", default=None)
    parser.add_argument("--message_key", default=None)
    parser.add_argument("--message_vars", default="{}")
    parser.add_argument("--api_key")
    parser.add_argument("--model")
    parser.add_argument("--preset", choices=PRESETS.keys(), default=None)
    parser.add_argument("--base_url", default=None)
    parser.add_argument("--history", default="[]")
    parser.add_argument("--system_instruction", default=None)
    parser.add_argument("--temperature", type=float, default=None)
    parser.add_argument("--json_mode", action="store_true")
    parser.add_argument(
        "--provider",
        choices=[
            "local",
            "gemini",
            "openrouter",
            "openai",
            "deepseek",
            "ollama",
        ],
        default=None,
    )
    parser.add_argument("--preferred_language", default="Arabic")
    parser.add_argument("--user_persona", default="You are Nibras")
    # المرحلة 3 (§18): علم التنسيق المُقيَّد — v2 فقط، مغلق افتراضيًا حتى
    # تُقَيَّد نهاية العمر الكامل (Phase 5 QML). المسار القديم يظل مطابقًا
    # بايت-بايت عندما يكون العلم غائبًا.
    parser.add_argument(
        "--orchestrator",
        choices=["v2"],
        default=None,
        help="تنسيق مُقيَّد فوق nibras.incident/v1 (تجريبي، مغلق افتراضيًا)",
    )

    args = parser.parse_args()

    if args.orchestrator is not None:  # Phase 3 (§18): bounded orchestrator
        _run_orchestrator_v2(args)
        return

    # الهيكل العام للمخرجات
    output: Dict[str, Any] = {
        "success": False,
        "response": None,
        "updated_history": [],
        "error": "",
    }

    try:
        # قراءة وتجهيز التاريخ الحالي
        try:
            history: List[Dict[str, str]] = json.loads(args.history)
        except Exception as e:
            print(
                f"[Warning] Failed to parse history JSON: {e}. Defaulting to empty list.",
                file=sys.stderr,
            )
            history = []

        # تجهيز الرسالة
        final_message = args.message
        if not final_message and args.message_key:
            try:
                message_vars = (
                    json.loads(args.message_vars) if args.message_vars else {}
                )
            except Exception as e:
                print(
                    f"[Warning] Failed to parse message_vars JSON: {e}. Defaulting to empty dict.",
                    file=sys.stderr,
                )
                message_vars = {}
            final_message = prompt.build_message(args.message_key, **message_vars)

        if not final_message:
            raise ValueError("Missing --message or invalid --message_key")

        final_system = args.system_instruction
        final_temp = args.temperature if args.temperature is not None else 0.7
        final_json_mode = args.json_mode

        # تطبيق الإعدادات المسبقة (Presets) إذا تم توفيرها
        if args.preset:
            preset_config = PRESETS[args.preset]
            if not final_system:
                final_system = preset_config.get("system_instruction")
            if args.temperature is None:
                final_temp = preset_config.get("temperature", final_temp)
            if preset_config.get("json_mode"):
                final_json_mode = True

        # الحصول على الـ Provider وتوليد الإجابة
        llm = get_provider(args, final_system, final_temp, final_json_mode)
        raw_response_text, _ = llm.generate(final_message, history)

        # تحضير الرد النهائي
        final_response_data = raw_response_text

        if final_json_mode:
            cleaned_obj = extract_and_clean_json(raw_response_text)
            if cleaned_obj is not None:
                final_response_data = cleaned_obj
            else:
                print(
                    f"JSON Parsing failed for: {raw_response_text}",
                    file=sys.stderr,
                )
                final_response_data = get_fallback_response(args.preferred_language)

        # تحديث التاريخ قبل إرجاعه (إضافة دورة المحادثة الحالية)
        updated_history = list(history)
        updated_history.append({"role": "user", "content": final_message})
        updated_history.append({"role": "assistant", "content": raw_response_text})

        # ملء بيانات المخرجات بنجاح
        output["success"] = True
        output["response"] = final_response_data
        output["updated_history"] = updated_history

    except Exception as e:
        output["error"] = str(e)
        if args.json_mode:
            output["response"] = get_fallback_response(args.preferred_language)
        # الحفاظ على التاريخ القديم في حال حدوث خطأ
        output["updated_history"] = history

    # ensure_ascii=False يضمن ظهور الحروف العربية بشكل صحيح في الطرفية والملفات
    print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
