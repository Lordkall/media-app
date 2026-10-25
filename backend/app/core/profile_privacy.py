import re


_PHONE_LIKE_SEQUENCE = re.compile(r"(?<!\d)\+?\d(?:[\s().-]*\d){7,}(?!\d)")


def redact_phone_numbers(text: str | None, show_whatsapp: bool) -> str | None:
    if show_whatsapp or not text:
        return text
    sanitized = _PHONE_LIKE_SEQUENCE.sub("", text)
    sanitized = re.sub(r"[ \t]{2,}", " ", sanitized)
    sanitized = re.sub(r"\s+([,.;])", r"\1", sanitized)
    return sanitized.strip()
