import flet as ft
from core import colors
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker, joinedload
from app.models.support import SupportTicket, TicketMessage
from datetime import datetime

from core.config import SYNC_DB_URL

def get_session():
    engine = create_engine(SYNC_DB_URL)
    return sessionmaker(bind=engine)()

class SupportAdminView(ft.Container):
    def __init__(self, page: ft.Page, user, on_navigate=None):
        super().__init__(expand=True)
        self.ctx_page = page
        self.user = user
        self.on_navigate = on_navigate
        
        self.tickets_list = ft.ListView(expand=True, spacing=10)
        self.chat_view = ft.Container(expand=True, visible=False)
        self.chat_messages = ft.ListView(expand=True, spacing=10, padding=10)
        self.reply_field = ft.TextField(expand=True, hint_text="Escribir respuesta...", border_radius=20, multiline=True, max_lines=3)
        self.current_ticket_id = None
        
        self.build_ui()
        self.load_tickets()
        
    def build_ui(self):
        header = ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, on_click=lambda _: self.on_navigate() if self.on_navigate else None),
            ft.Text("Mensajes de Soporte", size=20, weight=ft.FontWeight.BOLD, color=colors.PRIMARY)
        ], alignment=ft.MainAxisAlignment.START)
        
        # Chat Input Area
        self.chat_input = ft.Row([
            self.reply_field,
            ft.IconButton(ft.Icons.SEND, icon_color=colors.PRIMARY, on_click=self.send_reply)
        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
        
        self.close_btn = ft.Button("Cerrar Ticket", style=ft.ButtonStyle(color="white", style=ft.ButtonStyle(bgcolor=colors.ERROR_COLOR)), on_click=self.close_ticket)
        self.chat_header = ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, on_click=self.close_chat),
            ft.Text("Chat", size=18, weight=ft.FontWeight.BOLD),
            self.close_btn
        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
        
        self.chat_view.content = ft.Column([
            self.chat_header,
            ft.Divider(),
            ft.Container(content=self.chat_messages, expand=True, bgcolor=colors.INPUT_BG, border_radius=10),
            self.chat_input
        ], expand=True)
        
        self.main_content = ft.Column([
            header,
            ft.Divider(),
            self.tickets_list
        ], expand=True)
        
        self.content = ft.Stack([
            self.main_content,
            self.chat_view
        ], expand=True)
        
    def load_tickets(self):
        self.tickets_list.controls.clear()
        with get_session() as session:
            tickets = session.execute(select(SupportTicket).options(joinedload(SupportTicket.user)).order_by(SupportTicket.created_at.desc())).scalars().unique().all()
            
            # Ordenar por el mensaje más reciente y revisar unread
            for t in tickets:
                msgs = session.execute(select(TicketMessage).where(TicketMessage.ticket_id == t.id).order_by(TicketMessage.created_at.desc())).scalars().all()
                t._latest_msg_date = msgs[0].created_at if msgs else t.created_at
                t._has_unread = any(not m.is_read and m.sender_id != self.user.id for m in msgs)
            tickets = sorted(tickets, key=lambda x: x._latest_msg_date, reverse=True)
            
            for t in tickets:
                icon_color = colors.ACCENT_GREEN if t.status == "ABIERTO" else colors.TEXT_LIGHT
                icon_ctrl = ft.Icon(ft.Icons.HELP, color=icon_color)
                if getattr(t, '_has_unread', False):
                    icon_ctrl = ft.Badge(content=icon_ctrl, bgcolor="red", small_size=10)
                    
                self.tickets_list.controls.append(
                    ft.ListTile(
                        leading=icon_ctrl,
                        title=ft.Text(t.subject, weight=ft.FontWeight.BOLD),
                        subtitle=ft.Text(f"De: {t.user.first_name} {t.user.last_name} | {t._latest_msg_date.strftime('%Y-%m-%d %H:%M')} | {t.status}"),
                        on_click=self.create_open_chat_fn(t.id),
                        bgcolor="white"
                    )
                )
        if self.ctx_page:
            self.ctx_page.update()
            
    def create_open_chat_fn(self, ticket_id):
        return lambda e: self.open_chat(ticket_id)
        
    def open_chat(self, ticket_id):
        self.current_ticket_id = ticket_id
        self.main_content.visible = False
        self.chat_view.visible = True
        self.load_messages()
        
    def close_chat(self, e):
        self.current_ticket_id = None
        self.chat_view.visible = False
        self.main_content.visible = True
        self.load_tickets()
        
    def load_messages(self):
        self.chat_messages.controls.clear()
        if not self.current_ticket_id: return
        
        with get_session() as session:
            ticket = session.execute(select(SupportTicket).where(SupportTicket.id == self.current_ticket_id)).scalar_one_or_none()
            if not ticket: return
            
            messages = session.execute(select(TicketMessage).where(TicketMessage.ticket_id == self.current_ticket_id).order_by(TicketMessage.created_at)).scalars().all()
            for m in messages:
                if m.sender_id != self.user.id and not m.is_read:
                    m.is_read = True
            session.commit()
            
            for m in messages:
                is_admin = m.sender_id == self.user.id
                alignment = ft.MainAxisAlignment.END if is_admin else ft.MainAxisAlignment.START
                bgcolor = colors.PRIMARY if is_admin else "#E0E0E0"
                text_color = "white" if is_admin else colors.TEXT_DARK
                
                self.chat_messages.controls.append(
                    ft.Row([
                        ft.Container(
                            content=ft.Text(m.message, color=text_color),
                            bgcolor=bgcolor,
                            padding=10,
                            border_radius=10
                        )
                    ], alignment=alignment)
                )
            
            # Disable input and close button if closed
            is_closed = ticket.status == "CERRADO"
            self.reply_field.disabled = is_closed
            self.chat_input.disabled = is_closed
            self.close_btn.visible = not is_closed
            
        if self.ctx_page:
            self.ctx_page.update()
            
    def send_reply(self, e):
        if not self.reply_field.value or not self.current_ticket_id: return
        with get_session() as session:
            msg = TicketMessage(
                ticket_id=self.current_ticket_id,
                sender_id=self.user.id,
                message=self.reply_field.value
            )
            session.add(msg)
            session.commit()
        self.reply_field.value = ""
        self.load_messages()
        
    def close_ticket(self, e):
        if not self.current_ticket_id: return
        with get_session() as session:
            ticket = session.execute(select(SupportTicket).where(SupportTicket.id == self.current_ticket_id)).scalar_one_or_none()
            if ticket:
                ticket.status = "CERRADO"
                session.commit()
        self.close_chat(None)


class SupportUserView(ft.Container):
    def __init__(self, page: ft.Page, user, on_navigate=None):
        super().__init__(expand=True)
        self.ctx_page = page
        self.user = user
        self.on_navigate = on_navigate
        
        self.tickets_list = ft.ListView(expand=True, spacing=10)
        self.chat_view = ft.Container(expand=True, visible=False)
        self.chat_messages = ft.ListView(expand=True, spacing=10, padding=10)
        self.reply_field = ft.TextField(expand=True, hint_text="Escribir mensaje...", border_radius=20, multiline=True, max_lines=3)
        self.current_ticket_id = None
        
        self.build_ui()
        self.load_tickets()
        
    def build_ui(self):
        header = ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, on_click=lambda _: self.on_navigate() if self.on_navigate else None),
            ft.Text("Mis Mensajes", size=20, weight=ft.FontWeight.BOLD, color=colors.PRIMARY)
        ], alignment=ft.MainAxisAlignment.START)
        
        self.chat_input = ft.Row([
            self.reply_field,
            ft.IconButton(ft.Icons.SEND, icon_color=colors.PRIMARY, on_click=self.send_reply)
        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
        
        self.chat_header = ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, on_click=self.close_chat),
            ft.Text("Conversación", size=18, weight=ft.FontWeight.BOLD)
        ], alignment=ft.MainAxisAlignment.START)
        
        self.chat_view.content = ft.Column([
            self.chat_header,
            ft.Divider(),
            ft.Container(content=self.chat_messages, expand=True, bgcolor=colors.INPUT_BG, border_radius=10),
            self.chat_input
        ], expand=True)
        
        self.main_content = ft.Column([
            header,
            ft.Divider(),
            self.tickets_list
        ], expand=True)
        
        self.content = ft.Stack([
            self.main_content,
            self.chat_view
        ], expand=True)
        
    def load_tickets(self):
        self.tickets_list.controls.clear()
        with get_session() as session:
            tickets = session.execute(select(SupportTicket).where(SupportTicket.user_id == self.user.id).order_by(SupportTicket.created_at.desc())).scalars().all()
            
            # Ordenar por el mensaje más reciente y revisar unread
            for t in tickets:
                msgs = session.execute(select(TicketMessage).where(TicketMessage.ticket_id == t.id).order_by(TicketMessage.created_at.desc())).scalars().all()
                t._latest_msg_date = msgs[0].created_at if msgs else t.created_at
                t._has_unread = any(not m.is_read and m.sender_id != self.user.id for m in msgs)
            tickets = sorted(tickets, key=lambda x: x._latest_msg_date, reverse=True)
            
            for t in tickets:
                icon_color = colors.ACCENT_GREEN if t.status == "ABIERTO" else colors.TEXT_LIGHT
                icon_ctrl = ft.Icon(ft.Icons.HELP, color=icon_color)
                if getattr(t, '_has_unread', False):
                    icon_ctrl = ft.Badge(content=icon_ctrl, bgcolor="red", small_size=10)
                    
                self.tickets_list.controls.append(
                    ft.ListTile(
                        leading=icon_ctrl,
                        title=ft.Text(t.subject, weight=ft.FontWeight.BOLD),
                        subtitle=ft.Text(f"{t._latest_msg_date.strftime('%Y-%m-%d %H:%M')} | {t.status}"),
                        on_click=self.create_open_chat_fn(t.id),
                        bgcolor="white"
                    )
                )
        if self.ctx_page:
            self.ctx_page.update()
            
    def create_open_chat_fn(self, ticket_id):
        return lambda e: self.open_chat(ticket_id)
        
    def open_chat(self, ticket_id):
        self.current_ticket_id = ticket_id
        self.main_content.visible = False
        self.chat_view.visible = True
        self.load_messages()
        
    def close_chat(self, e):
        self.current_ticket_id = None
        self.chat_view.visible = False
        self.main_content.visible = True
        self.load_tickets()
        
    def load_messages(self):
        self.chat_messages.controls.clear()
        if not self.current_ticket_id: return
        
        with get_session() as session:
            ticket = session.execute(select(SupportTicket).where(SupportTicket.id == self.current_ticket_id)).scalar_one_or_none()
            if not ticket: return
            
            messages = session.execute(select(TicketMessage).where(TicketMessage.ticket_id == self.current_ticket_id).order_by(TicketMessage.created_at)).scalars().all()
            for m in messages:
                if m.sender_id != self.user.id and not m.is_read:
                    m.is_read = True
            session.commit()
            
            for m in messages:
                is_user = m.sender_id == self.user.id
                alignment = ft.MainAxisAlignment.END if is_user else ft.MainAxisAlignment.START
                bgcolor = colors.PRIMARY if is_user else "#E0E0E0"
                text_color = "white" if is_user else colors.TEXT_DARK
                
                self.chat_messages.controls.append(
                    ft.Row([
                        ft.Container(
                            content=ft.Text(m.message, color=text_color),
                            bgcolor=bgcolor,
                            padding=10,
                            border_radius=10
                        )
                    ], alignment=alignment)
                )
            
            # Disable input if closed
            is_closed = ticket.status == "CERRADO"
            self.reply_field.disabled = is_closed
            self.chat_input.disabled = is_closed
            
        if self.ctx_page:
            self.ctx_page.update()
            
    def send_reply(self, e):
        if not self.reply_field.value or not self.current_ticket_id: return
        with get_session() as session:
            msg = TicketMessage(
                ticket_id=self.current_ticket_id,
                sender_id=self.user.id,
                message=self.reply_field.value
            )
            session.add(msg)
            session.commit()
        self.reply_field.value = ""
        self.load_messages()
