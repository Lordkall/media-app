import json
import logging
import os
import re
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo

import requests
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.appointments import Appointment, AppointmentStatus
from app.models.doctors import Availability, Doctor, SPECIALTIES
from app.models.exchange_rate import ExchangeRate
from app.models.users import User

logger = logging.getLogger(__name__)

router = APIRouter()

SYSTEM_PROMPT = (
    'Actúa como Click, el asistente de citas de Salud Now. Analiza el mensaje del usuario tomando como '
    'referencia la fecha actual proporcionada. Extrae la especialidad médica solicitada y calcula la '
    'fecha exacta o el rango de fechas (fecha_inicio y fecha_fin) si el usuario menciona términos '
    'relativos como "este martes", "mañana" o "la semana de arriba / que viene". Devuelve únicamente '
    'un objeto JSON válido con la estructura: {"especialidad": "...", "fecha_inicio": "YYYY-MM-DD", '
    '"fecha_fin": "YYYY-MM-DD", "mensaje_respuesta": "..."}.'
)

# Mapeo de términos coloquiales o comunes a nombres oficiales de especialidades
SPECIALTY_SYNONYMS = {
    "odontologo": "Odontología General",
    "odontólogo": "Odontología General",
    "odontologa": "Odontología General",
    "odontóloga": "Odontología General",
    "odontologia": "Odontología General",
    "odontología": "Odontología General",
    "dentista": "Odontología General",
    "dientes": "Odontología General",
    "muela": "Odontología General",
    "muelas": "Odontología General",
    "gineco": "Ginecología y Obstetricia",
    "ginecologo": "Ginecología y Obstetricia",
    "ginecólogo": "Ginecología y Obstetricia",
    "ginecologa": "Ginecología y Obstetricia",
    "ginecóloga": "Ginecología y Obstetricia",
    "ginecologia": "Ginecología y Obstetricia",
    "ginecología": "Ginecología y Obstetricia",
    "embarazo": "Ginecología y Obstetricia",
    "cardiologo": "Cardiología Hemodinámica y Electrofisiología",
    "cardiólogo": "Cardiología Hemodinámica y Electrofisiología",
    "cardiologia": "Cardiología Hemodinámica y Electrofisiología",
    "cardiología": "Cardiología Hemodinámica y Electrofisiología",
    "corazon": "Cardiología Hemodinámica y Electrofisiología",
    "corazón": "Cardiología Hemodinámica y Electrofisiología",
    "pediatra": "Pediatría Neonatología",
    "pediatria": "Pediatría Neonatología",
    "pediatría": "Pediatría Neonatología",
    "niños": "Pediatría Neonatología",
    "bebe": "Pediatría Neonatología",
    "bebé": "Pediatría Neonatología",
    "dermatologo": "Dermatología Médico-Quirúrgica y Venereología",
    "dermatólogo": "Dermatología Médico-Quirúrgica y Venereología",
    "dermatologia": "Dermatología Médico-Quirúrgica y Venereología",
    "dermatología": "Dermatología Médico-Quirúrgica y Venereología",
    "piel": "Dermatología Médico-Quirúrgica y Venereología",
    "oftalmologo": "Oftalmología",
    "oftalmólogo": "Oftalmología",
    "oftalmologia": "Oftalmología",
    "oftalmología": "Oftalmología",
    "ojos": "Oftalmología",
    "vista": "Oftalmología",
    "traumatologo": "Cirugía Ortopédica y Traumatología",
    "traumatólogo": "Cirugía Ortopédica y Traumatología",
    "traumatologia": "Cirugía Ortopédica y Traumatología",
    "traumatología": "Cirugía Ortopédica y Traumatología",
    "huesos": "Cirugía Ortopédica y Traumatología",
    "urologo": "Urología",
    "urólogo": "Urología",
    "urologia": "Urología",
    "urología": "Urología",
    "neurologo": "Neurología",
    "neurólogo": "Neurología",
    "neurologia": "Neurología",
    "neurología": "Neurología",
    "otorrino": "Otorrinolaringología",
    "otorrinolaringologo": "Otorrinolaringología",
    "otorrinolaringólogo": "Otorrinolaringología",
    "alergologo": "Alergología",
    "alergólogo": "Alergología",
    "alergia": "Alergología",
    "alergias": "Alergología",
    "hematologo": "Hematología",
    "hematólogo": "Hematología",
    "hematologia": "Hematología",
    "hematología": "Hematología",
    "sangre": "Hematología",
    "gastroenterologo": "Gastroenterología",
    "gastroenterólogo": "Gastroenterología",
    "gastroenterologia": "Gastroenterología",
    "gastroenterología": "Gastroenterología",
    "estomago": "Gastroenterología",
    "estómago": "Gastroenterología",
    "oncologo": "Oncología",
    "oncólogo": "Oncología",
    "oncologia": "Oncología",
    "oncología": "Oncología",
    "cancer": "Oncología",
    "cáncer": "Oncología",
    "endocrinologo": "Endocrinología",
    "endocrinólogo": "Endocrinología",
    "endocrinologia": "Endocrinología",
    "endocrinología": "Endocrinología",
    "tiroides": "Endocrinología",
    "diabetes": "Endocrinología",
    "nefrologo": "Nefrología",
    "nefrólogo": "Nefrología",
    "nefrologia": "Nefrología",
    "nefrología": "Nefrología",
    "riñon": "Nefrología",
    "riñón": "Nefrología",
    "neumonologo": "Neumonología",
    "neumonólogo": "Neumonología",
    "neumonologia": "Neumonología",
    "neumonología": "Neumonología",
    "pulmon": "Neumonología",
    "pulmón": "Neumonología",
    "reumatologo": "Reumatología",
    "reumatólogo": "Reumatología",
    "reumatologia": "Reumatología",
    "reumatología": "Reumatología",
    "artritis": "Reumatología",
    "infectologo": "Infectología",
    "infectólogo": "Infectología",
    "infectologia": "Infectología",
    "infectología": "Infectología",
    "psiquiatra": "Psiquiatría",
    "psiquiatria": "Psiquiatría",
    "psiquiatría": "Psiquiatría",
    "psicologo": "Psicología",
    "psicólogo": "Psicología",
    "psicologia": "Psicología",
    "psicología": "Psicología",
    "geriatra": "Geriatría",
    "geriatria": "Geriatría",
    "geriatría": "Geriatría",
    "cirujano": "Cirugía General",
    "cirujana": "Cirugía General",
    "cirugia": "Cirugía General",
    "cirugía": "Cirugía General",
    "nutricionista": "Nutrición y Dietética",
    "nutricion": "Nutrición y Dietética",
    "nutrición": "Nutrición y Dietética",
    "medico general": "Medicina Familiar y Comunitaria",
    "médico general": "Medicina Familiar y Comunitaria",
    "medicina general": "Medicina Familiar y Comunitaria",
    "internista": "Medicina Interna",
}


