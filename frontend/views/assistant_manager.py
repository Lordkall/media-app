import flet as ft
from frontend.core import colors
import sys, os

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if base_path not in sys.path:
    sys.path.append(base_path)
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor

from frontend.core.config import SYNC_DB_URL

def get_engine():
    return create_engine(SYNC_DB_URL)

class AssistantManagerView(ft.Container):
    def __init__(self, page: ft.Page, user, on_navigate=None):
        super().__init__()
        self.ft_page = page
        self.user = user
        self.on_navigate = on_navigate
        self.expand = True
        
        self.engine = get_engine()
        self.Session = sessionmaker(bind=self.engine)
        
        # Determine linked_doctor_id for the current user
        with self.Session() as session:
            doc = session.query(Doctor).filter(Doctor.user_id == self.user.id).first()
            self.doctor_id = doc.id if doc else None

        self.assistants_list = ft.ListView(expand=True, spacing=10)
        self.build_ui()
        self.load_assistants()

    def load_assistants(self):
        self.assistants_list.controls.clear()
        if not self.doctor_id:
            return
            
        with self.Session() as session:
            assistants = session.query(User).filter(
                User.role == RoleEnum.ASSISTANT,
                User.linked_doctor_id == self.doctor_id
            ).all()
            
            if not assistants:
                self.assistants_list.controls.append(
                    ft.Text("No tienes asistentes registrados.", color=colors.TEXT_LIGHT, italic=True)
                )
            else:
                for ast in assistants:
                    self.assistants_list.controls.append(
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.PERSON, color=colors.PRIMARY),
                            title=ft.Text(f"{ast.first_name} {ast.last_name}", weight="bold"),
                            subtitle=ft.Text(ast.email),
                            trailing=ft.IconButton(
                                ft.Icons.DELETE, 
                                icon_color="red", 
                                tooltip="Eliminar Asistente",
                                on_click=lambda e, ast_id=ast.id: self.delete_assistant(ast_id)
                            )
                        )
                    )
        self.ft_page.update()
        
    def delete_assistant(self, user_id):
        with self.Session() as session:
            ast = session.query(User).filter(User.id == user_id).first()
            if ast:
                session.delete(ast)
                session.commit()
                snack = ft.SnackBar(ft.Text("Asistente eliminado"), bgcolor=colors.ACCENT_GREEN)
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.load_assistants()

    def open_create_modal(self, e):
        fname_input = ft.TextField(label="Nombre", border_radius=10, bgcolor=colors.INPUT_BG)
        lname_input = ft.TextField(label="Apellido", border_radius=10, bgcolor=colors.INPUT_BG)
        email_input = ft.TextField(label="Correo Electrónico", border_radius=10, bgcolor=colors.INPUT_BG)
        pwd_input = ft.TextField(label="Contraseña Temporal", password=True, can_reveal_password=True, border_radius=10, bgcolor=colors.INPUT_BG)
        
        def save_assistant(e):
            if not fname_input.value or not lname_input.value or not email_input.value or not pwd_input.value:
                return

            import re
            pwd = pwd_input.value
            if len(pwd) < 8:
                snack = ft.SnackBar(ft.Text("La contraseña debe tener al menos 8 caracteres."), bgcolor="red")
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
                return
            if not re.search(r"[a-zA-Z]", pwd) or not re.search(r"[0-9]", pwd):
                snack = ft.SnackBar(ft.Text("La contraseña debe contener letras y números."), bgcolor="red")
                self.ft_page.overlay.append(snack)
                snack.open = True
                self.ft_page.update()
                return

            
            with self.Session() as session:
                existing = session.query(User).filter(User.email == email_input.value).first()
                if existing:
                    snack = ft.SnackBar(ft.Text("El correo ya está en uso"), bgcolor="red")
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.ft_page.update()
                    return
                
                new_ast = User(
                    email=email_input.value,
                    first_name=fname_input.value,
                    last_name=lname_input.value,
                    phone="0000000000",
                    hashed_password=pwd_input.value,
                    role=RoleEnum.ASSISTANT,
                    linked_doctor_id=self.doctor_id
                )
                session.add(new_ast)
                session.commit()
                
            modal.open = False
            snack = ft.SnackBar(ft.Text("Asistente creado con éxito"), bgcolor=colors.ACCENT_GREEN)
            self.ft_page.overlay.append(snack)
            snack.open = True
            self.load_assistants()

        modal = ft.AlertDialog(
            title=ft.Text("Añadir Asistente"),
            content=ft.Column([fname_input, lname_input, email_input, pwd_input], tight=True),
            actions=[
                ft.TextButton("Cancelar", on_click=lambda _: setattr(modal, 'open', False) or self.ft_page.update()),
                ft.ElevatedButton("Crear Asistente", on_click=save_assistant, bgcolor=colors.PRIMARY, color="white")
            ]
        )
        self.ft_page.overlay.append(modal)
        modal.open = True
        self.ft_page.update()

    def build_ui(self):
        header = ft.Row([
            ft.IconButton(
                icon=ft.Icons.ARROW_BACK,
                icon_color=colors.PRIMARY,
                on_click=lambda e: self.on_navigate() if self.on_navigate else None
            ),
            ft.Text("Gestión de Asistentes", size=24, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK)
        ], alignment=ft.MainAxisAlignment.START)

        create_btn = ft.ElevatedButton(
            "Añadir Nuevo Asistente",
            icon=ft.Icons.ADD,
            on_click=self.open_create_modal,
            style=ft.ButtonStyle(
                bgcolor=colors.PRIMARY,
                color="white"
            )
        )

        content = ft.Column([
            header,
            ft.Text("Tus asistentes registrados podrán gestionar tu agenda de citas. Si tu plan VIP vence, perderán el acceso.", size=12, color=colors.TEXT_LIGHT),
            ft.Divider(color=colors.INPUT_BORDER),
            create_btn,
            ft.Container(
                content=self.assistants_list,
                expand=True,
                margin=ft.margin.Margin(top=10, right=0, bottom=0, left=0)
            )
        ], expand=True, spacing=10)

        self.content = ft.Container(
            content=content,
            bgcolor=colors.SURFACE,
            border_radius=15,
            padding=20,
            expand=True
        )
