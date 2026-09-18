"""
Vista del Centro de Notificaciones.
Muestra alertas en tiempo real sobre suscripciones, renovaciones, avisos administrativos y citas.
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
WARNING_COLOR = colors.WARNING_COLOR
ERROR_COLOR = colors.ERROR_COLOR
BORDER_COLOR = colors.INPUT_BORDER

class NotificationsView(ft.Container):
    def __init__(self, page: ft.Page, user=None, on_navigate=None):
        super().__init__(expand=True)
        self.ft_page = page
        self.user = user
        self.on_navigate = on_navigate
        self.bg_color = BG_COLOR
        self.padding = 30

        self.build_ui()
        self.load_notifications()

    def build_ui(self):
        def handle_back(e):
            try:
                self.ft_page.pubsub.send_all_on_topic(f"user_{self.user.id}", "refresh_home")
            except Exception: pass
            
            if self.on_navigate:
                self.on_navigate("home")
            elif self.ft_page and len(self.ft_page.views) > 1:
                self.ft_page.views.pop()
                self.ft_page.update()

        self.header = ft.Column([
            ft.Row([
                ft.IconButton(
                    icon=ft.Icons.ARROW_BACK,
                    icon_color=PRIMARY_COLOR,
                    on_click=handle_back
                ),
                ft.Text("Notificaciones", size=20, weight=ft.FontWeight.BOLD, color=TEXT_PRIMARY, expand=True),
                ft.TextButton("Leídas", icon=ft.Icons.DONE_ALL, on_click=self.mark_all_read)
            ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Text("Mantente informado sobre suscripciones, avisos y eventos", size=12, style=ft.ButtonStyle(color=TEXT_SECONDARY, style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR, color=SUCCESS_COLOR))
                    self.ft_page.overlay.append(snack)
                    snack.open = True
                    self.load_notifications()
                    
                    if doc:
                        self.ft_page.pubsub.send_all_on_topic(
                            f"user_{doc.user_id}",
                            f"new_notification:Tu suscripción ha sido validada"
                        )
        except Exception as e:
            print("Error approving subscription:", e)

    def create_notification_card(self, n):
        # Icono según tipo
        if n["type"] == "new_sub" or n["type"] == "new_subscription":
            icon = ft.Icon(ft.Icons.STAR, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"
        elif n["type"] == "warning" or n["type"] == "renewal_reminder" or n["type"] == "grace_period_warning":
            icon = ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=WARNING_COLOR, size=24)
            badge_bg = WARNING_COLOR + "20"
        elif n["type"] == "grace":
            icon = ft.Icon(ft.Icons.SCHEDULE, color=ACCENT_COLOR, size=24)
            badge_bg = ACCENT_COLOR + "20"
        elif n["type"] == "appointment_created":
            icon = ft.Icon(ft.Icons.CALENDAR_MONTH, color=SUCCESS_COLOR, size=24)
            badge_bg = SUCCESS_COLOR + "20"
        elif n["type"] == "appointment_cancelled":
            icon = ft.Icon(ft.Icons.CANCEL, color=ERROR_COLOR, size=24)
            badge_bg = ERROR_COLOR + "20"
        elif n["type"] == "doctor_registered":
            icon = ft.Icon(ft.Icons.PERSON_ADD, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"
        elif n["type"] == "doctor_approved":
            icon = ft.Icon(ft.Icons.HOW_TO_REG, color=SUCCESS_COLOR, size=24)
            badge_bg = SUCCESS_COLOR + "20"
        else:
            icon = ft.Icon(ft.Icons.NOTIFICATIONS, color=PRIMARY_COLOR, size=24)
            badge_bg = PRIMARY_COLOR + "20"

        btn_action = None
        if n.get("action_url"):
            if n["action_url"].startswith("approve_doctor:"):
                doc_id = int(n["action_url"].split(":")[1])
                btn_action = ft.ElevatedButton(
                    "Aprobar Doctor",
                    icon=ft.Icons.CHECK_CIRCLE,
                    style=ft.ButtonStyle(bgstyle=ft.ButtonStyle(color=SUCCESS_COLOR, style=ft.ButtonStyle(bgcolor=SUCCESS_COLOR, color="white")),
                    on_click=lambda e, s=sub_id, nid=n["id"]: self.handle_approve_subscription(s, nid)
                )
            else:
                btn_action = ft.ElevatedButton(
                    "Ir a Renovar / Ver",
                    icon=ft.Icons.OPEN_IN_NEW,
                    style=ft.ButtonStyle(bgstyle=ft.ButtonStyle(color=PRIMARY_COLOR, style=ft.ButtonStyle(bgcolor=badge_bg, color=TEXT_PRIMARY), expand=True),
                            ft.Text(n["time"], size=12, color=TEXT_SECONDARY),
                        ]),
                        ft.Text(n["message"], size=13, color=TEXT_SECONDARY),
                        ft.Row([btn_action]) if btn_action else ft.Container()
                    ], expand=True, spacing=4)
                ], vertical_alignment=ft.CrossAxisAlignment.START, spacing=15),
                padding=15,
                bgcolor=SURFACE_COLOR if n["read"] else SURFACE_COLOR,
                border=ft.border.Border.all(1, BORDER_COLOR if n["read"] else PRIMARY_COLOR)
            )
        )

    def mark_all_read(self, e):
        from sqlalchemy import create_engine, update
        from sqlalchemy.orm import sessionmaker
        from app.models.notifications import Notification

        try:
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)
            with Session() as session:
                session.execute(
                    update(Notification)
                    .where(Notification.user_id == self.user.id)
                    .values(is_read=True)
                )
                session.commit()
                
                # Notify home to clear badge
                self.ft_page.pubsub.send_all_on_topic(f"user_{self.user.id}", "refresh_home")
        except Exception as ex:
            print("Error marking all as read:", ex)

        snack = ft.SnackBar(
            content=ft.Text("Todas las notificaciones han sido marcadas como leídas."),
            bgcolor=SUCCESS_COLOR
        )
        self.ft_page.overlay.append(snack)
        snack.open = True
        self.ft_page.update()
        self.load_notifications()
