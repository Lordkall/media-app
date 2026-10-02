import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

class AlliedDoctorsScreen extends StatelessWidget {
  const AlliedDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctores Aliados'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Pantalla Doctores Aliados en construcción...'),
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
        title: const Text('Clínicas Aliadas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Pantalla Clínicas Aliadas en construcción...'),
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
        child: Text('Pantalla Preguntas Frecuentes en construcción...'),
      ),
    );
  }
}
