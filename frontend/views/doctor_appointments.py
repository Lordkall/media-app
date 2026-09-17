import flet as ft
import sys
import os
from frontend.core import colors

def show_doctor_appointments(page: ft.Page, user):
    base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    if base_path not in sys.path:
        sys.path.append(base_path)

    from sqlalchemy import create_engine, select
    from sqlalchemy.orm import sessionmaker, joinedload
    from app.models.doctors import Doctor
    from app.models.appointments import Appointment, AppointmentStatus
    from app.models.users import User
    from app.models.patients import Patient

    from frontend.core.config import SYNC_DB_URL
    sync_engine = create_engine(SYNC_DB_URL)
    Session = sessionmaker(bind=sync_engine)

    appointments_list = ft.Column(spacing=15, scroll=ft.ScrollMode.AUTO, expand=True)
    
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

    def load_appointments():
        appointments_list.controls.clear()
        try:
            with Session() as session:
                from app.models.users import RoleEnum
                role_val = getattr(user.role, 'value', str(user.role))
                if role_val == RoleEnum.ASSISTANT.value:
                    doc = session.execute(select(Doctor).where(Doctor.id == user.linked_doctor_id)).scalar_one_or_none()
                else:
                    doc = session.execute(select(Doctor).where(Doctor.user_id == user.id)).scalar_one_or_none()
                if not doc:
                    appointments_list.controls.append(ft.Text("No se encontró su perfil de doctor.", color="red"))
                    return
                
                query = select(Appointment).where(
                    Appointment.doctor_id == doc.id,
                    Appointment.appointment_date == filter_date["value"]
                ).options(joinedload(Appointment.patient).joinedload(Patient.user)).order_by(Appointment.appointment_date.asc())
                
                apps = session.execute(query).scalars().all()
                
                if not apps:
                    appointments_list.controls.append(ft.Text("No tienes citas médicas agendadas para esta fecha.", color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER))
                
                for a in apps:
                    pat_name = f"{a.patient.user.first_name} {a.patient.user.last_name}"
                    pat_phone = getattr(a.patient.user, "phone", "")
                    date_str = a.appointment_date.strftime("%d/%m/%Y")
                    turn = a.turn_number
                    
                    status_val = a.status.value if hasattr(a.status, 'value') else str(a.status)
                    status_color = colors.ACCENT_GREEN if status_val == "scheduled" else ("red" if status_val == "cancelled" else colors.SECONDARY)
                    status_text = "Confirmada" if status_val == "scheduled" else ("Cancelada" if status_val == "cancelled" else "Completada")
                    
                    def cancel_appointment(app_id):
                        def handler(e):
                            try:
                                with Session() as sess:
                                    app_to_cancel = sess.get(Appointment, app_id)
                                    if app_to_cancel:
                                        app_to_cancel.status = AppointmentStatus.CANCELLED
                                        
                                        # Notificar al paciente
                                        from app.models.notifications import Notification, NotificationType
                                        doc_name = f"Dr. {user.first_name} {user.last_name}"
                                        notif = Notification(
                                            user_id=app_to_cancel.patient.user_id,
                                            type=NotificationType.APPOINTMENT_CANCELLED,
                                            title="Cita Cancelada",
                                            message=f"El {doc_name} ha cancelado su cita agendada para el {app_to_cancel.appointment_date.strftime('%d/%m/%Y')}."
                                        )
                                        sess.add(notif)
                                        sess.commit()
                                        
                                        snack = ft.SnackBar(content=ft.Text("Cita cancelada con éxito"), bgcolor=colors.SUCCESS if hasattr(colors, 'SUCCESS') else colors.ACCENT_GREEN)
                                        page.overlay.append(snack)
                                        snack.open = True
                                    load_appointments()
                                    page.update()
                            except Exception as ex:
                                print(f"Error cancelando cita: {ex}")
                        return handler

                    def make_wa_handler(p):
                        async def handler(e):
                            if p and str(p).strip() and str(p).strip() != "0000000000":
                                clean_phone = ''.join(c for c in str(p) if c.isdigit())
                                await e.page.launch_url(f"https://wa.me/{clean_phone}")
                            else:
                                snack = ft.SnackBar(ft.Text("El paciente no tiene un número de teléfono válido registrado."), bgcolor="red")
                                e.page.overlay.append(snack)
                                snack.open = True
                                e.page.update()
                        return handler

                    card_content = ft.Column([
                        ft.Row([
                            ft.Icon(ft.Icons.PERSON, color=colors.PRIMARY),
                            ft.Text(pat_name, size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK)
                        ], spacing=10),
                        ft.Row([
                            ft.Icon(ft.Icons.PHONE, color=colors.TEXT_LIGHT, size=16),
                            ft.Text(pat_phone, size=14, color=colors.TEXT_LIGHT),
                            ft.IconButton(
                                icon=ft.Icons.CHAT, 
                                icon_color=colors.PRIMARY, 
                                icon_size=18,
                                tooltip="Contactar por WhatsApp",
                                on_click=make_wa_handler(pat_phone)
                            )
                        ], spacing=10),
                        ft.Row([
                            ft.Icon(ft.Icons.CALENDAR_TODAY, color=colors.TEXT_LIGHT, size=16),
                            ft.Text(f"Fecha: {date_str} - Turno: #{turn}", size=14, color=colors.TEXT_LIGHT)
                        ], spacing=10),
                        ft.Row([
                            ft.Icon(ft.Icons.INFO, color=status_color, size=16),
                            ft.Text(f"Estado: {status_text}", size=14, color=status_color, weight=ft.FontWeight.BOLD)
                        ], spacing=10)
                    ])

                    if status_val == "scheduled":
                        card_content.controls.append(
                            ft.Container(height=10)
                        )
                        card_content.controls.append(
                            ft.ElevatedButton("Cancelar Cita", icon=ft.Icons.CANCEL, style=ft.ButtonStyle(color="white", bgcolor="red"), on_click=cancel_appointment(a.id))
                        )

                    appointments_list.controls.append(
                        ft.Container(
                            content=card_content,
                            bgcolor=colors.CARD_BG,
                            padding=15,
                            border_radius=10,
                            shadow=ft.BoxShadow(spread_radius=1, blur_radius=5, color="#E0E0E0")
                        )
                    )
        except Exception as ex:
            appointments_list.controls.append(ft.Text(f"Error cargando citas: {ex}", color="red"))

    load_appointments()

    def close_dlg(e):
        dialog.open = False
        page.update()

    dialog = ft.AlertDialog(
        modal=True,
        title=ft.Row([
            ft.Icon(ft.Icons.CALENDAR_MONTH, color=colors.ACCENT_GREEN),
            ft.Text("Agenda de Citas", size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK)
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
            ft.ElevatedButton("Cerrar", bgcolor=colors.PRIMARY, color="white", on_click=close_dlg)
        ],
        actions_alignment=ft.MainAxisAlignment.END,
    )

    page.overlay.append(dialog)
    dialog.open = True
    page.update()
