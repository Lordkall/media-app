import asyncio
import re
from dataclasses import dataclass
from datetime import date, datetime
from zoneinfo import ZoneInfo

import requests
import urllib3
from bs4 import BeautifulSoup
from sqlalchemy import select
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.database import async_session_maker
from app.models.exchange_rate import ExchangeRate

CARACAS = ZoneInfo("America/Caracas")
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
MONTHS = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4,
    "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
    "septiembre": 9, "setiembre": 9, "octubre": 10,
    "noviembre": 11, "diciembre": 12,
}


@dataclass(frozen=True)
class PublishedRate:
    value: float
    effective_date: date


def _parse_effective_date(page_text: str) -> date:
    match = re.search(
        r"fecha\s+valor\s*:?\s*"
        r"(?:(?:lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)\s*,?\s*)?"
        r"(\d{1,2})\s*(?:de\s+)?([a-záéíóú]+)\s*,?\s*(?:de\s+)?(\d{4})",
        page_text,
        flags=re.IGNORECASE,
    )
    if match:
        day, month_name, year = match.groups()
        month = MONTHS.get(month_name.casefold())
        if month:
            return date(int(year), month, int(day))

    numeric = re.search(
        r"fecha\s+valor\s*:?\s*"
        r"(?:(?:lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)\s*,?\s*)?"
        r"(\d{1,2})[/-](\d{1,2})[/-](\d{4})",
        page_text,
        flags=re.IGNORECASE,
    )
    if numeric:
        day, month, year = map(int, numeric.groups())
        return date(year, month, day)
    raise ValueError("La página del BCV no contiene una Fecha Valor reconocible.")


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def extract_bcv_rate() -> PublishedRate:
    try:
        response = requests.get("https://www.bcv.org.ve/", verify=True, timeout=15)
    except requests.exceptions.SSLError:
        print("BCV: error de certificado SSL; se usa el fallback existente.")
        response = requests.get("https://www.bcv.org.ve/", verify=False, timeout=15)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    dollar = soup.find("div", id="dolar")
    if not dollar:
        raise ValueError("No se encontró el bloque oficial del dólar en BCV.")
    strong = dollar.find("strong")
    if not strong:
        raise ValueError("No se encontró el valor oficial del dólar en BCV.")
    rate_text = strong.get_text(strip=True).replace(" ", "")
    if "," in rate_text:
        rate_text = rate_text.replace(".", "").replace(",", ".")
    value = float(rate_text)
    effective_date = _parse_effective_date(soup.get_text(" ", strip=True))
    if value <= 0:
        raise ValueError("La tasa publicada por BCV no es válida.")
    return PublishedRate(value=value, effective_date=effective_date)


async def activate_due_rate(today: date | None = None):
    today = today or datetime.now(CARACAS).date()
    if today.weekday() >= 5:
        return None

    try:
        async with async_session_maker() as session:
            result = await session.execute(
                select(ExchangeRate)
                .where(
                    ExchangeRate.moneda_origen == "USD",
                    ExchangeRate.moneda_destino == "VES",
                )
                .with_for_update()
            )
            rate_entry = result.scalar_one_or_none()
            if not rate_entry:
                return None

            # Older deployments stored a future-valid rate as the active rate.
            # Keep its value but reclassify it as pending until its valid date.
            if (
                rate_entry.fecha_vigencia is not None
                and rate_entry.fecha_vigencia > today
                and rate_entry.fecha_vigencia_pendiente is None
            ):
                rate_entry.tasa_pendiente = rate_entry.tasa
                rate_entry.fecha_vigencia_pendiente = rate_entry.fecha_vigencia
                rate_entry.fecha_vigencia = None
                await session.commit()
                print(
                    "BCV: tasa con vigencia futura migrada a pendiente "
                    f"({rate_entry.fecha_vigencia_pendiente.isoformat()})."
                )

            if (
                rate_entry.tasa_pendiente is None
                or rate_entry.fecha_vigencia_pendiente is None
                or rate_entry.fecha_vigencia_pendiente > today
            ):
                return None

            effective_date = rate_entry.fecha_vigencia_pendiente
            rate_entry.tasa = rate_entry.tasa_pendiente
            rate_entry.fecha_vigencia = effective_date
            rate_entry.tasa_pendiente = None
            rate_entry.fecha_vigencia_pendiente = None
            await session.commit()
            print(
                f"BCV: tasa pendiente activada a las 00:00, "
                f"vigente desde {effective_date.isoformat()}."
            )
            return float(rate_entry.tasa)
    except Exception as exc:
        print(f"Error activando la tasa BCV pendiente: {exc}")
        raise


async def update_db_with_rate():
    today = datetime.now(CARACAS).date()
    if today.weekday() >= 5:
        print("BCV: fin de semana; se conserva la tasa vigente.")
        return None

    try:
        published = await asyncio.to_thread(extract_bcv_rate)
        if published.effective_date < today:
            print(
                "BCV: publicación antigua ignorada "
                f"(vigencia {published.effective_date.isoformat()}, hoy {today.isoformat()})."
            )
            return None

        async with async_session_maker() as session:
            result = await session.execute(
                select(ExchangeRate).where(
                    ExchangeRate.moneda_origen == "USD",
                    ExchangeRate.moneda_destino == "VES",
                )
            )
            rate_entry = result.scalar_one_or_none()
            is_new_entry = rate_entry is None
            if not rate_entry:
                # Bootstrap an empty table; there is no prior active rate to retain.
                rate_entry = ExchangeRate(
                    moneda_origen="USD",
                    moneda_destino="VES",
                    tasa=published.value,
                    fecha_vigencia=(
                        published.effective_date
                        if published.effective_date <= today
                        else today
                    ),
                )
                session.add(rate_entry)

            # Reclassify a future active date left behind by the previous
            # implementation before comparing this official publication.
            if (
                rate_entry.fecha_vigencia is not None
                and rate_entry.fecha_vigencia > today
                and rate_entry.fecha_vigencia_pendiente is None
            ):
                rate_entry.tasa_pendiente = rate_entry.tasa
                rate_entry.fecha_vigencia_pendiente = rate_entry.fecha_vigencia
                rate_entry.fecha_vigencia = None

            if (
                not is_new_entry
                and rate_entry.fecha_vigencia is not None
                and published.effective_date <= rate_entry.fecha_vigencia
            ):
                return float(rate_entry.tasa)

            if published.effective_date <= today:
                # This publication is already in force (for example after a
                # late service restart); activate only on a business date.
                rate_entry.tasa = published.value
                rate_entry.fecha_vigencia = published.effective_date
                if (
                    rate_entry.fecha_vigencia_pendiente is not None
                    and rate_entry.fecha_vigencia_pendiente <= published.effective_date
                ):
                    rate_entry.tasa_pendiente = None
                    rate_entry.fecha_vigencia_pendiente = None
            elif (
                rate_entry.fecha_vigencia_pendiente is None
                or published.effective_date >= rate_entry.fecha_vigencia_pendiente
            ):
                rate_entry.tasa_pendiente = published.value
                rate_entry.fecha_vigencia_pendiente = published.effective_date
            await session.commit()

        if published.effective_date > today:
            print(
                f"Tasa BCV guardada como pendiente: {published.value} VES/USD, "
                f"se activará el {published.effective_date.isoformat()} a las 00:00."
            )
            return None
        print(
            f"Tasa BCV activada: {published.value} VES/USD, "
            f"vigente desde {published.effective_date.isoformat()}."
        )
        return published.value
    except Exception as exc:
        print(f"Error obteniendo tasa BCV; se conserva la última tasa guardada: {exc}")
        return None
