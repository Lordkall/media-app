import flet as ft
from core import colors
import urllib.parse

def DoctorProfileView(page: ft.Page, doctor, on_navigate=None):
    def handle_back(e):
        page.views.pop()
        page.update()

    doc_u = doctor.user
    is_female = getattr(doc_u, 'gender', '') in ('F', 'Femenino', 'femenino')
    doc_name = f"Dr{'a' if is_female else ''}. {doc_u.first_name} {doc_u.last_name}"
    
    avatar_src = doc_u.avatar_url if doc_u.avatar_url else None
    initials = (doc_u.first_name[0] + doc_u.last_name[0]).upper()
    
    is_base64 = avatar_src and str(avatar_src).startswith("data:image/")
    b64_data = str(avatar_src).split("base64,")[-1] if is_base64 else None
    
    specialties_list = doctor.specialties if hasattr(doctor, 'specialties') and doctor.specialties else []
    spec_val = ", ".join(specialties_list) if specialties_list else "Sin especialidad"
    
    whatsapp_number = doc_u.phone.replace("-", "").replace(" ", "").replace("+", "")
    if not whatsapp_number.startswith("58"):
        if whatsapp_number.startswith("0"):
            whatsapp_number = "58" + whatsapp_number[1:]
        else:
            whatsapp_number = "58" + whatsapp_number
            
    whatsapp_msg = urllib.parse.quote(f"Hola {doc_name}, quisiera hacer una consulta.")
    whatsapp_url = f"https://api.whatsapp.com/send?phone={whatsapp_number}&text={whatsapp_msg}"

    location_text = ""
    if doc_u.state and doc_u.address:
        location_text = f"{doc_u.state} - {doc_u.address}"
    elif doc_u.address:
        location_text = doc_u.address
    elif doc_u.state:
        location_text = doc_u.state
    else:
        location_text = "Ubicación no especificada"

    days_mapping = {
        0: "Lunes", 1: "Martes", 2: "Miércoles",
        3: "Jueves", 4: "Viernes", 5: "Sábado", 6: "Domingo"
    }
    
    av_days = []
    try:
        av_days = sorted([a.day_of_week for a in doctor.availabilities])
    except:
        try:
            import sys
            import os
            from sqlalchemy import create_engine
            from sqlalchemy.orm import sessionmaker
            from app.models.doctors import Availability
            
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL)
            Session = sessionmaker(bind=sync_engine)
            with Session() as session:
                avs = session.query(Availability).filter(Availability.doctor_id == doctor.id).all()
                av_days = sorted(list({a.date.weekday() for a in avs}))
                
                if avs:
                    doc_start_time = avs[0].start_time
        except Exception as e:
            print("Error loading availabilities:", e)

    if av_days:
        working_days_str = ", ".join([days_mapping[d] for d in av_days])
        if 'doc_start_time' in locals() and doc_start_time:
            working_days_str += f" (Inicio: {doc_start_time})"
    else:
        working_days_str = "No especificado"

    content = ft.Column([
        ft.Row([
            ft.IconButton(ft.Icons.ARROW_BACK, icon_color=colors.TEXT_DARK, on_click=handle_back),
            ft.Text("Perfil del Doctor", size=20, weight=ft.FontWeight.W_700, color=colors.TEXT_DARK, expand=True)
        ], vertical_alignment=ft.CrossAxisAlignment.CENTER),
        
        ft.Container(height=20),
        
        ft.Row([
            ft.CircleAvatar(
                content=ft.Image(src_base64=b64_data, fit=ft.ImageFit.COVER, border_radius=100) if is_base64 else (ft.Text(initials, size=30, weight=ft.FontWeight.BOLD, color="white") if not avatar_src else None),
                foreground_image_src=None if is_base64 else (avatar_src if avatar_src else None),
                radius=60,
                bgcolor=colors.PRIMARY,
            )
        ], alignment=ft.MainAxisAlignment.CENTER),
        
        ft.Container(height=10),
        
        ft.Text(doc_name, size=24, weight=ft.FontWeight.BOLD, color=colors.PRIMARY, text_align=ft.TextAlign.CENTER),
        ft.Text(spec_val, size=16, weight=ft.FontWeight.W_500, color=colors.SECONDARY, text_align=ft.TextAlign.CENTER),
        
        ft.Container(height=20),
        ft.Divider(height=1, color=colors.INPUT_BORDER),
        ft.Container(height=20),
        
        ft.Text("Biografía", size=18, weight=ft.FontWeight.BOLD, color=colors.TEXT_DARK),
        ft.Container(height=5),
        ft.Text(doctor.bio if doctor.bio else "Este especialista no ha añadido una biografía aún.", size=14, color=colors.TEXT_LIGHT),
        
        ft.Container(height=20),
        
        ft.Row([
            ft.Icon(ft.Icons.LOCATION_ON, color=colors.TEXT_LIGHT, size=20),
            ft.Text(location_text, size=16, color=colors.TEXT_DARK)
        ], spacing=10),
        
        ft.Container(height=10),
        
        ft.Row([
            ft.Icon(ft.Icons.MONETIZATION_ON, color=colors.ACCENT_GREEN, size=20),
            ft.Text(f"Precio de consulta: ${doctor.consultation_fee if doctor.consultation_fee else '50'} USD", size=16, color=colors.TEXT_DARK)
        ], spacing=10),
        
        ft.Container(height=10),
        
        ft.Row([
            ft.Icon(ft.Icons.CALENDAR_MONTH, color=colors.SECONDARY, size=20),
            ft.Text(f"Días de atención: {working_days_str}", size=16, color=colors.TEXT_DARK)
        ], spacing=10),
        
        ft.Container(height=30),
        
        ft.Button(
            "Contactar por WhatsApp",
            icon=ft.Icons.CHAT,
            url=whatsapp_url,
            style=ft.ButtonStyle(
                bgcolor="#25D366", # WhatsApp green
                color="white",
                padding=15,
                shape=ft.RoundedRectangleBorder(radius=10)
            )
        )
    ], scroll=ft.ScrollMode.AUTO, horizontal_alignment=ft.CrossAxisAlignment.CENTER)

    return ft.View(
        route=f"/doctor/{doctor.id}",
        controls=[ft.Container(content=content, padding=20, expand=True)],
        bgcolor=colors.BACKGROUND
    )
