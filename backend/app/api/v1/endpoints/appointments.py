from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from app.api.dependencies import get_db, get_current_patient
from app.api.v1.endpoints.users import get_current_user
from app.models.users import User, RoleEnum
from app.models.appointments import Appointment, AppointmentStatus
from app.schemas.appointments import AppointmentCreate, AppointmentResponse
from datetime import datetime, timezone
from app.models.doctors import Doctor
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

        # Find the max turn_number for this doctor on this date
        max_turn_query = select(Appointment).where(
            Appointment.doctor_id == appointment_in.doctor_id,
            Appointment.appointment_date == req_date,
            Appointment.status != AppointmentStatus.CANCELLED
        ).order_by(Appointment.turn_number.desc())
        
        result = await db.execute(max_turn_query)
        last_appt = result.scalars().first()
        
        next_turn = 1
        if last_appt:
            next_turn = last_appt.turn_number + 1

        new_appointment = Appointment(
            patient_id=current_patient_id,
            doctor_id=appointment_in.doctor_id,
            appointment_date=req_date,
            turn_number=next_turn,
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
                message=f"¡Un paciente ha agendado una nueva cita contigo para el {req_date} (Turno #{next_turn})!"
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
    # This route cancels an appointment and shifts down the turn_number of subsequent appointments
    async with db.begin_nested():
        appt_query = select(Appointment).where(Appointment.id == appointment_id).with_for_update()
        appt = (await db.execute(appt_query)).scalar_one_or_none()
        
        if not appt:
            raise HTTPException(status_code=404, detail="Appointment not found")
        if appt.status == AppointmentStatus.CANCELLED:
            raise HTTPException(status_code=400, detail="Already cancelled")
            
        appt.status = AppointmentStatus.CANCELLED
        
        # Shift down subsequent appointments for the same doctor and date
        subsequent_query = select(Appointment).where(
            Appointment.doctor_id == appt.doctor_id,
            Appointment.appointment_date == appt.appointment_date,
            Appointment.turn_number > appt.turn_number,
            Appointment.status != AppointmentStatus.CANCELLED
        ).with_for_update()
        
        subs = (await db.execute(subsequent_query)).scalars().all()
        for s in subs:
            s.turn_number -= 1

    await db.commit()

    # Create notification for doctor
    try:
        from app.models.notifications import Notification, NotificationType
        from app.models.doctors import Doctor
        doctor_query = select(Doctor).where(Doctor.id == appt.doctor_id)
        doctor = (await db.execute(doctor_query)).scalar_one_or_none()
        if doctor:
            notif = Notification(
                user_id=doctor.user_id,
                type=NotificationType.APPOINTMENT_CANCELLED,
                title="Cita Cancelada",
                message=f"Una cita para el {appt.appointment_date} ha sido cancelada por el paciente."
            )
            db.add(notif)
            await db.commit()
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
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.doctor_id == doctor.id)
    else:
        patient_query = select(Patient).where(Patient.user_id == current_user.id)
        patient = (await db.execute(patient_query)).scalar_one_or_none()
        if not patient:
            return []
        query = select(Appointment).options(
            selectinload(Appointment.doctor).selectinload(Doctor.user),
            selectinload(Appointment.patient).selectinload(Patient.user)
        ).where(Appointment.patient_id == patient.id)
        
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
            
        # Basic time block calculation (Assuming starting at 8:00 AM with 30 min intervals)
        start_hour = 8
        start_min = (appt.turn_number - 1) * 30
        hr = start_hour + (start_min // 60)
        mn = start_min % 60
        ampm = "AM" if hr < 12 else "PM"
        display_hr = hr if hr <= 12 else hr - 12
        if display_hr == 0: display_hr = 12
        time_block = f"{display_hr:02d}:{mn:02d} {ampm}"
            
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
