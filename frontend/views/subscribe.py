"""
Vista de Suscripción para Doctores.
Muestra el estado actual de la suscripción, los planes disponibles (Patrocinado / Destacado / Gratuito)
y permite seleccionar un plan para suscribirse o renovar con pasarela de pago simulada.
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
CARD_BG = colors.CARD_BG
BORDER_COLOR = colors.INPUT_BORDER

class SubscribeView(ft.Container):
    def __init__(self, page: ft.Page, user=None, on_navigate=None, is_root=False):
        super().__init__(expand=True)
        self.ft_page = page
        self.user = user
        self.on_navigate = on_navigate
        self.is_root = is_root
        self.bg_color = BG_COLOR
        self.padding = 30
        
        self.current_sub = None
        self.loading = True
        self.billing_cycle = "Mensual"
        
        self.build_ui()
        self.load_data()

    def build_ui(self):
        def handle_back(e):
            if self.on_navigate:
                self.on_navigate("home")
            elif self.ft_page and len(self.ft_page.views) > 1:
                self.ft_page.views.pop()
                self.ft_page.update()

        async def on_logout_header(e):
            if hasattr(self.ft_page, 'shared_preferences'):
                try:
                    await self.ft_page.shared_preferences.remove("user_id")
                    await self.ft_page.shared_preferences.remove("session_token")
                except: pass
            if self.on_navigate:
                self.on_navigate("login")
            else:
                self.ft_page.views.clear()
                from views.login import LoginView
                self.ft_page.views.append(LoginView(self.ft_page))
            self.ft_page.update()

        self.header = ft.Row([
            ft.IconButton(
                icon=ft.Icons.ARROW_BACK,
                icon_color=PRIMARY_COLOR,
                on_click=handle_back,
                visible=not self.is_root
            ),
            ft.Column([
                ft.Text("Suscripción Médica", size=18, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                ft.Text("Planes para destacar tu perfil profesional", size=11, color=TEXT_SECONDARY),
            ], spacing=2, expand=True),
            ft.IconButton(
                icon=ft.Icons.LOGOUT,
                icon_color=ERROR_COLOR,
                tooltip="Cerrar Sesión",
                on_click=on_logout_header,
                visible=self.is_root
            )
        ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER)

        self.status_container = ft.Container(
            content=ft.ProgressRing(color=PRIMARY_COLOR),
            padding=15,
            alignment=ft.alignment.Alignment.CENTER
        )

        self.plans_container = ft.Column(
            controls=[],
            spacing=15,
            horizontal_alignment=ft.CrossAxisAlignment.STRETCH
        )

        def switch_billing(e, cycle):
            self.billing_cycle = cycle
            self.btn_mensual.bgcolor = PRIMARY_COLOR if cycle == "Mensual" else SURFACE_COLOR
            self.btn_mensual.color = "white" if cycle == "Mensual" else TEXT_PRIMARY
            self.btn_anual.bgcolor = PRIMARY_COLOR if cycle == "Anual" else SURFACE_COLOR
            self.btn_anual.color = "white" if cycle == "Anual" else TEXT_PRIMARY
            self.render_plans()
            self.ft_page.update()

        self.btn_mensual = ft.Button(
            "Mensual", 
            bgcolor=PRIMARY_COLOR, 
            color="white", 
            on_click=lambda e: switch_billing(e, "Mensual"),
            style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=20))
        )
        self.btn_anual = ft.Button(
            "Anual", 
            bgcolor=SURFACE_COLOR, 
            color=TEXT_PRIMARY, 
            on_click=lambda e: switch_billing(e, "Anual"),
            style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=20))
        )
        self.billing_toggle_container = ft.Row(
            [self.btn_mensual, self.btn_anual], 
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=10
        )

        self.normal_controls = [
            self.header,
            ft.Divider(height=15, color="transparent"),
            self.status_container,
            ft.Divider(height=15, color="transparent"),
            ft.Text("Planes para Doctores", size=18, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
            ft.Text("Los pacientes disfrutan de acceso gratuito. Selecciona tu plan:", size=13, color=TEXT_SECONDARY),
            ft.Divider(height=10, color="transparent"),
            self.billing_toggle_container,
            self.plans_container
        ]

        self.content = ft.Column(self.normal_controls.copy(), scroll=ft.ScrollMode.AUTO, expand=True)

    def load_data(self):
        role = self.user.role.value if hasattr(self.user.role, 'value') else str(self.user.role) if self.user and hasattr(self.user, 'role') else "doctor"
        if role not in ("doctor", "admin"):
            self.status_container.content = ft.Container(
                content=ft.Text("Los pacientes tienen acceso 100% gratuito. Solo los doctores gestionan suscripciones de visibilidad.", color=PRIMARY_COLOR, weight=ft.FontWeight.W_600, size=13),
                padding=20,
                bgcolor=SURFACE_COLOR,
                border_radius=12
            )
            self.ft_page.update()
            return
        
        try:
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker
            from app.models.subscriptions import Subscription, SubscriptionStatus
            from app.models.doctors import Doctor
            
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)

            with Session() as session:
                doc = session.execute(select(Doctor).where(Doctor.user_id == self.user.id)).scalar_one_or_none()
                if doc:
                    sub = session.execute(
                        select(Subscription).where(
                            Subscription.doctor_id == doc.id,
                            Subscription.status == SubscriptionStatus.ACTIVE
                        ).order_by(Subscription.created_at.desc())
                    ).scalars().first()
                    self.current_sub = sub
                    
                    self.pending_sub = session.execute(
                        select(Subscription).where(
                            Subscription.doctor_id == doc.id,
                            Subscription.status == SubscriptionStatus.PENDING_APPROVAL
                        ).order_by(Subscription.created_at.desc())
                    ).scalars().first()
        except Exception as ex:
            print("Error loading subscription:", ex)

        self.render_current_status()
        self.render_plans()
        self.ft_page.update()

    def show_pending_screen(self):
        def on_re_report(e):
            self.content.controls = self.normal_controls.copy()
            self.content.alignment = ft.MainAxisAlignment.START
            self.content.horizontal_alignment = ft.CrossAxisAlignment.START
            self.pending_sub = None
            self.render_current_status()
            self.render_plans()
            self.ft_page.update()

        async def on_logout(e):
            if hasattr(self.ft_page, 'shared_preferences'):
                try:
                    await self.ft_page.shared_preferences.remove("user_id")
                    await self.ft_page.shared_preferences.remove("session_token")
                except: pass
            if self.on_navigate:
                self.on_navigate("login")
            else:
                self.ft_page.views.clear()
                from views.login import LoginView
                self.ft_page.views.append(LoginView(self.ft_page))
            self.ft_page.update()

        self.content.controls = [
            ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.HOURGLASS_TOP, size=64, color=WARNING_COLOR),
                    ft.Text("Cuenta inactiva o pendiente", size=22, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                    ft.Text("Para utilizar la plataforma como Especialista Médico, debe suscribirse a un plan y esperar la validación del administrador.", size=13, color=TEXT_SECONDARY, text_align=ft.TextAlign.CENTER),
                    ft.Divider(height=20, color="transparent"),
                    ft.Button("Volver a reportar el pago", style=ft.ButtonStyle(style=ft.ButtonStyle(bgcolor=PRIMARY_COLOR), color="white"), on_click=on_re_report),
                    ft.TextButton("Cerrar Sesión", on_click=on_logout)
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, alignment=ft.MainAxisAlignment.CENTER),
                alignment=ft.Alignment.CENTER,
                expand=True,
                padding=20
            )
        ]
        self.content.alignment = ft.MainAxisAlignment.CENTER
        self.content.horizontal_alignment = ft.CrossAxisAlignment.CENTER

    def render_current_status(self):
        if getattr(self, 'pending_sub', None):
            self.show_pending_screen()
            return
            
        self.content.controls = self.normal_controls.copy()
        self.content.alignment = ft.MainAxisAlignment.START
        self.content.horizontal_alignment = ft.CrossAxisAlignment.START
        
        if self.current_sub:
            plan_str = "Plan VIP" if "sponsored" in str(self.current_sub.plan).lower() else "Plan Básico"
            days_left = (self.current_sub.end_date.replace(tzinfo=None) - __import__('datetime').datetime.utcnow()).days
            self.status_container.content = ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(ft.Icons.VERIFIED, color=SUCCESS_COLOR, size=24),
                        ft.Column([
                            ft.Text(f"Suscripción Activa: {plan_str}", size=15, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                            ft.Text("Posicionamiento prioritario TOP en tu especialidad", size=12, color=TEXT_SECONDARY)
                        ], expand=True),
                        ft.Container(
                            content=ft.Text(f"Vence en {max(0, days_left)} días", color=PRIMARY_COLOR, weight=ft.FontWeight.BOLD, size=11),
                            bgcolor=PRIMARY_COLOR + "15",
                            padding=6,
                            border_radius=12
                        )
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                ], spacing=8),
                padding=15,
                border_radius=12,
                bgcolor=SURFACE_COLOR,
                border=ft.border.Border.all(1, PRIMARY_COLOR + "40")
            )
        else:
            self.status_container.content = ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(ft.Icons.INFO, color=TEXT_SECONDARY, size=24),
                        ft.Column([
                            ft.Text("Suscripción Actual: Plan Gratuito", size=15, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                            ft.Text("No cuentas con prioridad en los resultados de búsqueda.", size=12, color=TEXT_SECONDARY)
                        ], expand=True),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                ], spacing=8),
                padding=15,
                border_radius=12,
                bgcolor=SURFACE_COLOR,
                border=ft.border.Border.all(1, BORDER_COLOR)
            )

        self.render_plans()

    def render_plans(self):
        is_basic = bool(self.current_sub and "featured" in str(self.current_sub.plan).lower())
        is_vip = bool(self.current_sub and "sponsored" in str(self.current_sub.plan).lower())
        
        is_anual = self.billing_cycle == "Anual"
        
        basic_price = "$200 / año" if is_anual else "$20 / mes"
        vip_price = "$400 / año" if is_anual else "$40 / mes"
        
        basic_price_val = "$200.00" if is_anual else "$20.00"
        vip_price_val = "$400.00" if is_anual else "$40.00"
        
        basic_badge = "Ahorra hasta 2 Meses" if is_anual else "Popular"
        vip_badge = "Ahorra hasta 2 Meses" if is_anual else "Recomendado"

        plan_basic = self.create_plan_card(
            title="Plan Básico",
            price=basic_price,
            subtitle="Presencia médica y posicionamiento destacado",
            features=[
                "Perfil médico verificado",
                "Insignia 'Doctor Destacado'",
                "Recepción ilimitada de citas",
                "Notificaciones en tiempo real"
            ],
            badge=basic_badge,
            badge_color=ACCENT_COLOR,
            btn_text=f"Plan Actual ({basic_price})" if is_basic else f"Seleccionar {basic_price}",
            price_val=basic_price_val,
            is_current=is_basic
        )

        plan_vip = self.create_plan_card(
            title="Plan VIP Patrocinado",
            price=vip_price,
            subtitle="Máxima visibilidad y posicionamiento TOP #1",
            features=[
                "Prioridad absoluta TOP #1 en búsquedas",
                "Insignia 'Patrocinado VIP'",
                "Banner promocional destacado",
                "Recordatorios automatizados a pacientes",
                "Cuenta adicional para Asistente Médico",
                "Estadísticas semanales de pacientes",
                "Soporte preferencial 24/7"
            ],
            badge=vip_badge,
            badge_color=PRIMARY_COLOR,
            btn_text=f"Plan Actual ({vip_price})" if is_vip else f"Seleccionar {vip_price}",
            price_val=vip_price_val,
            is_current=is_vip
        )

        self.plans_container.controls = [plan_basic, plan_vip]

    def create_plan_card(self, title, price, subtitle, features, badge, badge_color, btn_text, price_val, is_current=False):
        feature_items = [
            ft.Row([
                ft.Icon(ft.Icons.CHECK_CIRCLE, color=SUCCESS_COLOR, size=16),
                ft.Text(f, size=12, color=TEXT_PRIMARY, expand=True)
            ], spacing=6) for f in features
        ]

        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Text(title, size=18, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY, expand=True),
                    ft.Container(
                        content=ft.Text(badge, size=10, color="white", weight=ft.FontWeight.BOLD),
                        bgcolor=badge_color,
                        padding=4,
                        border_radius=8
                    )
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                ft.Text(price, size=22, weight=ft.FontWeight.BOLD, color=PRIMARY_COLOR if is_current else ACCENT_COLOR),
                ft.Text(subtitle, size=12, color=TEXT_SECONDARY),
                ft.Divider(height=12, color=BORDER_COLOR),
                ft.Column(feature_items, spacing=6),
                ft.Divider(height=12, color="transparent"),
                ft.Button(
                    btn_text,
                    icon=ft.Icons.CREDIT_CARD,
                    style=ft.ButtonStyle(
                        bgcolor=PRIMARY_COLOR if is_current else ACCENT_COLOR,
                        color="white",
                        shape=ft.RoundedRectangleBorder(radius=8),
                        padding=ft.padding.Padding.all(12)
                    ),
                    on_click=lambda e, t=title, p=price_val: self.open_payment_modal(t, p),
                )
            ], spacing=6),
            padding=16,
            border_radius=12,
            bgcolor=SURFACE_COLOR,
            border=ft.border.Border.all(2 if is_current else 1, PRIMARY_COLOR if is_current else BORDER_COLOR)
        )

    def open_payment_modal(self, plan_name, price_val):
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        from app.models.exchange_rate import ExchangeRate
        import decimal
        
        # Leer tasa BCV de la BD
        from core.config import SYNC_DB_URL
        sync_engine = create_engine(SYNC_DB_URL)
        Session = sessionmaker(bind=sync_engine)
        
        tasa_bcv = 36.50 # Failsafe default
        try:
            with Session() as session:
                rate_entry = session.execute(
                    select(ExchangeRate).where(
                        ExchangeRate.moneda_origen == 'USD',
                        ExchangeRate.moneda_destino == 'VES'
                    )
                ).scalar_one_or_none()
                if rate_entry:
                    tasa_bcv = float(rate_entry.tasa)
        except Exception as ex:
            print("Error leyendo tasa BCV:", ex)
            
        # Calcular el monto en VES
        precio_usd = float(price_val.replace("$", "").replace(",", ""))
        precio_ves = precio_usd * tasa_bcv
        precio_ves_str = f"{precio_ves:,.2f} VES"
        reference_input = ft.TextField(
            label="N° de Referencia",
            width=300,
            keyboard_type=ft.KeyboardType.NUMBER,
            input_filter=ft.NumbersOnlyInputFilter(),
            max_length=20,
            color=TEXT_PRIMARY,
            bgcolor=SURFACE_COLOR
        )
        
        def close_dlg(e):
            dialog.open = False
            self.ft_page.update()

        async def copy_payment_data(e):
            await self.ft_page.clipboard.set(f"Pago Movil:\n0102\n04165100646\n25006611\n{precio_ves_str}")
            snack = ft.SnackBar(ft.Text("Datos copiados al portapapeles"), bgcolor=SUCCESS_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()

        def confirm_pay(e):
            if not reference_input.value or len(reference_input.value.strip()) < 4:
                snack = ft.SnackBar(ft.Text("Por favor, ingrese un número de referencia válido."), bgcolor="red")
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
                return

            try:
                import sys, os, shutil
                from sqlalchemy import create_engine, select
                from sqlalchemy.orm import sessionmaker
                from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus
                from app.models.doctors import Doctor
                from app.models.notifications import Notification, NotificationType
                from app.models.users import User, RoleEnum
                from datetime import datetime, timedelta

                ref_number = reference_input.value.strip()

                from core.config import SYNC_DB_URL
                sync_engine = create_engine(SYNC_DB_URL)
                Session = sessionmaker(bind=sync_engine)

                with Session() as session:
                    doc = session.execute(select(Doctor).where(Doctor.user_id == self.user.id)).scalar_one_or_none()
                    if doc:
                        plan_enum = SubscriptionPlan.FEATURED if "Destacado" in plan_name or "Básico" in plan_name else SubscriptionPlan.SPONSORED
                        new_sub = Subscription(
                            doctor_id=doc.id,
                            plan=plan_enum,
                            status=SubscriptionStatus.PENDING_APPROVAL,
                            start_date=datetime.utcnow(),
                            end_date=datetime.utcnow() + timedelta(days=365 if self.billing_cycle == "Anual" else 30),
                            grace_end_date=datetime.utcnow() + timedelta(days=370 if self.billing_cycle == "Anual" else 35)
                        )
                        session.add(new_sub)
                        
                        admins = session.execute(select(User).where(User.role == RoleEnum.ADMIN)).scalars().all()
                        for admin in admins:
                            notif = Notification(
                                user_id=admin.id,
                                type=NotificationType.NEW_SUBSCRIPTION,
                                title="Nuevo Pago de Suscripción",
                                message=f"El Dr(a). {self.user.first_name} {self.user.last_name} reportó un pago para el {plan_name} ({self.billing_cycle}). Ref: {ref_number}",
                                action_url=f"approve_subscription:{new_sub.id}"
                            )
                            session.add(notif)

                        session.commit()
                        
                        dialog.open = False

                        snack = ft.SnackBar(
                            content=ft.Text(f"¡Pago reportado! Tu solicitud para el {plan_name} ha sido enviada. El Administrador confirmará el pago."),
                            bgcolor=SUCCESS_COLOR
                        )
                        self.ft_page.overlay.append(snack)
                        snack.open = True
                        
                        self.load_data()
                    else:
                        dialog.open = False
                        snack = ft.SnackBar(content=ft.Text("Error: No se encontró perfil de doctor asociado."), bgcolor="red")
                        self.ft_page.overlay.append(snack)
                        snack.open = True
                        self.ft_page.update()
            except Exception as ex:
                print(ex)

        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text(f"Suscripción {plan_name}", size=18, weight=ft.FontWeight.BOLD),
            content=ft.Column([
                ft.Text(f"El monto a transferir correspondiente: {price_val} USD", size=13, weight=ft.FontWeight.BOLD, color=PRIMARY_COLOR),
                ft.Text(f"Equivalente en Bolívares (Tasa BCV {tasa_bcv:.4f}): {precio_ves_str}", size=13, weight=ft.FontWeight.BOLD, color=SUCCESS_COLOR),
                ft.Divider(height=10, color="transparent"),
                ft.Container(
                    content=ft.Column([
                        ft.Row([
                            ft.Text("Datos de Pago Móvil", weight=ft.FontWeight.BOLD, size=13),
                            ft.IconButton(ft.Icons.COPY, icon_size=18, on_click=copy_payment_data, tooltip="Copiar datos")
                        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                        ft.Text(f"0102\n04165100646\n25006611\n{precio_ves_str}", size=13, color=TEXT_PRIMARY, selectable=True),
                    ], spacing=2),
                    bgcolor=SURFACE_COLOR,
                    padding=10,
                    border_radius=8,
                    border=ft.border.Border.all(1, BORDER_COLOR)
                ),
                ft.Divider(height=10, color="transparent"),
                ft.Text("Indicar Referencia de Pago:", size=12, weight=ft.FontWeight.BOLD),
                reference_input
            ], width=360, height=330, spacing=5),
            actions=[
                ft.TextButton("Cancelar", on_click=close_dlg),
                ft.Button("Realizar Pago de Suscripción", style=ft.ButtonStyle(style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR), color="white"), on_click=confirm_pay)
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )

        self.ft_page.overlay.append(dialog)
        dialog.open = True
        self.ft_page.update()
