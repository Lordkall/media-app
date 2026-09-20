"""
Vista del Centro de Notificaciones.
Muestra alertas en tiempo real sobre suscripciones, renovaciones, avisos administrativos y citas.
"""
import flet as ft
from core import colors

PRIMARY_COLOR = colors.PRIMARY
BG_COLOR = colors.BACKGROUND
SURFACE_COLOR = colors.SURFACE
TEXT_PRIMARY = colors.TEXT_DARK
TEXT_SECONDARY = colors.TEXT_LIGHT
ACCENT_COLOR = colors.SECONDARY
SUCCESS_COLOR = colors.ACCENT_GREEN
WARNING_COLOR = colors.WARNING_COLOR
ERROR_COLOR = colors.ERROR_COLOR
BORDER_COLOR = colors.INPUT_BORDER

class NotificationsView(ft.Container):
    def __init__(self, page: ft.Page, user=None, on_navigate=None):
        super().__init__(
            expand=True,
            gradient=ft.LinearGradient(
                begin=ft.alignment.top_left,
                end=ft.alignment.bottom_right,
                colors=["#E0EAFC", "#CFDEF3", "#B3C6DF"]
            )
        )
        self.ft_page = page
        self.user = user
        self.on_navigate = on_navigate
        self.padding = 30

        self.build_ui()
        self.load_notifications()

    def build_ui(self):
        def handle_back(e):
            try:
                self.ft_page.pubsub.send_all_on_topic(f"user_{self.user.id}", "refresh_home")
            except Exception: pass
            
            if self.on_navigate:
                self.on_navigate("home")
            elif self.ft_page and len(self.ft_page.views) > 1:
                self.ft_page.views.pop()
                self.ft_page.update()

        self.header = ft.Column([
            ft.Row([
                ft.IconButton(
                    icon=ft.Icons.ARROW_BACK,
                    icon_color=PRIMARY_COLOR,
                    on_click=handle_back
                ),
                ft.Text("Notificaciones", size=16, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY, expand=True, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS),
                ft.TextButton("Leídas", icon=ft.Icons.DONE_ALL, on_click=self.mark_all_read)
            ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Text("Mantente informado sobre suscripciones, avisos y eventos", size=12, color=TEXT_SECONDARY),
        ], spacing=4)

        self.list_container = ft.Column(spacing=12, scroll=ft.ScrollMode.AUTO, expand=True)

        self.content = ft.Column([
            self.header,
            ft.Divider(height=20, color="transparent"),
            self.list_container
        ], expand=True)

    def load_notifications(self):
        try:
            import sys
            import os
            from datetime import timedelta
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker
            from app.models.notifications import Notification

            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)

            with Session() as session:
                db_notifs = session.execute(
                    select(Notification)
                    .where(Notification.user_id == self.user.id)
                    .order_by(Notification.created_at.desc())
                ).scalars().all()
                
                notifs = []
                for n in db_notifs:
                    notifs.append({
                        "id": n.id,
                        "title": n.title,
                        "message": n.message,
                        "time": (n.created_at - timedelta(hours=4)).strftime("%d/%m/%Y %H:%M") if n.created_at else "",
                        "read": n.is_read,
                        "type": n.type.value if hasattr(n.type, 'value') else str(n.type),
                        "action_url": n.action_url
                    })
        except Exception as e:
            print("Error loading notifications:", e)
            notifs = []

        self.list_container.controls.clear()
        if not notifs:
            self.list_container.controls.append(
                ft.Container(
                    content=ft.Text("No tienes notificaciones en este momento", color=TEXT_SECONDARY),
                    alignment=ft.alignment.center,
                    padding=40
                )
            )
        else:
            for n in notifs:
                self.list_container.controls.append(self.create_notification_card(n))
        
        self.ft_page.update()

    def handle_approve_doctor(self, doc_id, notif_id):
        try:
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker
            from app.models.doctors import Doctor
            from app.models.notifications import Notification, NotificationType

            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)

            with Session() as session:
                doc = session.execute(select(Doctor).where(Doctor.id == doc_id)).scalar_one_or_none()
                if doc:
                    doc.is_approved = True
                    
                    notif = Notification(
                        user_id=doc.user_id,
                        type=NotificationType.DOCTOR_APPROVED,
                        title="¡Cuenta de Doctor Aprobada!",
                        message="Tu cuenta ha sido aprobada por el administrador. Ya apareces en la lista de doctores."
                    )
                    session.add(notif)
                    
                    curr_notif = session.execute(select(Notification).where(Notification.id == notif_id)).scalar_one_or_none()
                    if curr_notif:
                        curr_notif.is_read = True
                        curr_notif.action_url = None  # Prevent re-approving
                        
                    session.commit()
                    
                    snack = ft.SnackBar(ft.Text("Doctor aprobado con éxito."), bgcolor=SUCCESS_COLOR)
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.load_notifications()
        except Exception as e:
            print("Error approving doctor:", e)

    def handle_approve_subscription(self, sub_id: int, notif_id: int):
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        from app.models.subscriptions import Subscription, SubscriptionStatus
        from app.models.doctors import Doctor
        from app.models.notifications import Notification, NotificationType

        try:
            from core.config import SYNC_DB_URL
            engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=engine)
            with Session() as session:
                sub = session.execute(select(Subscription).where(Subscription.id == sub_id)).scalar_one_or_none()
                if sub:
                    sub.status = SubscriptionStatus.ACTIVE
                    
                    doc = session.execute(select(Doctor).where(Doctor.id == sub.doctor_id)).scalar_one_or_none()
                    if doc:
                        if not doc.is_approved:
                            doc.is_approved = True
                            notif_type = NotificationType.DOCTOR_APPROVED
                            msg = "Tu cuenta ha sido aprobada y tu suscripción está activa. Ya apareces en la lista de doctores."
                        else:
                            notif_type = NotificationType.SUBSCRIPTION_RENEWED
                            msg = "Tu suscripción ha sido validada y está activa."
                            
                        # Actualizar estado VIP según el plan de la suscripción
                        if sub.plan and sub.plan.name == "SPONSORED":
                            doc.is_sponsored = True
                            doc.sponsored_priority = 1
                            doc.is_featured = False
                        elif sub.plan and sub.plan.name == "FEATURED":
                            doc.is_sponsored = False
                            doc.sponsored_priority = 99
                            doc.is_featured = True
                        else:
                            doc.is_sponsored = False
                            doc.sponsored_priority = 99
                            doc.is_featured = False
                        
                    notif = Notification(
                        user_id=doc.user_id,
                        type=notif_type,
                        title="¡Suscripción Aprobada!",
                        message=msg
                    )
                    session.add(notif)
                    
                    curr_notif = session.execute(select(Notification).where(Notification.id == notif_id)).scalar_one_or_none()
                    if curr_notif:
                        curr_notif.is_read = True
                        curr_notif.action_url = None  # Prevent re-approving
                        
                    session.commit()
                    
                    snack = ft.SnackBar(ft.Text("Suscripción aprobada con éxito."), bgcolor=SUCCESS_COLOR)
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.load_notifications()
                    
                    if doc:
                        self.ft_page.pubsub.send_all_on_topic(
                            f"user_{doc.user_id}",
                            f"new_notification:Tu suscripción ha sido validada"
                        )
        except Exception as e:
            print("Error approving subscription:", e)

    def create_notification_card(self, n):
        # Icono según tipo
        if n["type"] == "new_sub" or n["type"] == "new_subscription":
            icon = ft.Icon(ft.Icons.STAR, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"
        elif n["type"] == "warning" or n["type"] == "renewal_reminder" or n["type"] == "grace_period_warning":
            icon = ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=WARNING_COLOR, size=24)
            badge_bg = WARNING_COLOR + "20"
        elif n["type"] == "grace":
            icon = ft.Icon(ft.Icons.SCHEDULE, color=ACCENT_COLOR, size=24)
            badge_bg = ACCENT_COLOR + "20"
        elif n["type"] == "appointment_created":
            icon = ft.Icon(ft.Icons.CALENDAR_MONTH, color=SUCCESS_COLOR, size=24)
            badge_bg = SUCCESS_COLOR + "20"
        elif n["type"] == "appointment_cancelled":
            icon = ft.Icon(ft.Icons.CANCEL, color=ERROR_COLOR, size=24)
            badge_bg = ERROR_COLOR + "20"
        elif n["type"] == "doctor_registered":
            icon = ft.Icon(ft.Icons.PERSON_ADD, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"
        elif n["type"] == "doctor_approved":
            icon = ft.Icon(ft.Icons.HOW_TO_REG, color=SUCCESS_COLOR, size=24)
            badge_bg = SUCCESS_COLOR + "20"
        else:
            icon = ft.Icon(ft.Icons.NOTIFICATIONS, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"

        btn_action = None
        if n.get("action_url"):
            if n["action_url"].startswith("approve_doctor:"):
                doc_id = int(n["action_url"].split(":")[1])
                btn_action = ft.Button(
                    "Aprobar Doctor",
                    icon=ft.Icons.CHECK_CIRCLE,
                    style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR, color="white"),
                    on_click=lambda e, d=doc_id, nid=n["id"]: self.handle_approve_doctor(d, nid)
                )
            elif n["action_url"].startswith("approve_subscription:"):
                sub_id = int(n["action_url"].split(":")[1])
                btn_action = ft.Button(
                    "Validar Pago",
                    icon=ft.Icons.CHECK_CIRCLE,
                    style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR, color="white"),
                    on_click=lambda e, s=sub_id, nid=n["id"]: self.handle_approve_subscription(s, nid)
                )
            else:
                btn_action = ft.Button(
                    "Ir a Renovar / Ver",
                    icon=ft.Icons.OPEN_IN_NEW,
                    style=ft.ButtonStyle(bgcolor=PRIMARY_COLOR, color="white"),
                    on_click=lambda e: self.on_navigate(n["action_url"]) if self.on_navigate else None
                )

        return ft.Container(
            content=ft.Row([
                ft.Container(
                    content=icon,
                    bgcolor=badge_bg,
                    padding=12,
                    border_radius=30
                ),
                ft.Column([
                    ft.Row([
                        ft.Text(n["title"], weight=ft.FontWeight.BOLD, size=15, color=TEXT_PRIMARY, expand=True),
                        ft.Text(n["time"], size=12, color=TEXT_SECONDARY),
                    ]),
                    ft.Text(n["message"], size=13, color=TEXT_SECONDARY),
                    ft.Row([btn_action]) if btn_action else ft.Container()
                ], expand=True, spacing=4)
            ], vertical_alignment=ft.CrossAxisAlignment.START, spacing=15),
            padding=15,
            border_radius=15,
            bgcolor=colors.CARD_BG,
            border=ft.border.all(1, colors.PRIMARY if not n["read"] else colors.GLASS_BORDER),
            blur=ft.Blur(15, 15, ft.BlurTileMode.MIRROR)
        )

    def mark_all_read(self, e):
        from sqlalchemy import create_engine, update
        from sqlalchemy.orm import sessionmaker
        from app.models.notifications import Notification

        try:
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)
            with Session() as session:
                session.execute(
                    update(Notification)
                    .where(Notification.user_id == self.user.id)
                    .values(is_read=True)
                )
                session.commit()
                
                # Notify home to clear badge
                self.ft_page.pubsub.send_all_on_topic(f"user_{self.user.id}", "refresh_home")
        except Exception as ex:
            print("Error marking all as read:", ex)

        snack = ft.SnackBar(
            content=ft.Text("Todas las notificaciones han sido marcadas como leídas."),
            bgcolor=SUCCESS_COLOR
        )
        self.ft_page.overlay.append(snack)
        snack.open = True
        self.ft_page.update()
        self.load_notifications()
