import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agendar_cita_tab.dart';
import '../core/profile_image_helper.dart';

class DoctorProfileScreen extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final name = 'Dr. ${doctor['first_name']} ${doctor['last_name']}';
    final specialties = (doctor['specialties'] as List<dynamic>?)?.join(', ') ?? 'Médico General';
    final isVip = doctor['is_vip'] == true;
    final imageUrl = doctor['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Doctor', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isVip ? const Color(0xFFFFC107) : const Color(0xFF0056B3), width: 3),
                    image: DecorationImage(image: ProfileImageHelper.getProfileImageProvider(imageUrl), fit: BoxFit.cover),
                  ),
                ),
                if (isVip)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                    child: const Icon(Icons.star, color: Colors.white, size: 24),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
            const SizedBox(height: 8),
            Text(specialties, style: const TextStyle(fontSize: 16, color: Color(0xFF475569))),
            const SizedBox(height: 16),
            const Text('Biografía', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
            const SizedBox(height: 8),
            const Text(
              'Médico especialista con más de 10 años de experiencia brindando atención integral y personalizada a cada paciente.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información de Consulta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  const ListTile(
                    leading: Icon(Icons.location_on, color: Color(0xFF0056B3)),
                    title: Text('Dirección de consultorio'),
                    subtitle: Text('Caracas, Venezuela (Pendiente por definir)'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.calendar_today, color: Color(0xFF0056B3)),
                    title: Text('Días Laborables'),
                    subtitle: Text('Lunes a Viernes'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.access_time, color: Color(0xFF0056B3)),
                    title: Text('Horario'),
                    subtitle: Text('08:00 AM - 05:00 PM'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.attach_money, color: Color(0xFF0056B3)),
                    title: Text('Precio de Consulta'),
                    subtitle: Text('\$40.00'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF0056B3)),
                    title: const Text('Teléfono'),
                    subtitle: const Text('+58 412 000 0000'),
                    trailing: IconButton(
                      icon: const Icon(Icons.message, color: Colors.green),
                      onPressed: () async {
                        final Uri url = Uri.parse('https://wa.me/584120000000');
                        if (!await launchUrl(url)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgendarCitaTab()));
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Agendar Cita', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056B3),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          ],
        ),
      ),
    );
  }
}
