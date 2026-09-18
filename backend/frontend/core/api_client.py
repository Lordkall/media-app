import requests
from requests.exceptions import RequestException
from core.config import API_BASE_URL as BASE_URL

class APIClient:
    def __init__(self):
        self.session = requests.Session()
        self.token = None

    def set_token(self, token: str):
        self.token = token
        self.session.headers.update({"Authorization": f"Bearer {token}"})
        
    def clear_token(self):
        self.token = None
        if "Authorization" in self.session.headers:
            del self.session.headers["Authorization"]

    def login(self, email: str, password: str):
        response = self.session.post(
            f"{BASE_URL}/auth/login",
            data={"username": email, "password": password}
        )
        response.raise_for_status()
        data = response.json()
        self.set_token(data["access_token"])
        return data

    def post(self, endpoint: str, json: dict = None, data: dict = None):
        response = self.session.post(f"{BASE_URL}{endpoint}", json=json, data=data)
        response.raise_for_status()
        return response.json()

    def get(self, endpoint: str, params: dict = None):
        response = self.session.get(f"{BASE_URL}{endpoint}", params=params)
        response.raise_for_status()
        return response.json()

    def put(self, endpoint: str, json: dict = None, data: dict = None):
        response = self.session.put(f"{BASE_URL}{endpoint}", json=json, data=data)
        response.raise_for_status()
        return response.json()

    def delete(self, endpoint: str, params: dict = None):
        response = self.session.delete(f"{BASE_URL}{endpoint}", params=params)
        response.raise_for_status()
        return response.json()

# Instancia global del cliente para ser usada por toda la aplicación
client = APIClient()
