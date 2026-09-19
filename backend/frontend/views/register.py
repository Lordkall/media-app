import flet as ft
from core import colors
import sys
import os
import re

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.append(base_path)
sys.path.append(os.path.join(base_path, 'backend'))
from app.models.users import User, RoleEnum
from sqlalchemy.exc import IntegrityError

# Prefijos válidos de operadoras venezolanas
PREFIJOS_VE = ("0416", "0426", "0414", "0424", "0412")
ESTADOS_VE = [
    "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar", "Carabobo", "Cojedes",
    "Delta Amacuro", "Dependencias Federales", "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
    "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
    "Trujillo", "Yaracuy", "Zulia"
]

def RegisterView(page: ft.Page):
    
    email_input = ft.TextField(
        label="Correo Electrónico",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        keyboard_type=ft.KeyboardType.EMAIL,
    )

    first_name_input = ft.TextField(
        label="Nombres",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
    )

    last_name_input = ft.TextField(
        label="Apellidos",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
    )

    phone_input = ft.TextField(
        label="Teléfono (ej: 04141234567)",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        keyboard_type=ft.KeyboardType.NUMBER,
        input_filter=ft.NumbersOnlyInputFilter(),
        max_length=11
    )
    
    state_dropdown = ft.Dropdown(
        label="Estado",
        options=[ft.dropdown.Option(estado) for estado in ESTADOS_VE],
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        text_size=14,
        content_padding=10,
        max_menu_height=200,
    )
    
    address_input = ft.TextField(
        label="Dirección",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
    )

    gender_radio = ft.RadioGroup(
        content=ft.Column([
            ft.Row([
                ft.Radio(value="Masculino", label="Masculino"),
                ft.Radio(value="Femenino", label="Femenino"),
            ], alignment=ft.MainAxisAlignment.CENTER),
            ft.Row([
                ft.Radio(value="Prefiero no decirlo", label="Prefiero no decirlo"),
            ], alignment=ft.MainAxisAlignment.CENTER),
        ], alignment=ft.MainAxisAlignment.CENTER, spacing=0),
        value="Prefiero no decirlo"
    )

    from app.models.doctors import SPECIALTIES
    
    selected_specialties = set()
    
    specialty_search = ft.TextField(
        label="Buscar Especialidad",
        prefix_icon=ft.Icons.SEARCH,
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        on_change=lambda e: update_specialties_list(e.control.value),
    )
    
    search_results_list = ft.ListView(height=150, spacing=5)
    
    search_results_container = ft.Container(
        content=search_results_list,
        bgcolor=colors.INPUT_BG,
        border_radius=12,
        border=ft.Border.all(1, colors.INPUT_BORDER if hasattr(colors, 'INPUT_BORDER') else "#e0e0e0"),
        padding=10,
        visible=False,
        width=300
    )
    
    selected_chips_row = ft.Row(wrap=True, spacing=5, alignment=ft.MainAxisAlignment.CENTER)
    
    specialty_container = ft.Column([
        ft.Text("Especialidades Médicas", size=14, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        specialty_search,
        search_results_container,
        selected_chips_row
    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, visible=False)
    
    def render_selected_chips():
        selected_chips_row.controls.clear()
        for s in sorted(list(selected_specialties)):
            def make_on_remove(spec):
                def handler(e):
                    selected_specialties.discard(spec)
                    render_selected_chips()
                    update_specialties_list(specialty_search.value)
                return handler
            
            selected_chips_row.controls.append(
                ft.Chip(
                    label=ft.Text(s, size=12, color="white"),
                    on_delete=make_on_remove(s),
                    bgcolor=colors.PRIMARY,
                    delete_icon_color="white"
                )
            )
        page.update()

    def update_specialties_list(search_term=""):
        search_results_list.controls.clear()
        term = search_term.strip().lower()
        if not term:
            search_results_container.visible = False
            page.update()
            return
            
        search_results_container.visible = True
        count = 0
        for s in SPECIALTIES:
            if s.lower().startswith(term):
                def make_on_change(spec):
                    def handler(e):
                        if e.control.value:
                            selected_specialties.add(spec)
                            # Limpiar la barra de búsqueda al elegir
                            specialty_search.value = ""
                            update_specialties_list("")
                        else:
                            selected_specialties.discard(spec)
                        render_selected_chips()
                    return handler
                    
                cb = ft.Checkbox(
                    label=s,
                    value=s in selected_specialties,
                    on_change=make_on_change(s),
                    fill_color=colors.PRIMARY,
                    label_style=ft.TextStyle(color=colors.TEXT_DARK)
                )
                search_results_list.controls.append(cb)
                count += 1
        
        if count == 0:
            search_results_list.controls.append(ft.Text("No se encontraron resultados", size=12, color=colors.TEXT_LIGHT))
        page.update()

    # Estado del rol
    role_value = {"value": "patient"}

    # Contenedores visuales para el rol
    patient_btn = ft.Container(
        content=ft.Row([ft.Icon(ft.Icons.PERSON), ft.Text("Soy Paciente", weight=ft.FontWeight.BOLD)], alignment=ft.MainAxisAlignment.CENTER),
        expand=True,
        padding=15,
        border_radius=10,
        border=ft.border.all(2, colors.PRIMARY),
        bgcolor=colors.PRIMARY,
        ink=True,
    )
    
    doctor_btn = ft.Container(
        content=ft.Row([ft.Icon(ft.Icons.MEDICAL_SERVICES, color=colors.TEXT_DARK), ft.Text("Soy Doctor", color=colors.TEXT_DARK, weight=ft.FontWeight.BOLD)], alignment=ft.MainAxisAlignment.CENTER),
        expand=True,
        padding=15,
        border_radius=10,
        border=ft.border.all(2, colors.INPUT_BORDER),
        bgcolor="transparent",
        ink=True,
    )

    def on_role_change(e=None):
        is_doc = (role_value["value"] == "doctor")
        specialty_container.visible = is_doc
        
        # Actualizar estilos
        patient_btn.bgcolor = "transparent" if is_doc else colors.PRIMARY
        patient_btn.border = ft.border.all(2, colors.INPUT_BORDER if is_doc else colors.PRIMARY)
        patient_btn.content.controls[0].color = colors.TEXT_DARK if is_doc else "white"
        patient_btn.content.controls[1].color = colors.TEXT_DARK if is_doc else "white"
        
        doctor_btn.bgcolor = colors.PRIMARY if is_doc else "transparent"
        doctor_btn.border = ft.border.all(2, colors.PRIMARY if is_doc else colors.INPUT_BORDER)
        doctor_btn.content.controls[0].color = "white" if is_doc else colors.TEXT_DARK
        doctor_btn.content.controls[1].color = "white" if is_doc else colors.TEXT_DARK
        
        page.update()

    def set_patient(e):
        role_value["value"] = "patient"
        on_role_change()

    def set_doctor(e):
        role_value["value"] = "doctor"
        on_role_change()

    patient_btn.on_click = set_patient
    doctor_btn.on_click = set_doctor

    role_selector = ft.Column([
        ft.Text("¿Cómo deseas registrarte?", size=14, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        ft.Row([patient_btn, doctor_btn], spacing=15)
    ], spacing=10)
    
    password_input = ft.TextField(
        label="Contraseña",
        password=True,
        can_reveal_password=True,
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
    )
    
    password_repeat_input = ft.TextField(
        label="Repetir contraseña",
        password=True,
        can_reveal_password=True,
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
    )
    
    error_text = ft.Text(color="red", size=12)

    def go_back(e):
        page.views.pop()
        page.update()

    def validate_phone(phone: str) -> bool:
        """Valida que el teléfono tenga un prefijo venezolano válido y 11 dígitos."""
        # Remover guiones, espacios y paréntesis
        cleaned = re.sub(r"[\s\-\(\)]+", "", phone)
        # Debe tener 11 dígitos y empezar con un prefijo válido
        if len(cleaned) != 11 or not cleaned.isdigit():
            return False
        return cleaned[:4] in PREFIJOS_VE

    def validate_email(email: str) -> bool:
        """Validación básica de correo electrónico."""
        pattern = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
        return bool(re.match(pattern, email))

    def handle_register(e):
        async def _run():
            error_text.value = ""
            page.update()
            
            email = (email_input.value or "").strip()
            first_name = (first_name_input.value or "").strip()
            last_name = (last_name_input.value or "").strip()
            phone = (phone_input.value or "").strip()
            state = state_dropdown.value
            address = (address_input.value or "").strip()
            password = (password_input.value or "").strip()
            password_repeat = (password_repeat_input.value or "").strip()
            
            # Validaciones
            if not all([email, first_name, last_name, phone, state, address, password, password_repeat]):
                error_text.value = "Todos los campos son obligatorios."
                page.update()
                return

            if password != password_repeat:
                error_text.value = "Las contraseñas no coinciden."
                page.update()
                return

            if len(password) < 8:
                error_text.value = "La contraseña debe tener al menos 8 caracteres (HTTP 400)."
                page.update()
                return
                
            if not any(char.isdigit() for char in password) or not any(char.isalpha() for char in password):
                error_text.value = "La contraseña debe contener letras y números (HTTP 400)."
                page.update()
                return

            if not validate_email(email):
                error_text.value = "Ingrese un correo electrónico válido."
                page.update()
                return

            if not validate_phone(phone):
                error_text.value = "Teléfono inválido. Use un número venezolano (0414/0424/0416/0426/0412)."
                page.update()
                return

            # Limpiar el teléfono para guardar solo dígitos
            cleaned_phone = re.sub(r"[\s\-\(\)]+", "", phone)
                
        async def _async_register():
            try:
                async with async_session_maker() as session:
                    new_user = User(
                        email=email_input.value.strip(),
                        first_name=first_name_input.value.strip(),
                        last_name=last_name_input.value.strip(),
                        phone=re.sub(r"[\s\-\(\)]+", "", phone_input.value.strip()),
                        state=state_dropdown.value,
                        address=address_input.value.strip(),
                        hashed_password=password_input.value.strip(),  # En prod se debería hacer un hash real
                        role=RoleEnum.PATIENT
                    )
                    session.add(new_user)
                    await session.flush() # Para obtener el ID
                    
                    if new_user.role == RoleEnum.PATIENT:
                        from app.models.patients import Patient
                        new_pat = Patient(user_id=new_user.id, contact_phone=new_user.phone)
                        session.add(new_pat)
                        
                    await session.commit()
                    
                    snack = ft.SnackBar(ft.Text("¡Cuenta creada exitosamente!"), bgcolor=colors.PRIMARY)
                    page.overlay.append(snack)
                    snack.open = True
                    
                    # Regresar al login
                    page.views.pop()
                    page.update()
            except IntegrityError:
                error_text.value = "El correo ya está registrado."
                page.update()
            except Exception as ex:
                error_text.value = f"Error: {str(ex)}"
                page.update()

        import asyncio
        # We need to await _run for synchronous validation and async update
        # However, _run modifies GUI before DB. We can merge them safely.
        async def _combined():
            error_text.value = ""
            page.update()
            
            email = (email_input.value or "").strip()
            first_name = (first_name_input.value or "").strip()
            last_name = (last_name_input.value or "").strip()
            phone = (phone_input.value or "").strip()
            state = state_dropdown.value
            address = (address_input.value or "").strip()
            password = (password_input.value or "").strip()
            password_repeat = (password_repeat_input.value or "").strip()
            
            if not all([email, first_name, last_name, phone, state, address, password, password_repeat]):
                error_text.value = "Todos los campos son obligatorios."
                page.update()
                return
                
            if role_value["value"] == "doctor" and not selected_specialties:
                error_text.value = "Debe seleccionar al menos una especialidad médica."
                page.update()
                return
                
            if password != password_repeat:
                error_text.value = "Las contraseñas no coinciden."
                page.update()
                return
                
            if len(password) < 8:
                error_text.value = "La contraseña debe tener al menos 8 caracteres (HTTP 400)."
                page.update()
                return
                
            if not any(char.isdigit() for char in password) or not any(char.isalpha() for char in password):
                error_text.value = "La contraseña debe contener letras y números (HTTP 400)."
                page.update()
                return
            if not validate_email(email):
                error_text.value = "Ingrese un correo electrónico válido."
                page.update()
                return
            if not validate_phone(phone):
                error_text.value = "Teléfono inválido. Use un número venezolano (0414/0424/0416/0426/0412)."
                page.update()
                return

            cleaned_phone = re.sub(r"[\s\-\(\)]+", "", phone)
            
            try:
                from core.api_client import client
                payload = {
                    "email": email,
                    "first_name": first_name,
                    "last_name": last_name,
                    "phone": cleaned_phone,
                    "state": state,
                    "address": address,
                    "gender": gender_radio.value,
                    "password": password,
                    "role": "doctor" if role_value["value"] == "doctor" else "patient",
                    "specialties": list(selected_specialties) if role_value["value"] == "doctor" else []
                }
                import asyncio
                await asyncio.to_thread(client.post, "/auth/register", json=payload)
                
                snack = ft.SnackBar(ft.Text("¡Cuenta creada exitosamente!"), bgcolor=colors.PRIMARY)
                page.overlay.append(snack)
                snack.open = True
                
                page.views.pop()
                page.update()
            except Exception as ex:
                if hasattr(ex, "response") and ex.response is not None:
                    try:
                        error_data = ex.response.json()
                        error_text.value = error_data.get("detail", "Error al registrar")
                    except:
                        error_text.value = f"Error del servidor: {ex.response.status_code}"
                else:
                    error_text.value = f"Error: {str(ex)}"
                page.update()

        page.run_task(_combined)

    content = ft.Column(
        [
            ft.Row([
                ft.IconButton(ft.Icons.ARROW_BACK, on_click=go_back, icon_color=colors.TEXT_DARK)
            ]),
            ft.Container(height=5),
            ft.Image(
                src="logo.png",
                width=140,
                height=140,
                fit=ft.ImageFit.CONTAIN,
            ),
            ft.Container(height=5),
            ft.Text("Crear cuenta", size=24, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
            ft.Container(height=5),
            ft.Text("Regístrese en Salud Now para gestionar sus citas", size=14, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
            ft.Container(height=10),
            role_selector,
            ft.Container(height=10),
            ft.Text("Género", size=14, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
            gender_radio,
            ft.Container(height=10),
            email_input,
            ft.Container(height=10),
            first_name_input,
            ft.Container(height=10),
            last_name_input,
            ft.Container(height=10),
            phone_input,
            ft.Container(height=10),
            state_dropdown,
            ft.Container(height=10),
            specialty_container,
            ft.Container(height=10),
            ft.Container(height=10),
            address_input,
            ft.Container(height=10),
            password_input,
            ft.Container(height=10),
            password_repeat_input,
            error_text,
            ft.Container(height=20),
            ft.Button(
                "Registrarse",
                bgcolor=colors.PRIMARY,
                color="white",
                on_click=handle_register
            ),
            ft.Container(expand=True)
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        scroll=ft.ScrollMode.AUTO,
        expand=True
    )

    return ft.View(
        route="/register",
        controls=[
            ft.Container(
                content=content,
                padding=20,
                expand=True
            )
        ],
        bgcolor=colors.BACKGROUND,
    )
