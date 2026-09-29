import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../widgets/profile_avatar.dart';
import '../models/ve_catalogs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'manual_appointment_sheet.dart';

class MisCitasTab extends StatefulWidget {
  const MisCitasTab({super.key});

  @override
  State<MisCitasTab> createState() => _MisCitasTabState();
}

class _MisCitasTabState extends State<MisCitasTab> {
  DateTime _selectedDate = caracasNow();
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String? _role;
  String _filterMode = 'Fecha';
  bool get _canManageAppointments => _role == 'doctor' || _role == 'assistant';
  bool get _doctorView => _canManageAppointments;

  DateTime _appointmentDateTime(dynamic appointment) {
    final rawDate = appointment['date']?.toString() ?? '';
    final date =
        DateTime.tryParse(rawDate.split('T').first) ?? DateTime(9999, 12, 31);
    final timeBlock = appointment['time_block']?.toString() ?? '';
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false)
        .firstMatch(timeBlock);
    if (match == null) return date;

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  List<dynamic> get _visibleAppointments {
    final activeAppointments = _appointments
        .where((appointment) => appointment['status'] != 'cancelled');
    if (_filterMode == 'Fecha') {
      final date = _selectedDate.toIso8601String().split('T')[0];
      return activeAppointments
          .where((a) => a['date'].toString().startsWith(date))
          .toList();
    }
    final recent = List<dynamic>.from(activeAppointments);
    final now = caracasNow();
    recent.sort((a, b) {
      final aDateTime = _appointmentDateTime(a);
      final bDateTime = _appointmentDateTime(b);
      final aUpcoming = !aDateTime.isBefore(now);
      final bUpcoming = !bDateTime.isBefore(now);
      if (aUpcoming != bUpcoming) return aUpcoming ? -1 : 1;
      // Put the closest future appointment first. For past appointments,
      // retain the most recently completed appointment at the top of history.
      final byDate = aUpcoming
          ? aDateTime.compareTo(bDateTime)
          : bDateTime.compareTo(aDateTime);
      if (byDate != 0) return byDate;
      return (int.tryParse(a['id'].toString()) ?? 0)
          .compareTo(int.tryParse(b['id'].toString()) ?? 0);
    });
    return recent;
  }

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
          _appointments = (jsonDecode(response.body) as List<dynamic>)
              .where((appointment) => appointment['status'] != 'cancelled')
              .toList();
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
      firstDate: caracasNow().subtract(const Duration(days: 365)),
      lastDate: caracasNow().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _newManualAppointment() async {
    if (!_canManageAppointments) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const ManualAppointmentSheet(),
    );
    if (saved == true && mounted) {
      setState(() => _filterMode = 'Más próximas');
      await _fetchAppointments();
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _canManageAppointments
            ? FloatingActionButton.extended(
                onPressed: _newManualAppointment,
                icon: const Icon(Icons.add),
                label: const Text('Nueva cita manual'),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            color: Color(0xFF00A896), size: 28),
                        const SizedBox(width: 8),
                        const Text('Mis Citas Médicas',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: _filterMode,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: 'Fecha',
                                child: Text('Filtrar por fecha')),
                            DropdownMenuItem(
                                value: 'Más próximas',
                                child: Text('Más próximas')),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _filterMode = value);
                          },
                        ),
                        if (_filterMode == 'Fecha')
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2F1F8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month,
                                      color: Color(0xFF0056B3), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                      style: const TextStyle(
                                          color: Color(0xFF0056B3),
                                          fontWeight: FontWeight.bold)),
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
                    else if (_visibleAppointments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text('No hay citas para este filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._visibleAppointments
                          .map((appt) => Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0056B3),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                          offset: Offset(0, 3))
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ProfileAvatar(
                                              imageUrl: appt['doctor_avatar']
                                                  ?.toString(),
                                              fallbackRole: 'doctor',
                                              size: 60),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  appt['doctor_name'] ??
                                                      'Desconocido',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: appt['status'] ==
                                                            'scheduled'
                                                        ? Colors.green
                                                        : Colors.orange,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                      appt['status'] ==
                                                              'scheduled'
                                                          ? 'PROGRAMADA'
                                                          : (appt['status'] ==
                                                                  'cancelled'
                                                              ? 'CANCELADA'
                                                              : appt['status']
                                                                  .toString()
                                                                  .toUpperCase()),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                                const SizedBox(height: 8),
                                                if (!_doctorView) ...[
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.location_on,
                                                          color:
                                                              Colors.redAccent,
                                                          size: 14),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                          child: Text(
                                                              appt['doctor_location'] ??
                                                                  '',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      12))),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                                Text(
                                                    '${_doctorView ? 'Motivo' : 'Especialidad'}: ${appt['doctor_specialty'] ?? ''}',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          if (appt['patient_phone'] != null &&
                                              appt['patient_phone']
                                                  .toString()
                                                  .isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.message,
                                                  color: Colors.greenAccent,
                                                  size: 32),
                                              onPressed: () async {
                                                final phone =
                                                    appt['patient_phone']
                                                        .toString()
                                                        .replaceAll(
                                                            RegExp(r'[^\d+]'),
                                                            '');
                                                final url = Uri.parse(
                                                    'https://wa.me/$phone');
                                                try {
                                                  await launchUrl(url,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                } catch (e) {
                                                  if (mounted)
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'No se pudo abrir WhatsApp')));
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () async {
                                                if (appt['status'] ==
                                                    'cancelled') return;
                                                try {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'Cancelando cita...')));
                                                  final resp =
                                                      await ApiClient.patch(
                                                          '/appointments/${appt["id"]}/cancel',
                                                          {});
                                                  if (resp.statusCode == 200) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Cita cancelada con éxito')));
                                                    _fetchAppointments();
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                'Error: ${resp.body}')));
                                                  }
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Error: $e')));
                                                }
                                              },
                                              child: Text(
                                                  appt['status'] == 'cancelled'
                                                      ? 'Cancelada'
                                                      : 'Cancelar Cita',
                                                  style: TextStyle(
                                                      color: appt['status'] ==
                                                              'cancelled'
                                                          ? Colors.grey
                                                          : const Color(
                                                              0xFFFFA07A),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text('${appt["date"]}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14)),
                                              Text(
                                                  '${appt["time_block"] ?? ""} - Turno #${appt["turn_number"]}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold)),
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
      ),
    );
  }
}
