"""
Vista para Agendar Cita Médica.
Permite seleccionar especialidad, médico, motivo de consulta y fecha (por turnos).
"""
import flet as ft
from core import colors
from datetime import datetime, date
import calendar
import sys
import os

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if base_path not in sys.path:
    sys.path.append(base_path)

PRIMARY_COLOR = colors.PRIMARY
BG_COLOR = colors.BACKGROUND
SURFACE_COLOR = colors.SURFACE
TEXT_PRIMARY = colors.TEXT_DARK
TEXT_SECONDARY = colors.TEXT_LIGHT
ACCENT_COLOR = colors.SECONDARY
SUCCESS_COLOR = colors.ACCENT_GREEN
ERROR_COLOR = colors.ERROR_COLOR

ESTADOS_VE = [
    "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar", "Carabobo", "Cojedes",
    "Delta Amacuro", "Dependencias Federales", "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
    "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
    "Trujillo", "Yaracuy", "Zulia"
]

class BookAppointmentView(ft.Container):
    def __init__(self, page: ft.Page, user=None, doctor=None, on_navigate=None):
        super().__init__(expand=True)
        self.ft_page = page
        self.user = user
        self.selected_doctor_param = doctor
        self.on_navigate = on_navigate
        self.bg_color = BG_COLOR
        self.padding = 20

        self.selected_date = date.today()
        self.db_doctors = []
        self.appointment_counts = {}
        self.patient_id = None
        
        self.fetch_doctors()
        self.build_ui()
        self.preselect_if_needed()

    def get_sync_session(self):
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker
        from core.config import SYNC_DB_URL
        sync_engine = create_engine(SYNC_DB_URL)
        return sessionmaker(bind=sync_engine)()

    def fetch_doctors(self):
        try:
            from sqlalchemy import select
            from sqlalchemy.orm import joinedload
            from app.models.doctors import Doctor
            from app.models.patients import Patient
            
            with self.get_sync_session() as session:
                query = select(Doctor).options(joinedload(Doctor.user), joinedload(Doctor.availabilities))
                self.db_doctors = session.execute(query).scalars().unique().all()
                
                if self.user:
                    pat = session.execute(select(Patient).where(Patient.user_id == self.user.id)).scalar_one_or_none()
                    if pat:
                        self.patient_id = pat.id
        except Exception as e:
            print(f"Error fetching doctors: {e}")
            self.db_doctors = []

    def load_appointment_counts(self, doc_id):
        self.appointment_counts = {}
        try:
            from sqlalchemy import select
            from app.models.appointments import Appointment
            with self.get_sync_session() as session:
                apps = session.execute(select(Appointment).where(Appointment.doctor_id == doc_id)).scalars().all()
                for a in apps:
                    d_str = a.appointment_date.strftime("%Y-%m-%d")
                    self.appointment_counts[d_str] = self.appointment_counts.get(d_str, 0) + 1
        except Exception as e:
            print(f"Error fetching appointments: {e}")

    def get_specialties(self, state=None):
        specs = set()
        for doc in self.db_doctors:
            if state and doc.user.state != state:
                continue
            spec_val = doc.specialties[0] if getattr(doc, 'specialties', None) else "Especialista Médico"
            specs.add(spec_val)
        return sorted(list(specs))

    def on_state_change(self, e):
        state = self.state_dropdown.value
        specs = self.get_specialties(state)
        self.specialty_dropdown.options = [ft.dropdown.Option(key=s, text=s) for s in specs]
        self.specialty_dropdown.value = None
        self.doctor_dropdown.options.clear()
        self.doctor_dropdown.value = None
        self.doctor_dropdown.disabled = True
        self.appointment_counts = {}
        self.render_calendar()
        if self.ft_page:
            self.ft_page.update()

    def preselect_if_needed(self):
        if self.selected_doctor_param:
            doc_u = self.selected_doctor_param.user
            
            # Preselect state if available
            if doc_u.state and doc_u.state in ESTADOS_VE:
                self.state_dropdown.value = doc_u.state
                self.on_state_change(None)
                
            spec = self.selected_doctor_param.specialties[0] if getattr(self.selected_doctor_param, 'specialties', None) else "Especialista Médico"
            
            if spec in [o.key for o in self.specialty_dropdown.options]:
                self.specialty_dropdown.value = spec
                self.on_specialty_change(None)
            
            doc_label = f"Dr{'a' if doc_u.first_name[-1].lower()=='a' else ''}. {doc_u.first_name} {doc_u.last_name}"
            for opt in self.doctor_dropdown.options:
                if opt.text == doc_label:
                    self.doctor_dropdown.value = opt.key
                    break
            self.on_doctor_change(None)

    def on_specialty_change(self, e):
        spec = self.specialty_dropdown.value
        state = self.state_dropdown.value if hasattr(self, 'state_dropdown') else None
        self.doctor_dropdown.options.clear()
        self.doctor_dropdown.value = None
        self.appointment_counts = {}
        
        if spec:
            for doc in self.db_doctors:
                if state and doc.user.state != state:
                    continue
                doc_spec = doc.specialties[0] if getattr(doc, 'specialties', None) else "Especialista Médico"
                if doc_spec == spec:
                    doc_u = doc.user
                    doc_label = f"Dr{'a' if doc_u.first_name[-1].lower()=='a' else ''}. {doc_u.first_name} {doc_u.last_name}"
                    self.doctor_dropdown.options.append(ft.dropdown.Option(key=str(doc.id), text=doc_label))
            
            self.doctor_dropdown.disabled = False
        else:
            self.doctor_dropdown.disabled = True
            
        self.render_calendar()
        if self.ft_page:
            self.ft_page.update()

    def on_doctor_change(self, e):
        if self.doctor_dropdown.value:
            doc_id = int(self.doctor_dropdown.value)
            self.load_appointment_counts(doc_id)
            
            # Fetch available dates explicitly using a fresh session to avoid detached instances
            self.available_dates = set()
            try:
                from sqlalchemy import select
                from app.models.doctors import Availability
                with self.get_sync_session() as session:
                    avs = session.execute(select(Availability).where(Availability.doctor_id == doc_id)).scalars().all()
                    self.available_dates = {a.date.isoformat() for a in avs if getattr(a, 'date', None)}
            except Exception as ex:
                print(f"Error fetching availabilities: {ex}")
                
        else:
            self.appointment_counts = {}
            self.available_dates = set()
            
        self.render_calendar()
        if self.ft_page:
            self.ft_page.update()

    def build_ui(self):
        def handle_back(e):
            if self.on_navigate:
                self.on_navigate("home")
            elif self.ft_page and len(self.ft_page.views) > 1:
                self.ft_page.views.pop()
                self.ft_page.update()

        header = ft.Column([
            ft.Row([
                ft.IconButton(
                    icon=ft.Icons.ARROW_BACK,
                    icon_color=PRIMARY_COLOR,
                    on_click=handle_back
                ),
                ft.Text("Agendar Cita", size=22, weight=ft.FontWeight.BOLD, color=PRIMARY_COLOR, expand=True),
            ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Text("Agende su cita con su médico (por orden de llegada).", size=13, color=TEXT_SECONDARY, text_align=ft.TextAlign.CENTER),
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2)

        specs = self.get_specialties()
        
        self.state_dropdown = ft.Dropdown(
            label="Estado",
            options=[ft.dropdown.Option(key=s, text=s) for s in ESTADOS_VE],
            bgcolor=colors.INPUT_BG,
            border_radius=12,
            border_color="transparent",
            color=TEXT_PRIMARY,
            on_change=self.on_state_change
        )
        
        self.specialty_dropdown = ft.Dropdown(
            label="Especialidad",
            options=[ft.dropdown.Option(key=s, text=s) for s in specs],
            bgcolor=colors.INPUT_BG,
            border_radius=12,
            border_color="transparent",
            color=TEXT_PRIMARY,
            on_change=self.on_specialty_change
        )

        self.doctor_dropdown = ft.Dropdown(
            label="Selecciona Médico",
            options=[],
            bgcolor=colors.INPUT_BG,
            border_radius=12,
            border_color="transparent",
            color=TEXT_PRIMARY,
            disabled=True,
            on_change=self.on_doctor_change
        )

        self.reason_dropdown = ft.Dropdown(
            label="Motivo de Cita",
            options=[
                ft.dropdown.Option(key="Consulta", text="Consulta"),
                ft.dropdown.Option(key="Entrega de Examenes", text="Entrega de Exámenes"),
                ft.dropdown.Option(key="Otros", text="Otros")
            ],
            bgcolor=colors.INPUT_BG,
            border_radius=12,
            border_color="transparent",
            color=TEXT_PRIMARY,
        )

        self.calendar_container = ft.Column(spacing=6)
        self.render_calendar()

        book_btn = ft.Button(
            "Confirmar Turno",
            style=ft.ButtonStyle(
                bgcolor=PRIMARY_COLOR,
                color="white",
                shape=ft.RoundedRectangleBorder(radius=25),
                padding=ft.padding.all(16),
            ),
            width=300,
            on_click=self.confirm_booking
        )

        self.content = ft.Column([
            header,
            ft.Divider(height=15, color="transparent"),
            self.state_dropdown,
            ft.Container(height=10),
            self.specialty_dropdown,
            ft.Container(height=10),
            self.doctor_dropdown,
            ft.Container(height=10),
            self.reason_dropdown,
            ft.Container(height=10),
            ft.Container(
                content=ft.Column([
                    ft.Text("Seleccione la fecha de atención", size=13, weight=ft.FontWeight.W_600, color=TEXT_PRIMARY),
                    ft.Row([
                        ft.Row([
                            ft.Container(width=12, height=12, bgcolor="#FFF59D", border_radius=6),
                            ft.Text("Día No Laborable", size=10, color=TEXT_SECONDARY)
                        ], spacing=4),
                        ft.Row([
                            ft.Container(width=12, height=12, bgcolor=ERROR_COLOR, border_radius=6),
                            ft.Text("Agenda Completa", size=10, color=TEXT_SECONDARY)
                        ], spacing=4)
                    ], spacing=15),
                    self.calendar_container
                ], spacing=8),
                padding=14,
                bgcolor=colors.INPUT_BG,
                border_radius=14,
            ),
            ft.Divider(height=20, color="transparent"),
            ft.Row([book_btn], alignment=ft.MainAxisAlignment.CENTER),
            ft.Container(height=20),
        ], scroll=ft.ScrollMode.AUTO, expand=True)

    def render_calendar(self):
        self.calendar_container.controls.clear()
        
        now = datetime.now()
        month_name = now.strftime("%B %Y").upper()
        
        month_header = ft.Text(month_name, size=11, weight=ft.FontWeight.BOLD, color=TEXT_SECONDARY, text_align=ft.TextAlign.CENTER)
        
        week_days = ["DOM", "LUN", "MAR", "MIE", "JUE", "VIE", "SAB"]
        days_header = ft.Row(
            [ft.Text(day, size=10, weight=ft.FontWeight.BOLD, color=PRIMARY_COLOR, width=32, text_align=ft.TextAlign.CENTER) for day in week_days],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
        )

        cal = calendar.monthcalendar(now.year, now.month)
        grid_rows = []
        today = date.today()
        
        selected_doc = None
        if self.doctor_dropdown.value:
            doc_id = int(self.doctor_dropdown.value)
            selected_doc = next((d for d in self.db_doctors if d.id == doc_id), None)
            
        doc_limit = selected_doc.max_patients_per_day if (selected_doc and hasattr(selected_doc, 'max_patients_per_day')) else 999
        available_dates = getattr(self, 'available_dates', set())

        for week in cal:
            row_controls = []
            for day in week:
                if day == 0:
                    row_controls.append(ft.Container(width=32, height=32))
                else:
                    cell_date = date(now.year, now.month, day)
                    is_past = cell_date < today
                    is_too_far = (cell_date - today).days > 14
                    
                    # If doctor is selected, check if this date is in their availabilities
                    is_unavailable = False
                    if selected_doc and cell_date.isoformat() not in available_dates:
                        is_unavailable = True
                    
                    count = self.appointment_counts.get(cell_date.strftime("%Y-%m-%d"), 0)
                    is_full = (count >= doc_limit)
                    
                    is_disabled = is_past or is_full or is_too_far or is_unavailable
                    is_selected = (cell_date == self.selected_date) and not is_disabled
                    
                    bg_col = "transparent"
                    text_col = TEXT_PRIMARY
                    
                    if is_full:
                        bg_col = ERROR_COLOR
                        text_col = "white"
                    elif is_unavailable:
                        bg_col = "#FFF59D"
                        text_col = TEXT_SECONDARY
                    elif is_past or is_too_far:
                        text_col = TEXT_SECONDARY
                    elif is_selected:
                        bg_col = SUCCESS_COLOR
                        text_col = "white"
                    
                    def select_day_fn(d=day, disabled=is_disabled):
                        def handler(e):
                            if disabled:
                                return
                            self.selected_date = date(now.year, now.month, d)
                            self.render_calendar()
                            if self.ft_page:
                                self.ft_page.update()
                        return handler

                    btn = ft.Container(
                        content=ft.Text(
                            str(day),
                            size=11,
                            weight=ft.FontWeight.BOLD if (is_selected or is_full) else ft.FontWeight.NORMAL,
                            color=text_col,
                        ),
                        width=32,
                        height=32,
                        border_radius=16,
                        bgcolor=bg_col,
                        alignment=ft.alignment.center,
                        on_click=select_day_fn(day, is_disabled)
                    )
                    row_controls.append(btn)
            grid_rows.append(ft.Row(row_controls, alignment=ft.MainAxisAlignment.SPACE_BETWEEN))

        self.calendar_container.controls.extend([
            ft.Row([month_header], alignment=ft.MainAxisAlignment.CENTER),
            days_header,
            *grid_rows
        ])

    def confirm_booking(self, e):
        print(f"[DEBUG] confirm_booking called. doctor={self.doctor_dropdown.value}, reason={self.reason_dropdown.value}, patient={self.patient_id}")
        if not self.doctor_dropdown.value:
            snack = ft.SnackBar(content=ft.Text("Por favor seleccione un médico."), bgcolor=colors.ERROR_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()
            return
            
        if not self.reason_dropdown.value:
            snack = ft.SnackBar(content=ft.Text("Por favor seleccione un motivo de cita."), bgcolor=colors.ERROR_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()
            return
            
        if not self.patient_id:
            snack = ft.SnackBar(content=ft.Text("No se encontró su perfil de paciente asociado."), bgcolor=colors.ERROR_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()
            return

        doc_id = int(self.doctor_dropdown.value)
        d_str = self.selected_date.strftime("%Y-%m-%d")
        
        try:
            from app.models.appointments import Appointment, AppointmentStatus
            with self.get_sync_session() as session:
                # Check for double booking
                existing_app = session.query(Appointment).filter(
                    Appointment.patient_id == self.patient_id,
                    Appointment.doctor_id == doc_id,
                    Appointment.appointment_date == self.selected_date,
                    Appointment.status != AppointmentStatus.CANCELLED
                ).first()
                if existing_app:
                    snack = ft.SnackBar(content=ft.Text("Ya tienes una cita agendada con este doctor para ese día."), bgcolor="red")
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.ft_page.update()
                    return

                # Reload count to be safe
                count = session.query(Appointment).filter(
                    Appointment.doctor_id == doc_id,
                    Appointment.appointment_date == self.selected_date
                ).count()
                
                new_turn = count + 1
                
                new_app = Appointment(
                    patient_id=self.patient_id,
                    doctor_id=doc_id,
                    appointment_date=self.selected_date,
                    turn_number=new_turn,
                    status=AppointmentStatus.SCHEDULED
                )
                session.add(new_app)
                
                from app.models.doctors import Doctor
                from app.models.notifications import Notification, NotificationType
                doc = session.get(Doctor, doc_id)
                if doc:
                    patient_name = f"{self.user.first_name} {self.user.last_name}"
                    notif = Notification(
                        user_id=doc.user_id,
                        type=NotificationType.APPOINTMENT_CREATED,
                        title="Nueva Cita Agendada",
                        message=f"El paciente {patient_name} ha agendado una cita para el {self.selected_date.strftime('%d/%m/%Y')} (Turno #{new_turn})."
                    )
                    session.add(notif)
                    
                session.commit()
                
                if doc:
                    self.ft_page.pubsub.send_all_on_topic(
                        f"user_{doc.user_id}", 
                        f"new_notification:¡Tienes una nueva cita de {patient_name}!"
                    )
                
            def close_success_dialog(e):
                dialog.open = False
                self.ft_page.update()
                if self.on_navigate:
                    self.on_navigate("home")
                elif self.ft_page and len(self.ft_page.views) > 1:
                    self.ft_page.views.pop()
                    self.ft_page.update()

            dialog = ft.AlertDialog(
                title=ft.Text("¡Cita Creada Exitosamente!", color=SUCCESS_COLOR, weight=ft.FontWeight.BOLD),
                content=ft.Text(f"Has sido registrado para el día {self.selected_date.strftime('%d/%m/%Y')} y tu turno es el #{new_turn}."),
                actions=[ft.TextButton("Entendido", on_click=close_success_dialog)],
                actions_alignment=ft.MainAxisAlignment.END,
            )
            self.ft_page.overlay.append(dialog)
            dialog.open = True
            self.ft_page.update()
                
        except Exception as ex:
            print(f"[ERROR] confirm_booking failed: {ex}")
            import traceback
            traceback.print_exc()
            snack = ft.SnackBar(content=ft.Text(f"Error al agendar: {str(ex)}"), bgcolor=colors.ERROR_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()
