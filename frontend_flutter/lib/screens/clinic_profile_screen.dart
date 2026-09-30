import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/profile_avatar.dart';
import 'dart:convert';
import 'doctor_profile_screen.dart';

class ClinicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> clinic;
  const ClinicProfileScreen({super.key, required this.clinic});

  @override
  State<ClinicProfileScreen> createState() => _ClinicProfileScreenState();
}

class _ClinicProfileScreenState extends State<ClinicProfileScreen> {
  bool _isLoading = true;
  List<dynamic> _doctors = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final response =
          await ApiClient.get('/clinics/${widget.clinic['id']}/doctors');
      if (response.statusCode == 200) {
        setState(() {
          _doctors = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clinic['first_name'] ?? 'Clínica',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(
                        imageUrl: widget.clinic['avatar_url']?.toString(),
                        fallbackRole: 'clinic',
                        size: 80,
                        borderColor: widget.clinic['is_vip'] == true
                            ? const Color(0xFFFFC107)
                            : Colors.transparent,
                        borderWidth: widget.clinic['is_vip'] == true ? 3 : 0,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.clinic['first_name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(widget.clinic['address'] ?? 'Sin dirección',
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Descripción',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.clinic['description'] ?? 'Sin descripción.',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  const Text('Contactos',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.clinic['phone'] ?? 'Sin número de contacto principal',
                      style: const TextStyle(fontSize: 16)),
                  if (widget.clinic['contact_phone_2'] != null &&
                      widget.clinic['contact_phone_2'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(widget.clinic['contact_phone_2'].toString(),
                        style: const TextStyle(fontSize: 16)),
                  ],
                  const SizedBox(height: 24),
                  const Text('Doctores Asociados',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_doctors.isEmpty)
                    const Text('No hay doctores registrados en esta clínica.')
                  else
                    ..._doctors.map((doc) => Card(
                          child: ListTile(
                            leading: ProfileAvatar(
                                imageUrl: doc['avatar_url']?.toString(),
                                fallbackRole: 'doctor',
                                size: 44),
                            title: Text(
                                'Dr. ${doc['first_name']} ${doc['last_name']}'),
                            subtitle: Text(
                                (doc['specialties'] as List<dynamic>?)
                                        ?.join(', ') ??
                                    'Médico General'),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          DoctorProfileScreen(doctor: doc)));
                            },
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
