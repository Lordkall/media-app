import flet as ft
from core import colors

def HomeView(page: ft.Page, user):
    """Vista principal después del login. Muestra contenido según el rol."""

    role_labels = {
        "admin": "Administrador",
        "doctor": "Doctor",
        "patient": "Paciente",
        "assistant": "Asistente",
        "ASSISTANT": "Asistente",
    }
    role_val = user.role.value if hasattr(user.role, 'value') else str(user.role)
    role_label = role_labels.get(role_val, role_val)

    if role_val in ("assistant", "ASSISTANT"):
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
        from core.config import SYNC_DB_URL
        engine = create_engine(SYNC_DB_URL)
        Session = sessionmaker(bind=engine)
        
        has_active_vip = False
        try:
            with Session() as session:
                sub = session.execute(
                    select(Subscription).where(
                        Subscription.doctor_id == user.linked_doctor_id,
                        Subscription.status == SubscriptionStatus.ACTIVE,
                        Subscription.plan == SubscriptionPlan.SPONSORED
                    )
                ).scalars().first()
                if sub:
                    has_active_vip = True
        except Exception as e:
            print("Error checking assistant VIP sub:", e)
            
        if not has_active_vip:
            def force_logout(e):
                page.session.clear()
                page.views.clear()
                from views.welcome import WelcomeView
                page.views.append(WelcomeView(page))
                page.update()
                
            return ft.View(
                "/home",
                controls=[
                    ft.Container(
                        content=ft.Column([
                            ft.Icon(ft.Icons.LOCK, size=60, color="red"),
                            ft.Text("Acceso Denegado", size=24, weight=ft.FontWeight.BOLD),
                            ft.Text("El doctor asociado ya no cuenta con un plan VIP activo.", text_align=ft.TextAlign.CENTER),
                            ft.Button("Cerrar Sesión", on_click=force_logout, style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"))
                        ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=20),
                        expand=True,
                        alignment=ft.alignment.center
                    )
                ],
                bgcolor=colors.BACKGROUND
            )

    if role_val == "doctor":
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        from app.models.subscriptions import Subscription, SubscriptionStatus
        from app.models.doctors import Doctor
        
        has_active_sub = False
        try:
            from core.config import SYNC_DB_URL
            engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=engine)
            with Session() as session:
                doc = session.execute(select(Doctor).where(Doctor.user_id == user.id)).scalar_one_or_none()
                if doc:
                    sub = session.execute(
                        select(Subscription).where(
                            Subscription.doctor_id == doc.id, 
                            Subscription.status == SubscriptionStatus.ACTIVE
                        ).order_by(Subscription.created_at.desc())
                    ).scalars().first()
                    if sub:
                        has_active_sub = True
        except Exception as e:
            print("Error checking subscription:", e)
            
        if not has_active_sub:
            from views.subscribe import SubscribeView
            return ft.View(route="/home", controls=[SubscribeView(page, user=user, is_root=True)], bgcolor=colors.BACKGROUND)

    def handle_logout(e=None, forced=False):
        async def _run():
            # Limpiar almacenamiento local
            try:
                await page.shared_preferences.remove("session_token")
                await page.shared_preferences.remove("user_id")
            except Exception as e:
                print("Error removing shared_preferences:", e)
                
            try:
                if hasattr(page, "my_pubsub_topic") and hasattr(page, "my_pubsub_handler"):
                    page.pubsub.unsubscribe_topic(page.my_pubsub_topic, page.my_pubsub_handler)
                    delattr(page, "my_pubsub_topic")
                    delattr(page, "my_pubsub_handler")
                page.pubsub.unsubscribe_topic(f"user_{user.id}", on_pubsub_message)
            except Exception:
                pass
            
            # Volver al login
            page.views.clear()
            from views.login import LoginView
            page.views.append(LoginView(page))
            
            if forced:
                snack = ft.SnackBar(ft.Text("Sesión cerrada porque iniciaste en otro dispositivo."), bgcolor="red")
                page.overlay.append(snack)
                snack.open = True
                
            page.update()
            
        page.run_task(_run)
            
        page.update()

    def on_pubsub_message(topic, msg):
        if str(msg).startswith("force_logout:"):
            sender_id = msg.split(":", 1)[1]
            if getattr(page, 'session_id', '') == sender_id:
                return # Ignore my own message
            handle_logout(forced=True)
        elif msg == "force_logout": # fallback
            handle_logout(forced=True)
        elif msg == "refresh_home":
            try:
                page.pubsub.unsubscribe_topic(f"user_{user.id}", on_pubsub_message)
            except: pass
            if page.views:
                page.views[0] = HomeView(page, user)
                page.update()
        elif str(msg).startswith("new_notification:"):
            msg_text = msg.split(":", 1)[1]
            snack = ft.SnackBar(ft.Text(msg_text), bgcolor="#10B981")
            page.overlay.append(snack)
            snack.open = True
            try:
                page.pubsub.unsubscribe_topic(f"user_{user.id}", on_pubsub_message)
            except: pass
            if page.views:
                page.views[0] = HomeView(page, user)
                page.update()
            
    if hasattr(page, "my_pubsub_topic") and hasattr(page, "my_pubsub_handler"):
        try:
            page.pubsub.unsubscribe_topic(page.my_pubsub_topic, page.my_pubsub_handler)
        except Exception:
            pass
            
    page.my_pubsub_topic = f"user_{user.id}"
    page.my_pubsub_handler = on_pubsub_message
    page.pubsub.subscribe_topic(page.my_pubsub_topic, on_pubsub_message)


    def go_to_browse_doctors(e):
        from views.browse_doctors import BrowseDoctorsView
        page.views.append(BrowseDoctorsView(page, user))
        page.update()

    def go_to_subscribe(e):
        from views.subscribe import SubscribeView
        page.views.append(ft.View(route="/subscribe", controls=[SubscribeView(page, user=user)], bgcolor=colors.BACKGROUND))
        page.update()

    def go_to_notifications(e):
        from views.notifications_view import NotificationsView
        page.views.append(ft.View(route="/notifications", controls=[NotificationsView(page, user=user)], bgcolor=colors.BACKGROUND))
        page.update()

    # Obtener count de notificaciones
    unread_count = 0
    unread_support_count = 0
    try:
        from sqlalchemy import create_engine, select, func
        from sqlalchemy.orm import sessionmaker
        import sys, os
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        if base_path not in sys.path: sys.path.append(base_path)
        from app.models.notifications import Notification
        from app.models.support import SupportTicket, TicketMessage
        from core.config import SYNC_DB_URL
        sync_engine = create_engine(SYNC_DB_URL)
        Session = sessionmaker(bind=sync_engine)
        with Session() as session:
            unread_count = session.execute(
                select(func.count(Notification.id)).where(
                    Notification.user_id == user.id,
                    Notification.is_read == False
                )
            ).scalar() or 0
            
            # Count unread support messages
            if getattr(user.role, 'value', str(user.role)) == "admin":
                unread_support_count = session.execute(
                    select(func.count(TicketMessage.id)).join(SupportTicket).where(
                        SupportTicket.status == "ABIERTO",
                        TicketMessage.is_read == False,
                        TicketMessage.sender_id != user.id
                    )
                ).scalar() or 0
            else:
                unread_support_count = session.execute(
                    select(func.count(TicketMessage.id)).join(SupportTicket).where(
                        SupportTicket.user_id == user.id,
                        SupportTicket.status == "ABIERTO",
                        TicketMessage.is_read == False,
                        TicketMessage.sender_id != user.id
                    )
                ).scalar() or 0
                
    except Exception as ex:
        print("Error al obtener notificaciones:", ex)

    # Tarjeta de opción del menú
    def menu_card(icon, title, subtitle, on_click=None, icon_color=colors.PRIMARY, badge_count=0):
        icon_ctrl = ft.Icon(icon, color=icon_color, size=26)
        if badge_count > 0:
            icon_ctrl = ft.Stack([
                ft.Container(icon_ctrl, padding=5),
                ft.Container(
                    content=ft.Text(str(badge_count) if badge_count < 100 else "99+", size=9, color="white", weight=ft.FontWeight.BOLD),
                    bgcolor="red",
                    border_radius=10,
                    padding=2,
                    right=0, top=0,
                )
            ], width=35, height=35)
            
        import time
        def handle_click(e):
            now = time.time()
            if now - getattr(page, "_last_click_time", 0) < 1.0:
                return
            page._last_click_time = now
            if on_click: on_click(e)
            
        return ft.Container(
            content=ft.Row(
                [
                    ft.Container(
                        content=icon_ctrl,
                        width=50, height=50,
                        bgcolor=colors.INPUT_BG,
                        border_radius=12,
                        alignment=ft.alignment.Alignment.CENTER,
                    ),
                    ft.Column(
                        [
                            ft.Text(title, size=14, weight=ft.FontWeight.W_600, color=colors.TEXT_DARK),
                            ft.Text(subtitle, size=11, color=colors.TEXT_LIGHT),
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    ft.Icon(ft.Icons.CHEVRON_RIGHT, color=colors.TEXT_LIGHT, size=20),
                ],
                spacing=12,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor="white",
            border_radius=14,
            padding=14,
            border=ft.border.Border.all(1, colors.INPUT_BORDER),
            on_click=handle_click,
            shadow=ft.BoxShadow(
                spread_radius=0,
                blur_radius=6,
                color="#0D000000",
                offset=ft.Offset(0, 2),
            ),
        )

    def show_my_appointments(e):
        def close_dlg(e):
            dialog.open = False
            page.update()

        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker, joinedload
        import sys
        import os
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        if base_path not in sys.path:
            sys.path.append(base_path)
            
        from app.models.appointments import Appointment, AppointmentStatus
        from app.models.patients import Patient
        from app.models.doctors import Doctor
        
        from core.config import SYNC_DB_URL
        sync_engine = create_engine(SYNC_DB_URL)
        Session = sessionmaker(bind=sync_engine)
        
        appointments_list = ft.Column(spacing=10, scroll=ft.ScrollMode.AUTO, expand=True)
        from datetime import date
        filter_date = {"value": date.today()}
        
        def on_date_change(e):
            if date_picker.value:
                filter_date["value"] = date_picker.value.date()
                date_btn.text = filter_date["value"].strftime("%d/%m/%Y")
                load_appointments()
                page.update()
                
        date_picker = ft.DatePicker(
            on_change=on_date_change,
            first_date=date(2024, 1, 1),
            last_date=date(2030, 12, 31),
            locale=ft.Locale("es", "ES"),
            cancel_text="Cancelar",
            confirm_text="Aceptar",
            help_text="Seleccionar fecha"
        )
        def open_date_picker(e):
            date_picker.open = True
            page.update()
            
        page.overlay.append(date_picker)
        date_btn = ft.TextButton(
            filter_date["value"].strftime("%d/%m/%Y"),
            icon=ft.Icons.CALENDAR_MONTH,
            on_click=open_date_picker,
            style=ft.ButtonStyle(color=colors.PRIMARY)
        )
        
        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Row([
                ft.Icon(ft.Icons.CALENDAR_MONTH, color=colors.ACCENT_GREEN),
                ft.Text("Mis Citas Médicas", size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK)
            ], spacing=8),
            content=ft.Container(
                content=ft.Column([
                    ft.Row([ft.Text("Fecha:", weight=ft.FontWeight.BOLD), date_btn], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    ft.Divider(height=1),
                    appointments_list
                ]),
                width=340,
                height=400,
            ),
            actions=[
                ft.Button("Cerrar", style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"), on_click=close_dlg)
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )

        page.overlay.append(dialog)

        def load_appointments():
            appointments_list.controls.clear()
            try:
                with Session() as session:
                    pat = session.execute(select(Patient).where(Patient.user_id == user.id)).scalar_one_or_none()
                    if not pat:
                        appointments_list.controls.append(ft.Text("No se encontró su perfil de paciente.", color=getattr(colors, 'ERROR_COLOR', '#e74c3c')))
                        return
                    
                    query = select(Appointment).where(
                        Appointment.patient_id == pat.id,
                        Appointment.appointment_date == filter_date["value"]
                    ).options(joinedload(Appointment.doctor).joinedload(Doctor.user)).order_by(Appointment.appointment_date.desc())
                    
                    apps = session.execute(query).scalars().all()
                    
                    if not apps:
                        appointments_list.controls.append(ft.Text("No tienes citas médicas.", color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER))
                    
                    for a in apps:
                        doc_name = f"Dr{'a' if getattr(a.doctor.user, 'gender', '') == 'F' else ''}. {a.doctor.user.first_name} {a.doctor.user.last_name}"
                        spec = a.doctor.specialties[0] if getattr(a.doctor, 'specialties', None) else "Especialista Médico"
                        date_str = a.appointment_date.strftime("%d/%m/%Y")
                        turn = a.turn_number
                        
                        status_val = a.status.value if hasattr(a.status, 'value') else str(a.status)
                        
                        status_color = colors.ACCENT_GREEN if status_val == "scheduled" else (getattr(colors, 'ERROR_COLOR', '#e74c3c') if status_val == "cancelled" else colors.SECONDARY)
                        status_text = "Confirmada" if status_val == "scheduled" else ("Cancelada" if status_val == "cancelled" else "Completada")
                        
                        def cancel_appointment(app_id):
                            def handler(e):
                                try:
                                    with Session() as sess:
                                        app_to_cancel = sess.get(Appointment, app_id)
                                        if app_to_cancel:
                                            app_to_cancel.status = AppointmentStatus.CANCELLED
                                            
                                            from app.models.notifications import Notification, NotificationType
                                            patient_name = f"{user.first_name} {user.last_name}"
                                            notif = Notification(
                                                user_id=app_to_cancel.doctor.user_id,
                                                type=NotificationType.APPOINTMENT_CANCELLED,
                                                title="Cita Cancelada",
                                                message=f"El paciente {patient_name} ha cancelado su cita agendada para el {app_to_cancel.appointment_date.strftime('%d/%m/%Y')}."
                                            )
                                            sess.add(notif)
                                            sess.commit()
                                        load_appointments()
                                        page.update()
                                except Exception as ex:
                                    snack = ft.SnackBar(ft.Text(f"Error al cancelar: {ex}"), bgcolor=getattr(colors, 'ERROR_COLOR', '#e74c3c'))
                                    page.overlay.append(snack)
                                    snack.open = True
                                    page.update()
                            return handler
                            
                        # Configurar colores para la tarjeta estilo "teal"
                        card_bg = colors.PRIMARY # Usar el azul del logo
                        text_primary = "white"
                        text_secondary = "#e2f1f5" # Un color muy claro para contraste con PRIMARY
                        
                        avatar_initials = a.doctor.user.first_name[0].upper() + a.doctor.user.last_name[0].upper()
                        location_text = f"{a.doctor.user.state or ''} {a.doctor.user.address or ''}".strip()
                        if not location_text:
                            location_text = "Centro Médico"

                        # Icono o estado superior derecho
                        status_chip = ft.Container(
                            content=ft.Text(status_text, size=10, color="white", weight=ft.FontWeight.BOLD),
                            bgcolor=status_color if status_val != "scheduled" else "transparent",
                            padding=4,
                            border_radius=8,
                            border=ft.border.Border.all(1, "white") if status_val == "scheduled" else None
                        )

                        # Fila superior: Avatar + Info + Estado
                        top_row = ft.Row([
                            ft.CircleAvatar(
                                content=ft.Text(avatar_initials, color=card_bg, size=14, weight=ft.FontWeight.BOLD),
                                bgcolor="white",
                                radius=20
                            ),
                            ft.Column([
                                ft.Text(doc_name, weight=ft.FontWeight.BOLD, size=14, color=text_primary),
                                ft.Text(location_text, size=11, color=text_secondary),
                            ], expand=True, spacing=2),
                            status_chip
                        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.START)

                        # Centro: Especialidad
                        middle_section = ft.Container(
                            content=ft.Row([
                                ft.Container(width=40),
                                ft.Text(f"Especialidad: {spec}", size=13, weight=ft.FontWeight.W_500, color=text_primary)
                            ]),
                            padding=10
                        )

                        # Fila inferior: Acción + Fecha/Hora
                        bottom_row_items = []
                        if status_val == "scheduled":
                            bottom_row_items.append(
                                ft.TextButton(
                                    "Cancelar Cita", 
                                    style=ft.ButtonStyle(color="#ff9b9b", padding=0), 
                                    on_click=cancel_appointment(a.id)
                                )
                            )
                        else:
                            bottom_row_items.append(ft.Container(expand=True))
                        
                        # Espaciador si hay botón, sino expande
                        if status_val == "scheduled":
                            bottom_row_items.append(ft.Container(expand=True))

                        bottom_row_items.append(
                            ft.Column([
                                ft.Text(date_str, size=11, color=text_secondary, text_align=ft.TextAlign.RIGHT),
                                ft.Text(f"Turno #{turn}", size=11, color=text_secondary, text_align=ft.TextAlign.RIGHT),
                            ], spacing=2, alignment=ft.MainAxisAlignment.END, horizontal_alignment=ft.CrossAxisAlignment.END)
                        )

                        bottom_row = ft.Row(bottom_row_items, alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.END)

                        card_content = [
                            top_row,
                            middle_section,
                            bottom_row
                        ]
                        
                        appointments_list.controls.append(
                            ft.Container(
                                content=ft.Column(card_content, spacing=0),
                                padding=16,
                                bgcolor=card_bg,
                                border_radius=15
                            )
                        )
            except Exception as ex:
                appointments_list.controls.append(ft.Text(f"Error: {ex}", color=getattr(colors, 'ERROR_COLOR', '#e74c3c')))

        load_appointments()
        dialog.open = True
        page.update()

    def go_to_book_appointment(e):
        from views.book_appointment import BookAppointmentView
        page.views.append(ft.View(
            route="/book-appointment",
            controls=[BookAppointmentView(page, user=user)],
            bgcolor=colors.BACKGROUND
        ))
        page.update()

    # Construir menú según rol exclusivo
    menu_items = []

    if role_val == "patient":
        menu_items.append(
            menu_card(
                ft.Icons.CALENDAR_MONTH,
                "Agendar Cita",
                "Selecciona tu médico, fecha u hora de atención",
                on_click=go_to_book_appointment,
                icon_color=colors.PRIMARY,
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.SEARCH,
                "Buscar Doctores",
                "Encuentra especialistas por categoría",
                on_click=go_to_browse_doctors,
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.CALENDAR_MONTH,
                "Mis Citas",
                "Ver y gestionar tus citas médicas",
                on_click=show_my_appointments,
                icon_color=colors.ACCENT_GREEN,
            )
        )
        
        def go_to_support_user(e):
            from views.support import SupportUserView
            page.views.append(ft.View(route="/support-user", controls=[SupportUserView(page, user=user, on_navigate=lambda: page.views.pop() or page.update())], bgcolor=colors.BACKGROUND))
            page.update()

        menu_items.append(
            menu_card(
                ft.Icons.SUPPORT_AGENT,
                "Mis Mensajes",
                "Historial de soporte técnico",
                on_click=go_to_support_user,
                icon_color=colors.PRIMARY,
                badge_count=unread_support_count,
            )
        )

        menu_items.append(
            menu_card(
                ft.Icons.NOTIFICATIONS,
                "Notificaciones",
                "Centro de alertas y avisos del sistema",
                on_click=go_to_notifications,
                icon_color=colors.PRIMARY,
                badge_count=unread_count,
            )
        )
    elif role_val == "doctor":
        def show_in_development_msg(e):
            snack = ft.SnackBar(content=ft.Text("Funcionalidad en desarrollo"), bgcolor=colors.PRIMARY)
            page.overlay.append(snack)
            snack.open = True
            page.update()

        def go_to_availability(e):
            from views.doctor_availability import DoctorAvailabilityView
            page.views.append(DoctorAvailabilityView(page, user))
            page.update()

        def go_to_doctor_appointments(e):
            from views.doctor_appointments import show_doctor_appointments
            show_doctor_appointments(page, user)

        menu_items.append(
            menu_card(
                ft.Icons.STAR,
                "Mi Suscripción / Posicionamiento",
                "Planes Patrocinado y Destacado",
                on_click=go_to_subscribe,
                icon_color="#f39c12",
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.SCHEDULE,
                "Mi Disponibilidad",
                "Configurar horarios de atención",
                on_click=go_to_availability,
                icon_color=colors.SECONDARY,
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.CALENDAR_MONTH,
                "Agenda de Citas Recibidas",
                "Ver pacientes agendados",
                on_click=go_to_doctor_appointments,
                icon_color=colors.ACCENT_GREEN,
            )
        )
        
        def go_to_support_user_doc(e):
            from views.support import SupportUserView
            page.views.append(ft.View(route="/support-user", controls=[SupportUserView(page, user=user, on_navigate=lambda: page.views.pop() or page.update())], bgcolor=colors.BACKGROUND))
            page.update()

        menu_items.append(
            menu_card(
                ft.Icons.SUPPORT_AGENT,
                "Mis Mensajes",
                "Historial de soporte técnico",
                on_click=go_to_support_user_doc,
                icon_color=colors.PRIMARY,
                badge_count=unread_support_count,
            )
        )

        menu_items.append(
            menu_card(
                ft.Icons.NOTIFICATIONS,
                "Notificaciones",
                "Centro de alertas y renovaciones",
                on_click=go_to_notifications,
                icon_color=colors.PRIMARY,
                badge_count=unread_count,
            )
        )
    elif role_val == "admin":
        def go_to_admin_subscriptions(e):
            from views.admin_subscriptions import AdminSubscriptionsView
            page.views.append(ft.View(route="/admin-subscriptions", controls=[AdminSubscriptionsView(page, user=user)], bgcolor=colors.BACKGROUND))
            page.update()

        def go_to_statistics(e):
            from views.statistics import StatisticsView
            page.views.append(ft.View(route="/statistics", controls=[StatisticsView(page, user=user)], bgcolor=colors.BACKGROUND))
            page.update()

        menu_items.append(
            menu_card(
                ft.Icons.ADMIN_PANEL_SETTINGS,
                "Gestión Global de Usuarios y Doctores",
                "Administrar roles, especialidades y doctores registrados",
                on_click=go_to_browse_doctors,
                icon_color="#e74c3c",
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.MONETIZATION_ON,
                "Supervisión de Suscripciones y Pagos",
                "Aprobar y auditar suscripciones de doctores",
                on_click=go_to_admin_subscriptions,
                icon_color="#f39c12",
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.BAR_CHART,
                "Estadísticas del Sistema",
                "Métricas de pacientes y doctores registrados",
                on_click=go_to_statistics,
                icon_color=colors.PRIMARY,
            )
        )
        
        def go_to_support_admin(e):
            from views.support import SupportAdminView
            page.views.append(ft.View(route="/support-admin", controls=[SupportAdminView(page, user=user, on_navigate=lambda: page.views.pop() or page.update())], bgcolor=colors.BACKGROUND))
            page.update()

        menu_items.append(
            menu_card(
                ft.Icons.SUPPORT_AGENT,
                "Mensajes de Soporte",
                "Gestiona los tickets de los usuarios",
                on_click=go_to_support_admin,
                icon_color=colors.PRIMARY,
                badge_count=unread_support_count,
            )
        )

        menu_items.append(
            menu_card(
                ft.Icons.NOTIFICATIONS,
                "Centro de Notificaciones y Sistema",
                "Alertas en tiempo real de inscripciones y renovaciones",
                on_click=go_to_notifications,
                icon_color=colors.PRIMARY,
                badge_count=unread_count,
            )
        )
    elif role_val == "assistant":
        def go_to_availability(e):
            from views.doctor_availability import DoctorAvailabilityView
            page.views.append(DoctorAvailabilityView(page, user))
            page.update()

        def go_to_doctor_appointments(e):
            from views.doctor_appointments import show_doctor_appointments
            show_doctor_appointments(page, user)
            
        menu_items.append(
            menu_card(
                ft.Icons.SCHEDULE,
                "Disponibilidad del Doctor",
                "Configurar horarios de atención",
                on_click=go_to_availability,
                icon_color=colors.SECONDARY,
            )
        )
        menu_items.append(
            menu_card(
                ft.Icons.CALENDAR_MONTH,
                "Agenda de Citas del Doctor",
                "Ver pacientes agendados",
                on_click=go_to_doctor_appointments,
                icon_color=colors.ACCENT_GREEN,
            )
        )

    def go_to_profile(e):
        try:
            from views.profile import ProfileView
            page.views.append(ft.View(
                route="/profile",
                controls=[ProfileView(page, user=user, on_navigate=lambda route: page.views.pop() if page.views else None)],
                bgcolor=colors.BACKGROUND
            ))
            page.update()
        except Exception as ex:
            snack = ft.SnackBar(ft.Text(f"Error al abrir perfil: {str(ex)}"), bgcolor="red")
            page.overlay.append(snack)
            snack.open = True
            page.update()

    avatar_url = getattr(user, 'avatar_url', None)
    if avatar_url and not str(avatar_url).strip():
        avatar_url = None
    elif avatar_url:
        avatar_url = str(avatar_url).strip()
        
    initials = (user.first_name[0] + user.last_name[0]).upper() if user and user.first_name else "U"

    user_avatar = ft.Container(
        content=ft.CircleAvatar(
            content=ft.Text(initials, size=20, weight=ft.FontWeight.BOLD, color="white") if not avatar_url else None,
            foreground_image_src=avatar_url if avatar_url else None,
            radius=35,
            bgcolor=colors.PRIMARY,
        ),
        on_click=go_to_profile,
        tooltip="Editar Mi Perfil"
    )

    content = ft.Column(
        [
            ft.Container(height=10),
            ft.Row(
                [
                    ft.Image(
                        src="logo.png",
                        width=50,
                        height=50,
                        fit=ft.BoxFit.CONTAIN,
                    ),
                    ft.Column([
                        ft.Text("Salud Now", size=18, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
                        ft.Text("Plataforma Médica", size=11, color=colors.SECONDARY),
                    ], spacing=0, expand=True),
                    ft.Column([
                        ft.OutlinedButton(
                            "Mi Perfil",
                            icon=ft.Icons.PERSON,
                            on_click=go_to_profile,
                            style=ft.ButtonStyle(color=colors.PRIMARY)
                        ),
                        ft.TextButton(
                            "Cerrar sesión",
                            icon=ft.Icons.LOGOUT,
                            icon_color="#e74c3c",
                            on_click=handle_logout,
                            style=ft.ButtonStyle(color="#e74c3c")
                        )
                    ], horizontal_alignment=ft.CrossAxisAlignment.END, spacing=0)
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=10
            ),
            ft.Container(height=15),
            # Greeting with Avatar
            ft.Row(
                [
                    user_avatar,
                    ft.Column([
                        ft.Text(
                            f"¡Hola, {user.first_name}!",
                            size=22,
                            weight=ft.FontWeight.W_800,
                            color=colors.TEXT_DARK,
                        ),
                        ft.Row(
                            [
                                ft.Container(
                                    content=ft.Text(role_label, size=10, color="white", weight=ft.FontWeight.W_600),
                                    bgcolor=colors.SECONDARY,
                                    border_radius=10,
                                    padding=ft.padding.Padding.only(left=8, right=8, top=3, bottom=3),
                                ),
                                ft.Text(user.email, size=11, color=colors.TEXT_LIGHT),
                            ],
                            spacing=6,
                        )
                    ], spacing=2, expand=True)
                ],
                alignment=ft.MainAxisAlignment.START,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=15
            ),
            ft.Container(height=15),
            ft.Divider(color=colors.INPUT_BORDER),
            ft.Container(height=10),
            ft.Text("Menú principal", size=18, weight=ft.FontWeight.W_600, color=colors.TEXT_DARK),
            ft.Container(height=12),
            *menu_items,
            ft.Container(expand=True),
            ft.Container(height=20),
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        scroll=ft.ScrollMode.AUTO,
    )

    support_fab_container = None
    if role_val != "admin" and role_val != "assistant":
        def open_support_modal(e):
            subject_field = ft.TextField(label="Asunto", width=300)
            message_field = ft.TextField(label="Mensaje", width=300, multiline=True, max_lines=4)
            def submit_ticket(ev):
                if not subject_field.value or not message_field.value: return
                from sqlalchemy import create_engine
                from sqlalchemy.orm import sessionmaker
                from app.models.support import SupportTicket, TicketMessage
                from core.config import SYNC_DB_URL
                engine = create_engine(SYNC_DB_URL)
                Session = sessionmaker(bind=engine)
                with Session() as session:
                    ticket = SupportTicket(user_id=user.id, subject=subject_field.value)
                    session.add(ticket)
                    session.commit()
                    msg = TicketMessage(ticket_id=ticket.id, sender_id=user.id, message=message_field.value)
                    session.add(msg)
                    session.commit()
                modal.open = False
                page.update()
                snack = ft.SnackBar(ft.Text("Ticket enviado exitosamente"), bgcolor=colors.ACCENT_GREEN)
                page.overlay.append(snack)
                snack.open = True
                page.update()
                
            modal = ft.AlertDialog(
                title=ft.Text("Soporte Técnico"),
                content=ft.Column([subject_field, message_field], tight=True),
                actions=[ft.TextButton("Cancelar", on_click=lambda ev: setattr(modal, 'open', False) or page.update()), ft.Button("Enviar", on_click=submit_ticket)]
            )
            page.overlay.append(modal)
            modal.open = True
            page.update()

        def on_pan_update(e: ft.DragUpdateEvent):
            if support_fab_container.right is not None:
                support_fab_container.right = max(0, support_fab_container.right - e.local_delta.x)
            if support_fab_container.bottom is not None:
                support_fab_container.bottom = max(0, support_fab_container.bottom - e.local_delta.y)
            support_fab_container.update()

        support_fab_container = ft.Container(
            content=ft.GestureDetector(
                on_pan_update=on_pan_update,
                content=ft.FloatingActionButton(icon=ft.Icons.CHAT, bgcolor=colors.PRIMARY, on_click=open_support_modal)
            ),
            right=20,
            bottom=20,
            width=56,
            height=56
        )

    main_container = ft.Container(
        content=content,
        padding=20,
        expand=True,
    )
    
    if support_fab_container:
        view_content = ft.Stack([main_container, support_fab_container], expand=True)
    else:
        view_content = main_container

    return ft.View(
        route="/home",
        controls=[view_content],
        bgcolor=colors.BACKGROUND,
    )
