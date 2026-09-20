"""
Vista del Panel de Gestión de Suscripciones para el Administrador.
Permite al Administrador:
1. Ver solicitudes pendientes de pago/activación y APROBARLAS o RECHAZARLAS.
2. Cambiar manualmente el plan de cualquier doctor (Básico $10, VIP $30 o Remover Suscripción).
3. Revocar o remover el rango VIP / Destacado inmediatamente.
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

class AdminSubscriptionsView(ft.Container):
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
        self.padding = 20

        self.build_ui()
        self.load_doctors_and_subscriptions()

    def build_ui(self):
        def handle_back(e):
            if self.on_navigate:
                self.on_navigate("home")
            elif self.ft_page and len(self.ft_page.views) > 1:
                self.ft_page.views.pop()
                self.ft_page.update()

        self.header = ft.Row([
            ft.IconButton(
                icon=ft.Icons.ARROW_BACK,
                icon_color=PRIMARY_COLOR,
                on_click=handle_back
            ),
            ft.Column([
                ft.Text("Gestión de Suscripciones", size=18, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                ft.Text("Aprueba pagos y asigna rangos VIP o Destacado", size=11, color=TEXT_SECONDARY),
            ], spacing=2, expand=True)
        ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER)

        self.list_container = ft.Column(spacing=12, scroll=ft.ScrollMode.AUTO, expand=True)

        self.content = ft.Column([
            self.header,
            ft.Divider(height=15, color="transparent"),
            ft.Text("Doctores Registrados y Estado de Suscripción", size=16, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
            ft.Divider(height=10, color="transparent"),
            self.list_container
        ], expand=True)

    def load_doctors_and_subscriptions(self):
        self.list_container.controls.clear()
        
        try:
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker, joinedload
            from app.models.doctors import Doctor
            from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
            
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            SyncSession = sessionmaker(bind=sync_engine)

            with SyncSession() as session:
                query = select(Doctor).options(joinedload(Doctor.user), joinedload(Doctor.subscriptions))
                doctors = session.execute(query).scalars().unique().all()

                if not doctors:
                    self.list_container.controls.append(
                        ft.Text("No hay doctores registrados en el sistema.", color=TEXT_SECONDARY)
                    )
                else:
                    for doc in doctors:
                        self.list_container.controls.append(self.create_doctor_subscription_card(doc, session))

            self.ft_page.update()
        except Exception as ex:
            self.list_container.controls.append(
                ft.Text(f"Error al cargar doctores: {str(ex)}", color=ERROR_COLOR)
            )
            self.ft_page.update()

    def create_doctor_subscription_card(self, doctor, session):
        doc_name = f"Dr{'a' if doctor.user.first_name[-1].lower() == 'a' else ''}. {doctor.user.first_name} {doctor.user.last_name}"
        specialty = doctor.specialties[0] if getattr(doctor, 'specialties', None) else "Especialista Médico"
        
        pending_sub = next((s for s in doctor.subscriptions if (hasattr(s.status, 'value') and s.status.value == "pending_approval") or s.status == "pending_approval"), None)

        # Determinar badge según estado
        if pending_sub:
            plan_name = pending_sub.plan.value if hasattr(pending_sub.plan, 'value') else str(pending_sub.plan)
            badge_text = f"⏳ Pago Pendiente ({plan_name})"
            badge_color = WARNING_COLOR
        elif doctor.is_sponsored:
            badge_text = "⭐ VIP Patrocinado ($40/mes)"
            badge_color = PRIMARY_COLOR
        elif doctor.is_featured:
            badge_text = "✓ Básico Destacado ($20/mes)"
            badge_color = ACCENT_COLOR
        else:
            badge_text = "⚪ Sin Suscripción (Gratuito)"
            badge_color = TEXT_SECONDARY

        def approve_vip(e, doc_id=doctor.id):
            self.update_doctor_plan(doc_id, is_sponsored=True, is_featured=False)

        def approve_basic(e, doc_id=doctor.id):
            self.update_doctor_plan(doc_id, is_sponsored=False, is_featured=True)

        def remove_plan(e, doc_id=doctor.id):
            self.update_doctor_plan(doc_id, is_sponsored=False, is_featured=False)

        def validate_payment(e, sub_id=pending_sub.id if pending_sub else None):
            self.approve_subscription_payment(sub_id)

        actions = []
        if pending_sub:
            actions.append(ft.Button(
                "Validar Pago",
                icon=ft.Icons.DOMAIN_VERIFICATION,
                style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR, color="white"),
                on_click=validate_payment
            ))
            
        actions.extend([
            ft.Button(
                "Asignar VIP Manual",
                icon=ft.Icons.STAR,
                style=ft.ButtonStyle(bgcolor=PRIMARY_COLOR, color="white"),
                on_click=approve_vip
            ),
            ft.Button(
                "Asignar Básico Manual",
                icon=ft.Icons.CHECK_CIRCLE,
                style=ft.ButtonStyle(bgcolor=ACCENT_COLOR, color="white"),
                on_click=approve_basic
            ),
            ft.OutlinedButton(
                "Remover Suscripción",
                icon=ft.Icons.BLOCK,
                style=ft.ButtonStyle(color=ERROR_COLOR),
                on_click=remove_plan
            )
        ])

        actions_row = ft.Row(actions, wrap=True, spacing=8)

        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Column([
                        ft.Text(doc_name, size=16, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                        ft.Text(f"Especialidad: {specialty} | {doctor.user.email}", size=12, color=TEXT_SECONDARY),
                    ], expand=True),
                    ft.Container(
                        content=ft.Text(badge_text, size=11, color="white", weight=ft.FontWeight.BOLD),
                        bgcolor=badge_color,
                        padding=5,
                        border_radius=10
                    )
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                ft.Divider(height=10, color=BORDER_COLOR),
                ft.Text("Acciones de Administrador:", size=12, weight=ft.FontWeight.W_600, color=TEXT_PRIMARY),
                actions_row
            ], spacing=8),
            padding=15,
            bgcolor=colors.CARD_BG,
            border_radius=15,
            border=ft.border.all(1, colors.GLASS_BORDER),
            blur=ft.Blur(15, 15, ft.BlurTileMode.MIRROR)
        )

    def update_doctor_plan(self, doctor_id: int, is_sponsored: bool, is_featured: bool):
        try:
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker
            from app.models.doctors import Doctor
            from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
            from datetime import datetime, timedelta, timezone

            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            SyncSession = sessionmaker(bind=sync_engine)

            with SyncSession() as session:
                doctor = session.get(Doctor, doctor_id)
                if doctor:
                    doctor.is_sponsored = is_sponsored
                    doctor.sponsored_priority = 1 if is_sponsored else 99
                    doctor.is_featured = is_featured
                    doctor.is_approved = is_sponsored or is_featured
                    
                    # Cancelar suscripciones activas previas
                    active_subs = session.execute(
                        select(Subscription).where(
                            Subscription.doctor_id == doctor_id,
                            Subscription.status == SubscriptionStatus.ACTIVE
                        )
                    ).scalars().all()
                    for s in active_subs:
                        s.status = SubscriptionStatus.CANCELLED
                    
                    # Actualizar o crear registro de suscripción
                    now = datetime.now(timezone.utc)
                    from app.models.notifications import Notification, NotificationType
                    if is_sponsored or is_featured:
                        plan_type = SubscriptionPlan.SPONSORED if is_sponsored else SubscriptionPlan.FEATURED
                        sub = Subscription(
                            doctor_id=doctor_id,
                            plan=plan_type,
                            status=SubscriptionStatus.ACTIVE,
                            start_date=now,
                            end_date=now + timedelta(days=30),
                            grace_end_date=now + timedelta(days=33),
                            auto_renew=True
                        )
                        session.add(sub)
                        
                        # Notificar al doctor que su plan fue activado
                        plan_label = "VIP Patrocinado" if is_sponsored else "Básico Destacado"
                        notif = Notification(
                            user_id=doctor.user_id,
                            type=NotificationType.SUBSCRIPTION_RENEWED,
                            title=f"¡Plan {plan_label} Activado!",
                            message=f"El administrador ha activado tu plan {plan_label}. Ya apareces en la lista de doctores y cuentas con todos los beneficios del plan."
                        )
                        session.add(notif)
                    else:
                        notif = Notification(
                            user_id=doctor.user_id,
                            type=NotificationType.SUBSCRIPTION_REVOKED,
                            title="Suscripción Removida",
                            message="Su suscripción ha sido cancelada o expirada. Su cuenta ha vuelto al plan básico gratuito y ya no cuenta con los beneficios VIP/Destacado."
                        )
                        session.add(notif)
                    
                    session.commit()
                    
                    # Enviar notificación en tiempo real por pubsub
                    if is_sponsored or is_featured:
                        plan_label = "VIP Patrocinado" if is_sponsored else "Básico Destacado"
                        self.ft_page.pubsub.send_all_on_topic(
                            f"user_{doctor.user_id}",
                            f"new_notification:¡Tu plan {plan_label} ha sido activado!"
                        )
                    
                    snack = ft.SnackBar(
                        content=ft.Text("Estado de la suscripción actualizado exitosamente."),
                        bgcolor=SUCCESS_COLOR
                    )
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.ft_page.update()
                    self.load_doctors_and_subscriptions()
        except Exception as ex:
            snack = ft.SnackBar(
                content=ft.Text("No se pudo conectar con el servidor."),
                bgcolor=ERROR_COLOR
            )
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()

    def approve_subscription_payment(self, subscription_id: int):
        try:
            from sqlalchemy import create_engine
            from sqlalchemy.orm import sessionmaker
            from app.models.subscriptions import Subscription, SubscriptionStatus
            from app.models.doctors import Doctor

            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            SyncSession = sessionmaker(bind=sync_engine)

            with SyncSession() as session:
                sub = session.get(Subscription, subscription_id)
                if sub and sub.status.name == "PENDING_APPROVAL":
                    sub.status = SubscriptionStatus.ACTIVE
                    
                    doctor = session.get(Doctor, sub.doctor_id)
                    if doctor:
                        doctor.is_approved = True
                        if sub.plan.name == "SPONSORED":
                            doctor.is_sponsored = True
                            doctor.sponsored_priority = 1
                            doctor.is_featured = False
                        else:
                            doctor.is_sponsored = False
                            doctor.sponsored_priority = 99
                            doctor.is_featured = True
                            
                        # Notificar al doctor
                        from app.models.notifications import Notification, NotificationType
                        notif_msg = "Tu suscripción ha sido validada y está activa."
                        if not doctor.is_approved:
                            notif_msg = "Tu cuenta ha sido aprobada y tu suscripción está activa. Ya apareces en la lista de doctores."
                        
                        notif = Notification(
                            user_id=doctor.user_id,
                            type=NotificationType.SUBSCRIPTION_RENEWED,
                            title="¡Suscripción Aprobada!",
                            message=notif_msg
                        )
                        session.add(notif)
                            
                    session.commit()
                    
                    if doctor:
                        self.ft_page.pubsub.send_all_on_topic(
                            f"user_{doctor.user_id}",
                            f"new_notification:Tu suscripción ha sido validada"
                        )
                    
                    snack = ft.SnackBar(
                        content=ft.Text("Pago validado y suscripción activada correctamente."),
                        bgcolor=SUCCESS_COLOR
                    )
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.ft_page.update()
                    self.load_doctors_and_subscriptions()
                else:
                    snack = ft.SnackBar(
                        content=ft.Text("Suscripción no encontrada o ya estaba activa."),
                        bgcolor=ERROR_COLOR
                    )
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.ft_page.update()
        except Exception as ex:
            print("Error en approve_subscription_payment:", ex)
            snack = ft.SnackBar(
                content=ft.Text(f"Error al validar pago: {ex}"),
                bgcolor=ERROR_COLOR
            )
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()