class AssistantChatRequest(BaseModel):
    message: str
    current_date: Optional[str] = None


class DoctorSlotItem(BaseModel):
    doctor_id: int
    doctor_name: str
    specialty: str
    avatar_url: Optional[str] = None
    date: str  # YYYY-MM-DD
    date_display: str  # e.g. "Martes 10 Nov"
    time_block: str  # e.g. "09:30 AM"
    turn_number: int
    available_slots_count: int
    price_usd: float
    price_bcv: float
    bcv_rate: float
    clinic_name: Optional[str] = None
    location: Optional[str] = None


class AssistantChatResponse(BaseModel):
    especialidad: Optional[str] = None
    fecha_inicio: Optional[str] = None
    fecha_fin: Optional[str] = None
    mensaje_respuesta: str
    doctors: List[DoctorSlotItem] = []


def _format_spanish_date(d: date) -> str:
    days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    months = [
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
    ]
    weekday = days[d.weekday()]
    month = months[d.month - 1]
    return f"{weekday} {d.day:02d} {month}"


def _fallback_parse(message: str, ref_date: date) -> Dict[str, Any]:
    """Extractor semántico y de fechas para cuando Gemini Flash no esté disponible offline."""
    lower_msg = message.lower()

    # 1. Extraer especialidad
    found_spec = None
    for term, target in SPECIALTY_SYNONYMS.items():
        if re.search(r"\b" + re.escape(term) + r"\b", lower_msg):
            found_spec = target
            break

    if not found_spec:
        for spec in SPECIALTIES:
            if spec.lower() in lower_msg:
                found_spec = spec
                break

    if not found_spec:
        found_spec = "Medicina General"

    # 2. Extraer rango de fechas
    start_d = ref_date
    end_d = ref_date + timedelta(days=7)

    weekday_map = {
        "lunes": 0,
        "martes": 1,
        "miercoles": 2,
        "miércoles": 2,
        "jueves": 3,
        "viernes": 4,
        "sabado": 5,
        "sábado": 5,
        "domingo": 6,
    }

    if "hoy" in lower_msg:
        start_d = ref_date
        end_d = ref_date
    elif "mañana" in lower_msg and "pasado mañana" not in lower_msg:
        start_d = ref_date + timedelta(days=1)
        end_d = start_d
    elif "pasado mañana" in lower_msg:
        start_d = ref_date + timedelta(days=2)
        end_d = start_d
    elif "semana que viene" in lower_msg or "semana de arriba" in lower_msg or "proxima semana" in lower_msg or "próxima semana" in lower_msg:
        # Próxima semana (Lunes a Domingo siguiente)
        days_ahead = 7 - ref_date.weekday()
        start_d = ref_date + timedelta(days=days_ahead)
        end_d = start_d + timedelta(days=6)
    elif "fin de semana" in lower_msg:
        days_to_sat = (5 - ref_date.weekday()) % 7
        start_d = ref_date + timedelta(days=days_to_sat)
        end_d = start_d + timedelta(days=1)
    else:
        # Buscar día puntual: e.g. "este martes", "el viernes"
        matched_day = None
        for day_name, day_idx in weekday_map.items():
            if re.search(r"\b" + re.escape(day_name) + r"\b", lower_msg):
                matched_day = day_idx
                break
        if matched_day is not None:
            days_diff = (matched_day - ref_date.weekday()) % 7
            if days_diff == 0 and "proximo" not in lower_msg and "próximo" not in lower_msg:
                days_diff = 7 if "que viene" in lower_msg else 0
            elif days_diff == 0:
                days_diff = 7
            target = ref_date + timedelta(days=days_diff)
            start_d = target
            end_d = target

    spec_label = found_spec if found_spec != "Medicina General" else "especialistas"
    if start_d == end_d:
        date_str = _format_spanish_date(start_d)
        msg_resp = f"¡Hola! He buscado especialistas en {spec_label} disponibles para ti el {date_str}. Aquí tienes los turnos listos para agendar:"
    else:
        msg_resp = f"¡Hola! He buscado especialistas en {spec_label} entre el {_format_spanish_date(start_d)} y el {_format_spanish_date(end_d)}. Aquí tienes los turnos disponibles:"

    return {
        "especialidad": found_spec,
        "fecha_inicio": start_d.strftime("%Y-%m-%d"),
        "fecha_fin": end_d.strftime("%Y-%m-%d"),
        "mensaje_respuesta": msg_resp,
    }


