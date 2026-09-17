import requests
from bs4 import BeautifulSoup
import urllib3
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential
from app.core.database import async_session_maker
from app.models.exchange_rate import ExchangeRate
from sqlalchemy import select

# Desactivar las advertencias SSL (Inseguro pero necesario para bcv.org.ve si falla su cert)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def extract_bcv_rate() -> float:
    url = "https://www.bcv.org.ve/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    
    # Timeout de 10 segundos para no bloquear la app
    response = requests.get(url, headers=headers, verify=False, timeout=10)
    response.raise_for_status()
    
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # El BCV tiene la tasa del dólar dentro de un div con id 'dolar'
    dolar_div = soup.find('div', id='dolar')
    if not dolar_div:
        raise ValueError("No se pudo encontrar el contenedor del dólar en el HTML")
        
    rate_str = dolar_div.find('strong').text.strip().replace(',', '.')
    return float(rate_str)

async def update_db_with_rate():
    try:
        # Run synchronous requests in thread pool to not block event loop
        new_rate = await asyncio.to_thread(extract_bcv_rate)
        print(f"Tasa BCV extraída exitosamente: {new_rate} VES/USD")
        
        async with async_session_maker() as session:
            result = await session.execute(
                select(ExchangeRate).where(
                    ExchangeRate.moneda_origen == 'USD',
                    ExchangeRate.moneda_destino == 'VES'
                )
            )
            rate_entry = result.scalar_one_or_none()
            
            if not rate_entry:
                rate_entry = ExchangeRate(moneda_origen='USD', moneda_destino='VES', tasa=new_rate)
                session.add(rate_entry)
            else:
                rate_entry.tasa = new_rate
                
            await session.commit()
            
        return new_rate
    except Exception as e:
        print(f"Error fatal extrayendo la tasa BCV (se mantendrá la última tasa guardada): {e}")
        return None
