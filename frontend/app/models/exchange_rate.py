from sqlalchemy import Column, Integer, String, Numeric, DateTime
from sqlalchemy.sql import func
from app.models.base import Base

class ExchangeRate(Base):
    __tablename__ = "tasas_de_cambio"
    
    id = Column(Integer, primary_key=True, index=True)
    moneda_origen = Column(String(3), nullable=False, default='USD')
    moneda_destino = Column(String(3), nullable=False, default='VES')
    tasa = Column(Numeric(10, 4), nullable=False)
    ultima_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
