import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const String _privacyMarkdown = """
# Política de Privacidad y Tratamiento de Datos

En **[Nombre de la Empresa]**, operando en **[País/Jurisdicción]**, actuamos como intermediarios tecnológicos a través de nuestra plataforma digital. Nuestro compromiso es garantizar la máxima privacidad y el cumplimiento de las normativas de protección de datos aplicables.

### 1. Definiciones previas
- **Plataforma**: La aplicación web y móvil de agendamiento.
- **Usuario**: Cualquier persona registrada (Paciente, Profesional o Clínica).

### 2. Naturaleza del servicio
Actuamos exclusivamente como intermediario tecnológico para la gestión de citas y conexión. **NO** prestamos servicios médicos ni emitimos diagnósticos. Ante cualquier emergencia, el paciente debe acudir a los servicios locales de urgencia.

### 3. Registro, veracidad y seguridad
Todo usuario debe registrarse con información veraz. Es su responsabilidad custodiar sus credenciales. Los Doctores y Clínicas deben proveer documentación comprobatoria de sus licencias.

### 4. Agendamiento y Cancelaciones
- **Pacientes**: Deben notificar cancelaciones con el tiempo estipulado. Inasistencias recurrentes ("no-show") podrán generar sanciones.
- **Profesionales**: Deben cumplir con su disponibilidad. Las cancelaciones deben hacerse de forma excepcional.

### 5. Pagos y Tarifas
La Plataforma facilita pagos y retiene comisiones por el uso del software según los planes adquiridos.

### 6. Deslinde de responsabilidad médica
La responsabilidad sobre el acto médico, diagnósticos y tratamientos recae **exclusivamente** sobre el profesional de la salud.

### 7. Privacidad, consentimiento y datos sensibles
Tratamos los historiales y notas médicas con los más altos estándares de seguridad y cifrado. Todos los profesionales adscritos asumen el deber de secreto profesional.

### 8. Uso indebido
Queda estrictamente prohibida la ingeniería inversa, scraping, o cualquier uso fraudulento de la plataforma.

### 9. Suspensión de cuentas
Nos reservamos el derecho de suspender cuentas por fraude, mala praxis administrativa o quejas recurrentes.

### 10. Modificaciones
Notificaremos cambios a esta política por correo. El uso continuado implica aceptación.

### 11. Ley aplicable
Cualquier controversia será resuelta bajo las leyes de **[País/Jurisdicción]**.

Para consultas: **[Correo de Soporte]**
""";

const String _cookiesMarkdown = """
# Política de Cookies y Tecnologías de Almacenamiento Local

### 1. Introducción y alcance
En **[Nombre de la App]** operada por **[Razón Social]**, valoramos tu privacidad. Esta política explica cómo usamos cookies, Local Storage, SDKs móviles y tokens en nuestra plataforma.

### 2. ¿Qué son estas tecnologías?
Son pequeños archivos de datos o identificadores almacenados en tu navegador o dispositivo móvil que permiten recordar tus preferencias, mantener tu sesión activa de forma segura y analizar el rendimiento general.

### 3. Tipos de tecnologías que utilizamos
| Categoría | Propósito |
|---|---|
| **Técnicas / Necesarias** | Mantener sesiones (paciente/doctor), prevenir ataques CSRF y seguridad. |
| **Preferencias** | Recordar idioma, zona horaria y filtros de búsqueda. |
| **Analíticas** | Métricas agregadas anónimas sobre fallos de la app y fluidez de uso. |
| **Funcionales** | Tokens push para enviar recordatorios de citas. |

### 4. Garantía especial sobre datos de salud
**NO** utilizamos cookies de rastreo publicitario de terceros (como Meta Pixel o Google Ads) en pantallas donde se procese información médica sensible, diagnósticos, recetas o historiales clínicos.

### 5. Cookies propias vs. de terceros
Utilizamos proveedores estrictamente necesarios como pasarelas de pago cifradas y mapas interactivos. No vendemos datos a corredores de datos.

### 6. ¿Cómo gestionar o desactivar las cookies?
- **Web**: Puedes gestionar esto desde Configuración > Privacidad en Chrome, Safari o Firefox.
- **Móvil**: Puedes restringir identificadores desde los Ajustes del sistema (iOS/Android).
*Aviso*: Deshabilitar cookies técnicas impedirá iniciar sesión o agendar citas.

### 7. Periodo de conservación
Las cookies de sesión se eliminan al cerrar el navegador. Las persistentes (ej. preferencias) tienen una duración máxima de 12 meses.

### 8. Actualizaciones
Cualquier cambio sustancial será notificado vía notificación push o correo.

Dudas de privacidad: **[Correo de Privacidad]**
""";

const String _termsMarkdown = """
# Términos y Condiciones Generales y Particulares de Uso

### 1. Aceptación de los Términos y Registro
Al registrarte en **[Nombre de la Plataforma]** de **[Razón Social]**, aceptas estos términos. Debes ser mayor de edad o contar con representación legal para agendar.

### 2. Glosario y Definiciones
- **Paciente**: Quien busca agendar servicios.
- **Médico/Especialista**: Profesional independiente.
- **Clínica/Aliado**: Centro con múltiples consultorios.
- **No-Show**: Inasistencia sin aviso previo.

### 3. Naturaleza del Servicio y Deslinde de Responsabilidad Médica
Somos un **intermediario tecnológico**. NO prestamos servicios de salud, ni atendemos urgencias.
**ADVERTENCIA DE EMERGENCIA**: En caso de riesgo vital, contacte a los servicios de auxilio locales.

### 4. Condiciones Específicas para Pacientes
- La información suministrada debe ser veraz.
- Penalizaciones o restricciones aplicarán ante casos repetitivos de *No-Show*.

### 5. Condiciones para Médicos y Especialistas
- Obligación legal de mantener licencias médicas activas.
- Responsabilidad civil, penal y administrativa exclusiva sobre cualquier acto médico realizado.

### 6. Condiciones para Clínicas
- Responsabilidad y solidaridad institucional sobre los doctores vinculados a su cuenta.
- Obligación de mantener la agenda de sus profesionales actualizada.

### 7. Pagos y Reembolsos
Las tarifas por servicio tecnológico se cobran al realizar reservas según corresponda. Los reembolsos se evalúan de acuerdo con la política de cancelación de cada profesional.

### 8. Protección de Datos y Secreto Médico
El expediente clínico pertenece al paciente y es custodiado bajo altos estándares criptográficos, obligando a los doctores al secreto profesional.

### 9. Conducta Prohibida
Se prohíbe la suplantación, lenguaje abusivo o el uso de software automatizado para alterar la plataforma.

### 10. Suspensión de Cuentas
Nos reservamos el derecho de bloquear cuentas inmediatamente por ejercicio ilegal de la medicina, fraude o comportamiento abusivo.

### 11. Modificaciones
Se notificarán por la app o correo. El uso continuará implicando aceptación.

### 12. Resolución de Conflictos
Se aplicarán las leyes de **[País/Ciudad]**. Se privilegiará la mediación como paso previo obligatorio a cualquier vía judicial.

Contacto legal: **[Correo de Contacto Legal]**
""";

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Privacidad')),
      body: const Markdown(data: _privacyMarkdown),
    );
  }
}

class CookiesPolicyScreen extends StatelessWidget {
  const CookiesPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Cookies')),
      body: const Markdown(data: _cookiesMarkdown),
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Condiciones')),
      body: const Markdown(data: _termsMarkdown),
    );
  }
}
