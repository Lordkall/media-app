from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.core.database import get_db
from app.models.users import User, RoleEnum
from app.models.support import SupportTicket, TicketMessage
from app.api.v1.endpoints.users import get_current_user
from pydantic import BaseModel
from app.models.notifications import Notification, NotificationType
from datetime import timezone
from zoneinfo import ZoneInfo

router = APIRouter()

class SupportCreate(BaseModel):
    subject: str
    message: str

class ReplyCreate(BaseModel):
    message: str

@router.post("/")
async def create_ticket(
    ticket_in: SupportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    new_ticket = SupportTicket(
        user_id=current_user.id,
        subject=ticket_in.subject,
        status="Pendiente"
    )
    db.add(new_ticket)
    await db.commit()
    await db.refresh(new_ticket)
    
    first_message = TicketMessage(
        ticket_id=new_ticket.id,
        sender_id=current_user.id,
        message=ticket_in.message
    )
    db.add(first_message)
    await db.commit()
    
    # Persist an in-app notification and send a push after the commit.
    try:
        admins_result = await db.execute(select(User))
        admins = [u for u in admins_result.scalars().all() if u.role == RoleEnum.ADMIN or u.role == "admin"]
        from app.core.firebase import send_push_notification
        for admin in admins:
            notification = Notification(
                user_id=admin.id,
                type=NotificationType.SUPPORT_MESSAGE,
                title="Nuevo ticket de soporte",
                message=f"{current_user.first_name} {current_user.last_name} ha enviado un mensaje: {ticket_in.subject}",
                action_url=f"support_ticket:{new_ticket.id}"
            )
            db.add(notification)
            
        await db.commit()
        
        # Send push to all admins (after commit so FCM tokens are fresh)
        for admin in admins:
            if admin.fcm_token:
                sent = send_push_notification(
                    admin.fcm_token,
                    "Nuevo ticket de soporte",
                    f"{current_user.first_name} {current_user.last_name}: {ticket_in.subject}",
                    {"type": "support_message", "ticket_id": str(new_ticket.id)}
                )
                print(f"Support push to admin {admin.id}: {'sent' if sent else 'failed'}")
            else:
                print(f"Support push skipped for admin {admin.id}: no FCM token")
    except Exception as e:
        print(f"Failed to notify admins: {e}")
        await db.rollback()

    return {"message": "Ticket created"}
@router.get("/debug-tickets")
async def debug_tickets(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SupportTicket))
    tickets = result.scalars().all()
    return [{"id": t.id, "subject": t.subject, "user_id": t.user_id} for t in tickets]

@router.get("/")
async def get_tickets(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role == RoleEnum.ADMIN or current_user.role == "admin":
        result = await db.execute(
            select(SupportTicket)
            .options(selectinload(SupportTicket.user), selectinload(SupportTicket.messages))
            .order_by(SupportTicket.created_at.desc())
        )
    else:
        result = await db.execute(
            select(SupportTicket)
            .options(selectinload(SupportTicket.user), selectinload(SupportTicket.messages))
            .where(SupportTicket.user_id == current_user.id)
            .order_by(SupportTicket.created_at.desc())
        )
    tickets = result.scalars().all()
    
    output = []
    for t in tickets:
        sender_name = t.user.email if t.user else "Unknown"
        if t.user:
            if t.user.role == RoleEnum.PATIENT:
                sender_name = f"Paciente {t.user.first_name} {t.user.last_name}"
            elif t.user.role == RoleEnum.DOCTOR:
                sender_name = f"Dr. {t.user.first_name} {t.user.last_name}"
            elif t.user.role == RoleEnum.ADMIN:
                sender_name = f"Admin {t.user.first_name} {t.user.last_name}"
                
        last_msg = t.messages[-1].message if t.messages else ""
        output.append({
            "id": t.id,
            "sender": sender_name,
            "subject": t.subject,
            "message": last_msg,
            "all_messages": [{"sender_id": m.sender_id, "message": m.message} for m in t.messages],
            "date": (
                (t.created_at.replace(tzinfo=timezone.utc) if t.created_at.tzinfo is None else t.created_at)
                .astimezone(ZoneInfo("America/Caracas"))
                .strftime("%d/%m/%Y %H:%M")
                if t.created_at else ""
            ),
            "status": t.status
        })
    return output

@router.get("/{ticket_id}/messages")
async def get_ticket_messages(
    ticket_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SupportTicket)
        .options(selectinload(SupportTicket.messages))
        .where(SupportTicket.id == ticket_id)
    )
    ticket = result.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Chat no encontrado")
    is_admin = current_user.role == RoleEnum.ADMIN or current_user.role == "admin"
    if not is_admin and ticket.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes acceso a este chat")
    return {
        "status": ticket.status,
        "messages": [
            {"sender_id": item.sender_id, "message": item.message}
            for item in ticket.messages
        ],
    }

