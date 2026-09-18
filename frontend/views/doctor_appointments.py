import flet as ft
import sys
import os
from core import colors

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

    from core.config import SYNC_DB_URL
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
        style=ft.ButtonStyle(style=ft.ButtonStyle(color=colors.PRIMARY, style=ft.ButtonStyle(bgcolor=colors.SUCCESS if hasattr(colors, color="red"))
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
                            ft.ElevatedButton("Cancelar Cita", icon=ft.Icons.CANCEL, style=ft.ButtonStyle(style=ft.ButtonStyle(color="white", style=ft.ButtonStyle(bgcolor="red", color=colors.CARD_BG),
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
            ft.ElevatedButton("Cerrar", style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"), on_click=close_dlg)
        ],
        actions_alignment=ft.MainAxisAlignment.END,
    )

    page.overlay.append(dialog)
    dialog.open = True
    page.update()
