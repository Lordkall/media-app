import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/web_footer.dart';

const String _privacyMarkdown = """
En **Salud Now**, operando en **Venezuela**, actuamos como intermediarios tecnológicos a través de nuestra plataforma digital. Nuestro compromiso es garantizar la máxima privacidad y el cumplimiento de las normativas de protección de datos aplicables.

### 1. Definiciones previas
- **Plataforma**: La aplicación web y móvil de agendamiento.
- **Usuario**: Cualquier persona registrada (Paciente, Profesional o Clínica).

### 2. Descargo de Responsabilidad Médico y Naturaleza del Servicio
La aplicación **SaludNow**, operada por la entidad mercantil **SaludNow, C.A.**, funciona exclusivamente como una herramienta tecnológica e intermediaria para la gestión de citas y conexión entre usuarios y prestadores de salud. Se establece de forma explícita e inequívoca que la aplicación **no es un dispositivo médico, no emite diagnósticos, no indica tratamientos** y su uso **no sustituye bajo ninguna circunstancia el criterio, la evaluación o el consejo de un profesional de la salud certificado**. Ante cualquier sospecha clínica, duda médica o emergencia, el usuario debe consultar a un médico calificado o acudir a los servicios locales de urgencia.

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
Cualquier controversia será resuelta bajo las leyes de **Venezuela**.

Para consultas: **saludnowsite@gmail.com**
""";

const String _cookiesMarkdown = """
### 1. Introducción y alcance
En **Salud Now** operada por **Salud Now C.A**, valoramos tu privacidad. Esta política explica cómo usamos cookies, Local Storage, SDKs móviles y tokens en nuestra plataforma.

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

Dudas de privacidad: **saludnowsite@gmail.com**
""";

const String _termsMarkdown = """
### 1. Aceptación de los Términos y Registro
Al registrarte en **Salud Now** de **Salud Now C.A**, aceptas estos términos. Debes ser mayor de edad o contar con representación legal para agendar.

### 2. Glosario y Definiciones
- **Paciente**: Quien busca agendar servicios.
- **Médico/Especialista**: Profesional independiente.
- **Clínica/Aliado**: Centro con múltiples consultorios.
- **No-Show**: Inasistencia sin aviso previo.

### 3. Descargo de Responsabilidad Médico
La aplicación móvil y plataforma web **SaludNow**, operada por la entidad mercantil **SaludNow, C.A.**, funciona exclusivamente como una herramienta tecnológica e intermediaria de conexión y gestión de citas entre usuarios y profesionales o entidades de salud independientes. 

Se establece de forma explícita e inequívoca que la aplicación **SaludNow no es un dispositivo médico ni software como dispositivo médico (SaMD)**, no emite diagnósticos clínicos, no prescribe ni indica tratamientos terapéuticos o farmacológicos, y no efectúa actos de medicina directa. Su uso **no sustituye bajo ninguna circunstancia el criterio, la evaluación presencial, el juicio diagnóstico o el consejo de un profesional de la salud certificado** y habilitado para el ejercicio de la medicina. 

Ante cualquier duda sobre un cuadro de salud, sospecha de enfermedad o situación que implique riesgo para la salud o la vida, el usuario debe consultar inmediatamente a un médico calificado o dirigirse a un centro de urgencias médicas local. **SaludNow no es un servicio de atención de emergencias ni urgencias médicas**.

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
Se aplicarán las leyes de **Venezuela**. Se privilegiará la mediación como paso previo obligatorio a cualquier vía judicial.

Contacto legal: **saludnowsite@gmail.com**
""";

class _BaseLegalScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String markdownData;

  const _BaseLegalScreen({
    required this.title,
    required this.subtitle,
    required this.markdownData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0056B3),
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Image.asset(
          'assets/logo_white.png',
          height: 48,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.health_and_safety, color: Colors.white, size: 36),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    height: 1.1,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  alignment: Alignment.centerLeft,
                  child: MarkdownBody(
                    data: markdownData,
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black, height: 1.5),
                      p: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.6),
                      listBullet: const TextStyle(color: Color(0xFF374151)),
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Padding for FAB
                if (kIsWeb) const WebFooter(),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: () {},
              backgroundColor: const Color(0xFF0056B3),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _BaseLegalScreen(
      title: 'Política de\nPrivacidad',
      subtitle: 'Conoce la Política de Privacidad\nde Salud Now.',
      markdownData: _privacyMarkdown,
    );
  }
}

class CookiesPolicyScreen extends StatelessWidget {
  const CookiesPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _BaseLegalScreen(
      title: 'Política de\nCookies',
      subtitle: 'Conoce la Política de Cookies\nde Salud Now.',
      markdownData: _cookiesMarkdown,
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _BaseLegalScreen(
      title: 'Términos y\nCondiciones',
      subtitle: 'Conoce los términos y condiciones del\nuso de Salud Now.',
      markdownData: _termsMarkdown,
    );
  }
}
