import datetime
import json
import os
import platform
import subprocess

import prompt
from gemini_provider import GeminiProvider
from local_provider import LocalProvider
from ollama_provider import OllamaProvider
from openai_provider import OpenAIProvider
from openrouter_provider import OpenRouterProvider

# -----------------------------------------------------------------------------
# 0. التكوينات والإعدادات المسبقة (Presets)
# -----------------------------------------------------------------------------
PRESETS = {
    "weather": {
        "system_instruction": prompt.WEATHER_MASTER_PROMPT,
        "json_mode": True,  # الطقس يحتاج دائماً JSON
        "temperature": 0.4,  # نحتاج دقة أكثر وإبداعاً أقل
    },
    "coder": {
        "system_instruction": prompt.PROGRAMMER_PROMPT,
        "json_mode": False,
        "temperature": 0.2,
    },
    "chat": {
        "system_instruction": prompt.ASSISTANT_PROMPT,
        "json_mode": False,
        "temperature": 0.7,
    },
    "idle_capsule": {
        "system_instruction": prompt.IDLE_CAPSULE_PROMPT,
        "json_mode": True,
        "temperature": 0.8,
    },
    "music": {
        "system_instruction": prompt.MUSIC_MASTER_PROMPT,
        "json_mode": True,
        "temperature": 0.5,
    },
    "todo": {
        "system_instruction": prompt.TODO_MASTER_PROMPT,
        "json_mode": True,
        "temperature": 0.4,
    },
    "boot_analyze": {
        "system_instruction": prompt.SYSTEM_ANALYST_PROMPT,
        "json_mode": True,
        "temperature": 0.1,
    },
    "spike_analyze": {
        "system_instruction": prompt.SPIKE_ANALYST_PROMPT,
        "json_mode": True,
        "temperature": 0.2,
    },
    "system_action": {
        "system_instruction": prompt.SYSTEM_ACTION_PROMPT,
        "json_mode": True,
        "temperature": 0.7,
    },
    "color_palette": {
        "system_instruction": prompt.COLOR_PALETTE_PROMPT,
        "json_mode": True,
        "temperature": 0.45,
    },
    "boot_solution": {
        "system_instruction": prompt.BOOT_SOLUTION_PROMPT,
        "json_mode": True,
        "temperature": 0.2,
    },
}


# R1 payload bound for one structured-collection envelope (plan §10.3:
# records ≤ 200 / per-message ≤ 2000 / envelope ≤ 512 KiB)
MAX_ENVELOPE_BYTES = 512 * 1024


def structured_evidence_enabled() -> bool:
    """المرحلة 2 (§18): مفتاح تجميع الشواهد المهيكلة — default-deny.

    يعمل المسار القديم ``{SYSTEM_LOGS}`` كما هو دائمًا؛ هذا المفتاح يسمح فقط
    **بتجميع** الحوادث المهيكلة (``nibras.incident/v1``) عبر ``get_boot_incident``.
    القيمة الافتراضية ``0`` ⇒ لا يُقرأ journalctl ولا podman/systemctl إطلاقًا.
    """
    return os.environ.get(
        "NIBRAS_SHELL_AI_STRUCTURED_EVIDENCE", "0"
    ).strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def get_boot_incident(runner=None, limit=200):
    """تجميع حوادث الإقلاع المهيكلة (nibras.incident/v1) — المرحلة 2.

    يعيد ``None`` عندما يكون المفتاح مطفأً (لا يتحسّس النظام إطلاقًا ولا يمسّ
    المسار القديم). الاستيرادات الكسولة المُحاطة بـ try/except تفشل بهدوء
    مُغلَق (fail-closed) ولا تكسر مسار ``{SYSTEM_LOGS}`` القديم مهما حدث.

    الشكل المُعاد (تجميع داخلي غير مُعاقَد — العقد المُعاقَد هو
    nibras.incident/v1 لكل سجل): ``{"collection": {...}, "incidents": [...≤200]}``.
    كل حادثة تحمل شواهدها وحالة تنقيتها وغياباتها بنفسها (§9)، ولقطة الاستبيان
    المشتركة (survey snapshot) تُبنى مرة واحدة وتُضمَّن في كل حادثة.
    """
    if not structured_evidence_enabled():
        return None
    try:
        from evidence import journal_collector as _jc
        from evidence.discovery import discover as _discover, OsRunner as _OsRunner
        from incident import normalizer as _nz
    except Exception as exc:  # noqa: BLE001 — fail-closed, never break legacy
        return {
            "collection": {
                "collection_failed": True,
                "failure_reasons": ["RUNTIME_UNAVAILABLE"],
                "notes": [
                    f"structured evidence layer unavailable: {type(exc).__name__}"
                ],
            },
            "incidents": [],
        }

    active_runner = runner if runner is not None else _OsRunner()
    collection = _jc.collect(active_runner, limit=limit)
    try:
        survey_snapshot = _nz.build_survey_snapshot(active_runner)
    except Exception as exc:  # noqa: BLE001 — survey degrades fail-closed too
        survey_snapshot = {
            "state": "ABSENT",
            "note": f"survey snapshot build failed: {type(exc).__name__}",
        }

    incidents = []
    payload_bytes = 0
    payload_capped = False
    for seq, record in enumerate(collection.records, start=1):
        try:
            discovery_result = _discover(record, active_runner)
            incident = _nz.build_incident(
                record,
                discovery_result,
                survey_snapshot=survey_snapshot,
                current_boot_id=collection.current_boot_id,
                container_seq=seq,
            )
        except Exception as exc:  # noqa: BLE001 — one bad record never halts
            incidents.append(
                {
                    "schema_version": _nz.SCHEMA_VERSION,
                    "collection_note": (
                        "INCIDENT_BUILD_FAILED: "
                        f"{type(exc).__name__} — record skipped honestly"
                    ),
                    "record_index": seq,
                }
            )
            continue
        # R1 payload bound (§10.3): stop ADDING when the envelope exceeds the
        # 512 KiB cap; the reached-cap state is recorded, never silently cut
        candidate_size = len(json.dumps(incident, default=str).encode("utf-8"))
        if payload_bytes + candidate_size > MAX_ENVELOPE_BYTES:
            payload_capped = True
            break
        incidents.append(incident)
        payload_bytes += candidate_size

    if payload_capped:
        collection_notes = list(collection.notes) if collection.notes else []
        collection_notes.append(
            f"PAYLOAD_CAP_REACHED: envelope stopped at {payload_bytes} bytes "
            f"of {len(collection.records)} collected records"
        )
    else:
        collection_notes = list(collection.notes)

    return {
        "collection": {
            "argv_used": collection.argv_used,
            "counters": collection.counters,
            "notes": collection_notes,
            "failure_reasons": collection.failure_reasons,
            "current_boot_id": collection.current_boot_id,
            "same_boot_as_cursor_group": collection.same_boot_as_cursor_group,
            "used_fallback": collection.used_fallback,
            "output_truncated": collection.output_truncated,
            "collection_failed": collection.collection_failed,
            "last_cursor": collection.last_cursor,
        },
        "incidents": incidents,
    }


