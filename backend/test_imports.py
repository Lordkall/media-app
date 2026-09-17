import sys
import os

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.append(base_path)

try:
    from frontend.views.register import RegisterView
    from frontend.views.admin_subscriptions import AdminSubscriptionsView
    from frontend.views.subscribe import SubscribeView
    from frontend.views.browse_doctors import BrowseDoctorsView
    print("All modules imported successfully.")
except Exception as e:
    print(f"Error importing modules: {e}")