@router.patch("/{ticket_id}/close")
async def close_ticket(
    ticket_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != RoleEnum.ADMIN:
        raise HTTPException(status_code=403)
        
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == ticket_id))
    ticket = result.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404)
        
    ticket.status = "Cerrado"
    await db.commit()
    return {"message": "Ticket closed"}

@router.post("/{ticket_id}/reply")
async def reply_ticket(
    ticket_id: int,
    reply: ReplyCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == ticket_id))
    ticket = result.scalar_one_or_none()
    if not ticket or ticket.status == "Cerrado":
        raise HTTPException(status_code=400, detail="Cannot reply to closed or non-existent ticket")
    is_admin = current_user.role == RoleEnum.ADMIN or current_user.role == "admin"
    if not is_admin and ticket.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes acceso a este chat")
        
    msg = TicketMessage(
        ticket_id=ticket.id,
        sender_id=current_user.id,
        message=reply.message
    )
    db.add(msg)
    await db.commit()

    # Send an in-app notification and a push to the other side of the conversation.
    try:
        if is_admin:
            # Admin replied -> notify the ticket owner
            notif_user_id = ticket.user_id
            notif_title = "Respuesta de soporte"
            notif_msg = f"El equipo de soporte ha respondido tu ticket: {ticket.subject}"
            notification = Notification(
                user_id=notif_user_id,
                type=NotificationType.SUPPORT_MESSAGE,
                title=notif_title,
                message=notif_msg,
                action_url=f"support_ticket:{ticket.id}"
            )
            db.add(notification)
            ticket_owner = await db.get(User, ticket.user_id)
            recipients = [ticket_owner] if ticket_owner else []
        else:
            # User replied -> notify all admins
            admins_result = await db.execute(select(User))
            admins = [u for u in admins_result.scalars().all() if u.role == RoleEnum.ADMIN or u.role == "admin"]
            for admin in admins:
                notification = Notification(
                    user_id=admin.id,
                    type=NotificationType.SUPPORT_MESSAGE,
                    title="Nuevo mensaje de soporte",
                    message=f"{current_user.first_name} {current_user.last_name} respondió en el ticket: {ticket.subject}",
                    action_url=f"support_ticket:{ticket.id}"
                )
                db.add(notification)
            recipients = admins
        await db.commit()
        from app.core.firebase import send_push_notification
        for recipient in recipients:
            if recipient and recipient.fcm_token:
                send_push_notification(
                    recipient.fcm_token,
                    "Respuesta de soporte" if is_admin else "Nuevo mensaje de soporte",
                    notif_msg if is_admin else f"{current_user.first_name} {current_user.last_name}: {ticket.subject}",
                    {"type": "support_message", "ticket_id": str(ticket.id)}
                )
    except Exception as e:
        print(f"Error sending reply notification: {e}")
        await db.rollback()

    return {"message": "Reply sent"}

@router.delete("/{ticket_id}")
async def delete_ticket(
    ticket_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != RoleEnum.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized to delete tickets")
        
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == ticket_id))
    ticket = result.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
        
    # Optional: ensure ticket is closed before deleting
    if ticket.status != "Cerrado":
        raise HTTPException(status_code=400, detail="Cannot delete open tickets")

    # Messages will be cascade-deleted or we need to delete them first
    # In SQLAlchemy if cascade delete is not set, we should delete messages first
    from app.models.support import TicketMessage
    await db.execute(TicketMessage.__table__.delete().where(TicketMessage.ticket_id == ticket_id))
    
    await db.delete(ticket)
    await db.commit()
    return {"message": "Ticket deleted"}
