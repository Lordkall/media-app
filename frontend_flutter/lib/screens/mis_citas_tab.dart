import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../widgets/profile_avatar.dart';
import '../models/ve_catalogs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'manual_appointment_sheet.dart';
import 'reschedule_appointment_sheet.dart';

class MisCitasTab extends StatefulWidget {
  const MisCitasTab({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  State<MisCitasTab> createState() => _MisCitasTabState();
}

class _MisCitasTabState extends State<MisCitasTab> {
  Future<void> _deleteAppointment(Map<String, dynamic> appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar Cita'),
        content: const Text(
            '¿Estás seguro de que deseas eliminar esta cita del historial?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eliminando cita...')));
        final resp = await ApiClient.delete('/appointments/${appt["id"]}');
        if (!mounted) return;
        if (resp.statusCode == 200 || resp.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cita eliminada')));
          _fetchAppointments();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${resp.body}')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appt) {
    final isDoctor = _doctorView;
    final otherPersonName = appt['doctor_name'] ?? 'Desconocido';
    final specialty = appt['doctor_specialty'] ?? (isDoctor ? 'Consulta Médica' : 'General');
    final date = appt['date']?.toString() ?? '';
    final time = appt['time_block']?.toString() ?? 'Hora pendiente';
    final turn = appt['turn_number']?.toString() ?? '-';
    final location = appt['doctor_location']?.toString() ?? '';
    final reason = appt['appointment_reason']?.toString() ?? (appt['reason']?.toString() ?? 'Consulta Médica');
    final status = (appt['status'] ?? 'scheduled').toString().toLowerCase();
    final avatarUrl = appt['doctor_avatar'] as String?;
    final String displayStatus = status == 'scheduled'
        ? 'PROGRAMADA'
        : (status == 'cancelled' ? 'CANCELADA' : status.toUpperCase());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      ProfileAvatar(
                        imageUrl: avatarUrl,
                        size: 84,
                        fallbackRole: isDoctor ? 'patient' : 'doctor',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        otherPersonName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0056B3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'scheduled'
                              ? Colors.green.shade600
                              : (status == 'cancelled' ? Colors.red.shade400 : Colors.blueGrey),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          displayStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F1F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: Color(0xFF0056B3), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TURNO ASIGNADO',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                            Text('Turno #$turn',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today, 'Fecha', date),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time, 'Hora estimada / Bloque', time),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on, 'Ubicación / Consultorio', location),
                ],
                if (appt['patient_phone'] != null && appt['patient_phone'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.phone, 'Teléfono del paciente', appt['patient_phone'].toString()),
                ],
                if (reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.medical_services_outlined, 'Motivo de consulta', reason),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0056B3)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF0B2545), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }


  late DateTime _selectedDate = widget.initialDate ?? caracasNow();
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
    if (_filterMode == 'Fecha') {
      final date = _selectedDate.toIso8601String().split('T')[0];
      return _appointments
          .where((a) => a['date'].toString().startsWith(date))
          .toList();
    }
    final now = caracasNow();
    if (_filterMode == 'Historial') {
      final past = _appointments.where((a) {
        final aDateTime = _appointmentDateTime(a);
        return aDateTime.isBefore(now) || a['status'] == 'completed' || a['status'] == 'cancelled';
      }).toList();
      past.sort((a, b) => _appointmentDateTime(b).compareTo(_appointmentDateTime(a)));
      return past;
    }
    
    // Más próximas
    final upcoming = _appointments.where((a) {
      final aDateTime = _appointmentDateTime(a);
      return !aDateTime.isBefore(now) && a['status'] == 'scheduled';
    }).toList();
    upcoming.sort((a, b) => _appointmentDateTime(a).compareTo(_appointmentDateTime(b)));
    return upcoming;
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
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month,
                            color: Color(0xFF00A896), size: 28),
                        SizedBox(width: 8),
                        Text('Mis Citas Médicas',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545))),
                      ],
                    ),
                    if (_canManageAppointments) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _newManualAppointment,
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva cita manual'),
                      ),
                    ],
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
                                child: Text('Próximas citas')),
                            DropdownMenuItem(
                                value: 'Historial',
                                child: Text('Historial')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _filterMode = value);
                            }
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
                      ..._visibleAppointments.map((appt) => Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showAppointmentDetails(appt),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0056B3),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                          offset: Offset(0, 3))
                                    ],
                                  ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ProfileAvatar(
                                          imageUrl:
                                              appt['doctor_avatar']?.toString(),
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
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: appt['status'] ==
                                                        'scheduled'
                                                    ? Colors.green
                                                    : Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                  appt['status'] == 'scheduled'
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
                                                  const Icon(Icons.location_on,
                                                      color: Colors.redAccent,
                                                      size: 14),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                      child: Text(
                                                          appt['doctor_location'] ??
                                                              '',
                                                          style:
                                                              const TextStyle(
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (appt['patient_phone'] != null &&
                                              appt['patient_phone']
                                                  .toString()
                                                  .isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.message,
                                                  color: Colors.greenAccent,
                                                  size: 28),
                                              tooltip: 'WhatsApp',
                                              onPressed: () async {
                                                final phone = appt['patient_phone']
                                                    .toString()
                                                    .replaceAll(
                                                        RegExp(r'[^\d+]'), '');
                                                final url = Uri.parse(
                                                    'https://wa.me/$phone');
                                                try {
                                                  await launchUrl(url,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(const SnackBar(
                                                            content: Text(
                                                                'No se pudo abrir WhatsApp')));
                                                  }
                                                }
                                              },
                                            ),
                                          if (_filterMode == 'Historial')
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                  size: 26),
                                              tooltip: 'Eliminar del historial',
                                              onPressed: () => _deleteAppointment(appt),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                        Expanded(
                                          child: appt['status'] == 'scheduled'
                                              ? Wrap(
                                                  spacing: 16,
                                                  runSpacing: 8,
                                                  children: [
                                                    if (!_doctorView) ...[
                                                      GestureDetector(
                                                        onTap: () async {
                                                          final success = await showModalBottomSheet<bool>(
                                                            context: context,
                                                            isScrollControlled: true,
                                                            useSafeArea: true,
                                                            backgroundColor: Theme.of(context).colorScheme.surface,
                                                            builder: (_) => RescheduleAppointmentSheet(
                                                              appointmentId: appt['id'],
                                                              doctorId: appt['doctor_id'],
                                                            ),
                                                          );
                                                          if (success == true) {
                                                            _fetchAppointments();
                                                          }
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.18),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.edit_calendar, size: 14, color: Colors.white),
                                                              SizedBox(width: 5),
                                                              Text(
                                                                'Reprogramar',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    GestureDetector(
                                                      onTap: () async {
                                                        try {
                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelando cita...')));
                                                          final resp = await ApiClient.patch('/appointments/${appt["id"]}/cancel', {});
                                                          if (!context.mounted) return;
                                                          if (resp.statusCode == 200) {
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada con éxito')));
                                                            _fetchAppointments();
                                                          } else {
                                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
                                                          }
                                                        } catch (e) {
                                                          if (!context.mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.22),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.cancel_outlined, size: 14, color: Colors.white),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Cancelar Cita',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                                                             : Text(
                                                   appt['status'] == 'cancelled' ? 'Cancelada' : 'Completada',
                                                   style: TextStyle(
                                                       color: appt['status'] == 'cancelled' ? Colors.grey : Colors.white70,
                                                       fontSize: 16,
                                                       fontWeight: FontWeight.bold),
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
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                                  ),
                                ),
                              ),
                            ),
                          )),
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
