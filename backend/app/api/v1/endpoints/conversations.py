from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_db
from app.api.v1.endpoints.users import get_current_user
from app.models.appointments import Appointment
from app.models.direct_conversations import DirectConversation, DirectMessage
from app.models.doctors import Doctor
from app.models.patients import Patient
from app.models.users import RoleEnum, User

router = APIRouter()


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


def _role(user: User) -> str:
    return user.role.value if hasattr(user.role, "value") else str(user.role)


async def _conversation_access(conversation_id: int, user: User, db: AsyncSession) -> DirectConversation:
    conversation = await db.get(DirectConversation, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="No se encontró la conversación")
    role = _role(user)
    if role == RoleEnum.DOCTOR.value:
        doctor = await db.scalar(select(Doctor).where(Doctor.user_id == user.id))
        if doctor and doctor.id == conversation.doctor_id:
            return conversation
    elif role == RoleEnum.PATIENT.value:
        patient = await db.scalar(select(Patient).where(Patient.user_id == user.id))
        if patient and patient.id == conversation.patient_id:
            return conversation
    raise HTTPException(status_code=403, detail="No tienes acceso a esta conversación")


@router.post("/appointments/{appointment_id}", status_code=status.HTTP_201_CREATED)
async def start_for_appointment(
    appointment_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if _role(current_user) != RoleEnum.DOCTOR.value:
        raise HTTPException(status_code=403, detail="Solo el doctor puede iniciar una conversación")
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    if not doctor:
        raise HTTPException(status_code=404, detail="No se encontró el perfil del doctor")
    appointment = await db.get(Appointment, appointment_id)
    if not appointment or appointment.doctor_id != doctor.id:
        raise HTTPException(status_code=404, detail="No se encontró la cita")
    if not appointment.patient_id:
        raise HTTPException(status_code=400, detail="Esta cita manual no está vinculada a una cuenta de paciente")
    patient = await db.get(Patient, appointment.patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="No se encontró el perfil del paciente")
    patient_user = await db.get(User, patient.user_id)
    if not patient_user:
        raise HTTPException(status_code=400, detail="El paciente no tiene una cuenta para recibir mensajes")

    conversation = await db.scalar(select(DirectConversation).where(
        DirectConversation.appointment_id == appointment.id,
        DirectConversation.is_closed.is_(False),
    ))
    if not conversation:
        conversation = DirectConversation(
            doctor_id=doctor.id,
            patient_id=patient.id,
            appointment_id=appointment.id,
        )
        db.add(conversation)
        await db.flush()
        db.add(DirectMessage(
            conversation_id=conversation.id,
            sender_user_id=current_user.id,
            body="Hola, me comunico contigo por tu cita. ¿En qué puedo ayudarte?",
        ))
        await db.commit()
        await db.refresh(conversation)
        try:
            if patient_user.fcm_token:
                from app.core.firebase import send_push_notification
                send_push_notification(
                    patient_user.fcm_token,
                    f"Mensaje de Dr. {current_user.first_name}",
                    "Tienes una nueva conversación sobre tu cita en Salud Now.",
                    {"type": "direct_message", "conversation_id": str(conversation.id)},
                )
        except Exception as exc:
            print(f"[CHAT] Push notification failed ({type(exc).__name__})")
    else:
        await db.commit()

    return {"id": conversation.id, "is_closed": conversation.is_closed}


@router.get("")
async def list_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    role = _role(current_user)
    if role == RoleEnum.DOCTOR.value:
        doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
        if not doctor:
            return []
        query = select(DirectConversation).where(DirectConversation.doctor_id == doctor.id)
    elif role == RoleEnum.PATIENT.value:
        patient = await db.scalar(select(Patient).where(Patient.user_id == current_user.id))
        if not patient:
            return []
        query = select(DirectConversation).where(DirectConversation.patient_id == patient.id)
    else:
        raise HTTPException(status_code=403, detail="Solo doctores y pacientes pueden acceder a conversaciones")

    result = await db.scalars(query.options(
        selectinload(DirectConversation.messages),
    ).order_by(DirectConversation.is_closed.asc(), DirectConversation.id.desc()))
    conversations = result.unique().all()
    participants: dict[int, User] = {}
    for item in conversations:
        other_id = item.patient_id if role == RoleEnum.DOCTOR.value else item.doctor_id
        participant_query = select(User).join(
            Patient if role == RoleEnum.DOCTOR.value else Doctor,
            Patient.user_id == User.id if role == RoleEnum.DOCTOR.value else Doctor.user_id == User.id,
        ).where((Patient.id if role == RoleEnum.DOCTOR.value else Doctor.id) == other_id)
        other_user = await db.scalar(participant_query)
        if other_user:
            participants[item.id] = other_user

    output = []
    for item in conversations:
        other = participants.get(item.id)
        unread = sum(1 for message in item.messages if message.sender_user_id != current_user.id and not message.is_read)
        last_message = item.messages[-1] if item.messages else None
        output.append({
            "id": item.id,
            "appointment_id": item.appointment_id,
            "other_user_id": other.id if other else None,
            "other_name": f"{other.first_name} {other.last_name}".strip() if other else "Usuario",
            "other_avatar": other.avatar_url if other else None,
            "is_closed": item.is_closed,
            "unread_count": unread,
            "last_message": last_message.body if last_message else "",
            "updated_at": last_message.created_at.isoformat() if last_message else item.created_at.isoformat(),
        })
    output.sort(key=lambda row: row["updated_at"], reverse=True)
    return output


@router.get("/unread-count")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    role = _role(current_user)
    if role == RoleEnum.DOCTOR.value:
        doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
        if not doctor:
            return {"count": 0}
        conversation_ids = select(DirectConversation.id).where(DirectConversation.doctor_id == doctor.id)
    elif role == RoleEnum.PATIENT.value:
        patient = await db.scalar(select(Patient).where(Patient.user_id == current_user.id))
        if not patient:
            return {"count": 0}
        conversation_ids = select(DirectConversation.id).where(DirectConversation.patient_id == patient.id)
    else:
        return {"count": 0}
    count = await db.scalar(select(func.count(DirectMessage.id)).where(
        DirectMessage.conversation_id.in_(conversation_ids),
        DirectMessage.sender_user_id != current_user.id,
        DirectMessage.is_read.is_(False),
    ))
    return {"count": count or 0}


@router.get("/{conversation_id}/messages")
async def get_messages(
    conversation_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _conversation_access(conversation_id, current_user, db)
    await db.execute(update(DirectMessage).where(
        DirectMessage.conversation_id == conversation_id,
        DirectMessage.sender_user_id != current_user.id,
        DirectMessage.is_read.is_(False),
    ).values(is_read=True))
    await db.commit()
    result = await db.execute(
        select(DirectMessage, User)
        .join(User, User.id == DirectMessage.sender_user_id)
        .where(DirectMessage.conversation_id == conversation_id)
        .order_by(DirectMessage.created_at.asc(), DirectMessage.id.asc())
    )
    return [{
        "id": message.id,
        "sender_user_id": message.sender_user_id,
        "sender_name": f"{sender.first_name} {sender.last_name}".strip(),
        "body": message.body,
        "is_read": message.is_read,
        "created_at": message.created_at.isoformat(),
    } for message, sender in result.all()]


@router.post("/{conversation_id}/messages", status_code=status.HTTP_201_CREATED)
async def send_message(
    conversation_id: int,
    payload: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _conversation_access(conversation_id, current_user, db)
    if conversation.is_closed:
        raise HTTPException(status_code=409, detail="La conversación está cerrada")
    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=422, detail="El mensaje no puede estar vacío")
    message = DirectMessage(
        conversation_id=conversation.id,
        sender_user_id=current_user.id,
        body=body,
    )
    db.add(message)
    if _role(current_user) == RoleEnum.DOCTOR.value:
        patient = await db.get(Patient, conversation.patient_id)
        recipient = await db.get(User, patient.user_id) if patient else None
    else:
        doctor = await db.get(Doctor, conversation.doctor_id)
        recipient = await db.get(User, doctor.user_id) if doctor else None
    await db.commit()
    await db.refresh(message)
    try:
        if recipient and recipient.fcm_token:
            from app.core.firebase import send_push_notification
            sender_label = "tu doctor" if _role(current_user) == RoleEnum.PATIENT.value else f"Dr. {current_user.first_name}"
            send_push_notification(
                recipient.fcm_token,
                f"Nuevo mensaje de {sender_label}",
                "Abre Salud Now para leer tu mensaje.",
                {"type": "direct_message", "conversation_id": str(conversation.id)},
            )
    except Exception as exc:
        print(f"[CHAT] Push notification failed ({type(exc).__name__})")
    return {"id": message.id, "sender_user_id": message.sender_user_id, "body": message.body, "created_at": message.created_at.isoformat()}


@router.post("/{conversation_id}/close")
async def close_conversation(
    conversation_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _conversation_access(conversation_id, current_user, db)
    if _role(current_user) != RoleEnum.DOCTOR.value:
        raise HTTPException(status_code=403, detail="Solo el doctor puede cerrar la conversación")
    conversation.is_closed = True
    conversation.closed_at = datetime.now(timezone.utc)
    await db.commit()
    return {"id": conversation.id, "is_closed": True}
