from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from app.api.dependencies import get_db, get_current_patient
from app.models.appointments import Appointment, AppointmentStatus
from app.schemas.appointments import AppointmentCreate, AppointmentResponse
from datetime import datetime, timezone
from app.models.doctors import Doctor

router = APIRouter()

@router.post("/", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    appointment_in: AppointmentCreate,
    db: AsyncSession = Depends(get_db),
    current_patient_id: int = Depends(get_current_patient)
):
    start_utc = appointment_in.start_time_utc
    end_utc = appointment_in.end_time_utc

    if start_utc.tzinfo is None or start_utc.tzinfo != timezone.utc:
        raise HTTPException(status_code=400, detail="start_time_utc must be timezone-aware and in UTC")
    
    if start_utc >= end_utc:
        raise HTTPException(status_code=400, detail="End time must be after start time")

    async with db.begin_nested():
        doctor_lock_query = select(Doctor).where(Doctor.id == appointment_in.doctor_id).with_for_update()
        doctor_record = (await db.execute(doctor_lock_query)).scalar_one_or_none()
        
        if not doctor_record:
            raise HTTPException(status_code=404, detail="Doctor not found")

        overlapping_check_query = select(Appointment).where(
            Appointment.doctor_id == appointment_in.doctor_id,
            Appointment.status == AppointmentStatus.SCHEDULED,
            or_(
                and_(Appointment.start_time_utc <= start_utc, Appointment.end_time_utc > start_utc),
                and_(Appointment.start_time_utc < end_utc, Appointment.end_time_utc >= end_utc),
                and_(Appointment.start_time_utc >= start_utc, Appointment.end_time_utc <= end_utc)
            )
        )
        
        result = await db.execute(overlapping_check_query)
        overlap = result.scalars().first()
        
        if overlap:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="The requested time slot is already booked for this doctor."
            )

        new_appointment = Appointment(
            patient_id=current_patient_id,
            doctor_id=appointment_in.doctor_id,
            start_time_utc=start_utc,
            end_time_utc=end_utc,
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
        
        if doctor_user and doctor_user.fcm_token:
            send_push_notification(
                token=doctor_user.fcm_token,
                title="Nueva Cita Agendada",
                body="¡Un paciente ha agendado una nueva cita contigo!"
            )
    except Exception as e:
        print(f"Error sending push notification: {e}")
    
    return new_appointment
