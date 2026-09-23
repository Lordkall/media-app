"""
Vista de Perfil de Usuario (Doctores y Pacientes).
Permite visualizar y editar la información personal, datos profesionales/médicos y foto de perfil.
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
BORDER_COLOR = colors.INPUT_BORDER

class ProfileView(ft.Container):
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

        # Avatar por defecto según nombre o iniciales
        self.avatar_src = getattr(user, 'avatar_url', None) or ""

        self.build_ui()

    def open_assistant_manager(self, e):
        from views.assistant_manager import AssistantManagerView
        self.ft_page.views.append(ft.View(
            route="/assistant-manager",
            controls=[AssistantManagerView(self.ft_page, user=self.user, on_navigate=lambda: self.ft_page.views.pop() or self.ft_page.update())],
            bgcolor=colors.BACKGROUND
        ))
        self.ft_page.update()

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
            ft.Text("Mi Perfil", size=20, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY, expand=True),
        ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER)

        # Campos de texto de edición
        self.first_name_input = ft.TextField(
            label="Nombre",
            value=self.user.first_name if self.user else "",
            border_radius=10,
            bgcolor=colors.INPUT_BG,
        )
        self.last_name_input = ft.TextField(
            label="Apellido",
            value=self.user.last_name if self.user else "",
            border_radius=10,
            bgcolor=colors.INPUT_BG,
        )
        self.phone_input = ft.TextField(
            label="Teléfono de Contacto",
            value=self.user.phone if self.user else "",
            border_radius=10,
            bgcolor=colors.INPUT_BG,
        )
        
        # Modal para cambiar contraseña
        current_pwd_input = ft.TextField(label="Contraseña Actual", password=True, can_reveal_password=True, width=300)
        new_pwd_input = ft.TextField(label="Nueva Contraseña", password=True, can_reveal_password=True, width=300)
        
        def close_pwd_dialog(e):
            pwd_dialog.open = False
            self.ft_page.update()

        def submit_pwd_change(e):
            curr_pwd = current_pwd_input.value or ""
            new_pwd = new_pwd_input.value or ""
            
            try:
                from core.api_client import client
                client.put("/users/me/password", json={
                    "current_password": curr_pwd,
                    "new_password": new_pwd
                })
            except Exception as ex:
                if hasattr(ex, "response") and ex.response is not None:
                    try:
                        error_data = ex.response.json()
                        err_msg = error_data.get("detail", "Error al cambiar la contraseña")
                    except:
                        err_msg = f"Error del servidor: {ex.response.status_code}"
                else:
                    err_msg = f"Error: {ex}"
                snack = ft.SnackBar(ft.Text(err_msg), bgcolor="red")
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
                return
            
            close_pwd_dialog(e)
            current_pwd_input.value = ""
            new_pwd_input.value = ""
            snack = ft.SnackBar(ft.Text("Contraseña cambiada con éxito"), bgcolor=SUCCESS_COLOR)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.ft_page.update()

        pwd_dialog = ft.AlertDialog(
            title=ft.Text("Cambiar Contraseña"),
            content=ft.Column([current_pwd_input, new_pwd_input], tight=True),
            actions=[
                ft.TextButton("Cancelar", on_click=close_pwd_dialog),
                ft.Button("Guardar Contraseña", on_click=submit_pwd_change, style=ft.ButtonStyle(bgcolor=PRIMARY_COLOR, color="white"))
            ]
        )
        
        def open_pwd_dialog(e):
            self.ft_page.overlay.append(pwd_dialog)
            pwd_dialog.open = True
            self.ft_page.update()

        change_pwd_btn = ft.OutlinedButton(
            "Cambiar Contraseña",
            icon=ft.Icons.LOCK,
            on_click=open_pwd_dialog,
            style=ft.ButtonStyle(color=PRIMARY_COLOR)
        )

        import os
        import shutil
        
        def process_avatar_bytes(file_bytes):
            import base64
            b64 = base64.b64encode(file_bytes).decode("utf-8")
            self.avatar_src = f"data:image/png;base64,{b64}"
            self.update_avatar_preview(self.avatar_src)
            self.ft_page.update()

        async def on_file_picked(e: ft.FilePickerResultEvent):
            if e.files and len(e.files) > 0:
                f = e.files[0]
                if self.ft_page.web:
                    upload_url = self.ft_page.get_upload_url(f.name, 60)
                    await self.file_picker.upload([ft.FilePickerUploadFile(name=f.name, upload_url=upload_url)])
                else:
                    with open(f.path, "rb") as file:
                        process_avatar_bytes(file.read())

        def on_file_uploaded(e: ft.FilePickerUploadEvent):
            if not getattr(e, "error", None):
                import tempfile
                import os
                upload_dir_path = os.path.join(tempfile.gettempdir(), "saludnow_uploads")
                file_path = os.path.join(upload_dir_path, e.file_name)
                if os.path.exists(file_path):
                    with open(file_path, "rb") as file:
                        process_avatar_bytes(file.read())
                    try:
                        os.remove(file_path)
                    except:
                        pass

        self.file_picker = ft.FilePicker(on_result=on_file_picked, on_upload=on_file_uploaded)
        
        if not hasattr(self.ft_page, "services"):
            self.ft_page.overlay.append(self.file_picker)
        else:
            self.ft_page.services.append(self.file_picker)
            
        self.ft_page.update() # CRITICAL: Update page so client registers the control

        role_str = self.user.role.value if hasattr(self.user.role, 'value') else str(self.user.role) if self.user and hasattr(self.user, 'role') else "patient"
        role_name = "Doctor" if role_str == "doctor" else ("Administrador" if role_str == "admin" else ("Asistente" if role_str == "assistant" or role_str == "ASSISTANT" else "Paciente"))

        initials = (self.user.first_name[0] + self.user.last_name[0]).upper() if self.user else "U"
        
        self.avatar_circle = ft.CircleAvatar(
            content=ft.Text(initials, size=24, weight=ft.FontWeight.BOLD, color="white") if not self.avatar_src else None,
            foreground_image_src=self.avatar_src if self.avatar_src else None,
            radius=45,
            bgcolor=PRIMARY_COLOR,
        )

        presets_row = ft.Row([
            ft.Container(
                content=ft.Row([
                    ft.Icon(ft.Icons.CLOUD_UPLOAD, color=colors.PRIMARY),
                    ft.Text("Cambiar Foto de Perfil", color=colors.PRIMARY, weight=ft.FontWeight.W_600)
                ], alignment=ft.MainAxisAlignment.CENTER),
                on_click=lambda _: self.file_picker.pick_files(
                    allow_multiple=False,
                    allowed_extensions=["png", "jpg", "jpeg", "gif", "webp"]
                )
            )
        ], alignment=ft.MainAxisAlignment.CENTER)

        avatar_section = ft.Column([
            self.avatar_circle,
            ft.Text(f"{role_name}", size=12, weight=ft.FontWeight.W_600, color=ACCENT_COLOR),
            presets_row
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=6)

        extra_fields = []
        if role_str == "doctor":
            self.address_input = ft.TextField(
                label="Ubicación / Dirección",
                value=self.user.address if self.user and getattr(self.user, 'address', None) else "",
                border_radius=10,
                bgcolor=colors.INPUT_BG,
            )
            doc_bio = "Especialista dedicado al cuidado integral del paciente."
            doc_fee = "50"
            try:
                from core.api_client import client
                import asyncio
                doc_data = client.get("/doctors/me") # Ideally should be to_thread, but it's in build_ui which is sync... wait! build_ui is sync so we just swallow it, it might block briefly on load. 
                if doc_data:
                    doc_bio = doc_data.get("bio", doc_bio)
                    doc_fee = str(doc_data.get("consultation_fee", doc_fee))
                    self.is_vip = doc_data.get("is_vip", False)
                    self.doc_specialties = doc_data.get("specialties", [])
            except Exception as e:
                print(f"Error cargando datos del doctor: {e}")
                self.is_vip = False
                self.doc_specialties = []
            
            from app.models.doctors import SPECIALTIES
            
            self.specialties_row = ft.Row(wrap=True, spacing=10)
            
            def render_specialties():
                self.specialties_row.controls.clear()
                for sp in self.doc_specialties:
                    def remove_sp(e, s=sp):
                        self.doc_specialties.remove(s)
                        render_specialties()
                        self.specialty_add_dropdown.disabled = len(self.doc_specialties) >= 5
                        self.ft_page.update()
                    self.specialties_row.controls.append(
                        ft.Chip(
                            label=ft.Text(sp, size=12),
                            on_delete=remove_sp,
                            bgcolor=colors.PRIMARY,
                            label_style=ft.TextStyle(color="white")
                        )
                    )
            
            def on_add_specialty(e):
                val = self.specialty_add_dropdown.value
                if val and val not in self.doc_specialties and len(self.doc_specialties) < 5:
                    self.doc_specialties.append(val)
                    render_specialties()
                    self.specialty_add_dropdown.value = None
                    self.specialty_add_dropdown.disabled = len(self.doc_specialties) >= 5
                    self.ft_page.update()
            
            self.specialty_add_dropdown = ft.Dropdown(
                label="Añadir Especialidad (Máx. 5)",
                options=[ft.dropdown.Option(key=s, text=s) for s in SPECIALTIES],
                on_change=on_add_specialty,
                disabled=len(self.doc_specialties) >= 5,
                border_radius=10,
                filled=True,
                fill_color=colors.INPUT_BG,
            )
            render_specialties()

            self.bio_input = ft.TextField(
                label="Biografía / Presentación Profesional",
                value=doc_bio,
                multiline=True,
                min_lines=3,
                border_radius=10,
                bgcolor=colors.INPUT_BG,
            )
            self.fee_input = ft.TextField(
                label="Costo de Consulta ($ USD)",
                value=doc_fee,
                border_radius=10,
                bgcolor=colors.INPUT_BG,
            )
            
            # Fetch start_time and days
            doc_start_time = "No configurado"
            working_days_str = "No configurado"
            try:
                from core.config import GlobalSession
                from app.models.doctors import Doctor, Availability
                from datetime import date
                with GlobalSession() as session:
                    doc = session.query(Doctor).filter(Doctor.user_id == self.user.id).first()
                    if doc:
                        avs = session.query(Availability).filter(
                            Availability.doctor_id == doc.id,
                            Availability.date >= date.today()
                        ).all()
                        if avs:
                            doc_start_time = avs[0].start_time
                            days_mapping = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
                            weekdays = sorted(list({a.date.weekday() for a in avs}))
                            working_days_str = ", ".join([days_mapping[wd] for wd in weekdays])
            except Exception as e:
                print("Error loading availability in profile:", e)
            
            extra_fields.extend([
                ft.Divider(height=10, color=BORDER_COLOR),
                ft.Text("Información Profesional de Doctor", size=14, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                ft.Text(f"Días Laborales: {working_days_str}", size=13, color=colors.TEXT_DARK, weight=ft.FontWeight.W_500),
                ft.Text(f"Horario de inicio laboral: {doc_start_time}", size=13, color=colors.TEXT_LIGHT, italic=True),
                self.address_input,
                self.bio_input,
                self.fee_input,
                ft.Divider(height=10, color="transparent"),
                ft.Text("Especialidades", size=14, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                self.specialty_add_dropdown,
                self.specialties_row
            ])
            
            if getattr(self, 'is_vip', False):
                extra_fields.extend([
                    ft.Divider(height=10, color=BORDER_COLOR),
                    ft.Text("Beneficios VIP", size=14, weight=ft.FontWeight.BOLD, color="#f39c12"),
                    ft.Button(
                        "Gestión de Asistente",
                        icon=ft.Icons.MANAGE_ACCOUNTS,
                        on_click=self.open_assistant_manager,
                        style=ft.ButtonStyle(
                            bgcolor="#f39c12",
                            color="white"
                        )
                    )
                ])

        save_btn = ft.Button(
            "Guardar Cambios de Perfil",
            icon=ft.Icons.SAVE,
            style=ft.ButtonStyle(
                bgcolor=PRIMARY_COLOR,
                color="white",
                padding=12,
                shape=ft.RoundedRectangleBorder(radius=10)
            ),
            on_click=self.save_profile
        )

        self.content = ft.Container(
            content=ft.Column([
                self.header,
                ft.Divider(height=10, color="transparent"),
                avatar_section,
                ft.Divider(height=15, color=BORDER_COLOR),
                ft.Text("Información Personal", size=14, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                self.first_name_input,
                self.last_name_input,
                self.phone_input,
                change_pwd_btn,
                *extra_fields,
                ft.Divider(height=15, color="transparent"),
                save_btn,
                ft.Container(height=20)
            ], scroll=ft.ScrollMode.AUTO, expand=True),
            bgcolor=colors.CARD_BG,
            border_radius=15,
            padding=20,
            border=ft.border.all(1, colors.GLASS_BORDER),
            blur=ft.Blur(15, 15, ft.BlurTileMode.MIRROR)
        )

    def on_avatar_change(self, e):
        self.update_avatar_preview(e.control.value)

    def update_avatar_preview(self, url: str):
        if url and url.strip():
            self.avatar_circle.foreground_image_src = url.strip()
            self.avatar_circle.content = None
        else:
            self.avatar_circle.foreground_image_src = None
            initials = (self.user.first_name[0] + self.user.last_name[0]).upper() if self.user else "U"
            self.avatar_circle.content = ft.Text(initials, size=24, weight=ft.FontWeight.BOLD, color="white")
        self.ft_page.update()

    async def save_profile(self, e):
        if self.user:
            self.user.first_name = self.first_name_input.value.strip()
            self.user.last_name = self.last_name_input.value.strip()
            self.user.phone = self.phone_input.value.strip()
            self.user.avatar_url = self.avatar_src
            if hasattr(self, 'address_input'):
                self.user.address = self.address_input.value.strip()
            
            try:
                import requests
                from core.config import API_BASE_URL
                import asyncio
                
                user_payload = {
                    "first_name": self.user.first_name,
                    "last_name": self.user.last_name,
                    "phone": self.user.phone,
                    "avatar_url": self.user.avatar_url
                }
                
                if hasattr(self, 'address_input'):
                    user_payload["address"] = self.user.address
                    
                session_token = await self.ft_page.client_storage.get_async("session_token")
                headers = {"Authorization": f"Bearer {session_token}"}
                
                def do_put_requests():
                    r1 = requests.put(f"{API_BASE_URL}/users/me", json=user_payload, headers=headers)
                    r1.raise_for_status()
                    
                    if hasattr(self, 'bio_input'):
                        doc_payload = {
                            "bio": self.bio_input.value.strip()
                        }
                        try:
                            doc_payload["consultation_fee"] = float(self.fee_input.value.strip())
                        except:
                            pass
                            
                        if hasattr(self, 'doc_specialties'):
                            doc_payload["specialties"] = self.doc_specialties
                            
                        r2 = requests.put(f"{API_BASE_URL}/doctors/me", json=doc_payload, headers=headers)
                        r2.raise_for_status()
                
                await asyncio.to_thread(do_put_requests)
                        
                snack = ft.SnackBar(
                    content=ft.Text("¡Perfil actualizado con éxito!"),
                    bgcolor=SUCCESS_COLOR
                )
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
            except Exception as ex:
                snack = ft.SnackBar(
                    content=ft.Text(f"Error al guardar: {ex}"),
                    bgcolor="red"
                )
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
