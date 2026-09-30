import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';
import 'agendar_cita_tab.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final Future<Map<String, String>> _schedule = _loadSchedule();

  Future<Map<String, String>> _loadSchedule() async {
    final id = widget.doctor['id'];
    if (id == null) return {'days': 'No disponible', 'hours': 'No disponible'};
    try {
      final response = await ApiClient.get('/doctors/$id/availability');
      if (response.statusCode != 200) {
        return {'days': 'No disponible', 'hours': 'No disponible'};
      }
      final rows = jsonDecode(response.body) as List<dynamic>;
      final today = caracasNow();
      final dayNames = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo'
      ];
      final days = <int>{};
      final hours = <String>{};
      for (final row in rows) {
        final date = DateTime.tryParse(row['date']?.toString() ?? '');
        if (date == null ||
            date.isBefore(DateTime(today.year, today.month, today.day))) {
          continue;
        }
        days.add(date.weekday);
        final start = _formatTime(row['start_time']?.toString());
        final end = _formatTime(row['end_time']?.toString());
        if (start != null && end != null) hours.add('$start - $end');
      }
      final sortedDays = days.toList()..sort();
      return {
        'days': sortedDays.isEmpty
            ? 'Sin días configurados'
            : sortedDays.map((day) => dayNames[day - 1]).join(', '),
        'hours': hours.isEmpty ? 'Sin horario configurado' : hours.join(' / '),
      };
    } catch (_) {
      return {'days': 'No disponible', 'hours': 'No disponible'};
    }
  }

  String? _formatTime(String? value) {
    if (value == null || value.length < 5) return null;
    final parts = value.substring(0, 5).split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final name = 'Dr. ${doctor['first_name']} ${doctor['last_name']}';
    final specialties = (doctor['specialties'] as List<dynamic>?)?.join(', ') ??
        'Médico General';
    final isVip = doctor['is_vip'] == true;
    final imageUrl = doctor['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Doctor',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ProfileAvatar(
                  imageUrl: imageUrl?.toString(),
                  fallbackRole: 'doctor',
                  size: 120,
                  borderColor:
                      isVip ? const Color(0xFFFFC107) : const Color(0xFF0056B3),
                  borderWidth: 3,
                ),
                if (isVip)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFC107), shape: BoxShape.circle),
                    child:
                        const Icon(Icons.star, color: Colors.white, size: 24),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545))),
            const SizedBox(height: 8),
            Text(specialties,
                style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('Biografía',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545))),
            const SizedBox(height: 8),
            Text(
              doctor['bio']?.toString().isNotEmpty == true
                  ? doctor['bio'].toString()
                  : 'Médico especialista con atención integral y personalizada.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información de Consulta',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  ListTile(
                      leading: const Icon(Icons.location_on,
                          color: Color(0xFF0056B3)),
                      title: const Text('Dirección de consultorio'),
                      subtitle: Text(doctor['address'] ??
                          doctor['state'] ??
                          'Ubicación pendiente')),
                  FutureBuilder<Map<String, String>>(
                    future: _schedule,
                    builder: (context, snapshot) {
                      final schedule = snapshot.data ??
                          {'days': 'Cargando...', 'hours': 'Cargando...'};
                      return Column(
                        children: [
                          ListTile(
                              leading: const Icon(Icons.calendar_today,
                                  color: Color(0xFF0056B3)),
                              title: const Text('Días laborables esta semana'),
                              subtitle: Text(schedule['days']!)),
                          ListTile(
                              leading: const Icon(Icons.access_time,
                                  color: Color(0xFF0056B3)),
                              title: const Text('Horario'),
                              subtitle: Text(schedule['hours']!)),
                        ],
                      );
                    },
                  ),
                  ListTile(
                      leading: const Icon(Icons.attach_money,
                          color: Color(0xFF0056B3)),
                      title: const Text('Precio de Consulta'),
                      subtitle:
                          Text('\$${doctor['consultation_fee'] ?? '40.00'}')),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF0056B3)),
                    title: const Text('Teléfono'),
                    subtitle: const Text('+58 412 000 0000'),
                    trailing: IconButton(
                      icon: const Icon(Icons.message, color: Colors.green),
                      onPressed: () async {
                        final url = Uri.parse('https://wa.me/584120000000');
                        if (!await launchUrl(url) && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('No se pudo abrir WhatsApp')));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AgendarCitaTab(
                      initialDoctorId: int.tryParse(doctor['id'].toString())))),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Agendar Cita', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
