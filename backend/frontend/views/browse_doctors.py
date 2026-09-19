import flet as ft
from core import colors
import sys
import os

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.append(base_path)
sys.path.append(os.path.join(base_path, 'backend'))
from app.models.doctors import Doctor, SPECIALTIES
from app.models.users import User
from sqlalchemy import select
from sqlalchemy.orm import joinedload


def _build_star_rating(rating: float) -> ft.Row:
    """Genera estrellas visuales para el rating."""
    stars = []
    full = int(rating)
    has_half = (rating - full) >= 0.3
    for i in range(5):
        if i < full:
            stars.append(ft.Icon(ft.Icons.STAR, color="#f5a623", size=14))
        elif i == full and has_half:
            stars.append(ft.Icon(ft.Icons.STAR_HALF, color="#f5a623", size=14))
        else:
            stars.append(ft.Icon(ft.Icons.STAR_BORDER, color="#d0d0d0", size=14))
    stars.append(ft.Text(f" {rating:.1f}", size=12, color=colors.TEXT_LIGHT))
    return ft.Row(stars, spacing=1)


def _doctor_card(doctor: Doctor, page: ft.Page = None) -> ft.Container:
    """Crea una tarjeta visual e interactiva para un doctor."""
    user = doctor.user
    specialties_str = ", ".join(doctor.specialties) if doctor.specialties else "Sin especialidad"
    avatar_src = user.avatar_url
    initials = f"{user.first_name[0]}{user.last_name[0]}".upper()

    def show_doctor_details(e):
        if not page:
            return
            
        from views.doctor_profile import DoctorProfileView
        page.views.append(DoctorProfileView(page, doctor=doctor))
        page.update()

    # Estrella para VIPs
    star_icon = None
    border_color = colors.INPUT_BORDER
    if doctor.is_sponsored:
        border_color = "#e6a817"
        star_icon = ft.Icon(ft.Icons.STAR, color="#e6a817", size=20)
    elif doctor.is_featured:
        border_color = colors.PRIMARY
        star_icon = ft.Icon(ft.Icons.STAR_BORDER, color=colors.PRIMARY, size=20)

    card_content = ft.Column(
        [
            ft.Container(height=5),
            ft.CircleAvatar(
                content=ft.Text(initials, size=24, weight=ft.FontWeight.BOLD, color="white") if not avatar_src else None,
                foreground_image_src=avatar_src if avatar_src else None,
                radius=35,
                bgcolor=colors.PRIMARY,
            ),
            ft.Container(height=5),
            ft.Text(
                f"Dr{'a' if getattr(user, 'gender', '') == 'F' else ''}. {user.first_name} {user.last_name}",
                size=13, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK, text_align=ft.TextAlign.CENTER
            ),
            ft.Text(
                specialties_str, size=11, color=colors.TEXT_LIGHT, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS, text_align=ft.TextAlign.CENTER
            )
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        alignment=ft.MainAxisAlignment.CENTER,
        spacing=4,
    )
    
    stack_items = [card_content]
    if star_icon:
        stack_items.append(
            ft.Container(
                content=star_icon,
                alignment=ft.alignment.top_right,
                margin=ft.margin.only(top=0, right=0, bottom=0, left=0)
            )
        )

    return ft.Container(
        content=ft.Stack(stack_items, expand=True),
        bgcolor="white",
        border_radius=14,
        padding=14,
        width=160,
        height=190,
        border=ft.border.all(1.5, border_color),
        on_click=show_doctor_details,
        shadow=ft.BoxShadow(
            spread_radius=0,
            blur_radius=8,
            color="#0F000000",
            offset=ft.Offset(0, 2),
        ),
    )


def BrowseDoctorsView(page: ft.Page, current_user):
    """Vista de exploración de doctores por especialidad."""

    doctors_list = ft.Row(wrap=True, spacing=15, run_spacing=15, alignment=ft.MainAxisAlignment.CENTER)
    selected_specialty = {"value": None}  # mutable ref
    search_value = {"value": ""}
    selected_state = {"value": "Todos"}

    def go_back(e):
        page.views.pop()
        page.update()

    def load_doctors():
        """Carga doctores de la BD con filtros."""
        try:
            from sqlalchemy import create_engine, select
            from sqlalchemy.orm import sessionmaker, joinedload
            
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            SyncSession = sessionmaker(bind=sync_engine)
            
            with SyncSession() as session:
                from sqlalchemy import or_
                from app.models.subscriptions import Subscription, SubscriptionStatus
                query = (
                    select(Doctor)
                    .join(Doctor.user)
                    .join(Doctor.subscriptions)
                    .where(Doctor.is_approved == True)
                    .where(Subscription.status == SubscriptionStatus.ACTIVE)
                    .options(joinedload(Doctor.user))
                    .order_by(
                        Doctor.is_sponsored.desc(),
                        Doctor.sponsored_priority.asc(),
                        Doctor.is_featured.desc(),
                        Doctor.rating.desc(),
                    )
                )

                # Filtro por especialidad
                if selected_specialty["value"]:
                    query = query.where(Doctor.specialties.any(selected_specialty["value"]))

                # Filtro por estado
                if selected_state["value"] != "Todos":
                    query = query.where(User.state == selected_state["value"])

                result = session.execute(query)
                docs = result.scalars().unique().all()

                # Filtro por búsqueda de texto
                search = search_value["value"].lower()
                if search:
                    docs = [
                        d for d in docs
                        if search in d.user.first_name.lower()
                        or search in d.user.last_name.lower()
                        or any(search in s.lower() for s in d.specialties)
                    ]

                doctors_list.controls.clear()

                if not docs:
                    doctors_list.controls.append(
                        ft.Container(
                            content=ft.Column(
                                [
                                    ft.Text("🔍", size=40),
                                    ft.Text("No se encontraron doctores", size=14, color=colors.TEXT_LIGHT),
                                ],
                                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                                spacing=8,
                            ),
                            alignment=ft.alignment.center,
                            padding=40,
                        )
                    )
                else:
                    for doc in docs:
                        doctors_list.controls.append(_doctor_card(doc, page=page))

                page.update()
        except Exception as ex:
            doctors_list.controls.clear()
            doctors_list.controls.append(
                ft.Text(f"Error al cargar doctores: {str(ex)}", color="red", size=12)
            )
            page.update()

    def on_search_change(e):
        search_value["value"] = e.control.value or ""
        load_doctors()

    def on_specialty_click(spec):
        def handler(e):
            if selected_specialty["value"] == spec:
                selected_specialty["value"] = None  # Deseleccionar
            else:
                selected_specialty["value"] = spec
            _update_chips()
            load_doctors()
        return handler

    # Chips de especialidad
    specialty_chips = ft.Row(
        scroll=ft.ScrollMode.AUTO,
        spacing=6,
    )

    def _update_chips():
        specialty_chips.controls.clear()
        # Chip "Todos"
        is_all = selected_specialty["value"] is None
        specialty_chips.controls.append(
            ft.Container(
                content=ft.Text(
                    "Todos",
                    size=12,
                    color="white" if is_all else colors.TEXT_DARK,
                    weight=ft.FontWeight.W_600 if is_all else ft.FontWeight.W_400,
                ),
                bgcolor=colors.PRIMARY if is_all else colors.INPUT_BG,
                border_radius=20,
                padding=ft.padding.only(left=14, right=14, top=8, bottom=8),
                on_click=on_specialty_click(None),
            )
        )
        for spec in SPECIALTIES:
            is_sel = selected_specialty["value"] == spec
            specialty_chips.controls.append(
                ft.Container(
                    content=ft.Text(
                        f"🩺 {spec}",
                        size=11,
                        color="white" if is_sel else colors.TEXT_DARK,
                        weight=ft.FontWeight.W_600 if is_sel else ft.FontWeight.W_400,
                    ),
                    bgcolor=colors.PRIMARY if is_sel else colors.INPUT_BG,
                    border_radius=20,
                    padding=ft.padding.only(left=12, right=12, top=8, bottom=8),
                    on_click=on_specialty_click(spec),
                )
            )
        page.update()

    _update_chips()

    ESTADOS_VE = [
        "Todos", "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar", "Carabobo", "Cojedes",
        "Delta Amacuro", "Dependencias Federales", "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
        "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa", "Sucre", "Táchira",
        "Trujillo", "Yaracuy", "Zulia"
    ]
    
    def on_state_change(e):
        selected_state["value"] = e.control.value
        load_doctors()
        
    state_dropdown = ft.Dropdown(
        label="Filtrar por Estado",
        options=[ft.dropdown.Option(estado) for estado in ESTADOS_VE],
        value="Todos",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        border_radius=12,
        on_change=on_state_change,
        content_padding=ft.padding.only(left=10, right=10, top=8, bottom=8),
    )

    # Search bar
    search_bar = ft.TextField(
        hint_text="Buscar doctor o especialidad...",
        prefix_icon=ft.Icons.SEARCH,
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK,
        border_radius=12,
        content_padding=ft.padding.only(left=10, right=10, top=8, bottom=8),
        on_change=on_search_change,
    )

    content = ft.Column(
        [
            # Header
            ft.Row(
                [
                    ft.IconButton(ft.Icons.ARROW_BACK, on_click=go_back, icon_color=colors.TEXT_DARK),
                    ft.Text("Buscar Doctores", size=20, weight=ft.FontWeight.W_700, color=colors.TEXT_DARK),
                ],
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            ft.Container(height=8),
            search_bar,
            ft.Container(height=10),
            state_dropdown,
            ft.Container(height=10),
            specialty_chips,
            ft.Container(height=12),
            # Loading indicator before doctors load
            ft.Container(
                content=doctors_list,
            ),
        ],
        scroll=ft.ScrollMode.AUTO,
        expand=True,
    )

    # Cargar doctores al entrar
    load_doctors()

    return ft.View(
        route="/browse_doctors",
        controls=[
            ft.Container(
                content=content,
                padding=ft.padding.only(left=16, right=16, top=10, bottom=10),
                expand=True,
            )
        ],
        bgcolor=colors.BACKGROUND,
    )