async def _call_gemini_flash(message: str, current_date_str: str, ref_date: date) -> Dict[str, Any]:
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        logger.info("GEMINI_API_KEY no configurada. Usando extractor semántico local.")
        return _fallback_parse(message, ref_date)

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    payload = {
        "system_instruction": {
            "parts": [{"text": SYSTEM_PROMPT}]
        },
        "contents": [{
            "parts": [{
                "text": f"Fecha actual del sistema: {current_date_str}\nMensaje del usuario: {message}"
            }]
        }],
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.2,
        },
    }

    try:
        resp = requests.post(url, json=payload, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            candidates = data.get("candidates", [])
            if candidates:
                raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                raw_text = re.sub(r"^```json\s*", "", raw_text.strip(), flags=re.MULTILINE)
                raw_text = re.sub(r"```$", "", raw_text.strip(), flags=re.MULTILINE)
                parsed = json.loads(raw_text)
                if "especialidad" in parsed and "fecha_inicio" in parsed and "fecha_fin" in parsed:
                    return parsed
        else:
            logger.warning(f"Error de Gemini Flash ({resp.status_code}): {resp.text}")
    except Exception as e:
        logger.warning(f"Excepción al llamar a Gemini Flash: {e}")

    return _fallback_parse(message, ref_date)


@router.post("/chat", response_model=AssistantChatResponse)
async def chat_with_assistant(
    request: AssistantChatRequest,
    db: AsyncSession = Depends(get_db),
):
    caracas_tz = ZoneInfo("America/Caracas")
    now_caracas = datetime.now(caracas_tz)
    ref_date = now_caracas.date()

    if request.current_date:
        try:
            ref_date = datetime.strptime(request.current_date, "%Y-%m-%d").date()
        except Exception:
            pass

    current_date_str = ref_date.strftime("%Y-%m-%d")

    # 1. Llamar a Gemini Flash o fallback
    analysis = await _call_gemini_flash(request.message, current_date_str, ref_date)
    especialidad = analysis.get("especialidad", "Medicina General")
    fecha_inicio_str = analysis.get("fecha_inicio", current_date_str)
    fecha_fin_str = analysis.get("fecha_fin", current_date_str)
    mensaje_respuesta = analysis.get(
        "mensaje_respuesta",
        "¡Hola! Aquí tienes las opciones disponibles para tu consulta médica:"
    )

    try:
        start_d = datetime.strptime(fecha_inicio_str, "%Y-%m-%d").date()
    except Exception:
        start_d = ref_date
    try:
        end_d = datetime.strptime(fecha_fin_str, "%Y-%m-%d").date()
    except Exception:
        end_d = start_d + timedelta(days=7)

    # Asegurar orden
    if end_d < start_d:
        end_d, start_d = start_d, end_d

    # 2. Tasa BCV
    bcv_res = await db.execute(
        select(ExchangeRate).where(
            ExchangeRate.moneda_origen == "USD",
            ExchangeRate.moneda_destino == "VES"
        )
    )
    rate_obj = bcv_res.scalar_one_or_none()
    bcv_rate = float(rate_obj.tasa) if rate_obj and rate_obj.tasa else 36.5

    # 3. Consultar doctores en PostgreSQL
    # Buscar doctores cuya especialidad coincida
    doctors_query = select(Doctor, User).join(User, Doctor.user_id == User.id)
    all_docs_res = await db.execute(doctors_query)
    all_docs = all_docs_res.all()

    clean_spec = especialidad.strip().lower()
    matching_doctors = []
    other_doctors = []

    for doc, user in all_docs:
        specs = [s.lower() for s in (doc.specialties or [])]
        is_match = any(clean_spec in s or s in clean_spec for s in specs) if specs else False
        if not is_match and clean_spec in ("medicina general", "general", "especialista"):
            is_match = True
        if is_match:
            matching_doctors.append((doc, user))
        else:
            other_doctors.append((doc, user))

    is_fallback_general = False
    if not matching_doctors and clean_spec not in ("medicina general", "general", "especialista"):
        is_fallback_general = True
        for doc, user in all_docs:
            specs = [s.lower() for s in (doc.specialties or [])]
            if any("general" in s or "familiar" in s or "interna" in s for s in specs):
                matching_doctors.append((doc, user))
        if not matching_doctors:
            matching_doctors = all_docs

    target_docs = matching_doctors if matching_doctors else all_docs

    # 4. Consultar disponibilidades y turnos libres
    found_slots: List[DoctorSlotItem] = []

    for doc, user in target_docs:
        avails_res = await db.execute(
            select(Availability).where(
                Availability.doctor_id == doc.id,
                Availability.date >= start_d,
                Availability.date <= end_d,
            ).order_by(Availability.date.asc())
        )
        avails = avails_res.scalars().all()

        for a in avails:
            booked_res = await db.execute(
                select(Appointment).where(
                    Appointment.doctor_id == doc.id,
                    Appointment.appointment_date == a.date,
                    Appointment.status != AppointmentStatus.CANCELLED,
                )
            )
            booked_list = booked_res.scalars().all()

            try:
                start_h, start_m = map(int, a.start_time[:5].split(":"))
                end_h, end_m = map(int, a.end_time[:5].split(":"))
            except Exception:
                start_h, start_m = 8, 0
                end_h, end_m = 17, 0

            start_minutes = start_h * 60 + start_m
            end_minutes = end_h * 60 + end_m
            duration = a.slot_duration_minutes or 30
            if duration not in (30, 60, 90, 120):
                duration = 30

            is_today = a.date == now_caracas.date()
            current_minutes = now_caracas.hour * 60 + now_caracas.minute

            free_slots_for_day = []
            for offset in range(0, max(0, end_minutes - start_minutes), duration):
                if offset + duration > end_minutes - start_minutes:
                    continue
                turn = offset // duration + 1
                slot_min = start_minutes + offset
                slot_time = (datetime.min + timedelta(minutes=slot_min)).strftime("%I:%M %p")

                occupied = any(
                    slot_min < (
                        b.appointment_start_minutes
                        if b.appointment_start_minutes is not None
                        else start_minutes + (b.turn_number - 1) * 30
                    ) + (b.appointment_duration_minutes or 30)
                    and (
                        b.appointment_start_minutes
                        if b.appointment_start_minutes is not None
                        else start_minutes + (b.turn_number - 1) * 30
                    ) < slot_min + duration
                    for b in booked_list
                )

                if not occupied and (not is_today or slot_min > current_minutes):
                    free_slots_for_day.append({"turn": turn, "time": slot_time})

            if free_slots_for_day:
                first_slot = free_slots_for_day[0]
                prefix = "Dra." if user.gender in ["Femenino", "Femenina"] else "Dr."
                doc_name = f"{prefix} {user.first_name or ''} {user.last_name or ''}".strip()
                doc_spec = doc.specialties[0] if doc.specialties else especialidad
                fee = float(doc.consultation_fee or 50.0)
                fee_bcv = round(fee * bcv_rate, 2)

                avatar = user.avatar_url
                if not avatar and user.avatar_data:
                    avatar = f"data:{user.avatar_content_type or 'image/jpeg'};base64,{user.avatar_data}"

                found_slots.append(
                    DoctorSlotItem(
                        doctor_id=doc.id,
                        doctor_name=doc_name,
                        specialty=doc_spec,
                        avatar_url=avatar,
                        date=a.date.isoformat(),
                        date_display=_format_spanish_date(a.date),
                        time_block=first_slot["time"],
                        turn_number=first_slot["turn"],
                        available_slots_count=len(free_slots_for_day),
                        price_usd=fee,
                        price_bcv=fee_bcv,
                        bcv_rate=bcv_rate,
                        clinic_name=doc.clinic_info or "Consultorio Privado",
                        location=user.state or "Caracas",
                    )
                )

    # Si no se encontraron turnos en la fecha solicitada, buscar próximas aperturas de esos doctores
    if not found_slots and matching_doctors:
        fallback_end = start_d + timedelta(days=21)
        for doc, user in matching_doctors:
            avails_res = await db.execute(
                select(Availability).where(
                    Availability.doctor_id == doc.id,
                    Availability.date >= start_d,
                    Availability.date <= fallback_end,
                ).order_by(Availability.date.asc())
            )
            avails = avails_res.scalars().all()
            for a in avails:
                prefix = "Dra." if user.gender in ["Femenino", "Femenina"] else "Dr."
                doc_name = f"{prefix} {user.first_name or ''} {user.last_name or ''}".strip()
                doc_spec = doc.specialties[0] if doc.specialties else especialidad
                fee = float(doc.consultation_fee or 50.0)
                fee_bcv = round(fee * bcv_rate, 2)
                avatar = user.avatar_url or (f"data:{user.avatar_content_type};base64,{user.avatar_data}" if user.avatar_data else None)

                found_slots.append(
                    DoctorSlotItem(
                        doctor_id=doc.id,
                        doctor_name=doc_name,
                        specialty=doc_spec,
                        avatar_url=avatar,
                        date=a.date.isoformat(),
                        date_display=_format_spanish_date(a.date),
                        time_block=a.start_time,
                        turn_number=1,
                        available_slots_count=3,
                        price_usd=fee,
                        price_bcv=fee_bcv,
                        bcv_rate=bcv_rate,
                        clinic_name=doc.clinic_info or "Consultorio Privado",
                        location=user.state or "Caracas",
                    )
                )
                if len(found_slots) >= 3:
                    break
            if len(found_slots) >= 5:
                break

        if found_slots:
            if is_fallback_general:
                mensaje_respuesta = (
                    f"En este momento no contamos con especialistas registrados en **{especialidad}**. "
                    f"Sin embargo, te recomendamos consultar con **Medicina General** para una evaluación inicial o emisión de referencia médica. "
                    f"Aquí tienes médicos generales disponibles con turnos próximos:"
                )
            else:
                mensaje_respuesta = (
                    f"No encontré cupos libres exactamente entre el {fecha_inicio_str} y el {fecha_fin_str}, "
                    f"pero aquí tienes las opciones más próximas de especialistas en {especialidad}:"
                )

    if not found_slots:
        if is_fallback_general:
            mensaje_respuesta = (
                f"En este momento no disponemos de especialistas en **{especialidad}** ni turnos de consulta general abiertos. "
                f"Por favor intenta con otra fecha o especialidad."
            )
        else:
            mensaje_respuesta = (
                f"He consultado a nuestros especialistas en {especialidad}, pero en este momento no tienen cupos "
                f"libres registrados para el rango del {fecha_inicio_str} al {fecha_fin_str}. "
                f"¿Te gustaría buscar en otra fecha o consultar otra especialidad?"
            )

    return AssistantChatResponse(
        especialidad=especialidad,
        fecha_inicio=fecha_inicio_str,
        fecha_fin=fecha_fin_str,
        mensaje_respuesta=mensaje_respuesta,
        doctors=found_slots,
    )

