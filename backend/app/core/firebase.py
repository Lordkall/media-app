import firebase_admin
from firebase_admin import credentials
import os

def init_firebase():
    if not firebase_admin._apps:
        # Check if service_account.json exists in the backend directory
        cred_path = os.path.join(os.path.dirname(__file__), "..", "..", "service_account.json")
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print("[FIREBASE] Initialized from service_account.json")
        else:
            # Fallback to environment variable
            firebase_creds = os.environ.get("FIREBASE_CREDENTIALS")
            if firebase_creds:
                import json
                try:
                    cred_dict = json.loads(firebase_creds)
                    cred = credentials.Certificate(cred_dict)
                    firebase_admin.initialize_app(cred)
                    print("[FIREBASE] Initialized from FIREBASE_CREDENTIALS env var")
                except Exception as e:
                    print(f"[FIREBASE ERROR] Could not initialize Firebase: {e}")
            else:
                print("WARNING: service_account.json or FIREBASE_CREDENTIALS not found. Firebase push notifications will not work.")

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
        print(f"[FCM] Error sending message: {e}")
        return False
