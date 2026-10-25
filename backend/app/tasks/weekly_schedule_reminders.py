import asyncio
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import or_, select

from app.core.database import async_session_maker
from app.models.notifications import Notification, NotificationType
from app.models.users import RoleEnum, User


async def send_weekly_schedule_reminders() -> None:
    now = datetime.now(ZoneInfo("America/Caracas"))
    if now.weekday() != 5 or now.hour < 9:
        return

    today = now.date()
    next_monday = today + timedelta(days=2)
    async with async_session_maker() as session:
        users = (await session.scalars(
            select(User)
            .where(
                User.role.in_((RoleEnum.DOCTOR, RoleEnum.ASSISTANT)),
                or_(
                    User.last_weekly_schedule_reminder_date.is_(None),
                    User.last_weekly_schedule_reminder_date < today,
                ),
            )
            .with_for_update(skip_locked=True)
        )).all()

        for user in users:
            if user.role == RoleEnum.DOCTOR:
                title = "Prepara tu horario de la próxima semana"
                message = f"Recuerda programar tu horario de atención para la semana que comienza el {next_monday:%d/%m/%Y}."
            else:
                title = "Programa el horario de la próxima semana"
                message = f"Recuerda ayudar a programar el horario de atención de la próxima semana, que comienza el {next_monday:%d/%m/%Y}."
            session.add(Notification(
                user_id=user.id,
                type=NotificationType.RENEWAL_REMINDER,
                title=title,
                message=message,
                action_url="weekly_schedule",
            ))
            user.last_weekly_schedule_reminder_date = today
        await session.commit()


async def weekly_schedule_reminder_loop() -> None:
    while True:
        try:
            await send_weekly_schedule_reminders()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            print(f"Weekly schedule reminder failed: {exc}")
        await asyncio.sleep(15 * 60)
