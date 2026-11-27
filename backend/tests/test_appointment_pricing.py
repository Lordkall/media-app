from datetime import date, timedelta
from decimal import Decimal
from unittest import TestCase

from pydantic import ValidationError

from app.core.appointment_pricing import appointment_price, category_for_reason
from app.models.doctors import Doctor
from app.schemas.doctors import AppointmentOffer, DoctorUpdate


class AppointmentPricingTest(TestCase):
    def setUp(self):
        self.day = date(2026, 11, 26)
        self.doctor = Doctor(consultation_fee=40.0, exam_delivery_fee=Decimal("0"))

    def set_offer(self, category, percent):
        self.doctor.appointment_offer = AppointmentOffer(
            category=category, percent=percent,
            starts_on=self.day, ends_on=self.day + timedelta(days=1),
        ).model_dump(mode="json")

    def test_free_uses_zero_and_blank_or_other_uses_consultation(self):
        self.assertEqual(appointment_price(self.doctor, "exam_delivery", self.day).total_cents, 0)
        self.assertEqual(appointment_price(self.doctor, "other", self.day).total_cents, 4000)
        self.assertEqual(appointment_price(self.doctor, "wound_care", self.day).total_cents, 4000)
        self.doctor.wound_care_fee = Decimal("12.75")
        self.assertEqual(appointment_price(self.doctor, "wound_care", self.day).total_cents, 1275)

    def test_category_offer_includes_both_endpoints_of_date_range(self):
        self.set_offer("consultation", 25)
        for days, cents in [(-1, 4000), (0, 3000), (1, 3000), (2, 4000)]:
            with self.subTest(days=days):
                price = appointment_price(self.doctor, "consultation", self.day + timedelta(days=days))
                self.assertEqual(price.total_cents, cents)
        self.assertEqual(appointment_price(self.doctor, "other", self.day).total_cents, 4000)

    def test_offer_for_all_rounds_once_and_preserves_free_services(self):
        self.set_offer("all", 50)
        self.doctor.wound_care_fee = Decimal("10.01")
        price = appointment_price(self.doctor, "wound_care", self.day)
        self.assertEqual((price.base_cents, price.total_cents, price.discount_percent), (1001, 501, 50))
        free = appointment_price(self.doctor, "exam_delivery", self.day)
        self.assertEqual((free.total_cents, free.discount_percent), (0, 0))
        self.assertEqual(appointment_price(self.doctor, "other", self.day).total_cents, 2000)

    def test_legacy_motives_and_backward_compatible_price(self):
        self.doctor.consultation_fee = None
        self.assertEqual(category_for_reason("  Entrega de exámenes  "), "exam_delivery")
        self.assertEqual(category_for_reason("Solicitud de informe"), "other")
        self.assertEqual(appointment_price(self.doctor, "other", self.day).total_cents, 5000)

    def test_update_distinguishes_free_reset_and_untouched(self):
        data = DoctorUpdate(exam_delivery_fee="0", wound_care_fee=None, appointment_offer=None)
        self.assertEqual(data.model_dump(exclude_unset=True), {
            "exam_delivery_fee": Decimal("0"),
            "wound_care_fee": None,
            "appointment_offer": None,
        })
        for fee in ["-1", "2.001", "NaN"]:
            with self.subTest(fee=fee), self.assertRaises(ValidationError):
                DoctorUpdate(exam_delivery_fee=fee)

    def test_rejects_invalid_percent_and_inverted_dates(self):
        with self.assertRaises(ValidationError):
            AppointmentOffer(category="all", percent=101, starts_on=self.day, ends_on=self.day)
        with self.assertRaises(ValidationError):
            AppointmentOffer(
                category="all", percent=10,
                starts_on=self.day, ends_on=self.day - timedelta(days=1),
            )
