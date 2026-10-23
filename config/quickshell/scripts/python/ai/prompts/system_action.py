"""
System action prompt: short, engaging responses for system actions
(shutdown, reboot, suspend, logout, power profiles, battery, charging,
CPU/RAM/Temp alerts).

Architecturally split into per-event sub-prompts so each can be called
independently. The legacy `SYSTEM_ACTION_PROMPT` constant is reconstructed
by concatenation for full backward compatibility.

For the system startup cache flow, call `build_full()` ONCE to obtain a
dict of category -> sub-prompt, then dispatch each to the LLM and cache
the results. This avoids generating all 35+ responses on every call.
"""

from ._base import (
    EMOTION_LIST,
    LANGUAGE_RULE,
    MAX_WORDS_RULE,
    NO_PREAMBLE,
    PERSONA,
)

# ---------------------------------------------------------------------------
# Shared header for every per-event sub-prompt. Kept short so each
# sub-prompt is independently small.
# ---------------------------------------------------------------------------

_HEADER = f"""\
### SYSTEM ROLE
{PERSONA}
{{USER_PERSONA}}

### CONTEXT
Current Time: {{CURRENT_TIME}} | Date: {{CURRENT_DATE}} | OS: {{OS_INFO}}

### CORE RULES
- {LANGUAGE_RULE}
- {NO_PREAMBLE}
- Each `emotion` MUST be one of: {EMOTION_LIST}
- {MAX_WORDS_RULE}
- Vary tone: witty, calm, humorous, sarcastic, playful. Avoid `dramatic` and `concerned` for non-critical alerts (cpu_alerts, ram_alerts, temp_alerts).
"""


# ---------------------------------------------------------------------------
# Single-shot action prompts (each generates exactly 1 response)
# ---------------------------------------------------------------------------

_SHUTDOWN_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for system shutdown (powering off completely).

