
@router.get("/me/search-doctors")
async def search_doctors_for_invite(
    name: str = Query(""), state: str = Query(""),
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    clinic = await _owned_clinic(current_user, db)
    query = select(Doctor, User).join(User, Doctor.user_id == User.id).where(
        Doctor.clinic_id.is_(None),
        Doctor.clinic_join_status.is_not("pending"),
        Doctor.clinic_join_status.is_not("invited")
    )
    if name:
        query = query.where(func.concat(User.first_name, ' ', User.last_name).ilike(f"%{name}%"))
    if state:
        query = query.where(User.state == state)
    
    rows = await db.execute(query.limit(20))
    return [{
        "doctor_id": doc.id,
        "name": f"{usr.first_name} {usr.last_name}",
        "specialties": doc.specialties or [],
        "avatar_url": usr.avatar_url,
        "state": usr.state
    } for doc, usr in rows]

@router.post("/me/invite-doctor/{doctor_id}")
async def invite_doctor(
    doctor_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    clinic = await _owned_clinic(current_user, db)
    doctor = await db.scalar(select(Doctor).where(Doctor.id == doctor_id).with_for_update())
    if not doctor or doctor.clinic_id is not None or doctor.clinic_join_status in ["pending", "invited"]:
        raise HTTPException(status_code=400, detail="El doctor no está disponible para invitaciones")
        
    subscription = await active_clinic_subscription(db, clinic.id)
    if not subscription or not await clinic_has_capacity(db, clinic.id, subscription.plan):
        raise HTTPException(status_code=409, detail="La clínica no tiene capacidad o plan activo")
        
    doctor.requested_clinic_id = clinic.id
    doctor.clinic_join_status = "invited"
    
    from app.models.notifications import Notification, NotificationType
    db.add(Notification(
        user_id=doctor.user_id,
        type=NotificationType.CLINIC_JOIN_REQUEST,
        title="Invitación de clínica",
        message=f"La clínica {current_user.first_name} te ha invitado a unirte a su red.",
    ))
    await db.commit()
    return {"message": "Invitación enviada"}
