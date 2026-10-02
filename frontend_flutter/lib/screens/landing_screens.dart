import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import '../core/api_client.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';

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
            'Reserva con los mejores especialistas, accede a tu historial mÃ©dico y recibe recordatorios. RegÃ­strate o descarga nuestra app y comienza a cuidar de ti.',
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
            'Somos la alternativa mÃ¡s accesible para que gestiones tu salud hoy.',
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
                title: 'Agenda tus citas fÃ¡cilmente',
                text: 'Encuentra al especialista que necesitas y agenda tu consulta en 3 minutos. Descarga nuestra app, regÃ­strate y comienza.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.health_and_safety,
                title: 'Conoce nuestras clÃ­nicas aliadas',
                text: 'Traemos muchas opciones de salud para ti. Desde tus clÃ­nicas y doctores favoritos hasta laboratorios y farmacias.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.star,
                title: 'AmplÃ­a tus beneficios',
                text: 'Al utilizar nuestra plataforma accederÃ¡s a funciones VIP, historiales compartidos y descuentos especiales.',
                color: const Color(0xFF0056B3),
              ),
              _buildFeatureCard(
                icon: Icons.handshake,
                title: 'Estamos siempre contigo',
                text: 'Te enviaremos recordatorios para que nunca faltes a una cita y puedas mantener tu salud al dÃ­a.',
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
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Map<String, dynamic>> doctors = data.map((e) => e as Map<String, dynamic>).toList();
        
        doctors.shuffle(Random());
        setState(() {
          _doctors = doctors.take(8).toList();
          _isLoading = false;
        });
      } else {
        _useFallbackDoctors();
      }
    } catch (e) {
      _useFallbackDoctors();
    }
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
    final String avatarUrl = doc['avatar_url'] ?? '';
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _isHovered ? const Color(0xFF0056B3) : Colors.grey.withOpacity(0.2)),
          boxShadow: _isHovered
              ? [BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 8))]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFF0056B3),
              backgroundImage: avatarUrl.startsWith('http') || avatarUrl.startsWith('assets') 
                  ? (avatarUrl.startsWith('http') ? NetworkImage(avatarUrl) : AssetImage(avatarUrl) as ImageProvider)
                  : null,
              child: (avatarUrl.isEmpty || (!avatarUrl.startsWith('http') && !avatarUrl.startsWith('assets')))
                  ? Text(
                      doc['name']!.substring(4, 5) + doc['name']!.split(' ').last.substring(0, 1),
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                doc['name']!,
                style: const TextStyle(
                  fontSize: 18,
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
              doc['specialty']!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0056B3),
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

class AlliedClinicsScreen extends StatelessWidget {
  const AlliedClinicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClÃ­nicas Aliadas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Pantalla ClÃ­nicas Aliadas en construcciÃ³n...'),
      ),
    );
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preguntas Frecuentes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Pantalla Preguntas Frecuentes en construcciÃ³n...'),
      ),
    );
  }
}

