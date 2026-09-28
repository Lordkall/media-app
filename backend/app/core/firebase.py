import firebase_admin
from firebase_admin import credentials
import base64
import json
import os

def init_firebase():
    if firebase_admin._apps:
        return

    default_cred_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "service_account.json")
    )
    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or default_cred_path
    try:
        if os.path.isfile(cred_path):
            credential = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(credential)
            print("[FIREBASE] Admin SDK initialized from service-account file")
            return

        raw_credentials = os.environ.get("FIREBASE_CREDENTIALS")
        if raw_credentials:
            try:
                credential_data = json.loads(raw_credentials)
            except json.JSONDecodeError:
                # Accept base64-encoded service-account JSON in Railway variables too.
                credential_data = json.loads(base64.b64decode(raw_credentials).decode("utf-8"))
            credential = credentials.Certificate(credential_data)
            firebase_admin.initialize_app(credential)
            print("[FIREBASE] Admin SDK initialized from FIREBASE_CREDENTIALS")
            return

        encoded_credentials = os.environ.get("FIREBASE_CREDENTIALS_BASE64")
        if encoded_credentials:
            credential_data = json.loads(base64.b64decode(encoded_credentials).decode("utf-8"))
            credential = credentials.Certificate(credential_data)
            firebase_admin.initialize_app(credential)
            print("[FIREBASE] Admin SDK initialized from FIREBASE_CREDENTIALS_BASE64")
            return

        print("[FIREBASE ERROR] Admin SDK credentials are missing; push notifications are disabled")
    except Exception as error:
        # Never print credential contents or access tokens to deployment logs.
        print(f"[FIREBASE ERROR] Admin SDK initialization failed ({type(error).__name__})")

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    if not firebase_admin._apps:
        print("[FCM] Push skipped: Firebase Admin is not initialized")
        return False
        
    from firebase_admin import messaging
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data={str(key): str(value) for key, value in (data or {}).items()},
        token=token,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="salud_now_notifications_v2",
                sound="default",
            ),
        ),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", content_available=True)
            ),
        ),
    )
    
    try:
        response = messaging.send(message)
        print(f"[FCM] Successfully sent message: {response}")
        return True
    except Exception as e:
        # Firebase exceptions can contain device registration tokens; log only
        # their type and keep secrets out of Railway logs.
        code = getattr(e, "code", None)
        suffix = f", code={code}" if code else ""
        print(f"[FCM] Error sending message ({type(e).__name__}{suffix})")
        return False
