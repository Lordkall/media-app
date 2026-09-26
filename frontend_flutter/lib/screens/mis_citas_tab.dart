import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../core/profile_image_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class MisCitasTab extends StatefulWidget {
  const MisCitasTab({super.key});

  @override
  State<MisCitasTab> createState() => _MisCitasTabState();
}

class _MisCitasTabState extends State<MisCitasTab> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchAppointments();
  }

  Future<void> _loadRole() async {
    final role = await AuthHelper.getRole();
    if (mounted) {
      setState(() {
        _role = role;
      });
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      final response = await ApiClient.get('/appointments/my');
      if (response.statusCode == 200) {
        setState(() {
          _appointments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFF00A896), size: 28),
                      const SizedBox(width: 8),
                      const Text('Mis Citas Médicas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fecha:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F1F8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Color(0xFF0056B3), size: 20),
                              const SizedBox(width: 8),
                              Text('${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}', style: const TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_appointments.where((a) => a['date'].startsWith(_selectedDate.toIso8601String().split('T')[0])).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('No tienes citas para este día.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._appointments
                        .where((a) => a['date'].startsWith(_selectedDate.toIso8601String().split('T')[0]))
                        .map((appt) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0056B3),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,3))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 60, height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            image: DecorationImage(
                                              image: ProfileImageHelper.getProfileImageProvider(appt['doctor_avatar']), 
                                              fit: BoxFit.cover
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appt['doctor_name'] ?? 'Desconocido', 
                                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: appt['status'] == 'scheduled' ? Colors.green : Colors.orange,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  appt['status'] == 'scheduled' ? 'PROGRAMADA' : (appt['status'] == 'cancelled' ? 'CANCELADA' : appt['status'].toString().toUpperCase()), 
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (_role != 'doctor') ...[
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
                                                    const SizedBox(width: 4),
                                                    Expanded(child: Text(appt['doctor_location'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              Text('${_role == 'doctor' ? 'Motivo' : 'Especialidad'}: ${appt['doctor_specialty'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        if (appt['patient_phone'] != null && appt['patient_phone'].toString().isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.message, color: Colors.greenAccent, size: 32),
                                            onPressed: () async {
                                              final phone = appt['patient_phone'].toString().replaceAll(RegExp(r'[^\d+]'), '');
                                              final url = Uri.parse('https://wa.me/$phone');
                                              try {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              if (appt['status'] == 'cancelled') return;
                                              try {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelando cita...')));
                                                final resp = await ApiClient.patch('/appointments/${appt["id"]}/cancel', {});
                                                if (resp.statusCode == 200) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada con éxito')));
                                                  _fetchAppointments();
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                              }
                                            },
                                            child: Text(
                                              appt['status'] == 'cancelled' ? 'Cancelada' : 'Cancelar Cita', 
                                              style: TextStyle(
                                                color: appt['status'] == 'cancelled' ? Colors.grey : const Color(0xFFFFA07A), 
                                                fontSize: 16, 
                                                fontWeight: FontWeight.bold
                                              )
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${appt["date"]}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                            Text('${appt["time_block"] ?? ""} - Turno #${appt["turn_number"]}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
