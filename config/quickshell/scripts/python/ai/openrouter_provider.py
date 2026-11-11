from base_provider import LLMProvider
from openai import OpenAI

try:  # package layout (scripts/python on sys.path)
    from .provider_limits import PROVIDER_REQUEST_DEADLINE_S
except ImportError:  # flat layout (cwd=scripts/python/ai)
    from provider_limits import PROVIDER_REQUEST_DEADLINE_S


# -----------------------------------------------------------------------------
# OpenRouter Provider
# -----------------------------------------------------------------------------
class OpenRouterProvider(LLMProvider):
    def __init__(
        self,
        api_key,
        model,
        system_instruction=None,
        temperature=0.7,
        json_mode=False,
    ):
        # OpenRouter يستخدم دائماً هذا الرابط الأساسي
        self.base_url = "https://openrouter.ai/api/v1"
        super().__init__(api_key, model, system_instruction, temperature, json_mode)

    def generate(self, message, history):
        # تعريف العميل مع رابط OpenRouter
        client = OpenAI(
            api_key=self.api_key,
            base_url=self.base_url,
            # Phase 6 (§10.3): shared request deadline where the SDK exposes it.
            timeout=PROVIDER_REQUEST_DEADLINE_S,
        )

        messages = []
        # إضافة تعليمات النظام إن وجدت
        if self.system_instruction:
            messages.append({"role": "system", "content": self.system_instruction})

        # إضافة التاريخ (History)
        messages.extend(history)

        # إضافة رسالة المستخدم الحالية
        messages.append({"role": "user", "content": message})

        # إعداد وضع JSON إن وجد
        # ملاحظة: ليس كل النماذج في OpenRouter تدعم json_object
        resp_format = {"type": "json_object"} if self.json_mode else None

        # طلب الرد
        # يمكنك إضافة headers إضافية هنا لـ OpenRouter لتعريف تطبيقك (اختياري)
        response = client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=self.temperature,
            response_format=resp_format,
            # extra_headers={
            #     "HTTP-Referer": "YOUR_SITE_URL", # اختياري لإظهار تطبيقك في OpenRouter rankings
            #     "X-Title": "YOUR_APP_NAME",     # اختياري
            # }
        )

        return response.choices[0].message.content, {}
