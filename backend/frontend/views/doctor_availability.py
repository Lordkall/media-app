import flet as ft
import sys
import os
from core import colors

def DoctorAvailabilityView(page: ft.Page, user, on_navigate=None):
    def handle_back(e):
        page.views.pop()
        page.update()

    # Base path for importing backend
    base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    if base_path not in sys.path:
        sys.path.append(base_path)

    from app.models.users import User
    from app.models.doctors import Doctor, Availability

    from core.config import GlobalSession
    Session = GlobalSession

    # Initial data
    doc = None
    availabilities = []
    max_patients = 5

    with Session() as session:
        from app.models.users import RoleEnum
        role_val = getattr(user.role, 'value', str(user.role))
        if role_val == RoleEnum.ASSISTANT.value:
            doc = session.query(Doctor).filter(Doctor.id == user.linked_doctor_id).first()
        else:
            doc = session.query(Doctor).filter(Doctor.user_id == user.id).first()
            
        if doc:
            max_patients = doc.max_patients_per_day
            availabilities = session.query(Availability).filter(Availability.doctor_id == doc.id).all()

    # Existing days
    existing_days = {a.date.isoformat() for a in availabilities}

    def on_no_limit_change(e):
        max_patients_input.disabled = no_limit_checkbox.value
        if no_limit_checkbox.value:
            max_patients_input.value = "999"
        page.update()

    no_limit_checkbox = ft.Checkbox(
        label="Sin Limites", 
        value=(max_patients >= 999),
        on_change=on_no_limit_change,
        fill_color=colors.PRIMARY
    )

    max_patients_input = ft.TextField(
        label="Máximo",
        value=str(max_patients if max_patients < 999 else 999),
        keyboard_type=ft.KeyboardType.NUMBER,
        border_radius=10,
        bgcolor=colors.INPUT_BG,
        width=150,
        disabled=(max_patients >= 999)
    )
    
    max_patients_row = ft.Row([max_patients_input, no_limit_checkbox], alignment=ft.MainAxisAlignment.START)

    # Initial start time
    initial_start_time = "09:00"
    if availabilities and availabilities[0].start_time:
        initial_start_time = availabilities[0].start_time

    time_options = [f"{str(h).zfill(2)}:00" for h in range(5, 20)] + [f"{str(h).zfill(2)}:30" for h in range(5, 20)]
    time_options.sort()

    start_time_dropdown = ft.Dropdown(
        label="Hora de Inicio Laboral",
        options=[ft.dropdown.Option(key=t, text=t) for t in time_options],
        value=initial_start_time,
        width=200,
        border_radius=10,
        bgcolor=colors.INPUT_BG,
        fill_color=colors.INPUT_BG
    )

    days_mapping = [
        (0, "Lunes"), (1, "Martes"), (2, "Miércoles"),
        (3, "Jueves"), (4, "Viernes"), (5, "Sábado"), (6, "Domingo")
    ]

    from datetime import date, timedelta
    
    current_week_start = [date.today() - timedelta(days=date.today().weekday())]
    week_container = ft.Container()
    
    def render_week():
        start = current_week_start[0]
        end = start + timedelta(days=6)
        
        months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        month_str = f"{months[start.month-1]} {start.day} - {end.day}"
        
        header = ft.Column([
            ft.Text("TOQUE PARA SELECCIONAR DÍAS LABORALES", size=10, color=colors.TEXT_LIGHT),
            ft.Row([
                ft.Text("SEMANA ACTUAL", weight=ft.FontWeight.BOLD, color="#3498db", size=14),
                ft.IconButton(ft.Icons.CHEVRON_LEFT, on_click=lambda e: change_week(-7), icon_color="#3498db"),
                ft.Text(month_str, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
                ft.IconButton(ft.Icons.CHEVRON_RIGHT, on_click=lambda e: change_week(7), icon_color="#3498db")
            ], spacing=0, alignment=ft.MainAxisAlignment.CENTER)
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=5)
        
        day_cards = []
        for i in range(7):
            d = start + timedelta(days=i)
            day_val = d.weekday()
            d_str = d.isoformat()
            is_selected = d_str in existing_days
            
            day_name = days_mapping[day_val][1]
            
            card_bgcolor = "#3498db" if is_selected else "white"
            text_color = "white" if is_selected else colors.TEXT_DARK
            def _b_all(width, color):
                bs = ft.BorderSide(width, color)
                return ft.Border(top=bs, bottom=bs, left=bs, right=bs)
            
            border = _b_all(1, "#3498db") if not is_selected else _b_all(1, "#E0E0E0")
            
            def create_toggle(val=d_str, is_sunday=(day_val == 6)):
                def toggle_day(e):
                    if val in existing_days:
                        existing_days.remove(val)
                    else:
                        existing_days.add(val)
                    if is_sunday:
                        change_week(7)
                    else:
                        render_week()
                        page.update()
                return toggle_day
                
            day_card = ft.Container(
                content=ft.Column([
                    ft.Text(day_name, color=text_color, size=10),
                    ft.Text(str(d.day), color=text_color, size=18, weight=ft.FontWeight.BOLD),
                    ft.Icon(ft.Icons.CHECK_CIRCLE if is_selected else ft.Icons.CHECK_BOX_OUTLINE_BLANK, color=text_color, size=20),
                    ft.Text("SELECCIONADO" if is_selected else "NO LABORAL", color=text_color, size=8)
                ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                width=80,
                height=120,
                bgcolor=card_bgcolor,
                border=border,
                border_radius=12,
                padding=5,
                on_click=create_toggle(d_str, day_val == 6),
                ink=True
            )
            day_cards.append(day_card)
            
        week_container.content = ft.Container(
            content=ft.Column([
                header,
                ft.Row(day_cards, wrap=True, spacing=10, run_spacing=10, alignment=ft.MainAxisAlignment.CENTER),
            ]),
            bgcolor=colors.CARD_BG,
            padding=15,
            border_radius=15,
            border=ft.border.all(1, colors.GLASS_BORDER),
            blur=ft.Blur(15, 15, ft.BlurTileMode.MIRROR)
        )
        
    def change_week(days):
        current_week_start[0] += timedelta(days=days)
        render_week()
        
    render_week()

    def save_availability(e):
        try:
            try:
                val = int(max_patients_input.value)
                if val < 1:
                    raise ValueError()
            except:
                snack = ft.SnackBar(content=ft.Text("Por favor ingresa un número válido para los pacientes."), bgcolor="red")
                page.overlay.append(snack)
                snack.open = True
                page.update()
                return

            with Session() as session:
                from app.models.users import RoleEnum
                role_val = getattr(user.role, 'value', str(user.role))
                if role_val == RoleEnum.ASSISTANT.value:
                    doc_record = session.query(Doctor).filter(Doctor.id == user.linked_doctor_id).first()
                else:
                    doc_record = session.query(Doctor).filter(Doctor.user_id == user.id).first()
                if not doc_record:
                    snack = ft.SnackBar(content=ft.Text("Error: Perfil de doctor no encontrado."), bgcolor="red")
                    page.overlay.append(snack)
                    snack.open = True
                    page.update()
                    return

                doc_record.max_patients_per_day = val

                # Delete old availabilities
                session.query(Availability).filter(Availability.doctor_id == doc_record.id).delete()

                selected_start_time = start_time_dropdown.value or "09:00"
                # Insert new ones
                for d_str in existing_days:
                    new_av = Availability(
                        doctor_id=doc_record.id,
                        date=date.fromisoformat(d_str),
                        start_time=selected_start_time,
                        end_time="17:00"
                    )
                    session.add(new_av)

                session.commit()

            snack = ft.SnackBar(content=ft.Text("Disponibilidad guardada con éxito"), bgcolor=colors.ACCENT_GREEN)
            page.overlay.append(snack)
            snack.open = True
            page.update()
            
        except Exception as ex:
            snack = ft.SnackBar(content=ft.Text(f"Error al guardar: {str(ex)}"), bgcolor="red")
            page.overlay.append(snack)
            snack.open = True
            page.update()

    save_btn = ft.Button(
        "Guardar Disponibilidad",
        icon=ft.Icons.SAVE,
        style=ft.ButtonStyle(
            bgcolor=colors.PRIMARY,
            color="white",
            padding=12,
            shape=ft.RoundedRectangleBorder(radius=10)
        ),
        on_click=save_availability
    )

    # Removed days_column

    content = ft.Column([
        ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, icon_color=colors.TEXT_DARK, on_click=handle_back),
            ft.Text("Mi Disponibilidad", size=20, weight=ft.FontWeight.W_700, color=colors.TEXT_DARK, expand=True)
        ], vertical_alignment=ft.CrossAxisAlignment.CENTER),
        
        ft.Container(height=20),
        
        ft.Text("Configuración de Pacientes", size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        ft.Text("Establece cuántos pacientes deseas atender como máximo por día.", size=12, color=colors.TEXT_LIGHT),
        ft.Container(height=10),
        max_patients_row,
        
        ft.Container(height=20),
        
        ft.Text("Hora de Inicio Laboral", size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        ft.Text("Selecciona la hora en la que inician tus consultas.", size=12, color=colors.TEXT_LIGHT),
        ft.Container(height=10),
        start_time_dropdown,
        
        ft.Container(height=20),
        
        ft.Text("Días Laborales", size=16, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        week_container,
        
        ft.Container(height=30),
        save_btn,
        ft.Container(height=20)
    ], scroll=ft.ScrollMode.AUTO, expand=True)

    return ft.View(
        route="/doctor-availability",
        controls=[ft.Container(
            content=content, padding=20, expand=True,
            gradient=ft.LinearGradient(
                begin=ft.alignment.top_left,
                end=ft.alignment.bottom_right,
                colors=["#E0EAFC", "#CFDEF3", "#B3C6DF"]
            )
        )],
        bgcolor=ft.colors.TRANSPARENT
    )
