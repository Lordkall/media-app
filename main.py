import os
import sys

# Añadir la carpeta backend al sys.path para resolución de módulos
backend_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend")
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Cambiar el directorio de trabajo a backend para que static/ y uploads/ se resuelvan correctamente
os.chdir(backend_dir)

# Exportar app para que uvicorn main:app y Railpack lo detecten automáticamente
from app.main import app

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
