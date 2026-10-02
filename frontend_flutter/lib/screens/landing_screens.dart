import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import '../core/api_client.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/profile_avatar.dart';

class ForUsersScreen extends StatelessWidget {
  const ForUsersScreen({super.key});

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 800 ? 100 : 24,
        vertical: 80,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B2545), // Dark blue background for hero fallback
        image: DecorationImage(
          image: AssetImage('assets/doctor_patients_bg.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestiona tus citas y tu salud de manera eficiente',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Reserva con los mejores especialistas, accede a tu historial médico y recibe recordatorios. Regístrate o descarga nuestra app y comienza a cuidar de ti.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.apple, color: Colors.white),
                label: const Text('App Store', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.android, color: Colors.white),
                label: const Text('Google Play', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 80,
      ),
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Somos la alternativa más accesible para que gestiones tu salud hoy.',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 48),
          GridView.count(
            crossAxisCount: isDesktop ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: isDesktop ? 1.8 : 1.2,
            children: [
              _buildFeatureCard(
                icon: Icons.calendar_month,
                title: 'Agenda tus citas fácilmente',
                text: 'Encuentra al especialista que necesitas y agenda tu consulta en 3 minutos. Descarga nuestra app, regístrate y comienza.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.health_and_safety,
                title: 'Conoce nuestras clínicas aliadas',
                text: 'Traemos muchas opciones de salud para ti. Desde tus clínicas y doctores favoritos hasta laboratorios y farmacias.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.star,
                title: 'Amplía tus beneficios',
                text: 'Al utilizar nuestra plataforma accederás a funciones VIP, historiales compartidos y descuentos especiales.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.handshake,
                title: 'Estamos siempre contigo',
                text: 'Te enviaremos recordatorios para que nunca faltes a una cita y puedas mantener tu salud al día.',
                color: const Color(0xFF0056B3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (kIsWeb) const WebHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroSection(context),
                  _buildFeaturesSection(context),
                  if (kIsWeb) const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AlliedDoctorsScreen extends StatefulWidget {
  const AlliedDoctorsScreen({super.key});

  @override
  State<AlliedDoctorsScreen> createState() => _AlliedDoctorsScreenState();
}

class _AlliedDoctorsScreenState extends State<AlliedDoctorsScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await ApiClient.get('/doctors/public');
      List<Map<String, dynamic>> finalDoctors = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        finalDoctors = data.map((e) => e as Map<String, dynamic>).toList();
      }
      
      if (finalDoctors.length < 8) {
        final fallbacks = _getFallbacks();
        fallbacks.shuffle(Random());
        for (var fallback in fallbacks) {
          if (finalDoctors.length >= 8) break;
          if (!finalDoctors.any((d) => d['name'] == fallback['name'])) {
            finalDoctors.add(fallback);
          }
        }
      }
      
      finalDoctors.shuffle(Random());
      
      setState(() {
        _doctors = finalDoctors.take(8).toList();
        _isLoading = false;
      });
    } catch (e) {
      _useFallbackDoctors();
    }
  }

  List<Map<String, dynamic>> _getFallbacks() {
    return [
      {'name': 'Dr. Carlos Mendoza', 'specialty': 'Cardiología', 'avatar_url': 'assets/avatars/doc_1.jpg'},
      {'name': 'Dra. María Fernanda López', 'specialty': 'Pediatría', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. José Ramírez', 'specialty': 'Traumatología', 'avatar_url': 'assets/avatars/doc_3.jpg'},
      {'name': 'Dra. Elena Silva', 'specialty': 'Ginecología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. Luis Hernández', 'specialty': 'Oftalmología', 'avatar_url': 'assets/avatars/doc_1.jpg'},
      {'name': 'Dra. Ana González', 'specialty': 'Dermatología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. Miguel Castillo', 'specialty': 'Medicina Interna', 'avatar_url': 'assets/avatars/doc_3.jpg'},
      {'name': 'Dra. Sofía Rojas', 'specialty': 'Neurología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
    ];
  }

  void _useFallbackDoctors() {
    final fallbacks = [
      {'name': 'Dr. Carlos Mendoza', 'specialty': 'Cardiología', 'avatar_url': 'assets/avatars/doc_1.jpg'},
      {'name': 'Dra. María Fernanda López', 'specialty': 'Pediatría', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. José Ramírez', 'specialty': 'Traumatología', 'avatar_url': 'assets/avatars/doc_3.jpg'},
      {'name': 'Dra. Elena Silva', 'specialty': 'Ginecología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. Luis Hernández', 'specialty': 'Oftalmología', 'avatar_url': 'assets/avatars/doc_1.jpg'},
      {'name': 'Dra. Ana González', 'specialty': 'Dermatología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
      {'name': 'Dr. Miguel Castillo', 'specialty': 'Medicina Interna', 'avatar_url': 'assets/avatars/doc_3.jpg'},
      {'name': 'Dra. Sofía Rojas', 'specialty': 'Neurología', 'avatar_url': 'assets/avatars/doc_2.jpg'},
    ];
    fallbacks.shuffle(Random());
    setState(() {
      _doctors = fallbacks.take(8).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (kIsWeb) const WebHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroSection(context),
                  _buildDoctorsGrid(context),
                  if (kIsWeb) const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 80,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B2545),
        image: DecorationImage(
          image: AssetImage('assets/allied_doctors_bg.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué especialistas puedes\nencontrar en Salud Now?',
            style: TextStyle(
              fontSize: isDesktop ? 48 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Encuentra a los mejores médicos de tu ciudad.\nAgenda consultas presenciales o virtuales y recibe atención de primera calidad.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              _buildStoreButton(Icons.apple, 'App Store'),
              const SizedBox(width: 16),
              _buildStoreButton(Icons.android, 'Google Play'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsGrid(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 80,
      ),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'Agenda tu cita con nuestros aliados',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ahora también puedes ubicar y agendar a especialistas de confianza. Entra, busca y elige tu médico en la plataforma.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_doctors.isEmpty)
            const Center(child: Text('No hay doctores disponibles por el momento.'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 500 ? 2 : 1),
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 0.85,
              ),
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                return DoctorHoverCard(doctor: _doctors[index]);
              },
            ),
        ],
      ),
    );
  }
}

class DoctorHoverCard extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const DoctorHoverCard({super.key, required this.doctor});

  @override
  State<DoctorHoverCard> createState() => _DoctorHoverCardState();
}

class _DoctorHoverCardState extends State<DoctorHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doctor;
    final String? avatarUrl = doc['avatar_url'] as String?;
    final String name = doc['name']?.toString() ?? '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _isHovered
                  ? const Color(0xFF0056B3)
                  : Colors.grey.withOpacity(0.2)),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8))
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              imageUrl: avatarUrl,
              size: _isHovered ? 110 : 90,
              fallbackRole: 'doctor',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: _isHovered ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              doc['specialty']?.toString() ?? 'Especialista',
              style: TextStyle(
                fontSize: _isHovered ? 16 : 14,
                color: const Color(0xFF0056B3),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AlliedClinicsScreen extends StatefulWidget {
  const AlliedClinicsScreen({super.key});

  @override
  State<AlliedClinicsScreen> createState() => _AlliedClinicsScreenState();
}

class _AlliedClinicsScreenState extends State<AlliedClinicsScreen> {
  List<Map<String, dynamic>> _clinics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinics();
  }

  Future<void> _fetchClinics() async {
    try {
      final response = await ApiClient.get('/clinics/public');
      List<Map<String, dynamic>> fetched = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        fetched = data.map((e) => e as Map<String, dynamic>).toList();
      }
      if (fetched.length < 8) {
        final fallbacks = _getFallbackClinics();
        fallbacks.shuffle(Random());
        for (var f in fallbacks) {
          if (fetched.length >= 8) break;
          if (!fetched.any((c) => c['name'] == f['name'])) fetched.add(f);
        }
      }
      fetched.shuffle(Random());
      setState(() {
        _clinics = fetched.take(8).toList();
        _isLoading = false;
      });
    } catch (_) {
      final fallbacks = _getFallbackClinics();
      fallbacks.shuffle(Random());
      setState(() {
        _clinics = fallbacks.take(8).toList();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackClinics() {
    return [
      {'name': 'Clínica Sanitas', 'city': 'Caracas', 'type': 'Hospital General', 'avatar_url': null},
      {'name': 'Centro Médico Docente', 'city': 'Valencia', 'type': 'Clínica Especializada', 'avatar_url': null},
      {'name': 'Hospital de Clínicas', 'city': 'Maracaibo', 'type': 'Hospital General', 'avatar_url': null},
      {'name': 'Policlínica Metropolitana', 'city': 'Caracas', 'type': 'Centro Quirúrgico', 'avatar_url': null},
      {'name': 'Clínica El Ávila', 'city': 'Caracas', 'type': 'Clínica Especializada', 'avatar_url': null},
      {'name': 'Centro Médico de Caracas', 'city': 'Caracas', 'type': 'Hospital General', 'avatar_url': null},
      {'name': 'Clínica La Viña', 'city': 'Valencia', 'type': 'Clínica Especializada', 'avatar_url': null},
      {'name': 'Clínica Paraíso', 'city': 'Maracaibo', 'type': 'Maternidad', 'avatar_url': null},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (kIsWeb) const WebHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroSection(context),
                  _buildClinicsGrid(context),
                  if (kIsWeb) const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 80,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B2545),
        image: DecorationImage(
          image: AssetImage('assets/allied_clinics_bg.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Centros Médicos\nAliados a Salud Now',
            style: TextStyle(
              fontSize: isDesktop ? 48 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Encuentra las mejores clínicas y hospitales de tu ciudad.\nDescubre dónde puedes atenderte con la mejor calidad.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicsGrid(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF0056B3))),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 80,
      ),
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            'Red de Clínicas Aliadas',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Contamos con una amplia red de clínicas para garantizar tu atención médica.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 500 ? 2 : 1),
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 0.85,
            ),
            itemCount: _clinics.length,
            itemBuilder: (context, index) =>
                ClinicHoverCard(clinic: _clinics[index]),
          ),
        ],
      ),
    );
  }
}

