from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.api.dependencies import get_db, get_current_patient
from app.api.v1.endpoints.users import get_current_user
from app.models.users import User, RoleEnum
from app.models.appointments import Appointment, AppointmentStatus
from app.schemas.appointments import AppointmentCreate, AppointmentResponse
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from app.models.doctors import Doctor, Availability
from app.models.patients import Patient

router = APIRouter()

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
        slot_count = max(0, (end_minutes - start_minutes) // 30)
        requested_turn = appointment_in.turn_number
        if requested_turn > slot_count:
            raise HTTPException(status_code=400, detail="El turno seleccionado está fuera del horario laboral")
        start_of_turn = start_minutes + (requested_turn - 1) * 30
        local_now = datetime.now(ZoneInfo("America/Caracas"))
        if req_date < local_now.date() or (
            req_date == local_now.date()
            and start_of_turn <= local_now.hour * 60 + local_now.minute
        ):
            raise HTTPException(status_code=400, detail="Ese horario ya pasó")

        booked_query = select(Appointment).where(
            Appointment.doctor_id == appointment_in.doctor_id,
            Appointment.appointment_date == req_date,
            Appointment.status != AppointmentStatus.CANCELLED
        )
        booked = (await db.execute(booked_query)).scalars().all()
        if any(appt.turn_number == requested_turn for appt in booked):
            raise HTTPException(status_code=409, detail="Ese horario ya fue reservado")

        new_appointment = Appointment(
            patient_id=current_patient_id,
            doctor_id=appointment_in.doctor_id,
            appointment_date=req_date,
            turn_number=requested_turn,
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
                message=f"¡Un paciente ha agendado una nueva cita contigo para el {req_date} (Turno #{requested_turn})!"
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

        doctor = await db.scalar(select(Doctor).where(Doctor.id == appt.doctor_id))
        patient = await db.scalar(select(Patient).where(Patient.id == appt.patient_id))
        if not doctor or not patient:
            raise HTTPException(status_code=404, detail="Appointment participant not found")

        if current_user.role == RoleEnum.DOCTOR:
            if doctor.user_id != current_user.id:
                raise HTTPException(status_code=403, detail="You cannot cancel this appointment")
            recipient_user_id = patient.user_id
            cancelled_by = "doctor"
            actor_name = "El doctor"
        elif current_user.role == RoleEnum.PATIENT:
            if patient.user_id != current_user.id:
                raise HTTPException(status_code=403, detail="You cannot cancel this appointment")
            recipient_user_id = doctor.user_id
            cancelled_by = "patient"
            actor_name = "El paciente"
        else:
            raise HTTPException(status_code=403, detail="Only an appointment participant can cancel")
            
        appt.status = AppointmentStatus.CANCELLED
        
    await db.commit()

    # Notify the participant who did not cancel the appointment.
    try:
        from app.models.notifications import Notification, NotificationType
        notif = Notification(
            user_id=recipient_user_id,
            type=NotificationType.APPOINTMENT_CANCELLED,
            title="Cita cancelada por el doctor" if cancelled_by == "doctor" else "Cita cancelada por el paciente",
            message=f"{actor_name} canceló la cita del {appt.appointment_date} (turno #{appt.turn_number}).",
        )
        db.add(notif)
        await db.commit()
        recipient = await db.get(User, recipient_user_id)
        if recipient and recipient.fcm_token:
            from app.core.firebase import send_push_notification
            send_push_notification(
                recipient.fcm_token,
                notif.title,
                notif.message,
                {"type": "appointment_cancelled", "appointment_id": str(appt.id)},
            )
    except Exception as e:
        print(f"Error saving cancellation notification: {e}")

    return {"message": "Cita cancelada y turnos actualizados."}

@router.get("/my")
async def get_my_appointments(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # This queries the appointments related to the current user
    from sqlalchemy.orm import selectinload
    if current_user.role == RoleEnum.DOCTOR:
        doctor_query = select(Doctor).where(Doctor.user_id == current_user.id)
        doctor = (await db.execute(doctor_query)).scalar_one_or_none()
        if not doctor:
            return []
        query = select(Appointment).options(
            selectinload(Appointment.doctor).selectinload(Doctor.user),
            selectinload(Appointment.doctor).selectinload(Doctor.availabilities),
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.doctor_id == doctor.id).order_by(Appointment.appointment_date.asc(), Appointment.id.asc())
    else:
        patient_query = select(Patient).where(Patient.user_id == current_user.id)
        patient = (await db.execute(patient_query)).scalar_one_or_none()
        if not patient:
            return []
        query = select(Appointment).options(
            selectinload(Appointment.doctor).selectinload(Doctor.user),
            selectinload(Appointment.doctor).selectinload(Doctor.availabilities),
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.patient_id == patient.id).order_by(Appointment.appointment_date.asc(), Appointment.id.asc())
        
    result = await db.execute(query)
    appointments = result.scalars().all()
    
    out = []
    for appt in appointments:
        doc = appt.doctor
        pat = appt.patient
        if current_user.role == RoleEnum.DOCTOR:
            # Show patient info instead of doctor info
            if pat and pat.user:
                display_name = f"{pat.user.first_name} {pat.user.last_name}"
                display_loc = pat.user.state or ""
                avatar = pat.user.avatar_url or ""
                phone = pat.contact_phone or ""
                motivo = pat.medical_history or "Consulta"
            else:
                display_name = "Paciente Desconocido"
                display_loc = ""
                avatar = ""
                phone = ""
                motivo = "Consulta"
            display_spec = motivo
        else:
            # Show doctor info
            if doc and doc.user:
                display_name = f"Dr. {doc.user.first_name} {doc.user.last_name}"
                avatar = doc.user.avatar_url or ""
            else:
                display_name = "Dr. Desconocido"
                avatar = ""
            display_spec = doc.specialties[0] if doc and doc.specialties else "General"
            display_loc = doc.user.address if doc and doc.user and doc.user.address else (doc.user.state if doc and doc.user else "")
            phone = doc.user.phone if doc and doc.user else ""
            
        availability = next(
            (item for item in (doc.availabilities if doc else [])
             if item.date == appt.appointment_date),
            None,
        )
        if availability:
            start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
            slot_minutes = start_hour * 60 + start_minute + (appt.turn_number - 1) * 30
        else:
            slot_minutes = 8 * 60 + (appt.turn_number - 1) * 30
        time_block = (datetime.min + timedelta(minutes=slot_minutes)).strftime("%I:%M %p")
            
        out.append({
            "id": appt.id,
            "patient_id": appt.patient_id,
            "doctor_id": appt.doctor_id,
            "doctor_name": display_name,
            "doctor_specialty": display_spec,
            "doctor_location": display_loc,
            "doctor_avatar": avatar,
            "patient_phone": phone,
            "time_block": time_block,
            "status": appt.status.value,
            "date": appt.appointment_date.isoformat(),
            "turn_number": appt.turn_number
        })
    return out
