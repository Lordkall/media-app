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
        super().__init__(expand=True)
        self.ft_page = page
        self.user = user
        self.on_navigate = on_navigate
        self.bg_color = BG_COLOR
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
        
        def on_file_picked(e: ft.FilePickerResultEvent):
            if e.files and len(e.files) > 0:
                file_path = e.files[0].path
                if not file_path:
                    snack = ft.SnackBar(ft.Text("La carga de archivos no está soportada en modo web de prueba."), bgcolor="red")
                    if hasattr(self, 'ft_page') and self.ft_page:
                        self.ft_page.overlay.append(snack)
                        snack.open = True
                        self.ft_page.update()
                    return
                filename = os.path.basename(file_path)
                dest_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "avatars")
                os.makedirs(dest_dir, exist_ok=True)
                dest_path = os.path.join(dest_dir, f"{self.user.id}_{filename}")
                shutil.copy(file_path, dest_path)
                self.avatar_src = f"frontend/assets/avatars/{self.user.id}_{filename}"
                self.update_avatar_preview(self.avatar_src)

        async def on_pick_file_click(e):
            self.file_picker.pick_files(allow_multiple=False)
                
        self.file_picker = ft.FilePicker()
        self.file_picker.on_result = on_file_picked
        self.ft_page.overlay.append(self.file_picker)

        role_str = self.user.role.value if hasattr(self.user.role, 'value') else str(self.user.role) if self.user and hasattr(self.user, 'role') else "patient"
        role_name = "Doctor" if role_str == "doctor" else ("Administrador" if role_str == "admin" else ("Asistente" if role_str == "assistant" or role_str == "ASSISTANT" else "Paciente"))

        # Visual de avatar
        initials = (self.user.first_name[0] + self.user.last_name[0]).upper() if self.user else "U"
        
        self.avatar_circle = ft.CircleAvatar(
            content=ft.Text(initials, size=24, weight=ft.FontWeight.BOLD, color="white") if not self.avatar_src else None,
            foreground_image_src=self.avatar_src if self.avatar_src else None,
            radius=45,
            bgcolor=PRIMARY_COLOR,
        )

        presets_row = ft.Row([
            ft.Button("Subir Foto de Perfil", icon=ft.Icons.UPLOAD_FILE, on_click=on_pick_file_click)
        ], alignment=ft.MainAxisAlignment.CENTER)

        avatar_section = ft.Column([
            self.avatar_circle,
            ft.Text(f"{role_name}", size=12, weight=ft.FontWeight.W_600, color=ACCENT_COLOR),
            presets_row
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=6)

        # Contenido adicional por rol
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
                doc_data = client.get("/doctors/me")
                if doc_data:
                    doc_bio = doc_data.get("bio", doc_bio)
                    doc_fee = str(doc_data.get("consultation_fee", doc_fee))
                    self.is_vip = doc_data.get("is_vip", False)
            except Exception as e:
                print(f"Error cargando datos del doctor: {e}")
                self.is_vip = False

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
            extra_fields.extend([
                ft.Divider(height=10, color=BORDER_COLOR),
                ft.Text("Información Profesional de Doctor", size=14, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY),
                self.address_input,
                self.bio_input,
                self.fee_input
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

        self.content = ft.Column([
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
        ], scroll=ft.ScrollMode.AUTO, expand=True)

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

    def save_profile(self, e):
        if self.user:
            self.user.first_name = self.first_name_input.value.strip()
            self.user.last_name = self.last_name_input.value.strip()
            self.user.phone = self.phone_input.value.strip()
            self.user.avatar_url = self.avatar_src
            if hasattr(self, 'address_input'):
                self.user.address = self.address_input.value.strip()
            
            try:
                from core.api_client import client
                
                user_payload = {
                    "first_name": self.user.first_name,
                    "last_name": self.user.last_name,
                    "phone": self.user.phone,
                    "avatar_url": self.user.avatar_url
                }
                
                if hasattr(self, 'address_input'):
                    user_payload["address"] = self.user.address
                    
                client.put("/users/me", json=user_payload)
                
                if hasattr(self, 'bio_input'):
                    doc_payload = {
                        "bio": self.bio_input.value.strip()
                    }
                    try:
                        doc_payload["consultation_fee"] = float(self.fee_input.value.strip())
                    except:
                        pass
                        
                    client.put("/doctors/me", json=doc_payload)
                        
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
