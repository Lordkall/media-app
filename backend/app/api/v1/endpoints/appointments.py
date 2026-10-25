from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, delete
from sqlalchemy.orm import joinedload
from sqlalchemy.exc import IntegrityError
from app.api.dependencies import get_db, get_current_patient
from app.api.v1.endpoints.users import get_current_user
from app.models.users import User, RoleEnum
from app.models.appointments import Appointment, AppointmentStatus
from app.schemas.appointments import AppointmentCreate, AppointmentResponse
from datetime import datetime, timedelta, date as date_type
from zoneinfo import ZoneInfo
from app.models.doctors import Doctor, Availability
from app.models.patients import Patient
from app.services.twilio_service import normalize_whatsapp_phone
from pydantic import BaseModel, Field, field_validator

router = APIRouter()

class RescheduleAppointment(BaseModel):
    appointment_date: date_type
    turn_number: int = Field(gt=0)


class ManualAppointmentCreate(BaseModel):
    appointment_date: date_type
    turn_number: int = Field(gt=0)
    patient_first_name: str = Field(min_length=1, max_length=100)
    patient_last_name: str = Field(min_length=1, max_length=100)
    patient_phone: str = Field(min_length=5, max_length=30)
    appointment_reason: str = Field(min_length=1, max_length=500)

    @field_validator("patient_first_name", "patient_last_name", "patient_phone", "appointment_reason")
    @classmethod
    def strip_and_require_value(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Este dato es obligatorio")
        return value

async def _staff_doctor(current_user: User, db: AsyncSession) -> Doctor:
    if current_user.role == RoleEnum.DOCTOR:
        doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    elif current_user.role == RoleEnum.ASSISTANT:
        if not current_user.linked_doctor_id:
            raise HTTPException(status_code=403, detail="El asistente no está vinculado a un doctor")
        doctor = await db.get(Doctor, current_user.linked_doctor_id)
    else:
        raise HTTPException(status_code=403, detail="Solo doctores y asistentes pueden agendar citas manuales")
    if not doctor:
        raise HTTPException(status_code=404, detail="No se encontró el perfil del doctor")
    return doctor

def _slot_label(start_minutes: int, turn_number: int, duration_minutes: int = 30) -> str:
    minutes = start_minutes + (turn_number - 1) * duration_minutes
    return (datetime.min + timedelta(minutes=minutes)).strftime("%I:%M %p")


async def _booked_intervals(db: AsyncSession, doctor_id: int, appointment_date: date_type, legacy_start: int):
    appointments = (await db.scalars(select(Appointment).where(
        Appointment.doctor_id == doctor_id,
        Appointment.appointment_date == appointment_date,
        Appointment.status != AppointmentStatus.CANCELLED,
    ))).all()
    return [
        (
            appointment.appointment_start_minutes
            if appointment.appointment_start_minutes is not None
            else legacy_start + (appointment.turn_number - 1) * 30,
            appointment.appointment_duration_minutes or 30,
        )
        for appointment in appointments
    ]


def _overlaps(start: int, duration: int, booked: list[tuple[int, int]]) -> bool:
    return any(start < booked_start + booked_duration and booked_start < start + duration
               for booked_start, booked_duration in booked)

@router.get("/manual/slots")
async def get_manual_slots(
    appointment_date: date_type = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doctor = await _staff_doctor(current_user, db)
    availability = await db.scalar(select(Availability).where(
        Availability.doctor_id == doctor.id, Availability.date == appointment_date
    ))
    if not availability:
        return {"date": appointment_date.isoformat(), "slots": []}
    start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
    end_hour, end_minute = map(int, availability.end_time[:5].split(":"))
    start_minutes = start_hour * 60 + start_minute
    duration = availability.slot_duration_minutes or 30
    if duration not in (30, 60, 120):
        duration = 30
    slot_count = max(0, (end_hour * 60 + end_minute - start_minutes) // duration)
    booked = await _booked_intervals(db, doctor.id, appointment_date, start_minutes)
    local_now = datetime.now(ZoneInfo("America/Caracas"))
    slots = []
    for turn in range(1, slot_count + 1):
        slot_start = start_minutes + (turn - 1) * duration
        if appointment_date < local_now.date() or (
            appointment_date == local_now.date()
            and slot_start <= local_now.hour * 60 + local_now.minute
        ):
            continue
        if not _overlaps(slot_start, duration, booked):
            slots.append({"turn_number": turn, "time_block": _slot_label(start_minutes, turn, duration)})
    return {"date": appointment_date.isoformat(), "slot_duration_minutes": duration, "slots": slots}

@router.post("/manual", status_code=status.HTTP_201_CREATED)
async def create_manual_appointment(
    payload: ManualAppointmentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doctor = await _staff_doctor(current_user, db)
    local_now = datetime.now(ZoneInfo("America/Caracas"))
    try:
        async with db.begin_nested():
            # Serialize booking paths for this doctor; the unique index also
            # protects the slot if another writer does not take this lock.
            doctor = await db.scalar(
                select(Doctor).where(Doctor.id == doctor.id).with_for_update()
            )
            availability = await db.scalar(
                select(Availability).where(
                    Availability.doctor_id == doctor.id,
                    Availability.date == payload.appointment_date,
                )
            )
            if not availability:
                raise HTTPException(
                    status_code=400,
                    detail="El doctor no tiene disponibilidad ese día",
                )
            start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
            end_hour, end_minute = map(int, availability.end_time[:5].split(":"))
            start_minutes = start_hour * 60 + start_minute
            end_minutes = end_hour * 60 + end_minute
            duration = availability.slot_duration_minutes or 30
            if duration not in (30, 60, 120):
                raise HTTPException(status_code=400, detail="La duración de los turnos configurada no es válida")
            slot_count = max(0, (end_minutes - start_minutes) // duration)
            if payload.turn_number > slot_count:
                raise HTTPException(
                    status_code=400,
                    detail="El turno está fuera del horario disponible",
                )
            slot_start = start_minutes + (payload.turn_number - 1) * duration
            if payload.appointment_date < local_now.date() or (
                payload.appointment_date == local_now.date()
                and slot_start <= local_now.hour * 60 + local_now.minute
            ):
                raise HTTPException(status_code=400, detail="Ese horario ya pasó")
            booked = await _booked_intervals(db, doctor.id, payload.appointment_date, start_minutes)
            if _overlaps(slot_start, duration, booked):
                raise HTTPException(
                    status_code=409,
                    detail="Ese horario acaba de ser reservado; actualiza los turnos",
                )
            appointment = Appointment(
                doctor_id=doctor.id,
                patient_id=None,
                appointment_date=payload.appointment_date,
                turn_number=payload.turn_number,
                appointment_start_minutes=slot_start,
                appointment_duration_minutes=duration,
                patient_first_name=payload.patient_first_name,
                patient_last_name=payload.patient_last_name,
                patient_phone=normalize_whatsapp_phone(payload.patient_phone) or payload.patient_phone,
                appointment_reason=payload.appointment_reason,
                booking_source="manual",
                status=AppointmentStatus.SCHEDULED,
            )
            db.add(appointment)
            await db.flush()
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Ese horario acaba de ser reservado; actualiza los turnos")
    await db.commit()
    return {
        "id": appointment.id,
        "doctor_id": doctor.id,
        "date": appointment.appointment_date.isoformat(),
        "turn_number": appointment.turn_number,
        "time_block": _slot_label(start_minutes, appointment.turn_number, duration),
        "status": appointment.status.value,
    }

@router.post("/", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    appointment_in: AppointmentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    req_date = appointment_in.appointment_date

    # Fetch patient ID from current user
    if current_user.role.value != "patient":
        raise HTTPException(status_code=403, detail="Only patients can create appointments")
    
    patient_query = select(Patient).where(Patient.user_id == current_user.id)
    patient = (await db.execute(patient_query)).scalar_one_or_none()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
        
    current_patient_id = patient.id

    async with db.begin_nested():
        doctor_lock_query = select(Doctor).where(Doctor.id == appointment_in.doctor_id).with_for_update()
        doctor_record = (await db.execute(doctor_lock_query)).scalar_one_or_none()
        
        if not doctor_record:
            raise HTTPException(status_code=404, detail="Doctor not found")

        availability_query = select(Availability).where(
            Availability.doctor_id == appointment_in.doctor_id,
            Availability.date == req_date,
        )
        availability = (await db.execute(availability_query)).scalar_one_or_none()
        if not availability:
            raise HTTPException(status_code=400, detail="El doctor no trabaja ese día")

        start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
        end_hour, end_minute = map(int, availability.end_time[:5].split(":"))
        start_minutes = start_hour * 60 + start_minute
        end_minutes = end_hour * 60 + end_minute
        duration = availability.slot_duration_minutes or 30
        if duration not in (30, 60, 120):
            raise HTTPException(status_code=400, detail="La duración de los turnos configurada no es válida")
        slot_count = max(0, (end_minutes - start_minutes) // duration)
        requested_turn = appointment_in.turn_number
        if requested_turn > slot_count:
            raise HTTPException(status_code=400, detail="El turno seleccionado está fuera del horario laboral")
        start_of_turn = start_minutes + (requested_turn - 1) * duration
        local_now = datetime.now(ZoneInfo("America/Caracas"))
        if req_date < local_now.date() or (
            req_date == local_now.date()
            and start_of_turn <= local_now.hour * 60 + local_now.minute
        ):
            raise HTTPException(status_code=400, detail="Ese horario ya pasó")

        booked = await _booked_intervals(db, doctor_record.id, req_date, start_minutes)
        if _overlaps(start_of_turn, duration, booked):
            raise HTTPException(status_code=409, detail="Ese horario ya fue reservado")

        selected_reason = (appointment_in.appointment_reason or appointment_in.reason or "Consulta").strip() or "Consulta"

        new_appointment = Appointment(
            patient_id=current_patient_id,
            doctor_id=appointment_in.doctor_id,
            appointment_date=req_date,
            turn_number=requested_turn,
            appointment_start_minutes=start_of_turn,
            appointment_duration_minutes=duration,
            appointment_reason=selected_reason,
            patient_first_name=current_user.first_name,
            patient_last_name=current_user.last_name,
            patient_phone=normalize_whatsapp_phone(current_user.phone) or current_user.phone,
            booking_source="online",
            status=AppointmentStatus.SCHEDULED
        )
        
        db.add(new_appointment)
        await db.flush()

    await db.commit()
    await db.refresh(new_appointment)
    
    # Try to send a Firebase Push Notification to the doctor
    try:
        from app.models.users import User
        from app.core.firebase import send_push_notification
        
        doctor_user_query = select(User).where(User.id == doctor_record.user_id)
        doctor_user_result = await db.execute(doctor_user_query)
        doctor_user = doctor_user_result.scalar_one_or_none()
        
        if doctor_user:
            from app.models.notifications import Notification, NotificationType
            notif = Notification(
                user_id=doctor_user.id,
                type=NotificationType.APPOINTMENT_CREATED,
                title="Nueva Cita Agendada",
                message=f"{current_user.first_name} {current_user.last_name} ha agendado una cita para el {req_date} (Turno #{requested_turn}) - Motivo: {selected_reason}."
            )
            db.add(notif)
            await db.commit()
    except Exception as e:
        print(f"Error saving appointment notification: {e}")
    return new_appointment

@router.patch("/{appointment_id}/cancel")
async def cancel_appointment(
    appointment_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # A cancelled turn is released; only the other participant receives a notice.
    async with db.begin_nested():
        appt_query = select(Appointment).where(Appointment.id == appointment_id).with_for_update()
        appt = (await db.execute(appt_query)).scalar_one_or_none()
        
        if not appt:
            raise HTTPException(status_code=404, detail="Appointment not found")
        if appt.status == AppointmentStatus.CANCELLED:
            raise HTTPException(status_code=400, detail="Already cancelled")

        doctor_query = select(Doctor).options(joinedload(Doctor.user)).where(Doctor.id == appt.doctor_id)
        doctor = (await db.execute(doctor_query)).scalar_one_or_none()
        patient = None
        if appt.patient_id:
            patient_query = select(Patient).options(joinedload(Patient.user)).where(Patient.id == appt.patient_id)
            patient = (await db.execute(patient_query)).scalar_one_or_none()

        if not doctor or (appt.patient_id and not patient):
            raise HTTPException(status_code=404, detail="Appointment participant not found")

        title = "Cita cancelada"
        if current_user.role in (RoleEnum.DOCTOR, RoleEnum.ASSISTANT):
            if (current_user.role == RoleEnum.DOCTOR and doctor.user_id != current_user.id) or (
                current_user.role == RoleEnum.ASSISTANT and current_user.linked_doctor_id != doctor.id
            ):
                raise HTTPException(status_code=403, detail="You cannot cancel this appointment")
            recipient_user_id = patient.user_id if patient else None
            cancelled_by = "doctor"
            if doctor and doctor.user:
                doc_name = f"{doctor.user.first_name} {doctor.user.last_name}"
                if doctor.user.gender in ["Femenino", "Femenina"]:
                    actor_name = f"La Dra. {doc_name}"
                    title = f"Cita Cancelada por la Doctora {doc_name}"
                else:
                    actor_name = f"El Dr. {doc_name}"
                    title = f"Cita Cancelada por el Doctor {doc_name}"
            else:
                actor_name = "El doctor"
                title = "Cita Cancelada por el Doctor"
        elif current_user.role == RoleEnum.PATIENT:
            if not patient or patient.user_id != current_user.id:
                raise HTTPException(status_code=403, detail="You cannot cancel this appointment")
            recipient_user_id = doctor.user_id
            cancelled_by = "patient"
            if patient and patient.user:
                patient_name = f"{patient.user.first_name} {patient.user.last_name}".strip()
                if patient.user.gender in ["Femenino", "Femenina"]:
                    actor_name = f"La paciente {patient_name}"
                    title = f"Cita Cancelada por {patient_name}"
                else:
                    actor_name = f"El paciente {patient_name}"
                    title = f"Cita Cancelada por {patient_name}"
            else:
                actor_name = "El paciente"
                title = "Cita Cancelada por el paciente"
        else:
            raise HTTPException(status_code=403, detail="Only an appointment participant can cancel")
            
        appt.status = AppointmentStatus.CANCELLED
        
    await db.commit()

    # Notify the participant who did not cancel the appointment. The Notification
    # insert hook sends the phone push, so do not send another push here.
    try:
        from app.models.notifications import Notification, NotificationType
        if recipient_user_id is None:
            return {"message": "Cita cancelada y turno liberado."}
        notif = Notification(
            user_id=recipient_user_id,
            type=NotificationType.APPOINTMENT_CANCELLED,
            title=title,
            message=f"{actor_name} canceló la cita del {appt.appointment_date} (Turno #{appt.turn_number}).",
        )
        db.add(notif)
        await db.commit()
    except Exception as e:
        print(f"Error saving cancellation notification: {e}")

    return {"message": "Cita cancelada y turnos actualizados."}


async def auto_complete_expired_appointments(db: AsyncSession) -> int:
    """
    Actualiza el estado de las citas a 'completada' cuando su fecha y hora ya hayan expirado,
    siempre y cuando no hayan sido canceladas previamente.
    Retorna la cantidad de citas actualizadas.
    """
    from sqlalchemy.orm import selectinload

    now = datetime.now(ZoneInfo("America/Caracas"))
    today = now.date()
    current_minutes = now.hour * 60 + now.minute

    query = (
        select(Appointment)
        .options(
            selectinload(Appointment.doctor).selectinload(Doctor.availabilities)
        )
        .where(Appointment.status == AppointmentStatus.SCHEDULED)
    )
    result = await db.execute(query)
    scheduled_appts = result.scalars().all()

    updated_count = 0
    for appt in scheduled_appts:
        is_expired = False
        if appt.appointment_date < today:
            is_expired = True
        elif appt.appointment_date == today:
            if appt.appointment_start_minutes is not None:
                start_minutes = appt.appointment_start_minutes
            else:
                doc = appt.doctor
                avail = next(
                    (a for a in (doc.availabilities if doc else []) if a.date == appt.appointment_date),
                    None
                )
                if avail and avail.start_time:
                    try:
                        sh, sm = map(int, avail.start_time[:5].split(":"))
                        start_minutes = sh * 60 + sm + (appt.turn_number - 1) * 30
                    except Exception:
                        start_minutes = 8 * 60 + (appt.turn_number - 1) * 30
                else:
                    start_minutes = 8 * 60 + (appt.turn_number - 1) * 30

            duration = appt.appointment_duration_minutes or 30
            end_minutes = start_minutes + duration

            if current_minutes >= end_minutes:
                is_expired = True

        if is_expired:
            appt.status = AppointmentStatus.COMPLETED
            db.add(appt)
            updated_count += 1

    if updated_count > 0:
        await db.commit()

    return updated_count


@router.post("/auto-complete-expired")
async def trigger_auto_complete_expired(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Endpoint para forzar la actualización de citas expiradas a completadas."""
    count = await auto_complete_expired_appointments(db)
    return {"updated_count": count, "message": f"{count} citas actualizadas a completadas"}


@router.get("/my")
async def get_my_appointments(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Actualizar citas expiradas antes de listar
    await auto_complete_expired_appointments(db)

    from sqlalchemy.orm import selectinload
    doctor_view = current_user.role in (RoleEnum.DOCTOR, RoleEnum.ASSISTANT)
    if doctor_view:
        doctor_id = current_user.linked_doctor_id if current_user.role == RoleEnum.ASSISTANT else None
        if current_user.role == RoleEnum.DOCTOR:
            doctor_query = select(Doctor).where(Doctor.user_id == current_user.id)
            doctor = (await db.execute(doctor_query)).scalar_one_or_none()
            doctor_id = doctor.id if doctor else None
        if not doctor_id:
            return []
        query = select(Appointment).options(
            selectinload(Appointment.doctor).selectinload(Doctor.user),
            selectinload(Appointment.doctor).selectinload(Doctor.availabilities),
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.doctor_id == doctor_id).order_by(Appointment.appointment_date.asc(), Appointment.appointment_start_minutes.asc(), Appointment.id.asc())
    else:
        patient_query = select(Patient).where(Patient.user_id == current_user.id)
        patient = (await db.execute(patient_query)).scalar_one_or_none()
        if not patient:
            return []
        query = select(Appointment).options(
            selectinload(Appointment.doctor).selectinload(Doctor.user),
            selectinload(Appointment.doctor).selectinload(Doctor.availabilities),
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.patient_id == patient.id).order_by(Appointment.appointment_date.asc(), Appointment.appointment_start_minutes.asc(), Appointment.id.asc())
        
    result = await db.execute(query)
    appointments = result.scalars().all()
    
    out = []
    for appt in appointments:
        doc = appt.doctor
        pat = appt.patient

        # Extraer teléfonos tanto del doctor como del paciente
        doctor_phone = doc.user.phone if (doc and doc.user and doc.user.phone) else ""
        if appt.patient_id is None:
            patient_phone = appt.patient_phone or ""
        elif pat and pat.user:
            patient_phone = pat.contact_phone or pat.user.phone or ""
        else:
            patient_phone = ""

        if doctor_view:
            # Show patient info instead of doctor info
            if appt.patient_id is None:
                display_name = f"{appt.patient_first_name or ''} {appt.patient_last_name or ''}".strip() or "Paciente presencial"
                display_loc = ""
                avatar = ""
                motivo = appt.appointment_reason or "Consulta"
            elif pat and pat.user:
                display_name = f"{pat.user.first_name} {pat.user.last_name}"
                display_loc = pat.user.state or ""
                avatar = pat.user.avatar_url or ""
                if not avatar and pat.user.avatar_data:
                    avatar = f"data:{pat.user.avatar_content_type or 'image/jpeg'};base64,{pat.user.avatar_data}"
                motivo = appt.appointment_reason or pat.medical_history or "Consulta"
            else:
                display_name = "Paciente Desconocido"
                display_loc = ""
                avatar = ""
                motivo = "Consulta"
            display_spec = motivo
        else:
            # Show doctor info
            if doc and doc.user:
                prefix = "Dra." if doc.user.gender in ["Femenino", "Femenina"] else "Dr."
                display_name = f"{prefix} {doc.user.first_name} {doc.user.last_name}"
                avatar = doc.user.avatar_url or ""
                if not avatar and doc.user.avatar_data:
                    avatar = f"data:{doc.user.avatar_content_type or 'image/jpeg'};base64,{doc.user.avatar_data}"
            else:
                display_name = "Dr. Desconocido"
                avatar = ""
            display_spec = doc.specialties[0] if doc and doc.specialties else "General"
            display_loc = doc.user.address if doc and doc.user and doc.user.address else (doc.user.state if doc and doc.user else "")

        availability = next(
            (item for item in (doc.availabilities if doc else [])
             if item.date == appt.appointment_date),
            None,
        )
        if appt.appointment_start_minutes is not None:
            slot_minutes = appt.appointment_start_minutes
        elif availability:
            start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
            slot_minutes = start_hour * 60 + start_minute + (appt.turn_number - 1) * 30
        else:
            slot_minutes = 8 * 60 + (appt.turn_number - 1) * 30
        time_block = (datetime.min + timedelta(minutes=slot_minutes)).strftime("%I:%M %p")

        patient_full_name = display_name if doctor_view else (f"{pat.user.first_name} {pat.user.last_name}" if pat and pat.user else (f"{appt.patient_first_name or ''} {appt.patient_last_name or ''}".strip() or "Paciente presencial"))
        doctor_full_name = f"{'Dra.' if doc.user.gender in ['Femenino', 'Femenina'] else 'Dr.'} {doc.user.first_name} {doc.user.last_name}" if doc and doc.user else "Dr(a). Médico"

        out.append({
            "id": appt.id,
            "patient_id": appt.patient_id,
            "doctor_id": appt.doctor_id,
            "doctor_name": display_name,
            "patient_name": patient_full_name,
            "doctor_full_name": doctor_full_name,
            "doctor_specialty": display_spec,
            "doctor_location": display_loc,
            "doctor_avatar": avatar,
            "doctor_phone": doctor_phone,
            "patient_phone": patient_phone,
            "patient_email": pat.user.email if pat and pat.user else "",
            "patient_cedula": getattr(pat.user, "cedula", "") if pat and pat.user else "",
            "time_block": time_block,
            "status": appt.status.value,
            "date": appt.appointment_date.isoformat(),
            "turn_number": appt.turn_number,
            "booking_source": appt.booking_source,
            "appointment_reason": appt.appointment_reason or (pat.medical_history if pat else "Consulta Médica"),
        })
    return out

async def _assert_appointment_access(
    appointment: Appointment,
    current_user: User,
    db: AsyncSession,
) -> None:
    role_str = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_str == "admin":
        return

    if role_str == "doctor":
        doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
        if doctor and doctor.id == appointment.doctor_id:
            return

    if role_str == "assistant":
        if current_user.linked_doctor_id and current_user.linked_doctor_id == appointment.doctor_id:
            return

    if role_str == "patient" and appointment.patient_id is not None:
        patient = await db.scalar(select(Patient).where(Patient.user_id == current_user.id))
        if patient and patient.id == appointment.patient_id:
            return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tienes permiso para acceder o modificar esta cita",
    )

@router.delete("/history")
async def clear_doctor_appointment_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role not in (RoleEnum.DOCTOR, RoleEnum.ASSISTANT):
        raise HTTPException(status_code=403, detail="Solo el doctor puede limpiar su historial")
    doctor = await _staff_doctor(current_user, db)
    result = await db.execute(delete(Appointment).where(
        Appointment.doctor_id == doctor.id,
        Appointment.status.in_((AppointmentStatus.CANCELLED, AppointmentStatus.COMPLETED)),
    ))
    await db.commit()
    return {"deleted_count": result.rowcount or 0, "message": "Historial de citas limpiado"}


@router.delete("/{appointment_id}")
async def delete_appointment(
    appointment_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Appointment).where(Appointment.id == appointment_id)
    appointment = (await db.execute(query)).scalar_one_or_none()
    
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
        
    await _assert_appointment_access(appointment, current_user, db)

    await db.delete(appointment)
    await db.commit()
    return {"message": "Cita eliminada correctamente"}

class RescheduleAppointment(BaseModel):
    appointment_date: date_type
    turn_number: int

@router.patch("/{appointment_id}/reschedule")
async def reschedule_appointment(
    appointment_id: int,
    reschedule_data: RescheduleAppointment,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Appointment).where(Appointment.id == appointment_id)
    appointment = (await db.execute(query)).scalar_one_or_none()
    
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
        
    await _assert_appointment_access(appointment, current_user, db)
        
    doctor_id = appointment.doctor_id
    req_date = reschedule_data.appointment_date
    requested_turn = reschedule_data.turn_number
    
    availability_query = select(Availability).where(
        Availability.doctor_id == doctor_id,
        Availability.date == req_date,
    )
    availability = (await db.execute(availability_query)).scalar_one_or_none()
    if not availability:
        raise HTTPException(status_code=400, detail="El doctor no trabaja ese día")
        
    start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
    end_hour, end_minute = map(int, availability.end_time[:5].split(":"))
    start_minutes = start_hour * 60 + start_minute
    end_minutes = end_hour * 60 + end_minute
    duration = availability.slot_duration_minutes or 30
    slot_count = max(0, (end_minutes - start_minutes) // duration)
    
    if requested_turn > slot_count:
        raise HTTPException(status_code=400, detail="El turno seleccionado está fuera del horario laboral")
        
    start_of_turn = start_minutes + (requested_turn - 1) * duration
    local_now = datetime.now(ZoneInfo("America/Caracas"))
    if req_date < local_now.date() or (
        req_date == local_now.date()
        and start_of_turn <= local_now.hour * 60 + local_now.minute
    ):
        raise HTTPException(status_code=400, detail="Ese horario ya pasó")

    booked = await _booked_intervals(db, doctor_id, req_date, start_minutes)
    # Exclude current appointment from booked list
    booked = [(s, d) for (s, d, appt_id) in booked if appt_id != appointment_id]
    
    if _overlaps(start_of_turn, duration, booked):
        raise HTTPException(status_code=409, detail="Ese horario ya fue reservado")

    appointment.appointment_date = req_date
    appointment.turn_number = requested_turn
    appointment.appointment_start_minutes = start_of_turn
    appointment.appointment_duration_minutes = duration
    
    await db.commit()
    
    # Notify doctor
    doctor_query = select(Doctor).options(joinedload(Doctor.user)).where(Doctor.id == appointment.doctor_id)
    doc_record = (await db.execute(doctor_query)).scalar_one_or_none()
    if doc_record and doc_record.user and doc_record.user.email:
        patient_query = select(Patient).options(joinedload(Patient.user)).where(Patient.id == appointment.patient_id)
        pat_record = (await db.execute(patient_query)).scalar_one_or_none()
        if pat_record and pat_record.user:
            patient_name = f"{pat_record.user.first_name} {pat_record.user.last_name}"
            prefix = "La paciente" if pat_record.user.gender in ["Femenino", "Femenina"] else "El paciente"
        else:
            patient_name = ""
            prefix = "Un paciente"
        
        try:
            from app.models.notifications import Notification, NotificationType
            notif = Notification(
                user_id=doc_record.user.id,
                type=NotificationType.APPOINTMENT_CREATED,
                title="Cita Reprogramada",
                message=f"{prefix} {patient_name} ha reprogramado su cita para el {req_date} en el turno #{requested_turn}."
            )
            db.add(notif)
            await db.commit()
        except Exception as e:
            print(f"Error saving rescheduled appointment notification: {e}")

    return {"message": "Cita reprogramada correctamente"}


@router.get("/doctor/stats")
async def get_doctor_appointment_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Estadísticas de citas para doctor, asistente o clínica:
    - citas esta semana
    - citas este mes
    - citas totales
    - citas canceladas
    - citas para hoy
    - cantidad de doctores (para clínicas)
    """
    await auto_complete_expired_appointments(db)

    if current_user.role not in (RoleEnum.DOCTOR, RoleEnum.ASSISTANT, RoleEnum.CLINIC):
        raise HTTPException(status_code=403, detail="Acceso denegado: solo doctores, asistentes o clínicas")

    from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
    from app.core.clinic_access import active_clinic_subscription

    is_vip = False
    doctor_ids = []

    if current_user.role == RoleEnum.CLINIC:
        from app.models.clinics import Clinic
        clinic = await db.scalar(select(Clinic).where(Clinic.user_id == current_user.id))
        if not clinic:
            raise HTTPException(status_code=404, detail="Perfil de clínica no encontrado")
        clinic_sub = await active_clinic_subscription(db, clinic.id)
        if not clinic_sub:
            raise HTTPException(status_code=403, detail="La clínica no tiene una suscripción activa")
        is_vip = clinic_sub.plan == SubscriptionPlan.CLINIC_VIP
        doc_ids_res = await db.scalars(
            select(Doctor.id).where(
                Doctor.clinic_id == clinic.id,
                or_(Doctor.clinic_join_status.is_(None), Doctor.clinic_join_status == "approved")
            )
        )
        doctor_ids = list(doc_ids_res.all())
    else:
        doctor = None
        if current_user.role == RoleEnum.ASSISTANT:
            if current_user.linked_doctor_id:
                doctor = await db.get(Doctor, current_user.linked_doctor_id)
        else:
            doctor_query = select(Doctor).where(Doctor.user_id == current_user.id)
            doctor = (await db.execute(doctor_query)).scalar_one_or_none()

        if not doctor:
            raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")

        is_vip = getattr(doctor, "is_sponsored", False)
        if not is_vip:
            sub = await db.scalar(
                select(Subscription).where(
                    Subscription.doctor_id == doctor.id,
                    Subscription.status == SubscriptionStatus.ACTIVE,
                    Subscription.plan == SubscriptionPlan.SPONSORED,
                )
            )
            if sub:
                is_vip = True
            elif doctor.clinic_id:
                clinic_sub = await active_clinic_subscription(db, doctor.clinic_id)
                if clinic_sub and clinic_sub.plan in (SubscriptionPlan.CLINIC_VIP, SubscriptionPlan.SPONSORED):
                    is_vip = True

        if not is_vip:
            raise HTTPException(status_code=403, detail="Las estadísticas solo están disponibles para doctores VIP")

        doctor_ids = [doctor.id]

    local_now = datetime.now(ZoneInfo("America/Caracas")).date()
    # Inicio de la semana (Lunes)
    start_of_week = local_now - timedelta(days=local_now.weekday())
    end_of_week = start_of_week + timedelta(days=6)

    # Inicio del mes
    start_of_month = date_type(local_now.year, local_now.month, 1)
    if local_now.month == 12:
        end_of_month = date_type(local_now.year, 12, 31)
    else:
        end_of_month = date_type(local_now.year, local_now.month + 1, 1) - timedelta(days=1)

    if doctor_ids:
        all_appts = (await db.scalars(
            select(Appointment).where(Appointment.doctor_id.in_(doctor_ids))
        )).all()
    else:
        all_appts = []

    total_count = len(all_appts)
    cancelled_count = sum(1 for a in all_appts if a.status == AppointmentStatus.CANCELLED)

    # Active/scheduled/completed in current week (excluding cancelled)
    week_count = sum(
        1 for a in all_appts
        if start_of_week <= a.appointment_date <= end_of_week
        and a.status != AppointmentStatus.CANCELLED
    )

    # Active/scheduled/completed in current month (excluding cancelled)
    month_count = sum(
        1 for a in all_appts
        if start_of_month <= a.appointment_date <= end_of_month
        and a.status != AppointmentStatus.CANCELLED
    )

    today_count = sum(
        1 for a in all_appts
        if a.appointment_date == local_now
        and a.status != AppointmentStatus.CANCELLED
    )

    return {
        "week_appointments": week_count,
        "month_appointments": month_count,
        "total_appointments": total_count,
        "cancelled_appointments": cancelled_count,
        "today_appointments": today_count,
        "doctor_count": len(doctor_ids),
        "is_vip": is_vip,
    }