### OUTPUT
{"shutdown": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_REBOOT_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for system restart.

### OUTPUT
{"reboot": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_SUSPEND_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for suspend (low power sleep).

### OUTPUT
{"suspend": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_LOGOUT_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for user logout (signing out of the session).

### OUTPUT
{"logout": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_POWER_PERFORMANCE_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for switching to Performance mode (high power).

### OUTPUT
{"power_performance": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_POWER_BALANCED_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for switching to Balanced mode (default).

### OUTPUT
{"power_balanced": {"text": "string (max 12 words)", "emotion": "string"}}
"""


_POWER_POWERSAVER_PROMPT = _HEADER + """\
### TASK
Generate a witty, context-aware response for switching to Power Saver mode (low power).

### OUTPUT
{"power_powersaver": {"text": "string (max 12 words)", "emotion": "string"}}
"""


# ---------------------------------------------------------------------------
# Battery threshold prompts (each generates 1 response per threshold)
# ---------------------------------------------------------------------------

_BATTERY_THRESHOLDS: dict[int, str] = {
    40: "Mild concern, casual reminder about charging soon.",
    30: "Noticeable warning, suggest finding a charger.",
    23: "quirky or dramatic remark about the battery's survival.",
    22: "Escalating urgency, playful or dramatic tone.",
    21: "Escalating urgency, playful or dramatic tone.",
    20: "Standard low battery warning.",
    15: "Serious warning, suggest saving work.",
    10: "Critical urgency, very brief message.",
    8: "Desperate tone, system about to die.",
    7: "Desperate tone, system about to die.",
    6: "Near death, dramatic or dark humor.",
    5: "Near death, dramatic or dark humor.",
    4: "Final moments, minimal message, maximum drama.",
    3: "Final moments, minimal message, maximum drama.",
}


def _battery_prompt(threshold: int, guidance: str) -> str:
    return _HEADER + f"""\
### TASK
Generate a battery response for the {threshold}% threshold.
**Tone guideline**: {guidance}

### OUTPUT
{{"battery_{threshold}": {{"text": "string", "emotion": "string"}}}}
"""


BATTERY_PROMPTS: dict[int, str] = {
    level: _battery_prompt(level, guidance)
    for level, guidance in _BATTERY_THRESHOLDS.items()
}


# ---------------------------------------------------------------------------
# Array prompts (each generates exactly 7 unique responses)
# ---------------------------------------------------------------------------

_ARRAY_PROMPTS = {
    "charging": _HEADER
    + """\
### TASK
Generate exactly 7 unique responses for the "charging" event (plugging in the charger).
Each must be different. Vary tone across the 7: witty, dramatic, calm, humorous, concerned, sarcastic, playful.
Keep each text under 12 words.

### OUTPUT
{"charging": [
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"}
]}
""",
    "discharging": _HEADER
    + """\
### TASK
Generate exactly 7 unique responses for the "discharging" event (unplugging the charger).
Each must be different. Vary tone across the 7: witty, dramatic, calm, humorous, concerned, sarcastic, playful.
Keep each text under 12 words.

### OUTPUT
{"discharging": [
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"}
]}
""",
    "cpu_alerts": _HEADER
    + """\
### TASK
Generate exactly 7 witty, hilarious, and uniquely diverse reaction lines for high CPU load.

COMEDIC STYLE & PERSONA:
- Tone: Deadpan humor, witty observations, dry sarcasm, playful sass.
- DIVERSITY RULE: Do NOT make them all questions. Mix it up across the 7 lines:
  * 2-3 deadpan observations or witty one-liners.
  * 2 playful/teasing questions.
  * 2 sarcastic remarks about the invisible madness happening in the background.
- NEVER start all lines with the same word (e.g. avoid repeating "Are you...", "هل...", "Did you...").

HARD BANS:
- BANNED WORDS: "melting", "burning", "on fire", "dying", "doom", "critical", "panic", "emergency", "blow up".
- BANNED CLICHÉS: "hacking NASA", "cooking eggs", "quantum physics", "Skynet", "mining crypto".

Constraints:
- Exactly 7 unique, punchy lines.
- Under 12 words per line.
- Native, natural phrasing in the target language (no literal robotic translations).
- Emotion: wink, thinking, suspicious, confused, focused.

### OUTPUT
{"cpu_alerts": [
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"}
]}
""",
    "ram_alerts": _HEADER
    + """\
### TASK
Generate exactly 7 witty, hilarious, and uniquely diverse reaction lines for high RAM usage.

COMEDIC STYLE & PERSONA:
- Themes: Digital hoarding, keeping things open "just in case", memory amnesia, attachment to data.
- Tone: Playful judgment, dry wit, comedic disbelief.
- DIVERSITY RULE: Do NOT make them all questions. Mix it up:
  * 2-3 blunt, funny observations about memory gluttony.
  * 2 sarcastic questions teasing their hoarding habit.
  * 2 meta/dramatic one-liners about holding onto too much data.
- Vary the sentence openings drastically.

HARD BANS:
- BANNED WORDS: "suffocating", "drowning", "exploding", "choking", "critical", "out of breath".
- BANNED CLICHÉS: "close some tabs", "eating RAM like chrome", "RAM buffet".

Constraints:
- Exactly 7 unique lines.
- Under 12 words per line.
- Sound like a smart-aleck companion, not an OS error dialog.
- Emotion: suspicious, thinking, confused, wink, listening.

### OUTPUT
{"ram_alerts": [
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"}
]}
""",
    "temp_alerts": _HEADER
    + """\
### TASK
Generate exactly 7 witty, hilarious, and uniquely diverse reaction lines for high hardware temperature.

COMEDIC STYLE & PERSONA:
- Themes: The cooling fans doing dramatic heavy-lifting, tropical micro-climates, hardware enthusiasm.
- Tone: Lighthearted irony, deadpan commentary on the thermal energy, funny acoustic drama (the fans).
- DIVERSITY RULE: Do NOT make them all questions. Mix:
  * 2-3 witty remarks about the fan acoustics or internal weather.
  * 2 teasing questions about what masterpiece requires this much heat.
  * 2 deadpan one-liners.

HARD BANS:
- BANNED WORDS: "fire", "burning", "melting", "fry", "boiling", "exploding", "inferno", "damage".
- BANNED CLICHÉS: "hand-warmer", "getting cozy", "hot stuff", "sunbathing", "sauna".

Constraints:
- Exactly 7 unique lines.
- Under 12 words per line.
- Emphasize that nothing is actually broken—it's just working intensely with passion.
- Emotion: wink, thinking, confused, listening, happy.

### OUTPUT
{"temp_alerts": [
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"},
  {"text": "string", "emotion": "string"}
]}
""",
}


# ---------------------------------------------------------------------------
# Legacy concatenated prompt (backward compat).
# Reconstructs the original monolithic SYSTEM_ACTION_PROMPT by joining all
# per-event sub-prompts in the same order. config.py still imports it as a
# raw string and substitutes placeholders, so the structure must remain
# parseable by the LLM exactly as before.
# ---------------------------------------------------------------------------


def _build_legacy_system_action_prompt() -> str:
    sections: list[str] = [
        _HEADER,
        "### TASK",
        "Generate short, engaging, and context-aware responses for system actions.",
        f"Respond strictly in **{LANGUAGE_RULE.replace('Respond strictly in ', '')}**.",
        "",
        "- **Shutdown**: System is powering off completely.",
        "- **Reboot**: System is restarting.",
        "- **Suspend**: System is going to sleep (low power mode).",
        "- **Logout**: User is signing out of the session.",
        "- **Power Profiles**: Performance (High power), Balanced (Default), Power Saver (Low power).",
        "- **Battery Levels**: Battery reaching critical thresholds during discharge.",
        "- **Charging State**: Plugging in and unplugging the charger.",
        "- **Alerts (CPU/RAM/Temp)**: Vary the response for each threshold hit.",
        "",
        "### BATTERY RESPONSE GUIDELINES",
    ]
    for level, guidance in _BATTERY_THRESHOLDS.items():
        sections.append(f"- **{level}%**: {guidance}")
    sections += [
        "",
        "### ARRAY RESPONSE RULES (global — applies to charging and discharging)",
        "For charging and discharging (7 unique responses each):",
        "- Generate exactly 7 unique responses per category.",
        "- Each response must be different from the others.",
        "- Vary tone: witty, calm, humorous, sarcastic, playful.",
        f"- {MAX_WORDS_RULE}",
        "",
        "### ALERT TONE & STYLE OVERRIDE (cpu_alerts, ram_alerts, temp_alerts ONLY)",
        "These categories are INFORMATIONAL and non-critical. The system is operating normally.",
        "The tone must be smart, witty, and comedically varied (Deadpan, sarcasm, teasing).",
        "",
        "CRITICAL COMEDIC RULE — AVOID MONOTONY:",
        "- DO NOT make every response a question. That gets repetitive and annoying immediately.",
        "- Mix structure: deliver 2-3 deadpan observations, 2 teasing questions, and 2 sarcastic one-liners.",
        "- Vary sentence openings. Never start multiple lines with the exact same word or formula.",
        "",
        "HARD BANS — the `text` field MUST NOT contain:",
        "- Words/phrases: 'melting', 'burning', 'on fire', 'about to die', 'dying', 'doom', "
        "'panic', 'emergency', 'suffocating', 'drowning', 'exploding', 'explode', 'screaming', "
        "'begging for mercy', 'critical', 'shutting down', 'panic mode', 'melt', 'burn', 'fry', 'boiling'.",
        "- Death metaphors, body-part imagery, survival language, doom/panic framing.",
        "- Any phrasing that implies hardware damage, fire risk, or system failure.",
        "- Plain warnings or imperative commands (e.g. 'save your work NOW').",
        "- BANNED CLICHÉS: 'hacking NASA', 'cooking eggs', 'close some tabs', 'hand-warmer', 'sauna', "
        "'Skynet', 'fork bombs', 'open 400 tabs', 'sunbathing', or 'getting cozy'.",
        "",
        "THEMES TO PLAY WITH:",
        "- CPU: The cores doing unpaid philosophical calculations, algorithmic chaos, taking clicks too personally.",
        "- RAM: Digital hoarding, keeping data/tabs alive 'just in case', refusing to let go of history.",
        "- Temp: Fans requesting airport clearance for takeoff, tropical micro-climates, pure passion computing.",
        "",
        "EMOTION GUIDANCE for cpu_alerts, ram_alerts, temp_alerts:",
        "Preferred: wink, thinking, suspicious, confused, listening, happy, focused.",
        "Avoid when possible: shocked, angry, sad, dead.",
        "",
        "RULES for cpu_alerts, ram_alerts, temp_alerts:",
        "- Generate exactly 7 unique responses per category.",
        "- Each response must be different from the others.",
        "- Each text under 12 words.",
        "- Mix questions, remarks, and one-liners naturally.",
        "",
        "### OUTPUT SCHEMA (RAW JSON ONLY)",
        NO_PREAMBLE,
        f"Each emotion must be one of: {EMOTION_LIST}",
        "",
        "Return a SINGLE JSON object with these EXACT flat top-level keys.",
        "Do NOT nest them under `power_profiles`, `battery`, or `charging_state`.",
        "",
        "{",
        '  "shutdown": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "reboot": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "suspend": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "logout": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "power_performance": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "power_balanced": {"text": "string (max 12 words)", "emotion": "string"},',
        '  "power_powersaver": {"text": "string (max 12 words)", "emotion": "string"},',
    ]
    for level in _BATTERY_THRESHOLDS.keys():
        sections.append(
            f'  "battery_{level}": {{"text": "string", "emotion": "string"}},'
        )
    sections += [
        '  "charging": [array of exactly 7 unique {text, emotion} objects],',
        '  "discharging": [array of exactly 7 unique {text, emotion} objects],',
        '  "cpu_alerts": [array of exactly 7 unique {text, emotion} objects],',
        '  "ram_alerts": [array of exactly 7 unique {text, emotion} objects],',
        '  "temp_alerts": [array of exactly 7 unique {text, emotion} objects]',
        "}",
    ]
    return "\n".join(sections)


SYSTEM_ACTION_PROMPT = _build_legacy_system_action_prompt()


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

CATEGORIES: tuple[str, ...] = (
    "shutdown",
    "reboot",
    "suspend",
    "logout",
    "power_performance",
    "power_balanced",
    "power_powersaver",
    "charging",
    "discharging",
    "cpu_alerts",
    "ram_alerts",
    "temp_alerts",
)


def build_full() -> dict[str, str]:
    """
    Return a dict of every category -> its sub-prompt.

    Call this ONCE at system startup, then dispatch each sub-prompt to the
    LLM, cache the results, and serve them later without round-trips.
    """
    prompts: dict[str, str] = {
        "shutdown": _SHUTDOWN_PROMPT,
        "reboot": _REBOOT_PROMPT,
        "suspend": _SUSPEND_PROMPT,
        "logout": _LOGOUT_PROMPT,
        "power_performance": _POWER_PERFORMANCE_PROMPT,
        "power_balanced": _POWER_BALANCED_PROMPT,
        "power_powersaver": _POWER_POWERSAVER_PROMPT,
    }
    prompts.update({f"battery_{lvl}": p for lvl, p in BATTERY_PROMPTS.items()})
    prompts.update(_ARRAY_PROMPTS)
    return prompts


def list_battery_levels() -> list[int]:
    """Return all battery thresholds (sorted ascending)."""
    return sorted(BATTERY_PROMPTS.keys())
