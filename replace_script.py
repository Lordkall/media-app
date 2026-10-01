import sys

with open('backend/app/api/v1/endpoints/admin.py', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(
    '        (Subscription.doctor_id == Doctor.id) & (Subscription.status == SubscriptionStatus.ACTIVE)',
    '        or_((Subscription.doctor_id == Doctor.id) & (Subscription.status == SubscriptionStatus.ACTIVE), (Doctor.clinic_id.isnot(None)) & (Doctor.clinic_join_status == \'approved\') & (Subscription.clinic_id == Doctor.clinic_id) & (Subscription.status == SubscriptionStatus.ACTIVE))'
)

text = text.replace(
    '"is_vip": sub is not None and sub.plan == SubscriptionPlan.SPONSORED,',
    '"is_vip": sub is not None and sub.plan in (SubscriptionPlan.SPONSORED, SubscriptionPlan.CLINIC_VIP),'
)

with open('backend/app/api/v1/endpoints/admin.py', 'w', encoding='utf-8') as f:
    f.write(text)

with open('backend/app/api/v1/endpoints/search.py', 'r', encoding='utf-8') as f:
    text2 = f.read()

text2 = text2.replace(
    '        (Subscription.doctor_id == Doctor.id) & (Subscription.status == SubscriptionStatus.ACTIVE)',
    '        or_((Subscription.doctor_id == Doctor.id) & (Subscription.status == SubscriptionStatus.ACTIVE), (Doctor.clinic_id.isnot(None)) & (Doctor.clinic_join_status == \'approved\') & (Subscription.clinic_id == Doctor.clinic_id) & (Subscription.status == SubscriptionStatus.ACTIVE))'
)

text2 = text2.replace(
    '"is_vip": sub is not None and sub.plan == SubscriptionPlan.SPONSORED,',
    '"is_vip": sub is not None and sub.plan in (SubscriptionPlan.SPONSORED, SubscriptionPlan.CLINIC_VIP),'
)

with open('backend/app/api/v1/endpoints/search.py', 'w', encoding='utf-8') as f:
    f.write(text2)
