from datetime import date, datetime
from zoneinfo import ZoneInfo


AGE_RANGES = (
    ("0-12", 0, 12),
    ("13-17", 13, 17),
    ("18-29", 18, 29),
    ("30-44", 30, 44),
    ("45-59", 45, 59),
    ("60+", 60, None),
)


def local_today() -> date:
    return datetime.now(ZoneInfo("America/Caracas")).date()


def calculate_age(birth_date: date | None, as_of: date | None = None) -> int | None:
    if not birth_date:
        return None
    as_of = as_of or local_today()
    if birth_date > as_of:
        return None
    return as_of.year - birth_date.year - (
        (as_of.month, as_of.day) < (birth_date.month, birth_date.day)
    )


def age_range(age: int | None) -> str:
    if age is None:
        return "Sin dato"
    for label, minimum, maximum in AGE_RANGES:
        if age >= minimum and (maximum is None or age <= maximum):
            return label
    return "Sin dato"


def gender_bucket(gender: str | None) -> str:
    value = (gender or "").strip().lower()
    if value in {"masculino", "hombre", "male"}:
        return "masculino"
    if value in {"femenino", "femenina", "mujer", "female"}:
        return "femenino"
    return "otro_o_sin_especificar"


def empty_age_ranges() -> dict[str, int]:
    return {label: 0 for label, _, _ in AGE_RANGES} | {"Sin dato": 0}


def empty_gender_counts() -> dict[str, int]:
    return {
        "masculino": 0,
        "femenino": 0,
        "otro_o_sin_especificar": 0,
    }
