
@router.get("/me/clinic-invitations")
async def get_clinic_invitations(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    doc = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    if not doc or not doc.requested_clinic_id or doc.clinic_join_status != "invited":
        return []
        
    from app.models.clinics import Clinic
    clinic = await db.get(Clinic, doc.requested_clinic_id)
    if not clinic:
        return []
        
    clinic_user = await db.get(User, clinic.user_id)
    
    return [{
        "clinic_id": clinic.id,
        "name": clinic_user.first_name,
        "address": clinic_user.address,
        "avatar_url": clinic_user.avatar_url
    }]

@router.post("/me/clinic-invitations/{clinic_id}/{action}")
async def resolve_clinic_invitation(
    clinic_id: int, action: str,
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="Solo los doctores pueden responder invitaciones")
        
    doc = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id).with_for_update())
    if not doc or doc.requested_clinic_id != clinic_id or doc.clinic_join_status != "invited":
        raise HTTPException(status_code=404, detail="Invitación no encontrada")
        
    from app.models.clinics import Clinic
    clinic = await db.get(Clinic, clinic_id)
    
    if action == "accept":
        from app.core.clinic_access import active_clinic_subscription, clinic_has_capacity
        subscription = await active_clinic_subscription(db, clinic.id)
        if not subscription or not await clinic_has_capacity(db, clinic.id, subscription.plan):
            raise HTTPException(status_code=409, detail="La clínica ya no tiene capacidad o plan activo")
            
        doc.clinic_id = clinic.id
        doc.requested_clinic_id = None
        doc.clinic_join_status = "approved"
        
        from app.models.notifications import Notification, NotificationType
        prefix = "La Dra." if current_user.gender in ["Femenino", "Femenina"] else "El Dr."
        db.add(Notification(
            user_id=clinic.user_id,
            type=NotificationType.CLINIC_JOIN_APPROVED,
            title="Invitación aceptada",
            message=f"{prefix} {current_user.first_name} {current_user.last_name} ha aceptado tu invitación y se ha unido a tu clínica."
        ))
        msg = "Invitación aceptada"
    elif action == "reject":
        doc.requested_clinic_id = None
        doc.clinic_join_status = None
        msg = "Invitación rechazada"
    else:
        raise HTTPException(status_code=400, detail="Acción no válida")
        
    await db.commit()
    return {"message": msg}