def get_raw_boot_logs():
    """تجميع بيانات الإقلاع واللوجات في نص واحد"""
    buffer = []

    # 1. Boot Time
    try:
        time_out = subprocess.check_output(
            ["systemd-analyze", "time"], text=True
        ).strip()
        buffer.append(f"--- BOOT DURATION ---\n{time_out}")
    except Exception as e:
        buffer.append(f"--- BOOT TIME ERROR: {e} ---")

    # 2. Critical Logs (Journalctl)
    try:
        # نجلب آخر 30 خطأ (Priority 3) من الإقلاع الحالي
        logs_out = subprocess.check_output(
            [
                "journalctl",
                "-b",
                "0",
                "-p",
                "3",
                "-n",
                "30",
                "--output",
                "short-iso",
                "--no-pager",
            ],
            text=True,
        ).strip()
        if not logs_out:
            logs_out = "No critical errors found."
        buffer.append(f"--- CRITICAL LOGS ---\n{logs_out}")
    except Exception as e:
        buffer.append(f"--- LOGS ERROR: {e} ---")

    return "\n\n".join(buffer)


def get_system_details():
    now = datetime.datetime.now()

    # Clean OS info string
    try:
        os_release = platform.freedesktop_os_release()
        os_string = f"{os_release.get('NAME', platform.system())} {os_release.get('VERSION_ID', platform.release())}"
    except Exception:
        os_string = f"{platform.system()} {platform.release()}"

    # Detect desktop environment
    xdg_desktop = os.environ.get("XDG_CURRENT_DESKTOP", "")
    session_type = os.environ.get("XDG_SESSION_TYPE", "")

    # Kernel version
    try:
        kernel_version = subprocess.check_output(["uname", "-r"], text=True).strip()
    except Exception:
        kernel_version = platform.release()

    # GPU info
    try:
        gpu_output = subprocess.check_output(["lspci"], text=True).strip()
        gpu_line = [l for l in gpu_output.split("\n") if "VGA" in l or "3D" in l]
        gpu_info = gpu_line[0].split(": ", 1)[1] if gpu_line else "Unknown"
    except Exception:
        gpu_info = "Unknown"

    return {
        "{CURRENT_DATE}": now.strftime("%Y-%m-%d"),
        "{CURRENT_TIME}": now.strftime("%H:%M"),
        "{DAY_NAME}": now.strftime("%A"),
        "{OS_INFO}": os_string,
        "{DESKTOP_ENVIRONMENT}": xdg_desktop,
        "{SESSION_TYPE}": session_type,
        "{KERNEL_VERSION}": kernel_version,
        "{GPU_INFO}": gpu_info,
        "{YEAR}": str(now.year),
    }


# -----------------------------------------------------------------------------
# 4. Factory & Main Logic
# -----------------------------------------------------------------------------
def get_provider(
    args,
    final_system_instruction,
    final_temperature,
    final_json_mode,
):
    preferred_language = args.preferred_language or "English"
    user_persona = args.user_persona or ""
    sys_details = get_system_details()

    if "{SYSTEM_LOGS}" in final_system_instruction:
        sys_logs = get_raw_boot_logs()
        final_system_instruction = final_system_instruction.replace(
            "{SYSTEM_LOGS}",
            sys_logs,
        )

    replacements = {
        "$aiPreferredLanguage": preferred_language,
        "{USER_PERSONA}": user_persona,
        **sys_details,
    }

    for key, value in replacements.items():
        if key in final_system_instruction:
            final_system_instruction = final_system_instruction.replace(key, str(value))

    common_args = {
        "api_key": args.api_key,
        "model": args.model,
        "system_instruction": final_system_instruction,
        "temperature": final_temperature,
        "json_mode": final_json_mode,
    }

    if args.provider == "local":
        return LocalProvider(**common_args)

    if args.provider == "ollama":
        common_args["base_url"] = args.base_url
        return OllamaProvider(**common_args)

    if args.provider == "gemini":  # or "gemini" in args.model.lower():
        return GeminiProvider(**common_args)

    if args.provider == "openrouter":
        return OpenRouterProvider(**common_args)

    # TODO: -> test logic
    base_url = args.base_url
    if args.provider == "deepseek" and not base_url:
        base_url = "https://api.deepseek.com"

    # TODO: -> test logic
    return OpenAIProvider(base_url=base_url, **common_args)
