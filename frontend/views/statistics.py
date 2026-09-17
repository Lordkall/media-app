import flet as ft
from frontend.core import colors
from sqlalchemy import create_engine, select, func
from sqlalchemy.orm import sessionmaker
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionStatus

def StatisticsView(page: ft.Page, user):
    """Vista de estadísticas para administradores."""

    def go_back(e):
        page.views.pop()
        page.update()

    stats_content = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True, spacing=20)

    try:
        from frontend.core.config import SYNC_DB_URL
        engine = create_engine(SYNC_DB_URL)
        Session = sessionmaker(bind=engine)
        
        with Session() as session:
            # 1. Total pacientes
            total_patients = session.execute(select(func.count(User.id)).where(User.role == RoleEnum.PATIENT)).scalar() or 0
            
            # 2. Pacientes por estado
            patients_by_state = session.execute(
                select(User.state, func.count(User.id))
                .where(User.role == RoleEnum.PATIENT)
                .group_by(User.state)
            ).all()
            
            # 3. Total doctores
            total_doctors = session.execute(select(func.count(User.id)).where(User.role == RoleEnum.DOCTOR)).scalar() or 0
            
            # 4. Doctores por estado
            doctors_by_state = session.execute(
                select(User.state, func.count(User.id))
                .where(User.role == RoleEnum.DOCTOR)
                .group_by(User.state)
            ).all()
            
            # 5. Doctores por plan (suscripciones activas)
            docs_by_plan = session.execute(
                select(Subscription.plan, func.count(Subscription.id))
                .where(Subscription.status == SubscriptionStatus.ACTIVE)
                .group_by(Subscription.plan)
            ).all()
            
            # 6. Distribucion por Genero
            gender_dist = session.execute(
                select(User.gender, func.count(User.id))
                .group_by(User.gender)
            ).all()

        def create_stat_card(title, value, icon, icon_color):
            return ft.Container(
                content=ft.Row([
                    ft.Icon(icon, color=icon_color, size=40),
                    ft.Column([
                        ft.Text(title, size=12, color=colors.TEXT_LIGHT),
                        ft.Text(str(value), size=24, weight=ft.FontWeight.BOLD, color=colors.PRIMARY),
                    ], spacing=2)
                ]),
                padding=20,
                bgcolor=colors.SURFACE,
                border_radius=12,
                border=ft.border.Border.all(1, colors.INPUT_BORDER),
                width=150,
            )

        def create_table(title, data, col_name1, col_name2):
            rows = []
            for row in data:
                rows.append(
                    ft.DataRow(cells=[
                        ft.DataCell(ft.Text(str(row[0] or "N/A"), size=12)),
                        ft.DataCell(ft.Text(str(row[1]), size=12, weight=ft.FontWeight.BOLD))
                    ])
                )
            
            return ft.Container(
                content=ft.Column([
                    ft.Text(title, size=16, weight=ft.FontWeight.BOLD, color=colors.PRIMARY),
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text(col_name1)),
                            ft.DataColumn(ft.Text(col_name2, text_align=ft.TextAlign.RIGHT)),
                        ],
                        rows=rows,
                    )
                ]),
                padding=20,
                bgcolor=colors.SURFACE,
                border_radius=12,
                border=ft.border.Border.all(1, colors.INPUT_BORDER),
                expand=True
            )

        # Totales
        stats_content.controls.append(
            ft.Row([
                create_stat_card("Total Pacientes", total_patients, ft.Icons.PEOPLE, colors.PRIMARY),
                create_stat_card("Total Doctores", total_doctors, ft.Icons.LOCAL_HOSPITAL, colors.ACCENT_GREEN),
            ], alignment=ft.MainAxisAlignment.SPACE_EVENLY)
        )
        
        # Gender Stats Table
        stats_content.controls.append(
            ft.Row([
                create_table("Distribución por Género", gender_dist, "Género", "Cantidad")
            ], alignment=ft.MainAxisAlignment.CENTER)
        )
        
        # Tablas
        stats_content.controls.append(create_table("Pacientes por Estado", patients_by_state, "Estado", "Pacientes"))
        stats_content.controls.append(create_table("Doctores por Estado", doctors_by_state, "Estado", "Doctores"))
        
        # Tabla de planes
        plan_names = {"basic": "Básico", "featured": "Destacado", "sponsored": "Patrocinado VIP"}
        plan_data = [(plan_names.get(p[0].value, str(p[0].value)), p[1]) for p in docs_by_plan]
        stats_content.controls.append(create_table("Suscripciones Activas", plan_data, "Plan", "Doctores"))

    except Exception as e:
        stats_content.controls.append(ft.Text(f"Error al cargar estadísticas: {e}", color="red"))

    # Header
    header = ft.Container(
        content=ft.Row(
            [
                ft.IconButton(icon=ft.Icons.ARROW_BACK_IOS_NEW, icon_size=18, on_click=go_back, icon_color=colors.PRIMARY),
                ft.Text("Estadísticas", size=20, weight=ft.FontWeight.W_800, color=colors.TEXT_DARK, expand=True, text_align=ft.TextAlign.CENTER),
                ft.Container(width=40)
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        ),
        padding=ft.padding.Padding.only(top=10, bottom=20),
    )

    return ft.Container(
        content=ft.Column([header, stats_content]),
        expand=True,
        padding=20,
        bgcolor=colors.BACKGROUND
    )
