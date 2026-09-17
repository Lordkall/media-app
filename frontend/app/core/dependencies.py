from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.models.users import User, RoleEnum
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan

# Mock dependency just for context resolution. Real app would have a valid get_current_user and get_db
def get_db():
    pass

def get_current_user():
    pass

def get_vip_doctor_context(
    current_user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
) -> int:
    """
    Verifica que el usuario (Doctor o Asistente) pertenezca a un ecosistema VIP.
    Retorna el `doctor_id` sobre el cual debe operar.
    """
    # 1. Determinar el doctor_id a evaluar
    if current_user.role == RoleEnum.DOCTOR:
        if not current_user.doctor_profile:
            raise HTTPException(status_code=400, detail="Perfil de doctor no encontrado.")
        target_doctor_id = current_user.doctor_profile.id
    elif current_user.role == RoleEnum.ASSISTANT:
        target_doctor_id = current_user.linked_doctor_id
        if not target_doctor_id:
            raise HTTPException(status_code=400, detail="Asistente sin doctor vinculado.")
    else:
        raise HTTPException(status_code=403, detail="Rol no autorizado para operaciones médicas.")

    # 2. Verificar suscripción VIP (SPONSORED)
    active_sub = db.execute(
        select(Subscription).where(
            Subscription.doctor_id == target_doctor_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.plan == SubscriptionPlan.SPONSORED
        )
    ).scalar_one_or_none()

    if not active_sub:
        if current_user.role == RoleEnum.ASSISTANT:
            # Deshabilitar acceso del asistente por falta de VIP
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, 
                detail="Acceso denegado: El doctor vinculado no posee una suscripción VIP activa."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Esta funcionalidad requiere Plan VIP."
            )
            
    return target_doctor_id