class ClinicHoverCard extends StatefulWidget {
  final Map<String, dynamic> clinic;
  const ClinicHoverCard({super.key, required this.clinic});

  @override
  State<ClinicHoverCard> createState() => _ClinicHoverCardState();
}

class _ClinicHoverCardState extends State<ClinicHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final clinic = widget.clinic;
    final String name = clinic['name']?.toString() ?? 'Clínica';
    final String type = clinic['type']?.toString() ?? 'Clínica General';
    final String city = clinic['city']?.toString() ?? 'Venezuela';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0xFF0056B3) : Colors.grey.withOpacity(0.2),
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8))
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              imageUrl: clinic['avatar_url'] as String?,
              size: _isHovered ? 110 : 90,
              fallbackRole: 'clinic',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: _isHovered ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontSize: _isHovered ? 16 : 14,
                color: const Color(0xFF0056B3),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  city,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _selectedTab = 'Pacientes'; // 'Pacientes', 'Doctores', 'Clínicas'
  final Set<String> _expandedQuestions = {};

  final Map<String, List<Map<String, dynamic>>> _faqData = {
    'Pacientes': [
      {
        'id': 'p1',
        'icon': Icons.health_and_safety,
        'title': '¿Qué es Salud Now y cómo funciona?',
        'desc': 'Conoce cómo funciona Salud Now, cómo buscar médicos y todo lo que puedes hacer con la app.',
        'answer':
            'Salud Now es una plataforma médica digital que conecta a pacientes con doctores y centros de salud en toda Venezuela.\n\n'
            '• Búsqueda inteligente: Encuentra especialistas por estado, ciudad y especialidad médica.\n'
            '• Agendamiento en tiempo real: Elige el día, turno y bloque de hora disponible sin hacer colas.\n'
            '• Historial de consultas: Visualiza tus récipes, turnos asignados y datos de consultorio desde tu teléfono o computadora.'
      },
      {
        'id': 'p2',
        'icon': Icons.person_add,
        'title': 'Creación de cuenta y verificación de identidad',
        'desc': 'Conoce todo sobre cómo puedes crear tu cuenta Salud Now y verificar tus datos.',
        'answer':
            'Crear tu cuenta es muy rápido y completamente gratuito:\n\n'
            '1. Presiona en "Registrarse" y selecciona tu perfil como Paciente.\n'
            '2. Ingresa tu nombre, correo electrónico, teléfono de contacto y estado de residencia.\n'
            '3. Configura una contraseña segura.\n'
            '4. Recibirás acceso inmediato para explorar el directorio médico y agendar consultas de inmediato.'
      },
      {
        'id': 'p3',
        'icon': Icons.login,
        'title': 'Inicio de Sesión y Seguridad',
        'desc': 'Conoce cómo puedes iniciar sesión en tu cuenta Salud Now con tus credenciales o biometría.',
        'answer':
            'Puedes iniciar sesión ingresando tu correo electrónico registrado y contraseña.\n\n'
            '• En la app móvil, puedes activar el ingreso rápido con huella o reconocimiento facial si tu dispositivo lo admite.\n'
            '• Para mantener tu cuenta protegida, nunca compartas tus credenciales de acceso con terceros.'
      },
      {
        'id': 'p4',
        'icon': Icons.security,
        'title': 'Recuperación de Contraseña',
        'desc': 'Descubre cómo recuperar el acceso a tu cuenta fácilmente si has olvidado tu clave.',
        'answer':
            'Si olvidaste tu clave de acceso:\n\n'
            '1. En la pantalla de inicio de sesión, toca "¿Olvidaste tu contraseña?".\n'
            '2. Escribe tu correo electrónico registrado.\n'
            '3. Recibirás un enlace o token seguro para restablecer tu contraseña y volver a ingresar sin complicaciones.'
      },
      {
        'id': 'p5',
        'icon': Icons.calendar_month,
        'title': '¿Cómo agendar, reprogramar o cancelar una cita?',
        'desc': 'Aprende a gestionar tus consultas médicas con especialistas desde la sección de citas.',
        'answer':
            '• Agendar: Ingresa al perfil del médico, selecciona la fecha deseada en su calendario, escoge el bloque horario y confirma tu turno.\n'
            '• Ver detalles: En la pestaña "Mis Citas", pulsa sobre cualquier tarjeta de cita para abrir la vista ampliada con tu número de turno, horario estimado y ubicación del consultorio.\n'
            '• Reprogramar o cancelar: Dentro de "Mis Citas" puedes reprogramar para una nueva fecha disponible o cancelar la cita si no podrás asistir.'
      },
      {
        'id': 'p6',
        'icon': Icons.history,
        'title': 'Historial Médico y Récipes Digitales',
        'desc': 'Conoce cómo acceder a tus récipes, indicaciones médicas e historial de atenciones.',
        'answer':
            'Salud Now guarda un registro ordenado de tus atenciones completadas:\n\n'
            '• En "Mis Citas" filtra por "Historial" para ver todas las citas finalizadas.\n'
            '• Podrás consultar los récipes médicos digitales emitidos por tus doctores tratantes, indicaciones farmacológicas y descargarlos cuando los necesites.'
      },
    ],
    'Doctores': [
      {
        'id': 'd1',
        'icon': Icons.medical_services,
        'title': '¿Cómo registrarme como médico especialista?',
        'desc': 'Pasos y requisitos para formar parte del directorio de especialistas de Salud Now.',
        'answer':
            'Para unirte a Salud Now como profesional médico:\n\n'
            '1. Selecciona "Registrarse" con el rol "Médico".\n'
            '2. Completa tus datos personales, especialidades médicas, número de colegiatura y estado de ejercicio profesional.\n'
            '3. Configura tu consultorio físico, honorarios de consulta y avatar o foto de perfil.\n'
            '4. Tu perfil quedará listo para activar tu agenda y recibir citas de pacientes.'
      },
      {
        'id': 'd2',
        'icon': Icons.calendar_today,
        'title': 'Gestión de agenda, horarios y turnos de consulta',
        'desc': 'Aprende a configurar tus días de consulta, bloques por paciente y turnos automáticos.',
        'answer':
            'Desde el panel del Doctor dispones de control total sobre tu tiempo:\n\n'
            '• Define tus días laborables y rangos horarios (ej. de 8:00 AM a 1:00 PM).\n'
            '• Establece la duración estimada de cada consulta (15, 30, 45 o 60 min).\n'
            '• El sistema asigna automáticamente números de turno correlativos a cada paciente para evitar sobrecupos y mantener la sala de espera organizada.\n'
            '• Puedes agregar citas manuales directamente si un paciente te contacta por vía externa.'
      },
      {
        'id': 'd3',
        'icon': Icons.local_hospital,
        'title': '¿Cómo vincularme a una clínica o policlínica aliada?',
        'desc': 'Únete al equipo médico de un centro asistencial usando su código de invitación.',
        'answer':
            'Si ejerces en un centro médico o clínica registrada en Salud Now:\n\n'
            '1. Solicita al administrador de la clínica su código de invitación exclusivo.\n'
            '2. En tu perfil de doctor, ingresa el código en la opción de vincularse a clínica.\n'
            '3. La clínica aprobará tu vinculación y aparecerás listado en el directorio de especialistas asociados a dicho centro asistencial.'
      },
      {
        'id': 'd4',
        'icon': Icons.card_membership,
        'title': 'Planes de Suscripción para Médicos y Métodos de Pago',
        'desc': 'Información sobre visibilidad destacada, planes disponibles y reporte de transferencias o Pago Móvil.',
        'answer':
            'Salud Now ofrece planes de suscripción para maximizar tu presencia y captación de pacientes:\n\n'
            '• Plan Básico / Destacado: Presencia preferencial en búsquedas por especialidad y ciudad.\n'
            '• Plan VIP / Patrocinado: Insignia dorada VIP, posición prioritaria en la portada y acceso ilimitado a todas las herramientas de gestión.\n'
            '• Pagos en Bs: Puedes reportar tus transferencias bancarias o Pago Móvil a la tasa oficial del BCV del día, las cuales son validadas rápidamente por administración.'
      },
      {
        'id': 'd5',
        'icon': Icons.description,
        'title': 'Emisión de Récipes e Indicaciones Médicas',
        'desc': 'Generación de recetas médicas digitales claras con tu membrete profesional.',
        'answer':
            'Al concluir una consulta médica presencial o virtual:\n\n'
            '• Redacta el diagnóstico, tratamiento prescrito, dosis e indicaciones clínicas.\n'
            '• El paciente recibirá el récipe en formato digital dentro de su aplicación y tú conservarás la copia en su expediente histórico.'
      },
    ],
    'Clínicas': [
      {
        'id': 'c1',
        'icon': Icons.domain,
        'title': '¿Cómo afiliar un centro médico, hospital o policlínica?',
        'desc': 'Conoce los beneficios y el proceso de registro corporativo para centros de salud.',
        'answer':
            'Salud Now permite a instituciones de salud gestionar su presencia médica de manera integral:\n\n'
            '1. Regístrate seleccionando la cuenta de "Clínica".\n'
            '2. Ingresa el nombre institucional, dirección física exacta, teléfonos de atención y especialidades ofrecidas.\n'
            '3. Sube el logotipo corporativo para que los pacientes te reconozcan en el directorio de Clínicas Aliadas.'
      },
      {
        'id': 'c2',
        'icon': Icons.group_add,
        'title': 'Invitar y administrar doctores de la institución',
        'desc': 'Genera códigos de invitación para que tus médicos formen parte del equipo de la clínica.',
        'answer':
            'Desde el panel administrativo de tu clínica:\n\n'
            '• Ve a la opción "Invitar Doctores" para generar un código único de vinculación.\n'
            '• Comparte este código con los especialistas de tu sede.\n'
            '• Revisa y aprueba solicitudes de doctores para agruparlos bajo el paraguas de tu clínica en la plataforma.'
      },
      {
        'id': 'c3',
        'icon': Icons.star,
        'title': 'Planes Clínicos y Posicionamiento Aliado',
        'desc': 'Mayor exposición para los servicios, laboratorios y emergencias de tu centro médico.',
        'answer':
            'Las clínicas suscritas cuentan con visibilidad destacada en la sección de Clínicas Aliadas:\n\n'
            '• Muestra tus servicios de hospitalización, emergencias, quirófanos y laboratorio.\n'
            '• Los pacientes pueden ubicar tu centro de salud por ciudad y contactar tus números de atención directa en un solo toque.'
      },
      {
        'id': 'c4',
        'icon': Icons.support_agent,
        'title': 'Canales de Soporte y Atención Administrativa',
        'desc': 'Resuelve dudas de facturación, suscripciones o configuración institucional.',
        'answer':
            'Dispones de una línea directa con nuestro equipo de soporte técnico y administrativo a través de la sección "Soporte" de la aplicación para asistirte con configuraciones institucionales o verificación de pagos corporativos.'
      },
    ],
  };

  void _showFaqDetailsModal(Map<String, dynamic> faq) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0056B3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(faq['icon'] as IconData, size: 28, color: const Color(0xFF0056B3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                faq['title'] as String,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  faq['answer'] as String,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.6),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (kIsWeb) const WebHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderSection(context),
                  _buildFaqGrid(context),
                  if (kIsWeb) const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 60,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Preguntas Frecuentes',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'En este espacio diseñado especialmente para ti, encontrarás respuestas a las preguntas\nfrecuentes sobre el uso de nuestra aplicación.',
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          // Tabs: Pacientes, Médicos, Clínicas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabButton('Pacientes'),
                  _buildTabButton('Médicos'),
                  _buildTabButton('Clínicas'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label) {
    final isSelected = (_selectedTab == label) ||
        (label == 'Médicos' && _selectedTab == 'Doctores');
    final targetValue = label == 'Médicos' ? 'Doctores' : label;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = targetValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F2937) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqGrid(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final String currentKey = _selectedTab == 'Médicos' ? 'Doctores' : _selectedTab;
    final List<Map<String, dynamic>> faqs = _faqData[currentKey] ?? _faqData['Pacientes']!;

    Widget buildFaqCard(Map<String, dynamic> faq) {
      final faqId = faq['id'] as String;
      final isExpanded = _expandedQuestions.contains(faqId);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedQuestions.remove(faqId);
              } else {
                _expandedQuestions.add(faqId);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isExpanded ? Colors.white : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded ? const Color(0xFF0056B3) : Colors.grey.withOpacity(0.2),
                width: isExpanded ? 1.5 : 1.0,
              ),
              boxShadow: isExpanded
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0056B3).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? const Color(0xFF0056B3).withOpacity(0.1)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isExpanded
                              ? const Color(0xFF0056B3).withOpacity(0.3)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Icon(
                        faq['icon'] as IconData,
                        size: 26,
                        color: isExpanded ? const Color(0xFF0056B3) : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        faq['title'] as String,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? const Color(0xFF0056B3) : Colors.black,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isExpanded ? const Color(0xFF0056B3) : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  faq['desc'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    faq['answer'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showFaqDetailsModal(faq),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Ver en ventana completa'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0056B3),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
      ),
      margin: const EdgeInsets.only(bottom: 80),
      child: isDesktop
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.7,
              ),
              itemCount: faqs.length,
              itemBuilder: (context, index) => buildFaqCard(faqs[index]),
            )
          : Column(
              children: faqs
                  .map((faq) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: buildFaqCard(faq),
                      ))
                  .toList(),
            ),
    );
  }
}

