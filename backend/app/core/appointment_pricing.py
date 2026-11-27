from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from unicodedata import normalize

from app.models.doctors import Doctor
from app.schemas.appointments import AppointmentPrice
from app.schemas.doctors import AppointmentCategory, AppointmentOffer


def category_for_reason(reason: str) -> AppointmentCategory:
    normalized = "".join(
        character for character in normalize("NFD", reason.casefold())
        if not "\u0300" <= character <= "\u036f"
    )
    match " ".join(normalized.split()):
        case "consulta" | "consulta medica":
            return "consultation"
        case "entrega de examenes":
            return "exam_delivery"
        case "cura":
            return "wound_care"
        case _:
            return "other"


def appointment_price(doctor: Doctor, category: AppointmentCategory, day: date) -> AppointmentPrice:
    overrides = {
        "exam_delivery": doctor.exam_delivery_fee,
        "wound_care": doctor.wound_care_fee,
    }
    fee = overrides.get(category)
    if fee is None:
        # Match the consultation price shown in the booking profile for older accounts.
        fee = Decimal(str(doctor.consultation_fee if doctor.consultation_fee is not None else 50))
    base_cents = int((fee * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    discount = 0
    if doctor.appointment_offer and base_cents > 0:
        offer = AppointmentOffer.model_validate(doctor.appointment_offer)
        if offer.starts_on <= day <= offer.ends_on and offer.category in ("all", category):
            discount = offer.percent
    total_cents = (base_cents * (100 - discount) + 50) // 100
    return AppointmentPrice(base_cents=base_cents, total_cents=total_cents, discount_percent=discount)
